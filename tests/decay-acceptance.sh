#!/bin/sh
# Offline acceptance test for `workstream-record.py decay`: the
# critical-path decay compare, on commit TIMESTAMPS. Builds a git
# fixture with GIT_COMMITTER_DATE controlled: a task minted the same
# day but hours after the paragraph is reported; a task minted before
# it is not; a workstream with no paragraph reports not found; a task
# re-worded after minting keeps its mint timestamp; an uncommitted
# workstream.md is unmeasurable rather than current; a gate is not a
# task. Plus the non-conforming fixture (wrapped open line, indented
# sub-task, suffixed heading) and the paragraph lifted from the corpus.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-decay-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

DAY=1767225600   # 2026-01-01T00:00:00Z
commit_at() { # <epoch> <message>
  git add -A
  GIT_COMMITTER_DATE="@$1 +0000" GIT_AUTHOR_DATE="@$1 +0000" git commit -q -m "$2"
}

cd "$T"
git init -q -b main
git config user.email fixture@example.invalid
git config user.name Fixture
git config commit.gpgsign false
mkdir -p .state/workstreams/maintain/kit .state/workstreams/feature/plain
W=.state/workstreams/maintain/kit/workstream.md

# Commit 1 (00:00): the paragraph, one task minted before it (#OG-1),
# and the gate. The paragraph is lifted 2026-09-05 from
# maintain/claude-workstream-kit in the project that built this
# sub-command.
cat > "$W" <<'FIX'
---
name: kit
type: maintain
status: active
---
## Backlog
**Critical path.** Order only, by design (D80): status and
measurements live on the #G-OG gate line, which every gate updates.
OG evaluations queue -> #G-OG (each item decided or deferred) ->
build of the approved items -> release -> AD re-install of the
consumers -> the next queue.

### Observed Kit Gaps (OG) -- the heading carries a suffix, as real files do
- [ ] #OG-1: the first evaluation, minted with the paragraph
- [ ] #G-OG: USER CHECKPOINT -- approve any kit change
FIX
cat > .state/workstreams/feature/plain/workstream.md <<'FIX'
---
name: plain
type: feature
status: active
---
## Backlog
- [ ] #PL-1: a task in a workstream with no critical path
FIX
commit_at "$DAY" "paragraph and OG-1"

# Commit 2 (03:00, same day): the paragraph's last line is edited, so its
# newest timestamp moves to 03:00.
sed -i.bak 's/consumers -> the next queue\./consumers -> the next queue, then triage./' "$W" && rm -f "$W.bak"
commit_at "$((DAY + 3 * 3600))" "edit the paragraph"

# Commit 3 (05:00, same day): #OG-2 minted, wrapped against the
# convention, with an indented sub-task #OG-2a.
cat >> "$W" <<'FIX'
- [ ] #OG-2: the second evaluation, minted two hours after the
paragraph's last edit, wrapped against the convention
  - [ ] #OG-2a: an indented sub-task minted with it
FIX
commit_at "$((DAY + 5 * 3600))" "mint OG-2"

# Commit 4 (next day): #OG-1 re-worded; its mint stays at commit 1.
sed -i.bak 's/the first evaluation, minted with the paragraph/the first evaluation, re-worded a day later/' "$W" && rm -f "$W.bak"
commit_at "$((DAY + 86400))" "reword OG-1"

python3 "$SCRIPT" decay "$T" > "$T/out.json"
q() { jq -r ".workstreams[] | select(.path | endswith(\"kit/workstream.md\")) | $1" "$T/out.json"; }

echo "== Sanity"
check "four commits, the paragraph's last line changed at +3h" \
  "[ \"\$(git rev-list --count HEAD)\" = 4 ] && [ \"\$(git log -1 --format=%ct -- $W)\" = $((DAY + 86400)) ]"
check "#OG-2 sits on a wrapped line and #OG-2a is indented" "grep -q '^paragraph.s last edit' $W && grep -q '^  - \\[ \\] #OG-2a' $W"

echo "== The compare"
check "the paragraph's newest commit time is +3h (the edit), not +0" '[ "$(q ".critical_path.newest_commit_time")" = "'$((DAY + 3 * 3600))'" ]'
check "the paragraph spans 5 lines from its first" '[ "$(q ".critical_path.lines")" = "5" ]'
check "#OG-2 (minted +5h, two hours after the edit) is reported with after_by_seconds 7200" \
  '[ "$(q ".minted_after[] | select(.id == \"#OG-2\") | .after_by_seconds")" = "7200" ]'
check "#OG-2a (the indented sub-task) is reported too" '[ "$(q ".minted_after[] | select(.id == \"#OG-2a\") | .id")" = "#OG-2a" ]'
check "#OG-1 (minted before the edit, re-worded after it) is NOT reported: rewording keeps the mint" \
  '[ "$(q "[.minted_after[] | select(.id == \"#OG-1\")] | length")" = "0" ]'
check "the gate #G-OG is not a task and is not reported" '[ "$(q "[.minted_after[] | select(.id == \"#G-OG\")] | length")" = "0" ]'
check "open_tasks counts the three tasks, not the gate" '[ "$(q ".open_tasks")" = "3" ]'
check "the workstream with no paragraph reports not found" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"plain/workstream.md\")) | .critical_path" "$T/out.json")" = "not found" ]'

echo "== Vary one input: an uncommitted edit makes the file unmeasurable, not current"
printf -- '- [ ] #OG-3: an uncommitted task\n' >> "$W"
python3 "$SCRIPT" decay "$T" > "$T/out2.json"
check "unmeasurable names the file and minted_after is empty" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"kit/workstream.md\")) | .unmeasurable" "$T/out2.json")" = "uncommitted changes in $W" ] && [ "$(jq -r ".workstreams[] | select(.path | endswith(\"kit/workstream.md\")) | .minted_after | length" "$T/out2.json")" = "0" ]'
git checkout -q -- "$W"
check "after reverting, the measure is back (#OG-2 reported again)" \
  '[ "$(python3 "$SCRIPT" decay "$T" | jq -r ".workstreams[] | select(.path | endswith(\"kit/workstream.md\")) | .minted_after | length")" = "2" ]'

echo "== Exit codes"
rc=0; python3 "$SCRIPT" decay >/dev/null 2>&1 || rc=$?
check "decay with no root: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" decay "$T/nowhere" >/dev/null 2>&1 || rc=$?
check "decay on a root with no .state: exit 2" '[ "$rc" -eq 2 ]'
check "the measure wrote nothing (git status clean)" '[ -z "$(git status --porcelain -- .state)" ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "DECAY ACCEPTANCE: ALL CHECKS PASS"; else echo "DECAY ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
