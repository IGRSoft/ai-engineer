#!/usr/bin/env bash
# PreCompact → state checkpoint (ai-engineer plugin, v1.0.0+).
# Copies .context/state.json to .context/state.checkpoint-<ts>.json before
# auto-compaction so long ai-engineer sessions survive context summarization.
# Pairs with the PostCompact recovery prose in
# skills/_shared/workflow-integration/SKILL.md.
#
# When igrsoft is the orchestrator it owns state.json and runs its own
# precompact hook; this checkpoint is harmless and idempotent (timestamped
# copy). Exit code is always 0 — never blocks compaction.
set -eu

SELF_TEST=0
[ "${1:-}" = "--self-test" ] && SELF_TEST=1

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONTEXT_DIR="$PROJECT_DIR/.context"
LOG_DIR="$CONTEXT_DIR/logs"
STATE_FILE="$CONTEXT_DIR/state.json"

mkdir -p "$LOG_DIR" || true

TS=$(date -u +%Y%m%d-%H%M%S)
CHECKPOINT="$CONTEXT_DIR/state.checkpoint-$TS.json"

if [ "$SELF_TEST" -eq 1 ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "precompact-checkpoint: self-test SKIP (jq not found)"
    exit 0
  fi
  # Drive the real code path: seeded project dir, no args (so --self-test does
  # not recurse), then assert named fields of the row actually emitted.
  TMP=$(mktemp -d)
  mkdir -p "$TMP/.context"
  echo '{"run_index":7,"stages":{}}' > "$TMP/.context/state.json"
  CLAUDE_PROJECT_DIR="$TMP" bash "$0" </dev/null >/dev/null 2>&1 || true

  ST_FAIL=0
  ls "$TMP"/.context/state.checkpoint-*.json >/dev/null 2>&1 || ST_FAIL=1
  EMITTED=$(tail -n 1 "$TMP/.context/logs/audit.jsonl" 2>/dev/null || true)
  [ -n "$EMITTED" ] || ST_FAIL=1
  if [ "$ST_FAIL" -eq 0 ]; then
    printf '%s\n' "$EMITTED" | jq -e '
      .actor == "ai-engineer:hook:precompact"
      and .action == "precompact_checkpoint"
      and .result == "ok"
      and .metadata.advisory == true
      and .metadata.run_index == "7"
      and (.metadata.state_file | test("^\\.context/state\\.checkpoint-[0-9]{8}-[0-9]{6}\\.json$"))
      and (.metadata.artifacts | type) == "array"
    ' >/dev/null || ST_FAIL=1
  fi
  rm -rf "$TMP"
  [ "$ST_FAIL" -eq 0 ] || { echo "precompact-checkpoint: self-test FAIL"; exit 1; }
  echo "precompact-checkpoint: self-test OK"
  exit 0
fi

if [ ! -f "$STATE_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg ts "$(date -u +%FT%TZ)" '{
      ts: $ts,
      actor: "ai-engineer:hook:precompact",
      action: "precompact_checkpoint",
      result: "skipped",
      metadata: { advisory: true, reason: "no state.json" }
    }' >> "$LOG_DIR/audit.jsonl" || true
  fi
  exit 0
fi

cp -p "$STATE_FILE" "$CHECKPOINT" || true

ARTIFACTS=$(find "$CONTEXT_DIR" -maxdepth 1 -type f \( \
  -name 'planning-*.md' -o -name 'coordination-*.md' -o -name 'development-*.md' \
\) 2>/dev/null | sort | jq -R . | jq -s . || echo '[]')

RUN_INDEX="unknown"
if command -v jq >/dev/null 2>&1; then
  RUN_INDEX=$(jq -r '.run_index // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
fi

if command -v jq >/dev/null 2>&1; then
  jq -cn \
    --arg ts "$(date -u +%FT%TZ)" \
    --arg state_file "${CHECKPOINT#$PROJECT_DIR/}" \
    --arg run_index "$RUN_INDEX" \
    --argjson artifacts "$ARTIFACTS" '{
      ts: $ts,
      actor: "ai-engineer:hook:precompact",
      action: "precompact_checkpoint",
      result: "ok",
      metadata: {
        advisory: true,
        state_file: $state_file,
        run_index: $run_index,
        artifacts: $artifacts
      }
    }' >> "$LOG_DIR/audit.jsonl" || true
fi

exit 0
