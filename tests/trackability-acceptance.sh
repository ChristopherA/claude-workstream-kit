#!/bin/sh
# Acceptance test for the installer's payload-trackability probe.
#
# The defect it guards: on a target whose .gitignore hides .claude/, the install
# succeeds, every payload file is written, and none of it can be committed --
# while --dry-run reported "In sync". The state files travel and the machinery
# does not, which is the one failure that defeats the kit's stated value while
# presenting as success.
#
# Every check is fired against BOTH a target that ignores the payload and one
# that does not, because a probe that has only ever seen the broken case cannot
# show it stays quiet on the healthy one.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

mk_target() { # <dir> <ignore-line>
  mkdir -p "$1"; cd "$1"
  git init -q -b main
  git config user.email "tests@example.invalid"; git config user.name "kit tests"
  git config commit.gpgsign false
  printf '%s\n' "$2" > .gitignore
  git add .gitignore; git commit -qm init
  cd - >/dev/null
}

# Runs the dry run WITHOUT a command substitution: $( ) is a subshell, so a
# variable set inside it does not survive, which is how the first version of
# this helper lost its output.
run_dry() { # <dir> <outfile>; sets RC
  set +e
  "$KIT_DIR/install.sh" --dry-run "$1" > "$2" 2>&1
  RC=$?
  set -e
}

T=$(mktemp -d "${TMPDIR:-/tmp}/kit-track.XXXXXX")
trap 'rm -rf "$T"' EXIT

echo "== RED: a target that ignores .claude/"
mk_target "$T/hidden" '.claude/'
"$KIT_DIR/install.sh" "$T/hidden" > "$T/hidden-install.txt" 2>&1
check "install still succeeds (exit 0)" "[ -f \"$T/hidden/.claude/hooks/session-start.sh\" ]"
check "install names the ignored paths" \
  "grep -q 'ignores these installed payload paths' \"$T/hidden-install.txt\""
check "install withdraws the commit instruction" \
  "grep -q 'not committable as the target stands' \"$T/hidden-install.txt\""
check "install states the git-delivery boundary" \
  "grep -q 'CANNOT extend to the same file arriving over git' \"$T/hidden-install.txt\""
check "payload really is invisible to git" \
  "[ -z \"\$(git -C \"$T/hidden\" ls-files .claude/)\" ]"

run_dry "$T/hidden" "$T/hidden-dry.txt"
check "dry run exits 3 (the third state)" "[ \"$RC\" = 3 ]"
check "dry run reports untrackable" "grep -q 'untrackable:' \"$T/hidden-dry.txt\""
check "dry run does NOT claim In sync" "! grep -q 'In sync' \"$T/hidden-dry.txt\""

echo "== GREEN: an identical target that tracks .claude/"
mk_target "$T/plain" 'unrelated-pattern'
"$KIT_DIR/install.sh" "$T/plain" > "$T/plain-install.txt" 2>&1
check "install prints the normal commit instruction" \
  "grep -q 'Commit the new files' \"$T/plain-install.txt\""
check "install raises no trackability warning" \
  "! grep -q 'ignores these installed payload paths' \"$T/plain-install.txt\""
git -C "$T/plain" add -A && git -C "$T/plain" commit -qm 'install kit'
run_dry "$T/plain" "$T/plain-dry.txt"
check "dry run exits 0" "[ \"$RC\" = 0 ]"
check "dry run claims In sync" "grep -q 'In sync' \"$T/plain-dry.txt\""
check "dry run reports no untrackable paths" "! grep -q 'untrackable:' \"$T/plain-dry.txt\""

echo "== A tracked payload under a matching ignore pattern is NOT flagged"
# Tracking beats a matching pattern, so a consumer who force-added the payload
# must stay silent -- otherwise the probe cries wolf at exactly the people who
# already did the right thing.
mk_target "$T/forced" '.claude/'
"$KIT_DIR/install.sh" "$T/forced" >/dev/null 2>&1
git -C "$T/forced" add -f .claude >/dev/null 2>&1
git -C "$T/forced" add -A >/dev/null 2>&1
git -C "$T/forced" commit -qm 'force-add payload'
run_dry "$T/forced" "$T/forced-dry.txt"
check "force-added payload is not reported untrackable" \
  "! grep -q 'untrackable:' \"$T/forced-dry.txt\""
check "force-added payload dry run exits 0" "[ \"$RC\" = 0 ]"

echo "== A non-git target is not a defect"
mkdir -p "$T/nogit"
"$KIT_DIR/install.sh" "$T/nogit" > "$T/nogit-install.txt" 2>&1
check "non-git target raises no trackability warning" \
  "! grep -q 'ignores these installed payload paths' \"$T/nogit-install.txt\""

echo
if [ "$RESULT" -eq 0 ]; then
  echo "TRACKABILITY ACCEPTANCE: ALL CHECKS PASS"
else
  echo "TRACKABILITY ACCEPTANCE: FAILURES ABOVE"
fi
exit "$RESULT"
