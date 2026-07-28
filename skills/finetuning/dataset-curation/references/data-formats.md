# Data Formats for Fine-Tuning

Use this when:

- Writing or reviewing code that emits or consumes training JSONL
- Choosing between messages, prompt/completion, and preference-pair schemas
- Implementing completion-only loss masking
- Debugging chat-template or tokenizer issues (doubled BOS, missing EOS, truncation eating the answer)
- Converting Alpaca/ShareGPT/completion data into the messages format

Skip this file if:

- You need the curation pipeline and hygiene gates → [../SKILL.md](../SKILL.md)
- You need preference-pair *generation strategy* → [../../preference-tuning/SKILL.md](../../preference-tuning/SKILL.md)

## SFT: the messages format (canonical)

One JSON object per line; `messages` is the only structural field trainers
read — keep provenance metadata as sibling top-level keys, never inside turns:

```json
{"id": "sup-00412", "source": "support-tickets-q2", "task_type": "howto",
 "messages": [
   {"role": "system", "content": "You are the support assistant for Acme CRM."},
   {"role": "user", "content": "How do I export my contacts?"},
   {"role": "assistant", "content": "Settings → Data → Export as CSV."}
 ]}
```

Field rules:

- `role` ∈ `system | user | assistant` (plus `tool` roles only when training
  tool use *and* the chat template supports them — verify the template first).
- At most one system turn, and only at index 0.
- Strict user/assistant alternation after the system turn; final turn is
  `assistant` (it carries the loss).
- `content` is a non-empty string. Empty assistant turns train the model to
  say nothing.

## Preference pairs (chosen/rejected)

Two common shapes; TRL-class trainers accept both (naming varies by version —
verify current TRL docs via context7):

```json
{"prompt": "Summarize this ticket: …",
 "chosen": "Concise, accurate summary.",
 "rejected": "Rambling summary that invents details."}
```

Conversational form — prompt is a message list, responses are assistant turns:

```json
{"prompt": [{"role": "user", "content": "Summarize this ticket: …"}],
 "chosen": [{"role": "assistant", "content": "Concise, accurate summary."}],
 "rejected": [{"role": "assistant", "content": "Rambling summary…"}]}
```

Rules: `chosen` and `rejected` share the *identical* prompt; the difference
between them should embody the preference dimension, not confounds (length,
markdown) — see [../../preference-tuning/SKILL.md](../../preference-tuning/SKILL.md).

## Completion-only masking

Cross-entropy ignores label `-100`. Completion-only masking sets labels to
`-100` on everything except assistant-turn tokens, so the model learns to
*produce* answers rather than imitate users and boilerplate:

```python
def mask_labels(input_ids: list[int], assistant_spans: list[tuple[int, int]]) -> list[int]:
    """Labels = input_ids inside assistant spans, -100 (ignored) elsewhere."""
    labels = [-100] * len(input_ids)
    for start, end in assistant_spans:
        labels[start:end] = input_ids[start:end]
    return labels
```

In practice you rarely hand-roll this: TRL exposes assistant-only /
completion-only loss via config flags or collators, with names that have
changed across versions — verify the current TRL docs (context7) and then
**check one batch**: decode the tokens where `labels != -100` and confirm they
are exactly the assistant text. Skipping that check is how prompt-imitation
bugs ship.

Also mask padding positions to `-100` (standard collators do); training loss
on pad tokens — especially when `pad == eos` — teaches degenerate stopping.

## chat_template.jinja mechanics

The chat template is a Jinja2 program stored in the tokenizer config that
renders `messages` into the exact token stream:

```python
text = tok.apply_chat_template(rec["messages"], tokenize=False,
                               add_generation_prompt=False)
print(text)  # eyeball: one BOS, role delimiters, EOS after the assistant turn
```

- `add_generation_prompt=False` for training text (the assistant turn is
  present); `True` at inference to append the empty assistant header the
  model will complete.
- Base checkpoints often ship a generic or missing template; instruct
  variants ship a specific one. **Training with template A and serving with
  template B is a silent quality collapse** — render-and-diff train vs serve
  paths once per model change.
- Some templates drop, merge, or relocate system turns. Verify what *your*
  template does with a system message instead of assuming.
