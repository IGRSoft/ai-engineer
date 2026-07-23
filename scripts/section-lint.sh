#!/usr/bin/env bash
#
# section-lint.sh — markdown section-length lint (≤1000 chars per leaf section)
# plus an ADVISORY required-H2 check for agents/ and commands/.
#
# Long sections bury the imperative rules agents must follow and defeat
# skim-reading during stage handoffs. A section is a heading line (#..######
# at column 0, outside fenced code blocks) plus its body up to the next
# heading of ANY level (leaf semantics — an H2's own text stops at its first
# H3). count = len(heading) + 1 + Σ(len(body_line) + 1). Fenced blocks
# (``` and ~~~, marker- and length-aware, ≤3 leading spaces) COUNT toward
# the cap; heading-lookalikes inside fences are ignored. YAML frontmatter
# and any pre-heading preamble are exempt (no heading owns them).
#
# Required-H2 check (advisory — warn lines only, NEVER affects the exit code),
# calibrated against this plugin's real files (2026-07 inventory):
#   agents/*.md   — must carry "## Workflow Integration", and one of
#                   "## Response Approach" OR "## Core Workflow"
#                   (prefix-matched: several agents suffix the heading, e.g.
#                   "## Response Approach (Update Workflow)"; ai-architector
#                   uses "## Core Workflow"). agents/_base/* are exempt.
#   commands/*.md — must carry the code-review exemplar skeleton H2s:
#                   CRITICAL BEHAVIORAL RULES, Usage, Options, Output Format,
#                   Error Handling, See Also.
#
# The length lint is strict (exit 1 on any overrun). The repo carries
# pre-existing prose debt, so the warn-only policy lives at the call site
# (scripts/test.sh), not here — direct invocation and CI both see the true
# failing state.
#
# Usage:
#   scripts/section-lint.sh              # lint agents/, agents/_base/, commands/,
#                                        # skills/**  (excludes templates/, scripts/,
#                                        # fixtures/ — scaffolds and test vectors,
#                                        # not agent-facing prose)
#   scripts/section-lint.sh <file> [...] # lint specific files
#   scripts/section-lint.sh --self-test  # verify the parser against inline fixtures
#
# Exit codes: 0 = all within cap, 1 = at least one over cap, 2 = usage/parser error.
#
# CI / repo-maintenance helper only — never read by agents at runtime.
#
set -Eeuo pipefail

