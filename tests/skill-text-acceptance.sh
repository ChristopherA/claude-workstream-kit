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
#   workstream-work, independent gate items: an empty multi-select was
#     the consent signal, and a question absent from the result reads
#     the same as one answered with nothing selected.
#   workstream-work, the intake re-list: the hook reports the inbox
#     once, and a goal was drafted without three handoffs that landed
#     after it ran.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HANDOFF="$KIT_DIR/.claude/skills/handoff/SKILL.md"
WORK="$KIT_DIR/.claude/skills/workstream-work/SKILL.md"
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

echo "== workstream-work: the consent signal for independent gate items"
INDEP=$(grep -F 'INDEPENDENT items get one message' "$WORK" || true)
check "the independent-items passage is found" '[ -n "$INDEP" ]'
check "it asks one single-select first, take all as recommended or discuss some first" \
  'printf "%s" "$INDEP" | grep -q "one single-select first" && printf "%s" "$INDEP" | grep -q "take all as recommended, or discuss some first"'
check "a multi-select is asked only on discuss" 'printf "%s" "$INDEP" | grep -q "multi-select of which to discuss only on discuss"'
check "an empty answer is not consent, and a missing question is re-asked" \
  'printf "%s" "$INDEP" | grep -q "never an empty answer" && printf "%s" "$INDEP" | grep -q "A question missing from the result is re-asked"'
check "the old empty-multi-select consent wording is gone" '! printf "%s" "$INDEP" | grep -q "a single multi-select asking which"'

echo "== workstream-work: the intake is re-listed before a goal and a gate"
RELIST=$(grep -F '**Re-list the intake first.**' "$WORK" || true)
GATE=$(grep -F -- '- `#G-` checkpoints:' "$WORK" || true)
check "the re-list paragraph and the gate bullet are found" '[ -n "$RELIST" ] && [ -n "$GATE" ]'
check "the re-list sits in the goal section, before Scope" \
  'awk "/^## Derive the goal condition/{on=1} on && /Re-list the intake first/{r=NR} on && /^\\*\\*Scope\\./{s=NR; exit} END{exit !(r && s && r < s)}" "$WORK"'
check "it lists the inbox again and the other channels the critical path names" \
  'printf "%s" "$RELIST" | grep -qF "list \`.state/handoffs/\` again" && printf "%s" "$RELIST" | grep -q "critical path names"'
check "the gate bullet re-lists the intake before it stops" 'printf "%s" "$GATE" | grep -q "re-list the intake, then STOP"'

echo
if [ "$RESULT" -eq 0 ]; then echo "SKILL-TEXT ACCEPTANCE: ALL CHECKS PASS"; else echo "SKILL-TEXT ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
