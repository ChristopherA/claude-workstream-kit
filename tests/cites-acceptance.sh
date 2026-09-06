#!/bin/sh
# Offline acceptance test for `workstream-record.py cites`: the citation
# sweep the extract, capture, close and work skills prescribe. Blocks are
# folded before matching, so a needle split by a 70-column wrap still
# hits; an ID-shaped needle matches on word boundaries only; every hit
# names its file, line, section, owning Backlog ID, strike state and the
# hold verb before it. The three mandatory fixture classes: a
# non-conforming file (wrapped open line, indented sub-task, suffixed
# phase heading, a Learning wrapped through its marker, a bare mention),
# a corpus-lifted block (dated), and a known-absent needle so the empty
# result is shown to be a real negative.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-cites-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

mkdir -p "$T/.state/workstreams/feature/alpha" "$T/.state/workstreams/feature/beta" "$T/.claude" "$T/docs"

# alpha: cites beta's #BT-1 as a BLOCKER on a wrapped open line (the
# non-conforming shape), an indented sub-task citing D2, a phase heading
# with a suffix, a struck citation, #BD-10 beside #BD-1, a two-word
# phrase split by the wrap, a Learning wrapped through its marker that
# cites #BT-1 as a SOURCE, and a bare mention of a marker.
cat > "$T/.state/workstreams/feature/alpha/workstream.md" <<'FIX'
---
name: alpha
type: feature
status: active
---
## Purpose
Alpha exercises the citation sweep.

## Backlog
### Build (BD) -- the heading carries a suffix, as real files do
- [ ] #BD-1: the first build task, which is blocked on #BT-1 in
feature/beta for the shared schema, wrapped against the convention
  - [ ] #BD-1a: an indented sub-task, reasoning in D2, citing the intake-channel
  note across the wrap
- [ ] #BD-10: a tenth task that must not hit a search for the first
- [x] #BD-2: done, ~~blocked on #BT-1~~ (the hold retired in place)

## Decisions
### D1 (2026-09-04): Chartered by D83 in maintain/claude-workstream-kit
Opened because a set-level refactor is feature work by that
workstream's criterion 4. The five verbs stay; a single maintenance
skill and a pure inversion were declined there. Release approval and
the consumer re-install stay with that workstream's #G-OG and AD
phase; this workstream ends at a built, verified payload. (Lifted
2026-09-05 from feature/kit-script-core D1 in the project that built
this sub-command: a Decision citing a Decision in another workstream.)

### D2 (2026-01-01): Local
Some rationale about the intake-channel
note, split by the wrap.

## Learnings
- L1 (2026-01-01): An insight routed from #BT-1, the marker wrapped: HANDED
  OFF 2026-01-02 to feature/beta.
- L2 (2026-01-01): The record quotes the two-word `HANDED OFF` marker
  mid-sentence, a mention.
FIX

cat > "$T/.state/workstreams/feature/beta/workstream.md" <<'FIX'
---
name: beta
type: feature
status: active
---
## Backlog
### Tasks (BT)
- [ ] #BT-1: the shared schema
FIX

printf -- '## Notes\nA note under a dot-directory citing #BT-1, found only with --repo.\n' > "$T/.claude/notes.md"
printf -- '# Doc\nA doc outside .state citing D83 in maintain/claude-workstream-kit.\n' > "$T/docs/note.md"

run() { python3 "$SCRIPT" cites "$T" "$@" > "$T/out.json"; }
q() { jq -r "$1" "$T/out.json"; }

echo "== Sanity: the fixture carries each planted case"
A="$T/.state/workstreams/feature/alpha/workstream.md"
check "#BT-1 sits on #BD-1's FIRST line and feature/beta on its second (a wrapped open line)" \
  "grep -q '^- \[ \] #BD-1: .*#BT-1 in\$' \"$A\" && grep -q '^feature/beta for the shared' \"$A\""
check "the two-word phrase is split across lines in both D2 and the sub-task" \
  "grep -q 'intake-channel\$' \"$A\" && [ \"\$(grep -c 'intake-channel\$' \"$A\")\" = 2 ]"
check "L1's HANDED OFF marker is split by the wrap" "grep -q 'HANDED\$' \"$A\""

echo "== An ID needle cited from another workstream's file, with the hold verb and owner"
run '#BT-1'
check "#BT-1 hits alpha's #BD-1 block, owned by #BD-1, hold_before 'blocked on'" \
  '[ "$(q ".hits[] | select(.file | endswith(\"alpha/workstream.md\")) | select(.owning_id == \"#BD-1\") | .hold_before")" = "blocked on" ]'
check "that hit cites the FIRST line of the block (the line holding the needle)" \
  '[ "$(q ".hits[] | select(.owning_id == \"#BD-1\") | .line")" = "$(grep -n "^- \[ \] #BD-1:" "$A" | cut -d: -f1)" ]'
check "the struck citation in #BD-2 is reported with struck true" \
  '[ "$(q ".hits[] | select(.owning_id == \"#BD-2\") | .struck")" = "true" ]'
