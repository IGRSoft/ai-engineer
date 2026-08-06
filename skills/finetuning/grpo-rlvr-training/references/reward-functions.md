# Reward Functions for GRPO / RLVR

Runnable reward implementations to inspect against the 50–100-sample gate in
`skills/finetuning/grpo-rlvr-training`, plus the failure modes each one is
prone to. TRL's reward-function signature moves between minors — verify the
current contract against TRL's docs (context7) before wiring these in.

## Contents

- [The signature](#the-signature)
- [Exact-match correctness](#exact-match-correctness)
- [Schema validation](#schema-validation)
- [Unit-test execution](#unit-test-execution)
- [Length-penalty wrapper](#length-penalty-wrapper)
- [Judge-as-reward](#judge-as-reward)
- [Building the inspection set](#building-the-inspection-set)

## The signature

A TRL reward function receives the decoded completions for a batch of prompts
plus whatever extra dataset columns it declares, and returns one float per
completion. Composite reward is a *list* of functions, not one function with
branches inside — TRL logs each one separately, which is what lets you see
which term the policy is actually climbing.

```python
def format_reward(completions: list[str], **kwargs) -> list[float]:
    """Reward the required output shape, independent of whether it is correct.

    Kept separate from correctness so a well-formed wrong answer and
    unparseable output are distinguishable in the gradient and in the logs.
    """
    return [1.0 if _matches_shape(c) else 0.0 for c in completions]
```

Two rules that hold across every function below:

- **Return a float per completion, in order.** A length mismatch or a `None`
  surfaces as a shape error deep inside the trainer, not as a clear message.
- **Do not swallow verifier exceptions into `0.0`.** A timeout and a wrong
  answer are different events. Collapsing them teaches the policy to avoid
  expensive-but-correct solutions, and it hides an infrastructure problem as a
  quality problem. Score errors distinctly and log the count.

## Exact-match correctness

The simplest verifier, and the one most often written too loosely.

```python
import re

ANSWER_RE = re.compile(r"<answer>\s*(.*?)\s*</answer>", re.S)

def correctness_reward(
    completions: list[str], ground_truth: list[str], **kwargs
) -> list[float]:
    """Score 1.0 only when the extracted answer span equals ground truth.

    Extraction is anchored to a delimiter rather than searching the whole
    completion: an unanchored search rewards a model that restates the
    prompt, because the correct token appears somewhere in the text.
    """
    scores = []
    for completion, truth in zip(completions, ground_truth, strict=True):
        match = ANSWER_RE.search(completion)
        scores.append(1.0 if match and _normalize(match.group(1)) == _normalize(truth) else 0.0)
    return scores


def _normalize(text: str) -> str:
    return " ".join(text.strip().casefold().split())
```

**Inspection focus:** take the completions that scored `1.0` and confirm the
extracted span is the model's *answer*, not an echo of the question. Then take
the `0.0` set and confirm none of them are correct answers rejected on
formatting or whitespace — a normalizer that is too strict makes correct
behavior unrewardable, which reads as "the model can't learn this task".

## Schema validation

Structured-output tasks verify by parsing. The trap is accepting more than you
meant to.

```python
from pydantic import BaseModel, ValidationError

class ToolCall(BaseModel, extra="forbid"):   # extra="forbid" is the whole point
    name: str
    arguments: dict

def schema_reward(completions: list[str], **kwargs) -> list[float]:
    """Reward completions that parse into the exact expected schema.

    extra="forbid" prevents the policy from learning to emit a superset of
    fields and letting a permissive parser sort it out — a default-permissive
    model turns "valid" into "contains something valid".
    """
    scores = []
    for completion in completions:
        try:
            ToolCall.model_validate_json(_extract_json(completion))
        except (ValidationError, ValueError):
            scores.append(0.0)
        else:
            scores.append(1.0)
    return scores
```

Schema design depth — when to constrain with an enum vs. validate after, and
how to keep the schema in one place — is
`skills/prompt-engineering/structured-outputs`.

## Unit-test execution

The strongest verifier class for code tasks, and the one with a security
boundary.

```python
import subprocess, tempfile, pathlib

def unit_test_reward(
    completions: list[str], tests: list[str], **kwargs
) -> list[float]:
    """Run the task's tests against each completion in a disposable workdir.

    Model output is untrusted code. This runs it, so the sandbox is a
    correctness requirement of the reward function, not a deployment detail:
    without isolation the reward function is a remote-code-execution path into
    the training host.
    """
    scores = []
    for completion, test_src in zip(completions, tests, strict=True):
        with tempfile.TemporaryDirectory() as workdir:
            root = pathlib.Path(workdir)
            (root / "solution.py").write_text(_extract_code(completion))
            (root / "test_solution.py").write_text(test_src)
            try:
                proc = subprocess.run(
                    ["pytest", "-q", "--timeout=10"],
                    cwd=root, capture_output=True, timeout=30,
                )
            except subprocess.TimeoutExpired:
                scores.append(_TIMEOUT_SCORE)   # distinct from "wrong", and counted
                continue
            scores.append(1.0 if proc.returncode == 0 else 0.0)
    return scores
```

**Sandbox it for real.** A temporary directory is not isolation — the process
still has the training host's network and filesystem. Run this in a container
or a locked-down execution service with no credentials mounted; route the
design of that boundary to `ai-engineer:ai-security-auditor`. Sandboxing
patterns for executing untrusted subprocesses are in
`system-developer:secure-coding`.

**Partial credit is a design decision.** Fraction-of-tests-passing gives a
denser signal than all-or-nothing, and denser signal is usually what makes an
RL run learn at all. It also rewards solutions that pass the easy tests and
skip the hard one, so pair it with a gate on the specific test that encodes the
task's actual difficulty.

## Length-penalty wrapper

Reach for this only after observing length creep — an unconditional penalty
suppresses the chain-of-thought that makes reasoning tasks work.

```python
def with_length_penalty(reward_fn, *, budget_tokens: int, weight: float = 0.1):
    """Subtract a penalty for tokens past a budget, floored at zero penalty.

    Wrapping rather than editing the base function keeps the correctness term
    and the length term separately loggable, so you can still see which one the
    policy is climbing after the penalty is added.
    """
    def wrapped(completions: list[str], **kwargs) -> list[float]:
        base = reward_fn(completions, **kwargs)
        return [
            score - weight * max(0, _count_tokens(c) - budget_tokens) / budget_tokens
            for score, c in zip(base, completions, strict=True)
        ]
    return wrapped
```

If length is climbing because the reward itself is length-biased, the fix is
the **Dr.GRPO** variant, not this wrapper — the wrapper treats a symptom that
the variant removes at the source.

## Judge-as-reward

The weakest verifier class. Use it only when no deterministic checker exists
and the judge has measured agreement with human labels.

```python
def judge_reward(completions: list[str], prompts: list[str], **kwargs) -> list[float]:
    """Score with a calibrated LLM judge at temperature 0.

    Held to the same calibration bar as any eval judge: without measured
    agreement against human labels, this is not a verifier — the policy will
    find the judge's blind spots faster than it learns the task, and the
    reward curve will look excellent while doing it.
    """
    return [_judge_score(p, c) for p, c in zip(prompts, completions, strict=True)]
```

Non-negotiables before a judge counts as a verifier:

- Agreement with human labels measured on a double-labeled slice and reported
  (`skills/evals/llm-judge`)
- The judge model, prompt, and version pinned and logged with the run — a judge
  that silently changes mid-project makes every reward incomparable
- A different judge (or a human slice) used for the final evaluation, or the
  run measures agreement with itself

## Building the inspection set

The gate that precedes any training run.

1. **Sample 50–100 completions** from the *base* model on the target prompts at
   the temperature the run will use. Samples from a different model or
   temperature do not exercise the failure modes the run will actually hit.
2. **Score them with the reward function as written**, saving prompt,
   completion, and per-term score to a JSONL file next to the config.
3. **Read every disagreement.** Sort by score and read both tails plus a random
   middle slice. You are looking for high scores you disagree with (the reward
   hack the policy will find) and low scores you disagree with (the capability
   the reward makes unlearnable).
4. **Fix the function, then re-score the same set.** Changing a hyperparameter
   to compensate for a reward that measures the wrong thing is how a run
   optimizes cleanly toward the wrong target.
5. **Version the inspection set with the run**
   (`skills/mlops/experiment-tracking`) so a later reward change can be
   re-inspected against the same baseline rather than a fresh sample.

Treat this file as the artifact: an inspection JSONL with no human sign-off is
the same as no inspection.
