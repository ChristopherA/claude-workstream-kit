#!/bin/sh
# Offline acceptance test for the gloss check: `workstream-record.py
# bare-ids` over a project and over stdin, the Stop hook
# bare-id-guard.py over a transcript, the session-start hook's Gloss
# section, and install.sh's Stop registration (idempotent). Cases:
# the canonical parenthetical and quoted forms pass; a home between
# the id and its gloss passes; a bare id, a possessive, and an id
# glossing an id fail; a second mention in the same paragraph
# inherits; the defining line, a code span, a fenced block and a
# struck span are exempt; completed notes and Decisions are not read;
# a gate id (#G-XX with letters only) is checked; the hook blocks once
# and lets the stop through when stop_hook_active is set or the turn
# is glossed; the hook ignores tool-result records when finding the
# turn's text.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
GUARD="$KIT_DIR/.claude/hooks/bare-id-guard.py"
HOOK="$KIT_DIR/.claude/hooks/session-start.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-bare-ids-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

mkdir -p "$T/p/.state/workstreams/feature/alpha"
cat > "$T/p/.state/ACTIVE.md" <<'FIX'
---
workstream: feature/alpha
task: "#AL-1 - the first build"
---
## Now

#AL-1 (the first build) is in flight; #G-AL waits behind it. D3
settles the shape, and `#AL-9` is only quoted here.

## Next

#AL-2's test, then #AL-2 (the smoke test) again.

## Blockers

None
FIX
cat > "$T/p/.state/workstreams/feature/alpha/workstream.md" <<'FIX'
---
name: alpha
type: feature
status: active
---
## Purpose

Build the thing D3 decided. #XX-N and #G-XX are the rule's own
placeholders.

**Critical path.** #AL-1 (the first build) -> #AL-2 -> #G-AL (the
build gate) -> CL.

## Backlog

### Build (AL)
- [ ] #AL-1: the first build, which reads L1 for its lesson
- [ ] #AL-2: the smoke test, after #AL-1 in feature/alpha (the first build)
- [x] #AL-0: done, its note names #AL-7 bare and that is frozen
  DONE 2026-01-01: #AL-7 and D9 both bare here, correctly unread.
- [ ] #G-AL: USER CHECKPOINT -- ~~#AL-8 struck~~ the build works

## Decisions
### D3 (2026-01-01): The shape
Decisions are frozen: #AL-6 bare here is not read.

## Learnings
- L1 (2026-01-01): a lesson citing #AL-5 "the fifth" -- integration target: docs/x.md

## Open Questions
- OQ-1: does #AL-3 need #AL-4 (the fourth)? Resolve at #AL-3.

## Deletion Criteria
- [ ] #AL-1 (the first build) shipped and #G-AL passed
- [x] a done criterion naming #AL-9 bare
FIX

python3 "$SCRIPT" bare-ids "$T/p" > "$T/out.json"
a() { jq -r ".files[] | select(.path == \"$1\") | $2" "$T/out.json"; }
A=.state/ACTIVE.md
W=.state/workstreams/feature/alpha/workstream.md

echo "== ACTIVE.md"
check "the glossed #AL-1 is not listed" '[ "$(a $A "[.bare[] | select(.id == \"#AL-1\")] | length")" = "0" ]'
check "the bare gate #G-AL is listed (a gate has no digit and is still an id)" '[ "$(a $A "[.bare[] | select(.id == \"#G-AL\")] | length")" = "1" ]'
check "the bare D3 is listed" '[ "$(a $A "[.bare[] | select(.id == \"D3\")] | length")" = "1" ]'
check "a code-span mention (#AL-9) is exempt" '[ "$(a $A "[.bare[] | select(.id == \"#AL-9\")] | length")" = "0" ]'
check "a possessive (#AL-2\x27s test) is bare, and the glossed second mention in the same paragraph does not rescue it" \
  '[ "$(a $A "[.bare[] | select(.id == \"#AL-2\")] | length")" = "1" ] && [ "$(a $A "[.bare[] | select(.id == \"#AL-2\")][0].line")" = "12" ]'
check "ACTIVE.md count is 3" '[ "$(a $A .count)" = "3" ]'

echo "== workstream.md: live prose only"
check "Purpose: D3 bare is listed; the placeholders #XX-N and #G-XX are not" \
  '[ "$(a $W "[.bare[] | select(.id == \"D3\")] | length")" = "1" ] && [ "$(a $W "[.bare[] | select(.id == \"#XX-N\" or .id == \"#G-XX\")] | length")" = "0" ]'
check "critical path: #AL-2 bare is listed once from the paragraph (line 11), and the gate whose gloss wraps onto the next line is not" \
  '[ "$(a $W "[.bare[] | select(.id == \"#AL-2\" and .line == 11)] | length")" = "1" ] && [ "$(a $W "[.bare[] | select(.id == \"#G-AL\" and .line == 11)] | length")" = "0" ]'