- Keep the rendered sample in the PR/review artifact — reviewers can't audit
  a template they've never seen rendered.

## Tokenizer edge cases

| Edge case | Symptom | Handling |
|-----------|---------|----------|
| No pad token (common for causal LMs) | Collator crash or silent `pad = None` | `tok.pad_token = tok.eos_token` is the common fix — then ensure pad positions are label-masked, or the model unlearns EOS |
| Doubled BOS | Template emits BOS *and* tokenizer adds one | Tokenize one rendered sample; inspect ids; set `add_special_tokens=False` on pre-templated text |
| Missing EOS after assistant turn | Model never stops at inference | Confirm the template appends EOS/end-turn marker to assistant turns |
| Truncation side | `truncation_side="right"` cuts off the *answer* (the loss) | Prefer structured truncation: drop leading turns, keep system + final assistant turn; if token-truncating prompts, truncate left |
| Added special tokens (new role markers) | Index errors or frozen random embeddings | `model.resize_token_embeddings(len(tok))`; note that adapters trained this way are incompatible with the unmodified base — record it in the run config |
| Tokenizer/model revision mismatch | Off-by-one vocab, garbage generations | Pin the same `revision` for model and tokenizer |

## Format validator

Run before dedup and after every conversion
(`uv run python -m data.validate data/sft/train.jsonl`):

```python
"""Validate messages-format JSONL; exit non-zero on any invalid record."""
import json
import sys
from pathlib import Path

from pydantic import BaseModel, field_validator

ROLES = {"system", "user", "assistant"}


class Message(BaseModel):
    role: str
    content: str

    @field_validator("role")
    @classmethod
    def role_known(cls, v: str) -> str:
        if v not in ROLES:
            raise ValueError(f"unknown role {v!r}")
        return v

    @field_validator("content")
    @classmethod
    def content_nonempty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("empty content")
        return v


class Record(BaseModel):
    messages: list[Message]

    @field_validator("messages")
    @classmethod
    def structure(cls, v: list[Message]) -> list[Message]:
        turns = v[1:] if v and v[0].role == "system" else v
        if not turns or turns[-1].role != "assistant":
            raise ValueError("must end on an assistant turn")
        for i, m in enumerate(turns):
            expected = "user" if i % 2 == 0 else "assistant"
            if m.role != expected:
                raise ValueError(f"turn {i}: expected {expected}, got {m.role}")
        return v


def main(path: str) -> int:
    bad = 0
    for lineno, line in enumerate(Path(path).read_text().splitlines(), 1):
        try:
            Record.model_validate(json.loads(line))
        except (ValueError, json.JSONDecodeError) as exc:
            bad += 1
            print(f"{path}:{lineno}: {exc}")
    print(f"{'FAIL' if bad else 'OK'}: {bad} invalid records")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
```

Wire it as a pipeline gate: a batch with any invalid record is quarantined
(see [../SKILL.md](../SKILL.md) pipeline table).

## Converting between common formats

| From | Shape | Mapping to messages |
|------|-------|---------------------|
| Alpaca | `{instruction, input, output}` | user = instruction (+ blank line + input when present); assistant = output |
| ShareGPT | `{conversations: [{from: human/gpt/system, value}]}` | `human→user`, `gpt→assistant`, `system→system`; drop trailing non-assistant turns |
| Completion pairs | `{prompt, completion}` | user = prompt; assistant = completion |

```python
def from_alpaca(rec: dict) -> dict:
    user = rec["instruction"] + (f"\n\n{rec['input']}" if rec.get("input") else "")
    return {"messages": [
        {"role": "user", "content": user},
        {"role": "assistant", "content": rec["output"]},
    ]}


SHAREGPT_ROLE = {"human": "user", "gpt": "assistant", "system": "system"}


def from_sharegpt(rec: dict) -> dict:
    msgs = [{"role": SHAREGPT_ROLE[m["from"]], "content": m["value"]}
            for m in rec["conversations"]]
    while msgs and msgs[-1]["role"] != "assistant":
        msgs.pop()
    return {"messages": msgs}
```

After **any** conversion, re-run the validator, the dedup scan, and the
PII/secret scan — conversion is a transformation, and every transformation
re-enters the pipeline gates in [../SKILL.md](../SKILL.md).
