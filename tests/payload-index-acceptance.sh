#!/bin/sh
# Offline acceptance test for install.sh's payload enumeration: from a git
# checkout the payload is what the index tracks under the five payload
# directories, so an untracked scratch file or a python __pycache__ in the
# steward's checkout is neither reported by the dry run nor installed; from
# a plain copy with no index the find fallback installs what is on disk.
# Observed 2026-09-05: a py_compile left .claude/scripts/__pycache__/ in the
# checkout and the dry run listed two .pyc files as payload it would create.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/kit-payload-index.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

# A private clone of the kit, so the real checkout is never touched. The
# clone carries the committed tree; the installer under test is the working
# copy, so it is copied over the clone's before anything runs.
git clone -q "$KIT_DIR" "$T/kit"
cp "$KIT_DIR/install.sh" "$T/kit/install.sh"
git -C "$T/kit" config commit.gpgsign false
mkdir -p "$T/kit/.claude/scripts/__pycache__"
printf 'x\n' > "$T/kit/.claude/scripts/__pycache__/probe.cpython-99.pyc"
printf 'x\n' > "$T/kit/.claude/skills/zz-scratch-untracked.md"
TRACKED=$(git -C "$T/kit" ls-files -- .claude/rules .claude/skills .claude/agents .claude/hooks .claude/scripts | wc -l | tr -d ' ')

mkproj() { mkdir -p "$1"; git -C "$1" init -q -b main; git -C "$1" config commit.gpgsign false; git -C "$1" config user.email f@example.invalid; git -C "$1" config user.name F; git -C "$1" commit -q --allow-empty -m init; }

echo "== From a checkout: the index is the payload"
mkproj "$T/p1"
check "fixture: the clone carries an untracked scratch file and a __pycache__ under payload directories" \
  "[ -f \"$T/kit/.claude/skills/zz-scratch-untracked.md\" ] && [ -f \"$T/kit/.claude/scripts/__pycache__/probe.cpython-99.pyc\" ] && [ -z \"\$(git -C \"$T/kit\" ls-files -- .claude/skills/zz-scratch-untracked.md)\" ]"
sh "$T/kit/install.sh" --dry-run "$T/p1" > "$T/dry1" 2>&1 || true
check "the dry run names neither the scratch file nor the __pycache__" "! grep -q 'zz-scratch-untracked' \"$T/dry1\" && ! grep -q '__pycache__' \"$T/dry1\""
check "the dry run's would-create count under the payload directories equals the tracked count ($TRACKED)" "[ \"\$(grep -cE '^  \\+ \\.claude/(rules|skills|agents|hooks|scripts)/' \"$T/dry1\")\" = \"$TRACKED\" ]"
sh "$T/kit/install.sh" "$T/p1" > "$T/real1" 2>&1
check "a real install writes no scratch file and no __pycache__ into the target" "[ ! -e \"$T/p1/.claude/skills/zz-scratch-untracked.md\" ] && [ ! -e \"$T/p1/.claude/scripts/__pycache__\" ]"
check "every tracked payload file was installed" "[ \"\$(cd \"$T/p1\" && find .claude/rules .claude/skills .claude/agents .claude/hooks .claude/scripts -type f | wc -l | tr -d ' ')\" = \"$TRACKED\" ]"
check "a second dry run reports the target in sync (exit 0)" "sh \"$T/kit/install.sh\" --dry-run \"$T/p1\" >/dev/null 2>&1"

echo "== From a plain copy with no index: the find fallback installs what is on disk"
mkdir -p "$T/kitcopy" && cp -R "$T/kit/." "$T/kitcopy/" && rm -rf "$T/kitcopy/.git"
mkproj "$T/p2"
sh "$T/kitcopy/install.sh" "$T/p2" > "$T/real2" 2>&1
check "fixture: the copy is not a git checkout" "! git -C \"$T/kitcopy\" rev-parse --git-dir >/dev/null 2>&1"
check "the fallback installs the tracked payload" "[ -f \"$T/p2/.claude/rules/workstreams-rule.md\" ] && [ -f \"$T/p2/.claude/scripts/workstream-record.py\" ]"
check "and, having no index to ask, it installs the scratch file too (the documented limit of a plain copy)" "[ -f \"$T/p2/.claude/skills/zz-scratch-untracked.md\" ]"

echo
if [ "$RESULT" -eq 0 ]; then echo "PAYLOAD-INDEX ACCEPTANCE: ALL CHECKS PASS"; else echo "PAYLOAD-INDEX ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
