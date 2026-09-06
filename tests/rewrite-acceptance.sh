#!/bin/sh
# Offline acceptance test for `workstream-rewrite.py records` and
# `decisions`: the two shipped condensation moves under their new names,
# each fired red-then-green with the dry run, the idempotence of a
# second run, the structure fingerprint and the failure exits asserted;
# plus the removed-side checks every rewrite's suite carries (the
# dropped paragraph is absent, the count a surviving line states is
# re-derived after) and the non-conforming fixture (an indented
# sub-task, a suffixed phase heading, a wrapped open line) reported as
# untouched. The shim's own suite (condense-acceptance.sh) covers the
# old name.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-rewrite.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-rewrite-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

W="$T/workstream.md"
LONG="a record that accreted while it was open: the evaluation, its three options, the build notes and the audit, all of which the completion note need not carry"
{
  cat <<'FIX'
---
name: fixture
type: maintain
status: active
---
## Purpose
A fixture.

## Backlog
### Build (BD) -- the heading carries a suffix, as real files do
FIX
  printf -- '- [x] #BD-1: Decide the widget shape. Evaluate (do NOT pre-decide): (i) round; (ii) square. DECIDED 2026-01-02 (D2) (i): round, because %s %s. Built at commit abc1234, mirrored as 1bbfbd74 in the other repo, 1234567 bytes moved, and released 2026-01-03.\n' "$LONG" "$LONG"
  cat <<'FIX'
- [x] #BD-2: a short done task, DONE 2026-01-01
- [ ] #BD-3: an open task wrapped against the convention, with a
second line
  - [ ] #BD-3a: an indented sub-task
- [ ] #G-BD: USER CHECKPOINT -- the build gate; three Decisions stand

## Decisions
### D3 (2026-01-03): Third, written first
The reasoning paragraph of the third decision, hard-wrapped over
two lines.

A second paragraph with the options weighed and rejected, which a
condensation drops.

### D1 (2026-01-01): First
The first decision's reasoning.

Its second paragraph.

### D2 (2026-01-02): Second, stays whole
The second decision's reasoning.

Its second paragraph, which must survive because D2 is not named.

## Learnings
- L1 (2026-01-01): an insight. APPLIED 2026-01-02 to a file.
FIX
} > "$W"
cp "$W" "$T/original.md"
fp() { grep -E '^#{1,6} ' "$1" | sort; grep -oE '^ *- \[[ x]\] #[A-Za-z]+-[0-9]+' "$1"; }
fp "$W" > "$T/fp-before.txt"

echo "== records: dry run, write, idempotence"
OUT=$(python3 "$SCRIPT" records "$W" --date 2026-05-05)
check "dry run reports condensed=1 and leaves the file byte-identical" \
  "printf '%s' \"\$OUT\" | grep -q '^condensed=1 ' && ! printf '%s' \"\$OUT\" | grep -q WRITTEN && cmp -s \"\$W\" \"\$T/original.md\""
check "dry run prints one entry line per condensed record in the report shape: ID, bytes before->after, the condensed line" \
  "printf '%s' \"\$OUT\" | grep -qE '^#BD-1 [0-9]+->[0-9]+: - \\[x\\] #BD-1: Decide the widget shape\\.' && [ \"\$(printf '%s\\n' \"\$OUT\" | grep -cE '^#[A-Z]+-[0-9]+ [0-9]+->[0-9]+: ')\" = 1 ]"
check "the entry line's byte figures are the fixture line's length and the note's" \
  "[ \"\$(printf '%s\\n' \"\$OUT\" | sed -n 's/^#BD-1 \\([0-9]*\\)->.*/\\1/p')\" = \"\$(grep '^- \\[x\\] #BD-1' \"\$W\" | tr -d '\\n' | wc -c | tr -d ' ')\" ]"
OUT=$(python3 "$SCRIPT" records "$W" --write --date 2026-05-05)
check "write reports condensed=1 and WRITTEN" "printf '%s' \"\$OUT\" | grep -q '^condensed=1 ' && printf '%s' \"\$OUT\" | grep -q WRITTEN"
check "#BD-1 fits the completion-note form, keeps status, date, Decision, commit and the dated marker" \
  "[ \"\$(grep '^- \\[x\\] #BD-1' \"\$W\" | wc -c)\" -lt 400 ] && grep '^- \\[x\\] #BD-1' \"\$W\" | grep -q 'DECIDED 2026-01-03; reasoning in D2; commits abc1234, 1bbfbd74. Condensed 2026-05-05 at extract'"
check "the eight-character hash in another repo is kept verbatim and the seven-digit number is not taken for one" \
  "grep '^- \\[x\\] #BD-1' \"\$W\" | grep -q '1bbfbd74' && ! grep '^- \\[x\\] #BD-1' \"\$W\" | grep -q '1234567'"
check "removed side: the evaluation prose is gone from the file" "! grep -q 'do NOT pre-decide' \"\$W\""
check "#BD-2, the wrapped #BD-3, the indented #BD-3a and the gate are byte-identical" \
  "grep -qF -- '- [x] #BD-2: a short done task, DONE 2026-01-01' \"\$W\" && grep -q '^second line\$' \"\$W\" && grep -qF -- '  - [ ] #BD-3a: an indented sub-task' \"\$W\" && grep -qF -- '- [ ] #G-BD: USER CHECKPOINT -- the build gate; three Decisions stand' \"\$W\""
