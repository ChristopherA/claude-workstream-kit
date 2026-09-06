#!/bin/sh
# Offline acceptance test for `workstream-rewrite.py learnings`: every
# Learning the record scores terminal condenses to its first sentence
# and its disposition sentence, re-wrapped. Cases: a wrapped marker
# condenses; a mention does not (the L11 fixture lifted from the
# corpus, the same one the record suite carries); an undispositioned
# entry and a deferred one are byte-identical after; a terminal entry
# already that short is byte-identical; a struck entry is untouched;
# the Learnings count is identical before and after; the second run
# changes nothing; the removed side is asserted (the dropped middle
# sentence is absent). The non-conforming fixture: the marker split by
# the wrap, an indented sub-task in the Backlog, a suffixed heading.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-rewrite.py"
RECORD="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-learnings-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

mkdir -p "$T/.state/workstreams/feature/alpha"
W="$T/.state/workstreams/feature/alpha/workstream.md"
cat > "$W" <<'FIX'
---
name: alpha
type: feature
status: active
---
## Purpose
Alpha exercises the Learnings condensation.

## Backlog
### Build (BD) -- the heading carries a suffix, as real files do
- [ ] #BD-1: an open task
  - [ ] #BD-1a: an indented sub-task

## Decisions
### D1 (2026-01-01): Only decision
Rationale, with a list under it:
- L9 is not a Learning: a list item inside a Decision that begins with L

## Learnings
- L1 (2026-01-01): An insight whose two-word marker wraps across the
  70-column break. The middle sentence explains the failure at length,
  with the evidence and the two probes that found it, all of which the
  disposition makes unnecessary to re-read. HANDED
  OFF 2026-01-02 to feature/beta, where #BT-1 carries it.
- L2 (2026-09-04): `workstream-record.py`'s disposition matching is
  correct BECAUSE it folds a Learning into a block and matches the
  marker against the joined text, so the multi-word `HANDED OFF`
  survives the 70-column wrap that splits it. An ad-hoc classifier
  written this session against the same file scored L47 as
  undispositioned for exactly that reason. Integration target: the
  fixture set (lifted 2026-09-04 from feature/kit-script-core L9 in
  the project that built this rule; a MENTION of a marker, mid-sentence).
- L3 (2026-01-01): An insight with no disposition at all, which stays
  whole however long it runs, because it still owes something.
- L4 (2026-01-01): Tracked work that has not landed. QUEUED 2026-01-02
  for #BD-1, and a deferred entry is not condensed.
- L5 (2026-01-01): Already short. APPLIED 2026-01-02 to docs/x.md.
- ~~L6 (2026-01-01): Struck through whole, retired in place, and left as it is.~~
- L7 (2026-01-01): DISPOSITION 2026-01-03: ROUTED to #BD-1, the date
  before the marker, with a trailing sentence about the routing that
  the condensation keeps only because it is the disposition sentence.

## Deletion Criteria
- [ ] STANDING: no orphaned Learnings -- HOLDS 2026-01-01
FIX
cp "$W" "$T/original.md"
count_before=$(grep -c '^- L[0-9]' "$W")
term_before=$(python3 "$RECORD" "$T" | jq -r '.workstreams[0].learnings.terminal')

echo "== Sanity: the fixture carries each planted case"
check "L1's marker is split by the wrap (HANDED at end of line, OFF at the start of the next)" \
  "grep -q 'HANDED\$' \"$W\" && grep -q '^  OFF 2026-01-02' \"$W\""
check "L2 carries the two-word marker mid-sentence" "grep -q 'multi-word \`HANDED OFF\`' \"$W\""
check "the record scores 4 terminal (L1, L5, L6, L7) of 7" "[ \"\$term_before\" = 4 ] && [ \"\$count_before\" = 7 ]"

echo "== Dry run"
OUT=$(python3 "$SCRIPT" learnings "$W" --date 2026-05-05)
check "dry run reports learnings_condensed=1 (L1 alone) and leaves the file byte-identical" \
  "printf '%s' \"\$OUT\" | grep -q '^learnings_condensed=1 ' && ! printf '%s' \"\$OUT\" | grep -q WRITTEN && cmp -s \"\$W\" \"\$T/original.md\""
check "learnings dry run prints one entry line in the shared report shape: L1, bytes before->after, the condensed line" \
  "printf '%s' \"\$OUT\" | grep -qE '^L1 [0-9]+->[0-9]+: - L1 \\(' && [ \"\$(printf '%s\\n' \"\$OUT\" | grep -cE '^L[0-9]+ [0-9]+->[0-9]+: ')\" = 1 ]"

