#!/bin/sh
# Acceptance test for install.sh --dry-run stamp-currency detection.
# Pure shell -- no Claude session. Run from anywhere:
#   sh tests/stamp-drift-acceptance.sh
#
# Verifies the dry-run's stamp contract (README: "exits non-zero when anything is
# out of sync"): a consumer whose payload matches the kit but whose version/source
# STAMP is behind is reported stamp-behind and exits non-zero, while a fully
# current consumer stays in sync at exit 0. Each stamp dimension (version-behind,
# .source-absent) is exercised in isolation, not as a convenient composite, so a
# regression in one limb cannot hide behind the other.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(cat "$KIT_DIR/VERSION")
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/proj"
mkdir -p "$PROJ"

# Baseline: a real install populates the current payload and current stamps.
"$KIT_DIR/install.sh" "$PROJ" >/dev/null 2>&1

# Run the dry run without tripping set -e on its intended non-zero exit.
run_dry() {
  set +e
  "$KIT_DIR/install.sh" --dry-run "$PROJ" >"$WORK/out" 2>&1
  rc=$?
  set -e
  echo "$rc"
}

echo "== S2: fully-current consumer is In sync at exit 0 (guards against over-firing)"
rc=$(run_dry)
check "S2 exit 0"                  "[ \"$rc\" = 0 ]"
check "S2 prints In sync verdict"  "grep -qF 'In sync:' \"$WORK/out\""
check "S2 no stamp-behind"         "! grep -qi 'stamp-behind' \"$WORK/out\""

echo "== S1: version behind AND .source absent (the reported fleet case)"
printf '0.4.0\n' > "$PROJ/.claude/workstream-kit.version"
rm -f "$PROJ/.claude/workstream-kit.source"
rc=$(run_dry)
check "S1 exit non-zero"           "[ \"$rc\" != 0 ]"
check "S1 prints stamp-behind"     "grep -qi 'stamp-behind' \"$WORK/out\""
check "S1 no In sync verdict"      "! grep -qF 'In sync:' \"$WORK/out\""
check "S1 no 'Nothing written'"    "! grep -qF 'Nothing written' \"$WORK/out\""
check "S1 payload still in sync"   "grep -qE 'payload:.*0 drifted' \"$WORK/out\""

echo "== S3: version current, .source absent (isolates the .source limb)"
printf '%s\n' "$VERSION" > "$PROJ/.claude/workstream-kit.version"
rm -f "$PROJ/.claude/workstream-kit.source"
rc=$(run_dry)
check "S3 exit non-zero"           "[ \"$rc\" != 0 ]"
check "S3 prints stamp-behind"     "grep -qi 'stamp-behind' \"$WORK/out\""

echo "== S4: version behind, .source present and current (isolates the version limb)"
"$KIT_DIR/install.sh" "$PROJ" >/dev/null 2>&1   # restore current stamps
printf '0.4.0\n' > "$PROJ/.claude/workstream-kit.version"
rc=$(run_dry)
check "S4 exit non-zero"           "[ \"$rc\" != 0 ]"
check "S4 prints stamp-behind"     "grep -qi 'stamp-behind' \"$WORK/out\""

echo
if [ "$RESULT" -eq 0 ]; then
  echo "STAMP-DRIFT ACCEPTANCE: ALL CHECKS PASS"
else
  echo "STAMP-DRIFT ACCEPTANCE: FAILURES ABOVE"
fi
exit "$RESULT"
