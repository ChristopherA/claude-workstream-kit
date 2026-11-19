#!/bin/sh
# Offline acceptance test: the payload shows an agent no zsh-only
# parameter expansion to compose. Claude Code's Bash tool checks every
# command for a dangerous `rm` and denies one it cannot parse, removal or
# not, so a read-only command built from such a form comes back denied,
# the same answer on every retry and no approval shown to an unattended
# session. The forms: expansion flags (`${(f)VAR}`, `${(s:,:)VAR}`),
# nested expansion (`${${u#*x}%y}`) and the length of a command
# substitution (`${#$(cmd)}`). Plain assignments, explicit paths or a
# pipe through sed do the same work. The sweep is fired at a fixture
# holding each form, and at one holding only portable forms, before its
# zero over the payload is believed.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-syntax-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

# Every line under <dir> holding one of the forms, as file:line:text.
sweep() {
  grep -rn -F -e '${(' -e '${${' -e '${#$(' "$1" 2>/dev/null || true
}

mkdir -p "$T/bad" "$T/good"
printf '%s\n' 'for l in ${(f)LIST}; do echo "$l"; done' > "$T/bad/flags.md"
printf '%s\n' 'r=${${u#*github.com[:/]}%.git}' > "$T/bad/nested.md"
printf '%s\n' 'n=${#$(print -l a b)}' > "$T/bad/length.md"
printf '%s\n' 'r=${u#*github.com[:/]}; r=${r%.git}' 'n=$(printf "%s\n" a b | wc -l)' 'echo "${HOME}" "${#VAR}"' > "$T/good/plain.md"

echo "== The sweep's own controls"
check "it catches each of the three forms in a fixture (3 lines)" \
  '[ "$(sweep "$T/bad" | wc -l | tr -d " ")" -eq 3 ]'
check "it passes the portable rewrites, \${VAR} and \${#VAR} included" \
  '[ -z "$(sweep "$T/good")" ]'

echo "== The payload"
check "the payload's .claude/ tree is found and non-empty" \
  '[ -d "$KIT_DIR/.claude/skills" ] && [ -n "$(ls "$KIT_DIR/.claude/skills")" ]'
HITS=$( { sweep "$KIT_DIR/.claude"; sweep "$KIT_DIR/README.md"; } )
check "no file under .claude/, nor the README, holds a zsh-only expansion" '[ -z "$HITS" ]'
[ -z "$HITS" ] || printf '%s\n' "$HITS" | cut -c1-200

echo
if [ "$RESULT" -eq 0 ]; then echo "PAYLOAD SYNTAX ACCEPTANCE: ALL CHECKS PASS"; else echo "PAYLOAD SYNTAX ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