check "an open task line: its own id is exempt, the L1 it cites is bare" \
  '[ "$(a $W "[.bare[] | select(.id == \"L1\")] | length")" = "1" ] && [ "$(a $W "[.bare[] | select(.id == \"#AL-1\" and .line == 17)] | length")" = "0" ]'
check "a home between id and gloss passes (#AL-1 in feature/alpha (the first build))" '[ "$(a $W "[.bare[] | select(.line == 18)] | length")" = "0" ]'
check "a completed task and its note are not read (#AL-7, D9 absent)" '[ "$(a $W "[.bare[] | select(.id == \"#AL-7\" or .id == \"D9\")] | length")" = "0" ]'
check "a struck span on the gate line is exempt (#AL-8 absent)" '[ "$(a $W "[.bare[] | select(.id == \"#AL-8\")] | length")" = "0" ]'
check "Decisions are not read (#AL-6 absent)" '[ "$(a $W "[.bare[] | select(.id == \"#AL-6\")] | length")" = "0" ]'
check "Learnings are not read (#AL-5 absent, quoted or not)" '[ "$(a $W "[.bare[] | select(.id == \"#AL-5\")] | length")" = "0" ]'
check "an unresolved OQ: #AL-3 bare once (second mention inherits), #AL-4 glossed" \
  '[ "$(a $W "[.bare[] | select(.id == \"#AL-3\")] | length")" = "1" ] && [ "$(a $W "[.bare[] | select(.id == \"#AL-4\")] | length")" = "0" ]'
check "an open criterion: #G-AL bare; a done criterion is not read (#AL-9 absent)" \
  '[ "$(a $W "[.bare[] | select(.id == \"#G-AL\" and .line == 34)] | length")" = "1" ] && [ "$(a $W "[.bare[] | select(.id == \"#AL-9\")] | length")" = "0" ]'
check "total is the sum of the files" '[ "$(jq -r .total "$T/out.json")" = "$(jq -r "[.files[].count] | add" "$T/out.json")" ]'

echo "== --text and --stdin"
python3 "$SCRIPT" bare-ids "$T/p" --text > "$T/out.txt"
check "--text prints one line per file with the distinct ids" 'grep -q "^\.state/ACTIVE\.md: 3 bare id mention(s): #G-AL, D3, #AL-2$" "$T/out.txt"'
check "--stdin reads a draft: the quoted form passes, the bare id is listed" \
  '[ "$(printf "#G-OG \"the kit gate\" stands; #OG-1 too.\n" | python3 "$SCRIPT" bare-ids --stdin | jq -r .total)" = "1" ]'
check "--stdin --text prints nothing on a glossed draft" '[ -z "$(printf "#OG-1 (the first) stands.\n" | python3 "$SCRIPT" bare-ids --stdin --text)" ]'
check "a fenced block is exempt" '[ "$(printf "text\n\`\`\`\n- [ ] #OG-1: quoted line naming #OG-2\n\`\`\`\n" | python3 "$SCRIPT" bare-ids --stdin | jq -r .total)" = "0" ]'
check "an id glossing an id does not count" '[ "$(printf "see (#OG-2) here\n" | python3 "$SCRIPT" bare-ids --stdin | jq -r .total)" = "1" ]'

echo "== Vary one input: glossing the gate in ACTIVE.md drops the count by one"
sed -i.bak 's/#G-AL waits behind it/#G-AL (the build gate) waits behind it/' "$T/p/$A" && rm -f "$T/p/$A.bak"
check "ACTIVE.md count is 2 after the gloss" '[ "$(python3 "$SCRIPT" bare-ids "$T/p" | jq -r ".files[] | select(.path == \"$A\") | .count")" = "2" ]'