fp "$W" > "$T/fp-after.txt"
check "headings and checkbox IDs/states identical before and after" "cmp -s \"\$T/fp-before.txt\" \"\$T/fp-after.txt\""
cp "$W" "$T/after1.md"
OUT=$(python3 "$SCRIPT" records "$W" --write --date 2026-06-06)
check "a second run reports condensed=0, NO CHANGE, and keeps the first run's date" \
  "printf '%s' \"\$OUT\" | grep -q '^condensed=0 ' && printf '%s' \"\$OUT\" | grep -q 'NO CHANGE' && cmp -s \"\$W\" \"\$T/after1.md\" && ! grep -q 'Condensed 2026-06-06' \"\$W\""

echo "== decisions: dry run, write, reorder, idempotence, the count a surviving line states"
OUT=$(python3 "$SCRIPT" decisions "$W" --decisions D1,D3 --release v0.1.0 --date 2026-05-05)
check "dry run reports decisions_condensed=2 reordered=yes and writes nothing" \
  "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=2 .*reordered=yes' && cmp -s \"\$W\" \"\$T/after1.md\""
check "decisions dry run prints the same entry shape: D3 and D1, bytes before->after, the heading" \
  "printf '%s' \"\$OUT\" | grep -qE '^D3 [0-9]+->[0-9]+: ### D3 ' && printf '%s' \"\$OUT\" | grep -qE '^D1 [0-9]+->[0-9]+: ### D1 ' && [ \"\$(printf '%s\\n' \"\$OUT\" | grep -cE '^D[0-9]+ [0-9]+->[0-9]+: ')\" = 2 ]"
OUT=$(python3 "$SCRIPT" decisions "$W" --write --decisions D1,D3 --release v0.1.0 --date 2026-05-05)
check "write reports decisions_condensed=2 and WRITTEN" "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=2' && printf '%s' \"\$OUT\" | grep -q WRITTEN"
check "Decisions now run D1, D2, D3" "[ \"\$(grep -E '^### D[0-9]+' \"\$W\" | cut -d' ' -f2 | tr '\\n' ' ')\" = 'D1 D2 D3 ' ]"
check "D3 keeps its heading and wrapped reasoning, then names the release" \
  "grep -A3 '^### D3 ' \"\$W\" | grep -q 'hard-wrapped over' && grep -A3 '^### D3 ' \"\$W\" | grep -q 'Shipped in v0.1.0. Condensed 2026-05-05 at extract'"
check "removed side: D3's and D1's second paragraphs are gone, D2's survives" \
  "! grep -q 'options weighed and rejected' \"\$W\" && ! grep -q '^Its second paragraph\\.\$' \"\$W\" && grep -q 'must survive because D2 is not named' \"\$W\""
check "the gate line's count (three Decisions) is still true after the move: three headings remain" \
  "[ \"\$(grep -c '^### D' \"\$W\")\" = 3 ] && grep -q 'three Decisions stand' \"\$W\""
check "the tasks are untouched by a decisions run" "grep -qF -- '- [x] #BD-2: a short done task, DONE 2026-01-01' \"\$W\""
fp "$W" > "$T/fp-after2.txt"
check "headings (as a multiset) and checkboxes identical after the move" "cmp -s \"\$T/fp-before.txt\" \"\$T/fp-after2.txt\""
cp "$W" "$T/after2.md"
OUT=$(python3 "$SCRIPT" decisions "$W" --write --decisions D1,D3 --release v0.9.9 --date 2026-06-06)
check "a second decisions run is a no-op" "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=0 .*reordered=no' && cmp -s \"\$W\" \"\$T/after2.md\""
OUT=$(python3 "$SCRIPT" decisions "$W" --decisions D1-D3 --release v0.1.0)
check "a range names D2 as well: dry run reports one more to condense" "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=1'"

echo "== Failure exits"
rc=0; python3 "$SCRIPT" decisions "$W" --decisions D9 --release v0.1.0 >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "a Decision that does not exist: exit 1, stderr names D9, file unchanged" \
  "[ \"\$rc\" -eq 1 ] && grep -q 'D9' \"\$T/e.txt\" && cmp -s \"\$W\" \"\$T/after2.md\""
rc=0; python3 "$SCRIPT" decisions "$W" --decisions D1 >/dev/null 2>&1 || rc=$?
check "decisions without --release: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" records "$T/absent.md" >/dev/null 2>&1 || rc=$?
check "a missing file: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" records "$W" --bogus >/dev/null 2>&1 || rc=$?
check "an unknown option: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" "$W" >/dev/null 2>&1 || rc=$?
check "no sub-command: exit 2" '[ "$rc" -eq 2 ]'
printf -- '## Learnings\n- L1: x\n' > "$T/nobacklog.md"
rc=0; python3 "$SCRIPT" records "$T/nobacklog.md" >/dev/null 2>&1 || rc=$?
check "a file with no ## Backlog: records refuses with exit 1" '[ "$rc" -eq 1 ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "REWRITE ACCEPTANCE: ALL CHECKS PASS"; else echo "REWRITE ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
