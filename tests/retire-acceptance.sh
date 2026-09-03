#!/bin/sh
# Offline acceptance test for payload retirement: a file the kit once shipped
# and no longer does is removed by a real install, its hook registrations go
# with it while foreign registrations on the same events survive, a locally
# modified copy is refused without --force and removed with it, and a target
# that never carried the file sees no retired line at all.
#
# Every negative check asserts the fixture state it assumes before it fires and
# matches the specific diagnostic it expects, not any failure.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-retire-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

RETIRED=.claude/hooks/capture-nudge.sh
# The content the kit shipped: HEAD's copy while the deletion is still
# uncommitted, else the parent of the commit that deleted the file.
if git -C "$KIT_DIR" cat-file -e "HEAD:${RETIRED}" 2>/dev/null; then
  git -C "$KIT_DIR" show "HEAD:${RETIRED}" > "$T/shipped-nudge.sh"
else
  DEL=$(git -C "$KIT_DIR" log -n1 --format=%H --diff-filter=D -- "$RETIRED")
  git -C "$KIT_DIR" show "${DEL}^:${RETIRED}" > "$T/shipped-nudge.sh"
fi

mk_target() { # <dir> -- a project carrying the retired hook and its registrations
  mkdir -p "$1/.claude/hooks"
  cp "$T/shipped-nudge.sh" "$1/$RETIRED"
  cat > "$1/.claude/settings.json" <<'JSON'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh"}]}],"PreCompact":[{"hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/capture-nudge.sh"}]},{"hooks":[{"type":"command","command":"echo keep-me"}]}],"SessionEnd":[{"hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/capture-nudge.sh"}]}]}}
JSON
  (cd "$1" && git init -q -b main && git config user.name t && git config user.email t@example.invalid \
     && git config commit.gpgsign false && git add -A && git commit -q -m fixture)
}

echo "== A: a target carrying the shipped hook"
A="$T/a"; mk_target "$A"
check "fixture: the retired file is present and matches what the kit shipped" \
  "cmp -s \"\$T/shipped-nudge.sh\" \"\$A/\$RETIRED\""
set +e; DRY=$(sh "$KIT_DIR/install.sh" --dry-run "$A" 2>&1); DRC=$?; set -e
check "dry-run exits 1 (the retired file counts as drift)" "[ \"\$DRC\" -eq 1 ]"
check "dry-run names the retired file as one a real run removes" \
  "printf '%s' \"\$DRY\" | grep -q -- '- $RETIRED  (retired -- would be removed; instance-behind'"
check "dry-run says the hook merge would change registrations" \
  "printf '%s' \"\$DRY\" | grep -q 'hook merge would change registrations'"
sh "$KIT_DIR/install.sh" "$A" > "$T/a-install.txt" 2>&1
check "install exits 0 and reports the removal" "grep -q 'removed retired $RETIRED' \"\$T/a-install.txt\""
check "the retired file is gone" "[ ! -f \"\$A/\$RETIRED\" ]"
check "no registration of the retired hook remains" \
  "! jq -e '[.. | .command? // empty] | any(test(\"capture-nudge\"))' \"\$A/.claude/settings.json\" >/dev/null"
check "the foreign PreCompact hook survives" \
  "jq -e '.hooks.PreCompact | any(.[] | .hooks[]?; .command == \"echo keep-me\")' \"\$A/.claude/settings.json\" >/dev/null"
check "SessionEnd, left with no groups, is dropped" \
  "! jq -e '.hooks.SessionEnd' \"\$A/.claude/settings.json\" >/dev/null"
check "the session-start registration stays" \
  "jq -e '.hooks.SessionStart | any(.[] | .hooks[]?; .command | test(\"session-start.sh\"))' \"\$A/.claude/settings.json\" >/dev/null"
set +e; DRY2=$(sh "$KIT_DIR/install.sh" --dry-run "$A" 2>&1); DRC2=$?; set -e
check "second dry-run reports nothing to remove" "! printf '%s' \"\$DRY2\" | grep -q 'retired -- would be removed'"

echo "== B: a target whose copy of the retired hook was edited locally"
B="$T/b"; mk_target "$B"
echo "# local edit" >> "$B/$RETIRED"
check "fixture: B's copy differs from what the kit shipped" "! cmp -s \"\$T/shipped-nudge.sh\" \"\$B/\$RETIRED\""
set +e; OUTB=$(sh "$KIT_DIR/install.sh" "$B" 2>&1); RCB=$?; set -e
check "install without --force refuses (exit 1)" "[ \"\$RCB\" -eq 1 ]"
check "the refusal names the retired file and says --force removes it" \
  "printf '%s' \"\$OUTB\" | grep -q -- '$RETIRED  (RETIRED in this kit and locally modified -- --force removes it)'"
check "the edited copy is still there after the refusal" "[ -f \"\$B/\$RETIRED\" ]"
sh "$KIT_DIR/install.sh" --force "$B" > "$T/b-force.txt" 2>&1
check "--force removes the edited copy" "[ ! -f \"\$B/\$RETIRED\" ] && grep -q 'removed retired' \"\$T/b-force.txt\""

echo "== C: a target that never carried the retired hook"
C="$T/c"; mkdir -p "$C"
check "fixture: C has no .claude directory" "[ ! -d \"\$C/.claude\" ]"
set +e; DRYC=$(sh "$KIT_DIR/install.sh" --dry-run "$C" 2>&1); set -e
check "dry-run prints no retired line" "! printf '%s' \"\$DRYC\" | grep -q 'retired -- would be removed'"
sh "$KIT_DIR/install.sh" "$C" > "$T/c-install.txt" 2>&1
check "install prints no removal line" "! grep -q 'removed retired' \"\$T/c-install.txt\""
check "the kit's own settings carry no PreCompact or SessionEnd key" \
  "! jq -e '.hooks.PreCompact, .hooks.SessionEnd' \"\$C/.claude/settings.json\" 2>/dev/null | grep -q '\\['"

echo
if [ "$RESULT" -eq 0 ]; then
  echo "RETIRE ACCEPTANCE: ALL CHECKS PASS"
else
  echo "RETIRE ACCEPTANCE: FAILURES ABOVE"
fi
exit "$RESULT"
