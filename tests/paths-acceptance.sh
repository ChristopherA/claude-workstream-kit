#!/bin/sh
# Offline acceptance test for `workstream-record.py paths`: the review
# skill's cheapest staleness probe, every path-like token in Decisions
# and open task blocks with whether it exists. Cases: an existing path;
# a missing one; a path inside a code span; a URL not reported; a path
# in a struck-through span reported as struck; a `~` path against the
# home directory; a bare name listed apart and never as missing; a
# `file:line` citation checked on its file; a word pair (and/or), a
# workstream reference and a metavariable not reported; a completed
# task's path out of scope. Plus the non-conforming fixture (wrapped
# open line, indented sub-task, suffixed heading) and a Decision lifted
# from the corpus.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-paths-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

mkdir -p "$T/.state/workstreams/feature/alpha" "$T/docs" "$T/.claude/scripts"
printf 'x\n' > "$T/docs/design.md"
printf 'x\n' > "$T/.claude/scripts/tool.py"
HOME_PROBE="$HOME"
cat > "$T/.state/workstreams/feature/alpha/workstream.md" <<'FIX'
---
name: alpha
type: feature
status: active
---
## Purpose
Alpha exercises the path probe.

## Backlog
### Build (BD) -- the heading carries a suffix, as real files do
- [ ] #BD-1: reconcile docs/design.md with the script core, wrapped
across a line against the convention, and read `.claude/scripts/tool.py`
  - [ ] #BD-1a: an indented sub-task naming docs/missing.md and CLAUDE.md
- [ ] #BD-2: ~~edit docs/gone.md~~ superseded; see https://example.invalid/docs/x.md and/or scope/name, not #XX-N/foo
- [x] #BD-3: done, its note naming docs/never-existed.md

## Decisions
### D1 (2026-09-04): A kit script is about the file, never about the session
Three tests, now in docs/design.md at kit bc65ba5 and binding on every
sub-command #DS-3 defines. (Lifted 2026-09-05 from
feature/kit-script-core D3 in the project that built this sub-command:
a Decision citing a path in the repo it describes.) The tag home
ws/old-one is a reference, not a path; the citation
`.claude/scripts/tool.py:12` names a line in an existing file, and
`git show ws/x:docs/a.md` is a command whose words are read apart.

### D2 (2026-01-01): Home paths
The rule lives at ~/.no-such-dir-for-this-suite/rule.md and the
templates at ~/ (the home itself); the metavariable
`~/.claude/projects/-Users-<user>-Workspace-<name>/` and the glob
`.claude/skills/*/SKILL.md` are neither.

## Learnings
- L1 (2026-01-01): A Learning naming docs/learning-only.md, out of scope.
FIX

python3 "$SCRIPT" paths "$T" > "$T/out.json"
q() { jq -r "$1" "$T/out.json"; }
ent() { jq -r ".paths[] | select(.path == \"$1\") | \"\\(.exists) \\(.struck) \\(.anchored) \\(.owning_id) \\(.section)\"" "$T/out.json"; }

echo "== Sanity"
check "docs/design.md exists in the fixture and docs/missing.md does not" "[ -f \"$T/docs/design.md\" ] && [ ! -f \"$T/docs/missing.md\" ]"
check "#BD-1's code-span path sits on the wrapped second line" "grep -q '^across a line.*tool.py' \"$T/.state/workstreams/feature/alpha/workstream.md\""

echo "== Existing, missing, code span, wrapped line, sub-task"
check "docs/design.md exists (reported twice: #BD-1 and D1)" '[ "$(ent docs/design.md | sort -u)" = "true false true #BD-1 ## Backlog
true false true null ## Decisions" ]'
check "the code-span path on #BD-1's wrapped line exists and cites the SECOND line" \
  '[ "$(q ".paths[] | select(.path == \".claude/scripts/tool.py\") | .line")" = "$(grep -n "^across a line" "$T/.state/workstreams/feature/alpha/workstream.md" | cut -d: -f1)" ]'
