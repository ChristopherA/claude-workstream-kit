#!/bin/sh
# Offline acceptance test for condense-completed-records.py: the extract
# skill's two condensation moves -- completed task records in the live
# Backlog, and shipped Decisions named by the caller -- each fired
# red-then-green, with the dry run, the idempotence of a second run, the
# structure fingerprint, and the failure exits asserted.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/condense-completed-records.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-condense-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

W="$T/workstream.md"
LONG="a record that accreted while it was open: the evaluation, its three options, the build notes and the audit, all of which the completion note need not carry"
{
  cat <<'EOF'
---
name: fixture
type: maintain
status: active
---
## Purpose
A fixture.

## Backlog
### Build (BD)
EOF
  printf -- '- [x] #BD-1: Decide the widget shape. Evaluate (do NOT pre-decide): (i) round; (ii) square. DECIDED 2026-01-02 (D2) (i): round, because %s %s. Built at commit abc1234 and released 2026-01-03.\n' "$LONG" "$LONG"
  cat <<'EOF'
- [x] #BD-2: a short done task, DONE 2026-01-01
- [ ] #BD-3: an open task
- [ ] #G-BD: USER CHECKPOINT -- the build gate

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
- L1 (2026-01-01): an insight APPLIED to a file.
EOF
} > "$W"
cp "$W" "$T/original.md"

fp() { grep -E '^#{1,6} ' "$1" | sort; grep -oE '^ *- \[[ x]\] #[A-Za-z]+-[0-9]+' "$1"; }
fp "$W" > "$T/fp-before.txt"

echo "== Sanity"
check "fixture: #BD-1 runs past 400 bytes, #BD-2 does not" \
  "[ \"\$(grep '^- \\[x\\] #BD-1' \"\$W\" | wc -c)\" -gt 400 ] && [ \"\$(grep '^- \\[x\\] #BD-2' \"\$W\" | wc -c)\" -lt 400 ]"
check "fixture: Decisions sit out of numeric order (D3 first)" \
  "[ \"\$(grep -E '^### D[0-9]+' \"\$W\" | head -1 | cut -c1-6)\" = '### D3' ]"

echo "== Move 1: dry run reports and writes nothing"
OUT=$(python3 "$SCRIPT" "$W" --date 2026-05-05)
check "dry run reports condensed=1" "printf '%s' \"\$OUT\" | grep -q '^condensed=1 '"
check "dry run does not say WRITTEN" "! printf '%s' \"\$OUT\" | grep -q WRITTEN"
check "dry run leaves the file byte-identical" "cmp -s \"\$W\" \"\$T/original.md\""

echo "== Move 1: --write condenses the long record only"
OUT=$(python3 "$SCRIPT" "$W" --write --date 2026-05-05)
check "write reports condensed=1 and WRITTEN" "printf '%s' \"\$OUT\" | grep -q '^condensed=1 ' && printf '%s' \"\$OUT\" | grep -q WRITTEN"
check "#BD-1 now fits the completion-note form under 400 bytes" \
  "[ \"\$(grep '^- \\[x\\] #BD-1' \"\$W\" | wc -c)\" -lt 400 ]"
check "#BD-1's note keeps the status word and date, the Decision and the commit" \
  "grep '^- \\[x\\] #BD-1' \"\$W\" | grep -q 'DECIDED 2026-01-03; reasoning in D2; commits abc1234'"
check "#BD-1's note carries the dated condensation marker" \
  "grep '^- \\[x\\] #BD-1' \"\$W\" | grep -q 'Condensed 2026-05-05 at extract'"
check "#BD-2 (short) is untouched" "grep -qF -- '- [x] #BD-2: a short done task, DONE 2026-01-01' \"\$W\""
check "the open task and the gate are untouched" \
  "grep -qF -- '- [ ] #BD-3: an open task' \"\$W\" && grep -qF -- '- [ ] #G-BD: USER CHECKPOINT -- the build gate' \"\$W\""
check "the Decisions section is untouched by a tasks-only run" \
  "[ \"\$(grep -E '^### D[0-9]+' \"\$W\" | head -1 | cut -c1-6)\" = '### D3' ] && grep -q 'Its second paragraph\\.' \"\$W\""
fp "$W" > "$T/fp-after.txt"
check "headings and checkbox IDs/states are identical before and after" "cmp -s \"\$T/fp-before.txt\" \"\$T/fp-after.txt\""

