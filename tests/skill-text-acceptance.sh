#!/bin/sh
# Offline acceptance test for instruction text the skills carry where no
# script enforces it, each clause one a session followed literally and
# was misled by. It guards the text, not the model's behaviour. Every
# check first finds the passage it reads, so a moved or renamed passage
# fails loudly instead of passing as clean.
#
#   handoff, Create step 7: a correction to an item in flight was a
#     shell append onto a file the receiver had triaged minutes earlier,
#     which silently created a fresh file holding only the correction.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HANDOFF="$KIT_DIR/.claude/skills/handoff/SKILL.md"
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

echo "== handoff: correcting an item in flight"
STEP7=$(grep -F '7. **Correcting an item still in flight' "$HANDOFF" || true)
check "Create step 7 is found" '[ -n "$STEP7" ]'
check "it confirms the file still exists in the receiver's inbox before editing" \
  'printf "%s" "$STEP7" | grep -q "exists in the receiver.s inbox"'
check "it reads the receiver's git log for a commit deleting the file" \
  'printf "%s" "$STEP7" | grep -qF "git -C <dest> log -1 -- <file>"'
check "a file already gone makes the correction a new handoff citing the filing and receive commits" \
  'printf "%s" "$STEP7" | grep -q "new handoff citing the filing and receive commits"'
check "it steers the edit away from a shell append" \
  'printf "%s" "$STEP7" | grep -q "fails on a missing file" && printf "%s" "$STEP7" | grep -qF "(\`>>\`)"'

echo
if [ "$RESULT" -eq 0 ]; then echo "SKILL-TEXT ACCEPTANCE: ALL CHECKS PASS"; else echo "SKILL-TEXT ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
