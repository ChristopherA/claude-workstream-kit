#!/bin/sh
# Offline acceptance test for how /workstream-work hands a /goal condition
# to the user. The clipboard and the fenced block carry the CONDITION
# ALONE, and the user types `/goal` and a space before pasting. With the
# `/goal` prefix on the clipboard, neither way of pasting arms the goal as
# meant: pasted as a prompt, the CLI collapses a long paste into a paste
# block that reaches the model as text, so no hook is armed; typed after
# `/goal`, the stored condition begins with a second `/goal`.
#
# This guards the skill's instruction text, not the model's behaviour.
# Every negative check first asserts that the text it reads was found, so
# a moved or renamed bullet fails loudly instead of passing as clean.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SKILL="$KIT_DIR/.claude/skills/workstream-work/SKILL.md"
FAIL="$KIT_DIR/.claude/skills/workstream-work/references/failures.md"
RESULT=0

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

BULLET=$(grep -F -- '- **Copy to clipboard**' "$SKILL" || true)
NOTE=$(grep -F 'On selection, the clipboard and the fenced block' "$FAIL" || true)

echo "== The skill's Copy to clipboard option"
check "exactly one Copy to clipboard bullet is found" '[ "$(printf "%s\n" "$BULLET" | grep -c .)" = 1 ]'
check "it puts the condition alone on the clipboard" 'printf "%s" "$BULLET" | grep -q "CONDITION ALONE"'
check "it tells the user to type /goal, a space, and paste" \
  'printf "%s" "$BULLET" | grep -qF "tell the user to type \`/goal\`, a space, and paste"'
check "it no longer places the prefixed /goal <condition> on the clipboard" \
  '! printf "%s" "$BULLET" | grep -qF "place the full \`/goal <condition>\`"'
check "the clipboard and the fenced block still carry the same text" \
  'grep -q "the clipboard and the fenced block carry the exact same text" "$SKILL"'

echo "== The failure reference agrees"
check "the reference's clipboard sentence is found" '[ -n "$NOTE" ]'
check "it says the text carries no /goal prefix" 'printf "%s" "$NOTE" | grep -qF "without a \`/goal\` prefix"'
check "it names both ways a prefixed paste fails" \
  'printf "%s" "$NOTE" | grep -q "arms no hook" && printf "%s" "$NOTE" | grep -q "second \`/goal\`"'

echo
if [ "$RESULT" -eq 0 ]; then echo "GOAL-DELIVERY ACCEPTANCE: ALL CHECKS PASS"; else echo "GOAL-DELIVERY ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