lint() {
	python3 - "$@" <<'PYEOF'
import re, sys

CAP = 1000
FENCE_RE = re.compile(r'^ {0,3}(`{3,}|~{3,})')
HEAD_RE = re.compile(r'^#{1,6} ')

# Required-H2 groups per file class; each group is a tuple of accepted
# PREFIXES — a file passes a group when any real (fence-exempt) heading
# starts with any alternative. Advisory only: misses warn, never fail.
REQUIRED = {
    'agent': [('## Workflow Integration',),
              ('## Response Approach', '## Core Workflow')],
    'command': [('## CRITICAL BEHAVIORAL RULES',), ('## Usage',),
                ('## Options',), ('## Output Format',),
                ('## Error Handling',), ('## See Also',)],
}

def required_for(path):
    if re.search(r'(^|/)agents/_base/', path):
        return None                       # shared templates — exempt
    if re.search(r'(^|/)agents/[^/]+\.md$', path):
        return REQUIRED['agent']
    if re.search(r'(^|/)commands/[^/]+\.md$', path):
        return REQUIRED['command']
    return None

def sections(text):
    """Yield (lineno, heading, char_count) leaf sections of a markdown text."""
    lines = text.splitlines()
    start = 0
    if lines and lines[0].rstrip('\r') == '---':          # skip YAML frontmatter
        for j in range(1, len(lines)):
            if lines[j].rstrip('\r') == '---':
                start = j + 1
                break
    fence_char, fence_len = None, 0
    cur = None                                            # [lineno, heading, count]
    for n in range(start, len(lines)):
        ln = lines[n]
        m = FENCE_RE.match(ln)
        if m:
            marker, mlen = m.group(1)[0], len(m.group(1))
            if fence_char is None:
                fence_char, fence_len = marker, mlen      # open
            elif marker == fence_char and mlen >= fence_len \
                    and ln[m.end():].strip() == '':
                fence_char = None                         # close (bare fence only)
            # opposite marker / shorter run / info-string close = content
        elif fence_char is None and HEAD_RE.match(ln):
            if cur:
                yield tuple(cur)
            cur = [n + 1, ln, len(ln) + 1]
            continue
        if cur:
            cur[2] += len(ln) + 1
    if cur:
        yield tuple(cur)

repo_mode = sys.argv[1] == '--repo'
paths = sys.argv[2:] if repo_mode else sys.argv[1:]
fail, viol, warns, nfiles = 0, 0, 0, 0
for path in paths:
    try:
        text = open(path, encoding='utf-8').read()
    except OSError as e:
        print(f"section-lint: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)
    nfiles += 1
    secs = list(sections(text))
    over, total = [], 0
    for lineno, heading, count in secs:
        total += 1
        if count > CAP:
            over.append((lineno, heading, count))
    for lineno, heading, count in over:
        print(f"section-lint: {path}:{lineno}: {count} chars (cap {CAP}) — OVER :: {heading.strip()}")
    groups = required_for(path)
    if groups:
        headings = [h.rstrip() for _, h, _ in secs]
        for alts in groups:
            if not any(h.startswith(a) for h in headings for a in alts):
                warns += 1
                print(f"section-lint: {path}: warn — missing required section "
                      f"{' or '.join(repr(a) for a in alts)} (advisory)")
    if over:
        fail, viol = 1, viol + len(over)
    elif not repo_mode:
        print(f"section-lint: {path}: {total} sections, all ≤ cap ok")
if repo_mode:
    print(f"section-lint: {nfiles} files, {viol} sections over cap, "
          f"{warns} required-section warnings (advisory)")
sys.exit(fail)
PYEOF
}

self_test() {
	td=$(mktemp -d -t section-lint-XXXXXX)
	trap 'rm -rf "${td}"' EXIT

	# fixture 1: one section within cap
	printf -- '## ok section\nshort body\n' >"${td}/ok.md"
	# fixture 2: one section over cap (brace expansion — no unquoted $() to split)
	{ printf -- '## big section\n'; printf 'x%.0s' {1..1100}; printf '\n'; } >"${td}/over.md"
	# fixture 3: heading-lookalike inside a fence stays in the enclosing section
	# shellcheck disable=SC2016 # backticks are literal markdown fence delimiters here
	printf -- '## real\n```markdown\n## fake heading\n```\ntail\n' >"${td}/fenced.md"
	# fixture 4: tilde fence wrapping backtick fences is ONE block
	# shellcheck disable=SC2016 # backticks are literal markdown fence delimiters here
	printf -- '## real\n~~~markdown\n```bash\ninner\n```\n## fake\n~~~\n' >"${td}/tilde.md"
	# fixture 5: leaf semantics — H2 body stops at the H3
	{ printf -- '## parent\n'; printf 'p%.0s' {1..800}; printf '\n### child\n'; \
		printf 'c%.0s' {1..800}; printf '\n'; } >"${td}/leaf.md"
	# fixture 6: frontmatter only, no headings
	printf -- '---\nname: a\ndescription: b\n---\npreamble only\n' >"${td}/plain.md"
	# fixture 7: agent file satisfying the required groups via the Core
	# Workflow alternative — must produce no warning
	mkdir -p "${td}/agents"
	printf -- '## Workflow Integration\nx\n## Core Workflow\ny\n' >"${td}/agents/arch.md"
	# fixture 8: agent file missing Workflow Integration (suffixed Response
	# Approach present) — must warn but still exit 0 (advisory)
	printf -- '## Response Approach (Fix Application Workflow)\nz\n' >"${td}/agents/gap.md"

	lint "${td}/ok.md" "${td}/plain.md" >/dev/null \
		|| { echo "section-lint self-test: FAIL (ok/plain fixtures flagged)" >&2; exit 2; }
	lint "${td}/over.md" >/dev/null \
		&& { echo "section-lint self-test: FAIL (over fixture passed)" >&2; exit 2; }
	lint "${td}/fenced.md" | grep -q '1 sections' \
		|| { echo "section-lint self-test: FAIL (fenced heading started a section)" >&2; exit 2; }
	lint "${td}/tilde.md" | grep -q '1 sections' \
		|| { echo "section-lint self-test: FAIL (nested fence mis-toggled)" >&2; exit 2; }
	lint "${td}/leaf.md" | grep -q '2 sections' \
		|| { echo "section-lint self-test: FAIL (leaf split not applied)" >&2; exit 2; }
	lint "${td}/agents/arch.md" | grep -q 'missing required section' \
		&& { echo "section-lint self-test: FAIL (Core Workflow alternative not accepted)" >&2; exit 2; }
	lint "${td}/agents/gap.md" >/dev/null \
		|| { echo "section-lint self-test: FAIL (advisory warning flipped the exit code)" >&2; exit 2; }
	lint "${td}/agents/gap.md" | grep -q 'missing required section' \
		|| { echo "section-lint self-test: FAIL (missing required section not warned)" >&2; exit 2; }
	echo "section-lint self-test: ALL PASS"
}

repo_files() {
	# git `*` matches `/`, so the agents/skills globs already recurse; the
	# explicit agents/_base and skills patterns document intent, sort -u dedupes.
	git ls-files -- 'agents/*.md' 'agents/_base/*.md' 'commands/*.md' \
		'skills/*.md' 'skills/**/*.md' \
		| sort -u \
		| grep -Ev '/(templates|scripts|fixtures)/' || true
}

case "${1:-}" in
	--self-test) self_test ;;
	"")
		cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
		# shellcheck disable=SC2046 # repo_files emits one clean path per line
		lint --repo $(repo_files)
		;;
	*) lint "$@" ;;
esac
