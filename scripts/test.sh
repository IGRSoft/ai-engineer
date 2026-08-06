#!/usr/bin/env bash
#
# test.sh — run the ai-engineer bundled-script test suite.
#
# Exercises the plugin's shell surface (hooks/, scripts/, and any
# skills/<domain>/scripts/) plus the repo-consistency and prose gates:
#   1. bash -n      — syntax-check hooks/*.sh and scripts/*.sh
#   2. shellcheck   — lint every bundled skill script + this repo's scripts/
#   3. hook self-tests — bash hooks/<script>.sh --self-test (schema fixtures)
#   4. validate     — scripts/validate.sh --strict (manifest/agent/skill gate)
#   5. prose lints  — desc-lint (fatal) + section-lint (warn-only)
#
# Dropped vs the system-developer original: the bats (tests/scripts/*.bats)
# and pytest (tests/scripts/*_test.py) suites — ai-engineer v1 ships no
# tests/ directory; re-add them when one exists.
#
# Note on formatting: the plugin's own scripts are tab-indented and are NOT
# shfmt-gated (validate.sh predates and does not pass `shfmt -i 2`). This
# runner enforces shellcheck on scripts/, not shfmt. hooks/ are ported
# space-indented infra verified here via bash -n + --self-test rather than by
# this linter, matching their upstream treatment. No comment line here may
# begin with the linter's own name — ShellCheck >=0.11 parses that as a
# directive and fails the file (SC1073).
#
# Mirrors the plugin's "degrade gracefully" philosophy: a missing tool is a
# SKIP, not a failure — unless --strict, which turns SKIPs into failures so a
# CI image that should have the tool fails loudly. Actual failures always fail.
#
# Usage:
#   scripts/test.sh [--strict]
#
# Exit codes:
#   0  every suite that ran passed (SKIPs allowed without --strict)
#   1  a lint or test suite failed (or a SKIP under --strict)
#   2  usage error
#
set -Eeuo pipefail

STRICT=0
for arg in "$@"; do
	case "${arg}" in
		--strict) STRICT=1 ;;
		-h | --help)
			grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'
			exit 0
			;;
		*)
			printf 'ERROR unknown argument "%s" | fix: run with --strict or no args\n' "${arg}" >&2
			exit 2
			;;
	esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

FAIL_COUNT=0
SKIP_COUNT=0
RAN_COUNT=0

pass() { printf 'PASS  %s\n' "$1"; RAN_COUNT=$((RAN_COUNT + 1)); }
fail() {
	printf 'FAIL  %s\n' "$1" >&2
	FAIL_COUNT=$((FAIL_COUNT + 1))
	RAN_COUNT=$((RAN_COUNT + 1))
}
skip() {
	# skip <suite> <install-hint>
	if [[ "${STRICT}" -eq 1 ]]; then
		printf 'FAIL  %s (required under --strict; %s)\n' "$1" "$2" >&2
		FAIL_COUNT=$((FAIL_COUNT + 1))
		RAN_COUNT=$((RAN_COUNT + 1))
	else
		printf 'SKIP  %s (%s)\n' "$1" "$2"
		SKIP_COUNT=$((SKIP_COUNT + 1))
	fi
}

# Scripts this suite owns: bundled skill scripts + this repo's scripts/.
# Newline-delimited; bash 3.2-safe (no mapfile).
SCRIPTS="$(
	find skills -type f -path '*/scripts/*.sh'
	find scripts -type f -name '*.sh'
)"

# --- 1. bash -n (hooks + scripts) -------------------------------------------
SYNTAX_FAIL=0
SYNTAX_N=0
for f in hooks/*.sh scripts/*.sh; do
	[[ -f "${f}" ]] || continue
	SYNTAX_N=$((SYNTAX_N + 1))
	bash -n "${f}" || { printf 'bash -n failed: %s\n' "${f}" >&2; SYNTAX_FAIL=1; }
done
if [[ "${SYNTAX_FAIL}" -eq 0 ]]; then
	pass "bash -n (${SYNTAX_N} scripts)"
else
	fail "bash -n"
fi

# --- 2. shellcheck ----------------------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
	if printf '%s\n' "${SCRIPTS}" | tr '\n' '\0' | xargs -0 shellcheck; then
		pass "shellcheck ($(printf '%s\n' "${SCRIPTS}" | grep -c .) scripts)"
	else
		fail "shellcheck"
	fi
else
	skip "shellcheck" "brew install shellcheck"
fi

# --- 3. hook self-tests -----------------------------------------------------
HOOK_FAIL=0
HOOK_N=0
for h in hooks/*.sh; do
	[[ -f "${h}" ]] || continue
	HOOK_N=$((HOOK_N + 1))
	bash "${h}" --self-test || { printf 'self-test failed: %s\n' "${h}" >&2; HOOK_FAIL=1; }
done
if [[ "${HOOK_N}" -eq 0 ]]; then
	skip "hook self-tests" "no hooks/*.sh found"
elif [[ "${HOOK_FAIL}" -eq 0 ]]; then
	pass "hook self-tests (${HOOK_N} hooks)"
else
	fail "hook self-tests"
fi

# --- 4. validate --strict ---------------------------------------------------
if command -v jq >/dev/null 2>&1; then
	if scripts/validate.sh --strict; then
		pass "validate --strict"
	else
		fail "validate --strict"
	fi
else
	skip "validate --strict" "brew install jq (required by validate.sh)"
fi

# --- 5. markdown prose lints ------------------------------------------------
# desc-lint is FATAL (ambient agent/command/skill description caps). section-lint
# is WARN-ONLY: a pre-existing prose-debt baseline, burn-down tracked in the
# CHANGELOG — it must not fail the suite, even under --strict.
if command -v python3 >/dev/null 2>&1; then
	if scripts/desc-lint.sh; then
		pass "desc-lint"
	else
		fail "desc-lint"
	fi
	sec_summary="$(scripts/section-lint.sh 2>/dev/null | tail -n1 || true)"
	printf 'WARN  section-lint (warn-only): %s\n' "${sec_summary:-no summary}"
else
	skip "prose-lints" "install python3 (required for desc-lint/section-lint)"
fi

# --- Summary ----------------------------------------------------------------
printf '\nSummary: %d ran, %d failed, %d skipped%s\n' \
	"${RAN_COUNT}" "${FAIL_COUNT}" "${SKIP_COUNT}" \
	"$(if [[ "${STRICT}" -eq 1 ]]; then printf ' (strict)'; fi)"

[[ "${FAIL_COUNT}" -eq 0 ]] || exit 1
exit 0
