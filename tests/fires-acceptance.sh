#!/bin/sh
# Offline acceptance test for `workstream-record.py fires`: the extract
# skill's firing symptoms as one verdict per workstream. Each symptom
# alone fires and names itself; a workstream with none reports quiet; a
# paused workstream is still measured; the size threshold agrees with
# the session-start hook's (a constant that must agree in two files is
# a fixture, since the hook is sh with no python dependency). The
# non-conforming fixture (a Learning wrapped through its marker, a bare
# marker mention, a wrapped open line) is what the undispositioned
# count reads through.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-fires-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

mk() { # <type/name> <status> <extra backlog> <learnings> <criteria>
  mkdir -p "$T/.state/workstreams/$1"
  {
    printf -- '---\nname: %s\ntype: %s\nstatus: %s\n---\n## Purpose\nA fixture.\n\n## Backlog\n### Live (LV)\n- [ ] #LV-1: an open task\n' "${1#*/}" "${1%/*}" "$2"
    printf '%b' "$3"
    printf -- '\n## Learnings\n'
    printf '%b' "$4"
    printf -- '\n## Deletion Criteria\n'
    printf '%b' "$5"
  } > "$T/.state/workstreams/$1/workstream.md"
}
TODAY=$(date +%Y-%m-%d)
OLD=$(date -v-45d +%Y-%m-%d 2>/dev/null || date -d '45 days ago' +%Y-%m-%d)

mk feature/quiet active '' "- L1 (2026-01-01): An insight. APPLIED 2026-01-02 to docs/x.md.\n" "- [ ] STANDING: healthy -- HOLDS $TODAY\n"
# One symptom each. The undispositioned case uses the non-conforming
# shape: a wrapped marker on L1 (scored terminal) and a mention on L2
# (undispositioned), plus a wrapped open line.
mk feature/learning active '- [ ] #LV-2: a task wrapped against\nthe convention\n' "- L1 (2026-01-01): An insight whose marker wraps: HANDED\n  OFF 2026-01-02 to feature/quiet.\n- L2 (2026-01-01): The record quotes the two-word \`HANDED OFF\` marker mid-sentence.\n" ''
mk feature/phase active '### Done (DN)\n- [x] #DN-1: done\n- [x] #G-DN: USER CHECKPOINT -- decided\n' '' ''
mk feature/notes active '' '' ''
printf '## Notes\nundispositioned\n' > "$T/.state/workstreams/feature/notes/notes.md"
mk feature/stray active '' '' ''
printf 'x\n' > "$T/.state/workstreams/feature/stray/draft.md"
mk feature/never active '' '' "- [ ] STANDING: never re-checked\n"
mk feature/stale paused '' '' "- [ ] STANDING: re-checked long ago -- HOLDS $OLD\n"
mk feature/big active '' '' ''
mk feature/outside active '' '' ''
printf -- '\n## Decisions\n- [ ] #LV-9: appended after the Backlog ended\n' >> "$T/.state/workstreams/feature/outside/workstream.md"
head -c 70000 /dev/zero | tr '\0' 'x' >> "$T/.state/workstreams/feature/big/workstream.md"

python3 "$SCRIPT" fires "$T" > "$T/out.txt"
python3 "$SCRIPT" fires "$T" --json > "$T/out.json"
line() { grep "^feature/$1:" "$T/out.txt"; }
sym() { jq -r ".workstreams[] | select(.workstream == \"feature/$1\") | [.symptoms[].symptom] | join(\"|\")" "$T/out.json"; }

echo "== Sanity"
check "nine workstreams, one line each" '[ "$(wc -l < "$T/out.txt" | tr -d " ")" = "9" ]'
check "the big fixture is past 65536 bytes" '[ "$(wc -c < "$T/.state/workstreams/feature/big/workstream.md" | tr -d " ")" -gt 65536 ]'
check "the threshold agrees with the session-start hook (both files carry 65536, and nothing else in the payload does)" \
  '[ "$(grep -rn "65536" "$KIT_DIR/.claude/hooks/session-start.sh" "$KIT_DIR/.claude/scripts" | wc -l | tr -d " ")" = "2" ] && [ "$(jq -r ".threshold_bytes" "$T/out.json")" = "65536" ]'

echo "== Each symptom alone fires and names itself"
check "quiet reports quiet" '[ "$(line quiet)" = "feature/quiet: quiet" ]'
check "learning: undispositioned Learnings 1 (the wrapped marker scored, the mention not)" \
  '[ "$(sym learning)" = "undispositioned Learnings" ] && line learning | grep -q "undispositioned Learnings 1"'
check "phase: completed phase Done (DN)" '[ "$(sym phase)" = "completed phase" ] && line phase | grep -q "completed phase Done (DN)"'
check "notes: notes.md beside the file" '[ "$(sym notes)" = "notes.md beside the file" ]'
check "stray: unknown file in the directory, named" '[ "$(sym stray)" = "unknown file in the directory" ] && line stray | grep -q "draft.md"'
check "never: STANDING criteria never re-checked" '[ "$(sym never)" = "STANDING criteria never re-checked" ]'
check "stale (PAUSED, still measured): STANDING re-check older than the interval, with the date" \
  '[ "$(sym stale)" = "STANDING re-check older than the interval" ] && line stale | grep -q "oldest HOLDS $OLD"'
check "outside: open task outside Backlog, with its line and ID" '[ "$(sym outside)" = "open task outside Backlog" ] && line outside | grep -q "line $(grep -n "#LV-9" "$T/.state/workstreams/feature/outside/workstream.md" | cut -d: -f1) (#LV-9)"'
check "big: size, in KB past 64KB" '[ "$(sym big)" = "size" ] && line big | grep -q "past 64KB"'

echo "== The interval and the filter"
check "--interval-days 60 quiets the stale one" \
  '[ "$(python3 "$SCRIPT" fires "$T" --interval-days 60 | grep "^feature/stale:")" = "feature/stale: quiet" ]'
check "naming a workstream measures it alone" \
  '[ "$(python3 "$SCRIPT" fires "$T" feature/phase | wc -l | tr -d " ")" = "1" ]'
rc=0; python3 "$SCRIPT" fires "$T" feature/nowhere >/dev/null 2>&1 || rc=$?
check "naming an absent workstream: exit 2" '[ "$rc" -eq 2 ]'
# Vary one input: disposition L2 in the learning fixture and it goes quiet.
sed -i.bak 's/marker mid-sentence\./marker mid-sentence. DROPPED 2026-01-03 as a duplicate./' "$T/.state/workstreams/feature/learning/workstream.md"
rm -f "$T/.state/workstreams/feature/learning/workstream.md.bak"
check "dating a disposition on L2 turns learning quiet (the wrapped open line is not a symptom)" \
  '[ "$(python3 "$SCRIPT" fires "$T" feature/learning)" = "feature/learning: quiet" ]'

echo "== Exit codes"
rc=0; python3 "$SCRIPT" fires >/dev/null 2>&1 || rc=$?
check "fires with no root: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" fires "$T" --interval-days x >/dev/null 2>&1 || rc=$?
check "--interval-days with no number: exit 2" '[ "$rc" -eq 2 ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "FIRES ACCEPTANCE: ALL CHECKS PASS"; else echo "FIRES ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
