#!/bin/sh
# Acceptance test for the status line (registered by default, set-if-absent).
# Mechanical -- no Claude Code session required. Run from anywhere:
# tests/statusline-acceptance.sh
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJ="${TMPDIR:-/tmp}/kit-statusline-proj.$$"
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required for this test"; exit 0; }

echo "== Setup: fresh project at $PROJ"
rm -rf "$PROJ"
mkdir -p "$PROJ" && cd "$PROJ"
git init -q -b main

echo "== Default install: script present, statusLine registered, hooks intact"
"$KIT_DIR/install.sh" "$PROJ" >/dev/null
check "script copied" "[ -x .claude/scripts/status-line.sh ]"
check "statusLine registered by default" "jq -e '.statusLine.command | test(\"status-line.sh\")' .claude/settings.json >/dev/null"
check "statusLine type is command" "[ \"\$(jq -r .statusLine.type .claude/settings.json)\" = command ]"
check "hooks present after install" "jq -e .hooks.SessionStart .claude/settings.json >/dev/null"

# Mock statusLine stdin payload; project_dir is what the registered command resolves against.
printf 'workstream: feature/demo\n' > .state/ACTIVE.md
INPUT=$(printf '{"model":{"display_name":"Opus"},"workspace":{"project_dir":"%s"},"context_window":{"used_percentage":30},"cost":{"total_cost_usd":0}}' "$PROJ")

echo "== Registered command resolves the project script and renders (end-to-end)"
CMD=$(jq -r .statusLine.command .claude/settings.json)
OUT=$(printf '%s' "$INPUT" | sh -c "$CMD")
if printf '%s' "$OUT" | grep -q 'feature/demo'; then echo "PASS: registered command resolves script + renders workstream"; else echo "FAIL: registered command resolves script + renders workstream"; RESULT=1; fi
if printf '%s' "$OUT" | grep -q "$(basename "$PROJ")"; then echo "PASS: registered command renders project basename"; else echo "FAIL: registered command renders project basename"; RESULT=1; fi
if printf '%s' "$OUT" | grep -q '50%'; then echo "PASS: registered command renders remaining-to-compact %"; else echo "FAIL: registered command renders remaining-to-compact %"; RESULT=1; fi

echo "== Script renders correctly when invoked directly too"
OUT2=$(printf '%s' "$INPUT" | sh .claude/scripts/status-line.sh)
if printf '%s' "$OUT2" | grep -q 'feature/demo'; then echo "PASS: direct invocation renders workstream"; else echo "FAIL: direct invocation renders workstream"; RESULT=1; fi

echo "== --context reads the newest record for THIS project and stays silent otherwise"
CTX="$PROJ/ctx"; mkdir -p "$CTX" "$PROJ/other"
check "no record: no output, exit 0" "[ -z \"\$(WORKSTREAM_KIT_CONTEXT_DIR=\"\$CTX\" sh .claude/scripts/status-line.sh --context \"\$PROJ\")\" ]"
# The writer, pointed at the same directory, produces the record the reader selects.
INPUT2=$(printf '{"model":{"display_name":"Opus"},"workspace":{"project_dir":"%s"},"context_window":{"used_percentage":45,"remaining_percentage":55,"context_window_size":200000},"cost":{"total_cost_usd":0},"session_id":"sess-a"}' "$PROJ")
printf '%s' "$INPUT2" | WORKSTREAM_KIT_CONTEXT_DIR="$CTX" sh .claude/scripts/status-line.sh >/dev/null
check "the writer wrote its record into the overridden directory" "[ -f \"\$CTX/claude-sess-a-context.json\" ]"
# A newer record for ANOTHER project, and an older one for this project: the newest for THIS project wins.
jq -n --arg p "$PROJ/other" '{session_id:"sess-b",project_dir:$p,remaining_pct:10,usable_consumed_pct:99,updated:"2099-01-01T00:00:00Z"}' > "$CTX/claude-sess-b-context.json"
jq -n --arg p "$PROJ" '{session_id:"sess-c",project_dir:$p,remaining_pct:90,usable_consumed_pct:5,updated:"2000-01-01T00:00:00Z"}' > "$CTX/claude-sess-c-context.json"
OUT3=$(WORKSTREAM_KIT_CONTEXT_DIR="$CTX" sh .claude/scripts/status-line.sh --context "$PROJ")
check "--context prints the two numbers from this project's newest record (sess-a), not the other project's newer one" \
  "[ \"\$OUT3\" = 'context: 0% of usable consumed, 55% of window remaining' ]"
check "--context for the other project selects its own record" \
  "[ \"\$(WORKSTREAM_KIT_CONTEXT_DIR=\"\$CTX\" sh .claude/scripts/status-line.sh --context \"\$PROJ/other\")\" = 'context: 99% of usable consumed, 10% of window remaining' ]"
check "--context for a project with no record prints nothing" "[ -z \"\$(WORKSTREAM_KIT_CONTEXT_DIR=\"\$CTX\" sh .claude/scripts/status-line.sh --context \"\$PROJ/nowhere\")\" ]"
rc=0; sh .claude/scripts/status-line.sh --context >/dev/null 2>&1 || rc=$?
check "--context without a directory: exit 2" '[ "$rc" -eq 2 ]'
check "the default directory is /tmp (the writer's), read with a trailing slash" "grep -q 'CONTEXT_DIR%/}/' .claude/scripts/status-line.sh && grep -q 'CONTEXT_DIR:-/tmp' .claude/scripts/status-line.sh"

echo "== Idempotent: re-run does not change settings.json"
jq -S . .claude/settings.json > before.json
"$KIT_DIR/install.sh" "$PROJ" >/dev/null
jq -S . .claude/settings.json > after.json
check "statusLine merge is idempotent" "diff -q before.json after.json >/dev/null"

echo "== Never clobber a pre-existing statusLine (set-if-absent)"
jq '.statusLine={type:"command",command:"custom-sl"}' .claude/settings.json > ss.tmp && mv ss.tmp .claude/settings.json
"$KIT_DIR/install.sh" "$PROJ" >/dev/null
check "existing statusLine preserved" "[ \"\$(jq -r .statusLine.command .claude/settings.json)\" = custom-sl ]"

cd /
rm -rf "$PROJ"
echo
if [ "$RESULT" -eq 0 ]; then
  echo "STATUSLINE ACCEPTANCE: ALL CHECKS PASS"
else
  echo "STATUSLINE ACCEPTANCE: FAILURES ABOVE"
fi
exit "$RESULT"