check "the unstruck hits are reported with struck false" \
  '[ "$(q "[.hits[] | select(.owning_id == \"#BD-1\") | .struck] | unique | join(\",\")")" = "false" ]'
check "the Learning citing #BT-1 as a source has no hold verb before it" \
  '[ "$(q ".hits[] | select(.section == \"## Learnings\") | .hold_before")" = "null" ]'
check "beta's own defining line is a hit too, owned by #BT-1 (the sweep is whole-tree)" \
  '[ "$(q ".hits[] | select(.file | endswith(\"beta/workstream.md\")) | .owning_id")" = "#BT-1" ]'
check "without --repo the dot-directory note is NOT scanned (4 hits: #BD-1, #BD-2, L1, beta's line; none under .claude)" \
  '[ "$(q ".hits | length")" = "4" ] && [ "$(q "[.hits[] | select(.file | startswith(\".claude\"))] | length")" = "0" ]'

echo "== --repo reaches the dot-directory and docs/"
run '#BT-1' --repo
check "with --repo the .claude/notes.md hit is found (5 hits)" \
  '[ "$(q ".hits | length")" = "5" ] && [ "$(q ".hits[] | select(.file == \".claude/notes.md\") | .line")" = "2" ]'
run 'D83' --repo
check "D83 is found in docs/note.md and in the corpus-lifted D1 block" \
  '[ "$(q "[.hits[].file] | sort | join(\",\")")" = ".state/workstreams/feature/alpha/workstream.md,docs/note.md" ]'
check "the D1 hit sits in section ## Decisions with no owning ID" \
  '[ "$(q ".hits[] | select(.file | endswith(\"alpha/workstream.md\")) | \"\(.section) \(.owning_id)\"")" = "## Decisions null" ]'

echo "== ID word boundaries: #BD-1 does not match #BD-10 or #BD-1a"
run '#BD-1'
check "#BD-1 hits exactly one block (its own line), not #BD-10 or #BD-1a" \
  '[ "$(q ".hits | length")" = "1" ] && [ "$(q ".hits[0].owning_id")" = "#BD-1" ]'
run '#BD-10'
check "#BD-10 hits its own block only" '[ "$(q ".hits | length")" = "1" ] && [ "$(q ".hits[0].owning_id")" = "#BD-10" ]'
run '#BD-1a'
check "#BD-1a (the indented sub-task) hits its own block, owned by #BD-1a" \
  '[ "$(q ".hits | length")" = "1" ] && [ "$(q ".hits[0].owning_id")" = "#BD-1a" ]'

echo "== A two-word needle split by a wrap, and --section"
run 'intake-channel note'
check "the phrase is found twice, once in the sub-task and once in D2, across the wrap" \
  '[ "$(q ".hits | length")" = "2" ] && [ "$(q "[.hits[].section] | sort | join(\",\")")" = "## Backlog,## Decisions" ]'
check "the sub-task hit is owned by #BD-1a" '[ "$(q ".hits[] | select(.section == \"## Backlog\") | .owning_id")" = "#BD-1a" ]'
run 'intake-channel note' --section Decisions
check "--section Decisions keeps only the D2 hit" '[ "$(q ".hits | length")" = "1" ] && [ "$(q ".hits[0].section")" = "## Decisions" ]'
run 'HANDED OFF' --section Learnings
check "the wrapped marker in L1 and the mention in L2 are both found (the sweep does not judge)" '[ "$(q ".hits | length")" = "2" ]'

echo "== A known-absent needle on a fixture carrying every other case: a real negative"
run 'no-such-phrase-anywhere' '#ZZ-99'
check "zero hits, with files_scanned above zero (the sweep ran)" \
  '[ "$(q ".hits | length")" = "0" ] && [ "$(q ".files_scanned")" -gt 0 ]'
check "multiple needles are reported back in order" '[ "$(q ".needles | join(\" \")")" = "no-such-phrase-anywhere #ZZ-99" ]'

echo "== Usage and exit codes"
rc=0; python3 "$SCRIPT" cites "$T" >/dev/null 2>&1 || rc=$?
check "cites with no needle: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" cites "$T/nowhere" '#BT-1' >/dev/null 2>&1 || rc=$?
check "cites on a root with no .state: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" cites "$T" '#BT-1' --bogus >/dev/null 2>&1 || rc=$?
check "an unknown option: exit 2" '[ "$rc" -eq 2 ]'
rc=0; HELP=$(python3 "$SCRIPT" --help 2>/dev/null) || rc=$?
check "--help prints the usage text to stdout and exits 0" '[ "$rc" -eq 0 ] && printf "%s" "$HELP" | grep -q "^Usage:"'
check "the sweep wrote nothing (git-free fixture: the tree's file count is unchanged)" \
  '[ "$(find "$T" -type f ! -name out.json | wc -l | tr -d " ")" = "4" ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "CITES ACCEPTANCE: ALL CHECKS PASS"; else echo "CITES ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
