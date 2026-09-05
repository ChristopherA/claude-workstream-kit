#!/bin/sh
# Offline acceptance test for `workstream-record.py self-check`: the
# status skill's instrument validation as a sub-command, every pattern
# the record uses fired at built-in known-positive and known-negative
# strings. A self-check that has never failed has been run, not tested,
# so this suite copies the scripts, breaks one pattern with sed, and
# asserts the copy's self-check exits 1 NAMING that pattern; then the
# original exits 0.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-selfcheck-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

echo "== The shipped scripts pass their own self-check"
rc=0; python3 "$SCRIPT" self-check > "$T/ok.txt" 2>&1 || rc=$?
check "self-check exits 0" '[ "$rc" -eq 0 ]'
check "it reports every pattern checked, and at least ten of them" \
  '[ "$(grep -c "^ok " "$T/ok.txt")" -ge 10 ] && grep -q "^SELF-CHECK OK" "$T/ok.txt"'
check "the hold verb, the threshold word, Held-out, a negated hold, a wrapped marker, a marker mention, ml-explore/mlx and the dated and undated SATISFIED are among the strings" \
  '(for s in "blocked on" threshold Held-out "Nothing in this file" "HANDED OFF" mid-sentence ml-explore/mlx "SATISFIED 2026" "SATISFIED sentence"; do grep -q -- "$s" "$T/ok.txt" || exit 1; done)'

echo "== A broken pattern is caught and named"
mkdir -p "$T/broken"
cp "$KIT_DIR/.claude/scripts/workstream-record.py" "$KIT_DIR/.claude/scripts/workstream_state.py" "$T/broken/"
sed -i.bak 's/blocked (?:by|on)/blocked (?:by|onn)/' "$T/broken/workstream_state.py" && rm -f "$T/broken/workstream_state.py.bak"
check "fixture: the copy's hold pattern is broken (blocked onn)" 'grep -q "blocked (?:by|onn)" "$T/broken/workstream_state.py"'
rc=0; python3 "$T/broken/workstream-record.py" self-check > "$T/broken.txt" 2>&1 || rc=$?
check "the broken copy's self-check exits 1" '[ "$rc" -eq 1 ]'
check "it names HOLD_RE and the string that missed" 'grep -q "^MISS HOLD_RE" "$T/broken.txt" && grep -q "blocked on" "$T/broken.txt"'
check "the other patterns still report ok (one miss, not a crash)" '[ "$(grep -c "^ok " "$T/broken.txt")" -ge 9 ]'

echo "== A second break, in the marker rule, is caught too"
mkdir -p "$T/broken2"
cp "$KIT_DIR/.claude/scripts/workstream-record.py" "$KIT_DIR/.claude/scripts/workstream_state.py" "$T/broken2/"
# Drop the position half of the marker rule: every mention becomes a marker.
sed -i.bak "s/        if not at_start:/        if False:/" "$T/broken2/workstream_state.py" && rm -f "$T/broken2/workstream_state.py.bak"
check "fixture: the copy's position test is disabled" 'grep -q "        if False:" "$T/broken2/workstream_state.py"'
rc=0; python3 "$T/broken2/workstream-record.py" self-check > "$T/broken2.txt" 2>&1 || rc=$?
check "the marker-rule break exits 1 naming disposition and the mention string" \
  '[ "$rc" -eq 1 ] && grep -q "^MISS disposition" "$T/broken2.txt" && grep -q "mid-sentence" "$T/broken2.txt"'

echo "== The original is untouched by the copies"
check "the shipped self-check still exits 0" 'python3 "$SCRIPT" self-check >/dev/null 2>&1'
rc=0; python3 "$SCRIPT" self-check "$T" >/dev/null 2>&1 || rc=$?
check "self-check takes no arguments (exit 2 with one)" '[ "$rc" -eq 2 ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "SELF-CHECK ACCEPTANCE: ALL CHECKS PASS"; else echo "SELF-CHECK ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