echo "== The Stop hook"
cat > "$T/t.jsonl" <<'FIX'
{"type":"user","message":{"role":"user","content":"report please"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Earlier turn text with #OLD-1 bare, which belongs to a previous turn."}]}}
{"type":"user","message":{"role":"user","content":"and again"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"x","name":"Bash","input":{}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"x","content":"ok"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Done: #AL-1 (the first build) landed; #G-AL waits. Run `rg '#AL-9'`."}]}}
FIX
printf '{"transcript_path":"%s","stop_hook_active":false}' "$T/t.jsonl" > "$T/in-false.json"
printf '{"transcript_path":"%s","stop_hook_active":true}' "$T/t.jsonl" > "$T/in-true.json"
printf '{"transcript_path":"%s"}' "$T/t.jsonl" > "$T/in-plain.json"
printf '{"transcript_path":"%s"}' "$T/nowhere.jsonl" > "$T/in-missing.json"
OUT=$(python3 "$GUARD" < "$T/in-false.json")
check "a bare gate in the turn's final text blocks the stop" 'printf "%s" "$OUT" | jq -e ".decision == \"block\"" >/dev/null'
check "the reason names the bare id and the canonical form" 'printf "%s" "$OUT" | jq -r .reason | grep -q "#G-AL" && printf "%s" "$OUT" | jq -r .reason | grep -q "(the phase split question)"'
check "the previous turn's bare id (#OLD-1) is not reported: the walk stops at the last human message" '! printf "%s" "$OUT" | jq -r .reason | grep -q "OLD-1"'
check "the glossed #AL-1 and the code-span #AL-9 are not reported" '! printf "%s" "$OUT" | jq -r .reason | grep -qE "AL-1|AL-9"'
check "stop_hook_active true: no output, exit 0" '[ -z "$(python3 "$GUARD" < "$T/in-true.json")" ]'
sed -i.bak 's/#G-AL waits/#G-AL (the build gate) waits/' "$T/t.jsonl" && rm -f "$T/t.jsonl.bak"
check "a glossed turn: no output, exit 0" '[ -z "$(python3 "$GUARD" < "$T/in-plain.json")" ]'
cat > "$T/t2.jsonl" <<'FIX'
{"type":"user","message":{"role":"user","content":"go"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"A recap early in the turn with #ZZ-1 bare, already shown."}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"y","name":"Bash","input":{}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"y","content":"ok"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Closing message, clean: #ZZ-2 (the second) landed."}]}}
FIX
printf '{"transcript_path":"%s"}' "$T/t2.jsonl" > "$T/in-t2.json"
check "only the FINAL message is judged: a bare id in an earlier message of the same turn does not block a clean closing message" '[ -z "$(python3 "$GUARD" < "$T/in-t2.json")" ]'
cat > "$T/t3.jsonl" <<'FIX'
{"type":"user","message":{"role":"user","content":"go"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"First paragraph of the final message, #ZZ-3 bare."}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Second text record of the same final message, clean."}]}}
FIX
printf '{"transcript_path":"%s"}' "$T/t3.jsonl" > "$T/in-t3.json"
check "a final message split across two text records is judged whole (the first record's bare id blocks)" 'python3 "$GUARD" < "$T/in-t3.json" | jq -r .reason | grep -q "#ZZ-3"'
check "a missing transcript: no output, exit 0" '[ -z "$(python3 "$GUARD" < "$T/in-missing.json")" ] && printf "{}" | python3 "$GUARD" >/dev/null'

echo "== The session-start hook's Gloss section"
OUT=$(CLAUDE_PROJECT_DIR="$T/p" sh "$HOOK" 2>/dev/null)
check "the hook prints a Gloss section naming ACTIVE.md's bare ids" 'printf "%s\n" "$OUT" | grep -q "^Gloss (workstream-record.py bare-ids" && printf "%s\n" "$OUT" | grep -q "^  \.state/ACTIVE\.md: 2 bare id mention(s)"'
check "the workstream file has its own line" 'printf "%s\n" "$OUT" | grep -q "^  \.state/workstreams/feature/alpha/workstream.md: "'
check "bare ids are not a drain symptom" '! printf "%s\n" "$OUT" | grep -q "fires -- .*bare"'

echo "== install.sh registers the Stop hook, idempotently"
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$T/q"
  git -C "$T/q" init -q -b main; git -C "$T/q" config commit.gpgsign false; git -C "$T/q" config user.email f@example.invalid; git -C "$T/q" config user.name F; git -C "$T/q" commit -q --allow-empty -m init
  sh "$KIT_DIR/install.sh" "$T/q" >/dev/null 2>&1 || true
  check "a fresh install registers Stop -> bare-id-guard.py" 'jq -e ".hooks.Stop | any(.[] | .hooks[]?; .command | test(\"bare-id-guard.py\"))" "$T/q/.claude/settings.json" >/dev/null'
  check "and SessionStart is still registered" 'jq -e ".hooks.SessionStart | any(.[] | .hooks[]?; .command | test(\"session-start.sh\"))" "$T/q/.claude/settings.json" >/dev/null'
  sh "$KIT_DIR/install.sh" "$T/q" >/dev/null 2>&1 || true
  check "a second install adds no second Stop entry" '[ "$(jq -r "[.hooks.Stop[] | .hooks[] | select(.command | test(\"bare-id-guard.py\"))] | length" "$T/q/.claude/settings.json")" = "1" ]'
  check "the hook file was installed and is executable" '[ -x "$T/q/.claude/hooks/bare-id-guard.py" ]'
else
  echo "SKIP: jq absent, install registration not checked"
fi

echo "== Exit codes and no writes"
rc=0; python3 "$SCRIPT" bare-ids >/dev/null 2>&1 || rc=$?
check "bare-ids with no root: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" bare-ids "$T/nowhere" >/dev/null 2>&1 || rc=$?
check "bare-ids on a root with no .state: exit 2" '[ "$rc" -eq 2 ]'
check "self-check still passes" 'python3 "$SCRIPT" self-check >/dev/null'

echo
if [ "$RESULT" -eq 0 ]; then echo "BARE-IDS ACCEPTANCE: ALL CHECKS PASS"; else echo "BARE-IDS ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