check "docs/missing.md in the indented sub-task is missing, owned by #BD-1a" '[ "$(ent docs/missing.md)" = "false false true #BD-1a ## Backlog" ]'
check "missing holds docs/missing.md, the command's docs/a.md and the ~ path, and nothing that exists" \
  '[ "$(q "[.missing[].path] | sort | join(\",\")")" = "docs/a.md,docs/missing.md,~/.no-such-dir-for-this-suite/rule.md" ]'

echo "== Struck, URL, word pair, workstream reference, metavariable, glob, command words"
check "docs/gone.md is reported with struck true and is not in missing" \
  '[ "$(ent docs/gone.md)" = "false true true #BD-2 ## Backlog" ] && [ "$(q "[.missing[] | select(.path == \"docs/gone.md\")] | length")" = "0" ]'
check "the URL is not reported" '[ "$(q "[.paths[] | select(.path | contains(\"example.invalid\"))] | length")" = "0" ]'
check "and/or, scope/name, #XX-N/foo, ws/old-one and feature/kit-script-core are not reported" \
  '[ "$(q "[.paths[] | select(.path == \"and/or\" or .path == \"scope/name\" or .path == \"#XX-N/foo\" or .path == \"ws/old-one\" or .path == \"feature/kit-script-core\")] | length")" = "0" ]'
check "the metavariable path and the glob are not reported" \
  '[ "$(q "[.paths[] | select(.path | test(\"<user>|\\\\*\"))] | length")" = "0" ]'
check "the command's path word docs/a.md is read apart from git show (reported, missing)" '[ "$(ent docs/a.md)" = "false false true null ## Decisions" ]'
check "ws/x:docs/a.md as one token is not reported" '[ "$(q "[.paths[] | select(.path | contains(\"ws/x:\"))] | length")" = "0" ]'

echo "== Home paths and file:line citations"
check "~/.no-such-dir-for-this-suite/rule.md is anchored and missing" '[ "$(ent "~/.no-such-dir-for-this-suite/rule.md")" = "false false true null ## Decisions" ]'
check "~/ exists (the home directory itself)" '[ "$(ent "~/")" = "true false true null ## Decisions" ]'
check ".claude/scripts/tool.py:12 is checked on its file and exists" '[ "$(ent ".claude/scripts/tool.py:12")" = "true false true null ## Decisions" ]'

echo "== Bare names listed apart, never missing"
check "CLAUDE.md is bare (anchored false) and absent from missing" \
  '[ "$(ent CLAUDE.md)" = "false false false #BD-1a ## Backlog" ] && [ "$(q "[.missing[] | select(.path == \"CLAUDE.md\")] | length")" = "0" ]'
check "bare lists exactly CLAUDE.md" '[ "$(q "[.bare[].path] | join(\",\")")" = "CLAUDE.md" ]'

echo "== Out of scope: a completed task's note and a Learning"
check "docs/never-existed.md (done task) and docs/learning-only.md (Learning) are not reported" \
  '[ "$(q "[.paths[] | select(.path == \"docs/never-existed.md\" or .path == \"docs/learning-only.md\")] | length")" = "0" ]'
# Vary one input that must change the verdict: create the missing file.
printf 'x\n' > "$T/docs/missing.md"
check "creating docs/missing.md removes it from missing" \
  '[ "$(python3 "$SCRIPT" paths "$T" | jq -r "[.missing[] | select(.path == \"docs/missing.md\")] | length")" = "0" ]'

echo "== Exit codes"
rc=0; python3 "$SCRIPT" paths >/dev/null 2>&1 || rc=$?
check "paths with no root: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" paths "$T/nowhere" >/dev/null 2>&1 || rc=$?
check "paths on a root with no .state: exit 2" '[ "$rc" -eq 2 ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "PATHS ACCEPTANCE: ALL CHECKS PASS"; else echo "PATHS ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
