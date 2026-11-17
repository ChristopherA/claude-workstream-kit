#!/bin/sh
# Acceptance test for keeping Python bytecode out of a target's commits.
# A check that compiles a kit script writes __pycache__/ beside it, and the
# upgrade skill stages all of .claude/, so in a target whose own ignores do
# not cover bytecode it landed in the upgrade commit (19 files committed
# where 16 were the kit's). The installer now adds __pycache__/ to
# .claude/.gitignore when the target's ignores miss it, once, and the work
# skill's file check names a parse that writes nothing. Pure shell -- no
# Claude session. Run from anywhere:
#   sh tests/bytecode-acceptance.sh
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
covered() { git -C "$1" check-ignore -q --no-index "$2"; }

echo "== An uncovered git target"
P="$WORK/plain"
mkdir -p "$P"
git -C "$P" init -q
check "fixture: the target's ignores do not cover bytecode under .claude/" \
  "! covered \"$P\" .claude/scripts/__pycache__/m.cpython-314.pyc"
rc=0; "$KIT_DIR/install.sh" --dry-run "$P" >"$WORK/dry.txt" 2>&1 || rc=$?
check "the dry run reports '+ .claude/.gitignore' and writes nothing" \
  "grep -q '^  + .claude/.gitignore' \"$WORK/dry.txt\" && [ ! -e \"$P/.claude/.gitignore\" ]"
"$KIT_DIR/install.sh" "$P" >"$WORK/run1.txt" 2>&1
check "the install adds __pycache__/ to .claude/.gitignore and says so" \
  "grep -qx '__pycache__/' \"$P/.claude/.gitignore\" && grep -q 'added __pycache__/ to .claude/.gitignore' \"$WORK/run1.txt\""
check "bytecode under .claude/scripts and under a skill's scripts is now ignored" \
  "covered \"$P\" .claude/scripts/__pycache__/m.cpython-314.pyc && covered \"$P\" .claude/skills/a/scripts/__pycache__/m.cpython-314.pyc"
check "the ignore reaches nothing outside .claude/" \
  "! covered \"$P\" src/__pycache__/m.cpython-314.pyc"
python3 -m py_compile "$P/.claude/scripts/workstream-record.py"
check "fixture: a compile check wrote bytecode into the payload" \
  "ls \"$P/.claude/scripts/__pycache__\"/*.pyc >/dev/null 2>&1"
git -C "$P" add -A -- .claude
check "the upgrade skill's 'git add -A -- .claude' stages no bytecode, and does stage .claude/.gitignore" \
  "! git -C \"$P\" diff --cached --name-only | grep -q '\\.pyc\$' && git -C \"$P\" diff --cached --name-only | grep -qx '.claude/.gitignore'"
cp "$P/.claude/.gitignore" "$WORK/gi1"
"$KIT_DIR/install.sh" "$P" >"$WORK/run2.txt" 2>&1
check "a re-install leaves .claude/.gitignore byte-identical and prints no addition (append once)" \
  "cmp -s \"$P/.claude/.gitignore\" \"$WORK/gi1\" && ! grep -q 'added __pycache__' \"$WORK/run2.txt\""
rc=0; "$KIT_DIR/install.sh" --dry-run "$P" >"$WORK/dry2.txt" 2>&1 || rc=$?
check "the dry run on the installed target no longer reports .claude/.gitignore" \
  "! grep -q '.claude/.gitignore' \"$WORK/dry2.txt\""

echo "== A target whose own ignores already cover bytecode"
C="$WORK/covered"
mkdir -p "$C"
git -C "$C" init -q
printf '__pycache__/\n' > "$C/.gitignore"
"$KIT_DIR/install.sh" "$C" >"$WORK/c.txt" 2>&1
check "no .claude/.gitignore is written" "[ ! -e \"$C/.claude/.gitignore\" ]"

echo "== A target with its own .claude/.gitignore"
O="$WORK/own"
mkdir -p "$O/.claude"
git -C "$O" init -q
printf 'local-notes/\n' > "$O/.claude/.gitignore"
"$KIT_DIR/install.sh" "$O" >"$WORK/o.txt" 2>&1
check "the line is appended after the target's own, which stays first" \
  "[ \"\$(head -n1 \"$O/.claude/.gitignore\")\" = 'local-notes/' ] && grep -qx '__pycache__/' \"$O/.claude/.gitignore\" && [ \"\$(wc -l < \"$O/.claude/.gitignore\" | tr -d ' ')\" = 2 ]"

echo "== A target that is not a git repository"
N="$WORK/nogit"
mkdir -p "$N"
"$KIT_DIR/install.sh" "$N" >"$WORK/n.txt" 2>&1
check "no .claude/.gitignore is written" "[ ! -e \"$N/.claude/.gitignore\" ]"

echo "== The work skill's file check"
for f in "$KIT_DIR/.claude/skills/workstream-work/SKILL.md" "$KIT_DIR/.claude/skills/workstream-work/references/failures.md"; do
  check "$(basename "$f") names a Python check that writes no bytecode, and py_compile only as the one to avoid" \
    "grep -qF 'ast.parse(open(sys.argv[1]).read())' \"$f\" && ! grep -qF '\`python3 -m py_compile\`' \"$f\""
done

echo
if [ "$RESULT" -eq 0 ]; then echo "BYTECODE ACCEPTANCE: ALL CHECKS PASS"; else echo "BYTECODE ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