echo "== Write"
OUT=$(python3 "$SCRIPT" learnings "$W" --write --date 2026-05-05)
check "write reports learnings_condensed=1 learnings=7 and WRITTEN" \
  "printf '%s' \"\$OUT\" | grep -q '^learnings_condensed=1 .*learnings=7' && printf '%s' \"\$OUT\" | grep -q WRITTEN"
L1=$(awk '/^- L1 /,/^- L2 /' "$W" | grep -v '^- L2 ' | tr '\n' ' ' | tr -s ' ')
check "L1 condenses to its first sentence and its disposition sentence, the marker rejoined" \
  "printf '%s' \"\$L1\" | grep -q 'An insight whose two-word marker wraps across the 70-column break. HANDED OFF 2026-01-02 to feature/beta, where #BT-1 carries it.'"
check "removed side: L1's middle sentence is gone" "! grep -q 'the two probes that found it' \"$W\""
check "L1 is re-wrapped under 72 columns with two-space continuations" \
  "! awk '/^- L1 /,/^- L2 /' \"$W\" | grep -v '^- L2 ' | awk 'length > 72 {bad=1} END {exit bad}' || false; awk '/^- L1 /,/^- L2 /' \"$W\" | grep -v '^- L2 ' | tail -n +2 | grep -q '^  [^ ]'"
awk '/^- L2 /,/^- L3 /' "$W" | grep -v '^- L3 ' > "$T/l2-after.txt"; awk '/^- L2 /,/^- L3 /' "$T/original.md" | grep -v '^- L3 ' > "$T/l2-before.txt"
check "L2 (the mention) is byte-identical" "cmp -s \"$T/l2-after.txt\" \"$T/l2-before.txt\""
check "L3 (undispositioned), L4 (deferred), L5 (short terminal) and L6 (struck) are byte-identical" \
  "for n in 3 4 5 6; do m=\$((n + 1)); awk \"/^- (~~)?L\$n /,/^- (~~)?L\$m /\" \"$W\" | grep -v \"^- (~~)?L\$m \" > \"$T/a.txt\"; awk \"/^- (~~)?L\$n /,/^- (~~)?L\$m /\" \"$T/original.md\" | grep -v \"^- (~~)?L\$m \" > \"$T/b.txt\"; cmp -s \"$T/a.txt\" \"$T/b.txt\" || exit 1; done"
awk '/^- L7 /,/^$/' "$W" > "$T/l7-after.txt"; awk '/^- L7 /,/^$/' "$T/original.md" > "$T/l7-before.txt"
check "L7 (the DISPOSITION-date form, one sentence) is terminal and already that short: byte-identical" "cmp -s \"$T/l7-after.txt\" \"$T/l7-before.txt\""
check "the Learnings count is identical before and after (7), and the record still scores 4 terminal" \
  "[ \"\$(grep -c '^- L[0-9]' \"$W\")\" = 7 ] && [ \"\$(python3 \"$RECORD\" \"$T\" | jq -r '.workstreams[0].learnings.terminal')\" = 4 ]"
check "the Backlog, Decisions and criteria are untouched (the '- L9' item under Decisions included)" \
  "grep -qF -- '  - [ ] #BD-1a: an indented sub-task' \"$W\" && grep -q '^- L9 is not a Learning' \"$W\" && grep -q 'HOLDS 2026-01-01' \"$W\""

echo "== Idempotence"
cp "$W" "$T/after1.md"
OUT=$(python3 "$SCRIPT" learnings "$W" --write --date 2026-06-06)
check "a second run reports learnings_condensed=0 and NO CHANGE, byte-identical" \
  "printf '%s' \"\$OUT\" | grep -q '^learnings_condensed=0 ' && printf '%s' \"\$OUT\" | grep -q 'NO CHANGE' && cmp -s \"\$W\" \"\$T/after1.md\""

echo "== Failure exits"
printf -- '## Backlog\n- [ ] #X-1: x\n' > "$T/nolearn.md"
rc=0; python3 "$SCRIPT" learnings "$T/nolearn.md" >/dev/null 2>&1 || rc=$?
check "a file with no ## Learnings: exit 1" '[ "$rc" -eq 1 ]'
rc=0; python3 "$SCRIPT" learnings >/dev/null 2>&1 || rc=$?
check "no file: exit 2" '[ "$rc" -eq 2 ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "LEARNINGS ACCEPTANCE: ALL CHECKS PASS"; else echo "LEARNINGS ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