echo "== Move 1: a second run is a no-op"
cp "$W" "$T/after1.md"
OUT=$(python3 "$SCRIPT" "$W" --write --date 2026-06-06)
check "second run reports condensed=0 and NO CHANGE" "printf '%s' \"\$OUT\" | grep -q '^condensed=0 ' && printf '%s' \"\$OUT\" | grep -q 'NO CHANGE'"
check "second run leaves the file byte-identical" "cmp -s \"\$W\" \"\$T/after1.md\""
check "the marker still carries the FIRST run's date" "grep -q 'Condensed 2026-05-05 at extract' \"\$W\" && ! grep -q 'Condensed 2026-06-06' \"\$W\""

echo "== Move 2: shipped Decisions condense and the section is reordered"
OUT=$(python3 "$SCRIPT" "$W" --no-tasks --decisions D1,D3 --release v0.1.0 --date 2026-05-05)
check "dry run reports decisions_condensed=2 reordered=yes and writes nothing" \
  "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=2 .*reordered=yes' && cmp -s \"\$W\" \"\$T/after1.md\""
OUT=$(python3 "$SCRIPT" "$W" --write --no-tasks --decisions D1,D3 --release v0.1.0 --date 2026-05-05)
check "write reports decisions_condensed=2 and WRITTEN" "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=2' && printf '%s' \"\$OUT\" | grep -q WRITTEN"
check "Decisions now run D1, D2, D3" \
  "[ \"\$(grep -E '^### D[0-9]+' \"\$W\" | cut -d' ' -f2 | tr '\\n' ' ')\" = 'D1 D2 D3 ' ]"
check "D3 keeps its heading and its wrapped reasoning paragraph, then names the release" \
  "grep -A3 '^### D3 ' \"\$W\" | grep -q 'hard-wrapped over' && grep -A3 '^### D3 ' \"\$W\" | grep -q 'Shipped in v0.1.0. Condensed 2026-05-05 at extract'"
check "D3's second paragraph is gone" "! grep -q 'options weighed and rejected' \"\$W\""
check "D1's second paragraph is gone" "! grep -q '^Its second paragraph\\.\$' \"\$W\""
check "D2 (not named) keeps its second paragraph" "grep -q 'must survive because D2 is not named' \"\$W\""
check "the tasks are untouched by a --no-tasks run" "grep -qF -- '- [x] #BD-2: a short done task, DONE 2026-01-01' \"\$W\""
fp "$W" > "$T/fp-after2.txt"
check "headings (as a multiset) and checkboxes are identical after the move" "cmp -s \"\$T/fp-before.txt\" \"\$T/fp-after2.txt\""
cp "$W" "$T/after2.md"
OUT=$(python3 "$SCRIPT" "$W" --write --no-tasks --decisions D1,D3 --release v0.9.9 --date 2026-06-06)
check "a second Decisions run is a no-op (condensed=0, reordered=no, byte-identical)" \
  "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=0 .*reordered=no' && cmp -s \"\$W\" \"\$T/after2.md\""
OUT=$(python3 "$SCRIPT" "$W" --no-tasks --decisions D1-D3 --release v0.1.0)
check "a range names D2 as well: dry run reports one more to condense" "printf '%s' \"\$OUT\" | grep -q 'decisions_condensed=1'"

echo "== Failure exits"
set +e
python3 "$SCRIPT" "$W" --no-tasks --decisions D9 --release v0.1.0 >"$T/o.txt" 2>"$T/e.txt"; rc=$?
set -e
check "a Decision that does not exist: exit 1, stderr names D9, file unchanged" \
  "[ \"\$rc\" -eq 1 ] && grep -q 'D9' \"\$T/e.txt\" && cmp -s \"\$W\" \"\$T/after2.md\""
set +e
python3 "$SCRIPT" "$W" --decisions D1 >/dev/null 2>&1; rc=$?
set -e
check "--decisions without --release: exit 2" "[ \"\$rc\" -eq 2 ]"
set +e
python3 "$SCRIPT" "$T/absent.md" >/dev/null 2>&1; rc=$?
set -e
check "a missing file: exit 2" "[ \"\$rc\" -eq 2 ]"
set +e
python3 "$SCRIPT" "$W" --bogus >/dev/null 2>&1; rc=$?
set -e
check "an unknown option: exit 2" "[ \"\$rc\" -eq 2 ]"

echo
if [ "$RESULT" -eq 0 ]; then
  echo "CONDENSE ACCEPTANCE: ALL CHECKS PASS"
else
  echo "CONDENSE ACCEPTANCE: FAILURES ABOVE"
fi
exit "$RESULT"
