#!/bin/sh
# Offline acceptance test for the session-start hook's signals: the
# open-task count, the substantive-change dates, the roster with its type
# column, the paused and ghost rows, the dated gate marker read over a
# wrapped gate block, the named inbox, and the installed-versus-worktree
# kit version line. Fast and self-contained -- it builds a fixture repo and
# fires the hook against it, so a release can verify these without the
# three-session va3 run.
#
# Every check is fired red-then-green where a branch has two sides: a
# detector that has never run against a case it must match has not been
# tested. Where the fixture is clean of a case by construction (this
# project has no ghost directory), the fixture PLANTS one.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HOOK="$KIT_DIR/.claude/hooks/session-start.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-hook-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

NOW=$(date +%s)
OLD=$((NOW - 40 * 86400))
OLDER=$((NOW - 100 * 86400))

commit_at() { # <epoch> <message>
  git add -A
  GIT_COMMITTER_DATE="@$1 +0000" GIT_AUTHOR_DATE="@$1 +0000" git commit -q -m "$2"
}

mk_ws() { # <path> <type> <status> <open-tasks> <gates> <criteria>
  mkdir -p "$(dirname "$1")"
  {
    echo "---"
    echo "name: $(basename "$(dirname "$1")")"
    echo "type: $2"
    echo "status: $3"
    # Deliberately wrong: the hook must NOT read this field.
    echo "updated: 2020-01-01"
    echo "---"
    echo "## Purpose"
    echo "A fixture workstream whose purpose paragraph is prose that"
    echo "a reflow may rewrap without changing any task."
    echo
    echo "## Backlog"
    i=1; while [ "$i" -le "$4" ]; do echo "- [ ] #BD-$i: task $i"; i=$((i + 1)); done
    i=1; while [ "$i" -le "$5" ]; do echo "- [ ] #G-B$i: USER CHECKPOINT -- gate $i"; i=$((i + 1)); done
    echo "- [x] #BD-99: a done task"
    echo
    echo "## Deletion Criteria"
    i=1; while [ "$i" -le "$6" ]; do echo "- [ ] criterion $i"; i=$((i + 1)); done
  } > "$1"
}

echo "== Setup: fixture project at $T"
mkdir -p "$T/.state/handoffs" "$T/.claude"
cd "$T"
git init -q -b main
git config user.name "kit tests"; git config user.email "tests@example.invalid"
git config commit.gpgsign false

mk_ws "$T/.state/workstreams/project/alpha/workstream.md"  project  active 3 1 2
mk_ws "$T/.state/workstreams/project/beta/workstream.md"   project  active 2 0 1
mk_ws "$T/.state/workstreams/maintain/gamma/workstream.md" maintain active 1 0 0
# delta: paused, old, names no resume trigger. epsilon: paused, old, and
# its pause says what resumes it. zeta: frontmatter says done, directory
# still present -- the planted ghost.
mk_ws "$T/.state/workstreams/feature/delta/workstream.md"   feature paused 1 0 0
mk_ws "$T/.state/workstreams/feature/epsilon/workstream.md" feature paused 1 0 0
# epsilon's trigger sits in the Purpose, where the hook reads for one;
# delta carries the word in a Learning, which must NOT count as a trigger.
sed 's/^a reflow may rewrap without changing any task\.$/&\
Paused; resume when the upstream API ships./' \
  "$T/.state/workstreams/feature/epsilon/workstream.md" > "$T/e.tmp"
mv "$T/e.tmp" "$T/.state/workstreams/feature/epsilon/workstream.md"
printf '\n## Learnings\n- L1 (2026-01-01): resuming a paused build re-reads the whole record; re-open only with the record drained.\n' \
  >> "$T/.state/workstreams/feature/delta/workstream.md"
mk_ws "$T/.state/workstreams/project/zeta/workstream.md"    project done   0 0 0
# The ledger records beta as closed while beta's directory is present --
# the other half of the ghost check.
cat > "$T/.state/workstreams/ARCHIVE.md" <<'LED'
# Archive
- 2026-01-01 project/beta -- closed in the ledger, directory left behind (tag: ws/beta)
- 2026-01-01 project/beta-prime -- a name that shares a prefix and must not match beta (tag: ws/beta-prime)
LED
# beta is oversized: the SIZE signal must reach an UNPOINTED workstream.
# Pad to a MEASURED size, never a guessed line count: 900 lines landed 846
# bytes short of the 65536 threshold and the SIZE check silently did not fire.
while [ "$(wc -c < "$T/.state/workstreams/project/beta/workstream.md" | tr -d ' ')" -lt 70000 ]; do
  echo "padding -- a completion note is one line however long it runs." >> "$T/.state/workstreams/project/beta/workstream.md"
done

cat > "$T/.state/ACTIVE.md" <<'ACT'
---
workstream: project/alpha
task: "#BD-1 - first task"
updated: 2020-01-01
---
## Now
Fixture.
ACT

# alpha's second gate carries a capitalised MENTION of the marker with no
# date, inside the Backlog (an append would land under Deletion Criteria).
sed 's/^- \[ \] #G-B1: USER CHECKPOINT -- gate 1$/&\
- [ ] #G-BM: USER CHECKPOINT -- build note: the wrap sentence and the SATISFIED sentence quoted/' \
  "$T/.state/workstreams/project/alpha/workstream.md" > "$T/a.tmp"
mv "$T/a.tmp" "$T/.state/workstreams/project/alpha/workstream.md"
commit_at "$NOW" 'fixture'

# gamma, delta and epsilon are committed back in time, so age fires for
# them and nothing else. gamma also carries a gate decided in the record
# and never presented, its dated marker on the THIRD line of a wrapped
# gate block (the GATE-READY green side, wrapped); beta carries a gate
# whose lower-case "satisfied" is ordinary prose (a red side; alpha's
# mention above is the other).
echo "- [ ] #BD-2: another" >> "$T/.state/workstreams/maintain/gamma/workstream.md"
cat >> "$T/.state/workstreams/maintain/gamma/workstream.md" <<'G'
- [ ] #G-BX: USER CHECKPOINT -- the release gate, whose line wraps over
several lines because the agenda accreted; the exit criterion is
SATISFIED 2026-01-01 and it has not yet been presented
G
echo "- [ ] #G-BB: USER CHECKPOINT -- once the user is satisfied with the draft" >> "$T/.state/workstreams/project/beta/workstream.md"
commit_at "$OLD" 'age gamma'
echo "- [ ] #BD-2: another" >> "$T/.state/workstreams/feature/delta/workstream.md"
echo "- [ ] #BD-2: another" >> "$T/.state/workstreams/feature/epsilon/workstream.md"
commit_at "$OLDER" 'age delta and epsilon'
# A whitespace-only reflow of gamma's prose, committed NOW: no checkbox
# or Decision changed, so gamma's age must NOT reset.
sed 's/^a reflow may rewrap without changing any task\.$/a reflow may rewrap\nwithout changing any task./' \
  "$T/.state/workstreams/maintain/gamma/workstream.md" > "$T/g.tmp"
mv "$T/g.tmp" "$T/.state/workstreams/maintain/gamma/workstream.md"
commit_at "$NOW" 'reflow gamma prose'

OUT=$(CLAUDE_PROJECT_DIR="$T" sh "$HOOK")
printf '%s\n' "$OUT" > "$T/out.txt"

echo "== The open count anchors on the task-ID form"
# 3 tasks + 2 gates = 5 backlog lines; the 2 criteria are excluded, not folded in.
check "open tasks excludes Deletion Criteria (5, not 7)" \
  "grep -q 'open tasks: 5,' \"\$T/out.txt\""
check "criteria reported separately (2)" \
  "grep -q 'unmet criteria: 2' \"\$T/out.txt\""
check "bare-anchor count (7) does not appear" \
  "! grep -q 'open tasks: 7' \"\$T/out.txt\""
check "gates counted" "grep -q 'open gates: 2' \"\$T/out.txt\""

echo "== Dates derive from git, from the last checkbox or Decision change"
check "no false STALENESS from a 2020 updated: field" \
  "! grep -q '^STALENESS: no checkbox or Decision changed' \"\$T/out.txt\""
check "no false ACTIVE.md lag from a 2020 updated: field" \
  "! grep -q 'ACTIVE.md last changed' \"\$T/out.txt\""
check "fixture: gamma's LAST commit is the reflow at NOW (sanity)" \
  "[ \"\$(git log -1 --format=%s -- .state/workstreams/maintain/gamma/workstream.md)\" = 'reflow gamma prose' ]"
check "genuinely old workstream IS flagged STALE despite the reflow commit (green side)" \
  "grep -q 'maintain/gamma.*STALE' \"\$T/out.txt\""
check "recently-committed workstream is NOT flagged STALE (red side)" \
  "! grep -q 'project/alpha.*STALE' \"\$T/out.txt\""
# Vary the input that must change the verdict: a checkbox change at NOW.
echo "- [ ] #BD-3: fresh task" >> "$T/.state/workstreams/maintain/gamma/workstream.md"
commit_at "$NOW" 'gamma checkbox'
check "a checkbox change at NOW clears STALE on gamma (the substantive test moves)" \
  "! CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q 'maintain/gamma.*STALE'"

echo "== Paused rows: no STALE; NO-RESUME only where the pause names no trigger"
check "paused delta (100d, no resume trigger) is NOT flagged STALE" \
  "! grep -q 'feature/delta.*STALE' \"\$T/out.txt\""
check "fixture: delta says 'resuming' and 're-open' outside its Purpose (planted suppressor)" \
  "grep -q 'resuming a paused build' \"\$T/.state/workstreams/feature/delta/workstream.md\" && ! awk '/^## / && \$0 !~ /^## Purpose/ {exit} {print}' \"\$T/.state/workstreams/feature/delta/workstream.md\" | grep -qiE 'resum|re-?open'"
check "paused delta is flagged NO-RESUME despite the word in a Learning (green side)" \
  "grep -q 'feature/delta.*NO-RESUME' \"\$T/out.txt\""
check "fixture: epsilon names its resume trigger inside the Purpose (sanity)" \
  "awk '/^## / && \$0 !~ /^## Purpose/ {exit} {print}' \"\$T/.state/workstreams/feature/epsilon/workstream.md\" | grep -qi 'resume when'"
check "paused epsilon (100d, resume trigger named) carries no flag (red side)" \
  "grep -q 'feature/epsilon' \"\$T/out.txt\" && ! grep -q 'feature/epsilon.*\(STALE\|NO-RESUME\)' \"\$T/out.txt\""

echo "== Ghosts: a done frontmatter or a ledger line with the directory still present"
check "fixture: zeta's directory exists with status done (planted positive)" \
  "[ -f \"\$T/.state/workstreams/project/zeta/workstream.md\" ] && grep -q '^status: done' \"\$T/.state/workstreams/project/zeta/workstream.md\""
check "zeta (status done, directory present) is flagged GHOST" \
  "grep -q 'project/zeta.*GHOST' \"\$T/out.txt\""
check "beta (in the ledger, directory present) is flagged GHOST" \
  "grep -q 'project/beta.*GHOST' \"\$T/out.txt\""
check "alpha (active, not in the ledger) is NOT flagged GHOST (red side)" \
  "! grep -q 'project/alpha.*GHOST' \"\$T/out.txt\""
check "legend explains GHOST" "grep -q 'GHOST = ' \"\$T/out.txt\""

echo "== The roster reports every workstream, with its type"
check "roster header names all six" "grep -q 'Workstreams (6)' \"\$T/out.txt\""
check "unpointed workstream listed" "grep -q 'project/beta' \"\$T/out.txt\""
check "active pointer marked" "grep -q '^-> project/alpha' \"\$T/out.txt\""
check "oversized UNPOINTED workstream flagged SIZE" \
  "grep -q 'project/beta.*SIZE' \"\$T/out.txt\""
check "type and status surfaced per workstream" "grep -q 'maintain/gamma *maintain *active' \"\$T/out.txt\""
check "a paused row shows its type and status" "grep -q 'feature/delta *feature *paused' \"\$T/out.txt\""

echo "== GATE-READY reads the whole gate block for the DATED marker"
check "fixture: gamma's marker is on a continuation line, not the gate's first line" \
  "grep -q '^SATISFIED 2026-01-01' \"\$T/.state/workstreams/maintain/gamma/workstream.md\" && ! grep -q '#G-BX.*SATISFIED' \"\$T/.state/workstreams/maintain/gamma/workstream.md\""
check "GATE-READY on the row whose wrapped gate is recorded satisfied (green side)" \
  "grep -q 'maintain/gamma.*GATE-READY' \"\$T/out.txt\""
check "fixture: beta's gate line says satisfied in lower case only" \
  "grep -q '#G-BB.*satisfied' \"\$T/.state/workstreams/project/beta/workstream.md\" && ! grep -q '#G-BB.*SATISFIED' \"\$T/.state/workstreams/project/beta/workstream.md\""
check "no GATE-READY on the lower-case row (red side)" \
  "! grep -q 'project/beta.*GATE-READY' \"\$T/out.txt\""
check "fixture: alpha's gate carries the capitalised word with no date after it (planted mention)" \
  "grep -q 'the SATISFIED sentence quoted' \"\$T/.state/workstreams/project/alpha/workstream.md\""
check "no GATE-READY on the MENTION row (red side, the case that reached a release)" \
  "! grep -q 'project/alpha.*GATE-READY' \"\$T/out.txt\""
check "legend explains GATE-READY" "grep -q 'GATE-READY = ' \"\$T/out.txt\""

echo "== The inbox is named by its path"
touch "$T/.state/handoffs/from-elsewhere-20260101-000000.md"
check "handoff line names .state/handoffs/" \
  "CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q 'Handoffs pending in .state/handoffs/: 1'"
rm -f "$T/.state/handoffs/from-elsewhere-20260101-000000.md"

echo "== Installed kit version against the worktree's VERSION"
mkdir -p "$T/kit"
echo "0.10.1" > "$T/.claude/workstream-kit.version"
echo "0.10.2" > "$T/kit/VERSION"
check "behind: the line names both versions and the upgrade command" \
  "WORKSTREAM_KIT_DIR=\"\$T/kit\" CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q 'Kit: 0.10.1 installed, worktree has 0.10.2 -- /workstream-upgrade'"
echo "0.10.1" > "$T/kit/VERSION"
check "equal: the line says it matches" \
  "WORKSTREAM_KIT_DIR=\"\$T/kit\" CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q 'Kit: 0.10.1 installed, matches the worktree'"
# Same VERSION, but the worktree carries commits past the installed source:
# the kit's own steward sees this at every session start of a build, and
# "matches" there is false. The source stamp names the installed commit.
git -C "$T/kit" init -q
git -C "$T/kit" config commit.gpgsign false
git -C "$T/kit" config user.name fixture
git -C "$T/kit" config user.email fixture@example.invalid
git -C "$T/kit" add VERSION && git -C "$T/kit" commit -q -m 'release'
KIT_SRC=$(git -C "$T/kit" rev-parse --short HEAD)
echo later > "$T/kit/later" && git -C "$T/kit" add later && git -C "$T/kit" commit -q -m 'unreleased'
printf 'version: 0.10.1\nsource: %s\nref: v0.10.1\n' "$KIT_SRC" > "$T/.claude/workstream-kit.source"
check "ahead at the same VERSION: names the source and the commit count, says unreleased" \
  "WORKSTREAM_KIT_DIR=\"\$T/kit\" CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q 'Kit: 0.10.1 installed from $KIT_SRC; the worktree is 1 commit(s) past it at the same VERSION -- an unreleased build'"
check "ahead at the same VERSION: does NOT say matches (red side)" \
  "! WORKSTREAM_KIT_DIR=\"\$T/kit\" CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q 'matches the worktree'"
printf 'version: 0.10.1\nsource: %s\nref: v0.10.1\n' "$(git -C "$T/kit" rev-parse --short HEAD)" > "$T/.claude/workstream-kit.source"
check "source at the worktree HEAD: matches again" \
  "WORKSTREAM_KIT_DIR=\"\$T/kit\" CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q 'Kit: 0.10.1 installed, matches the worktree'"
rm -f "$T/.claude/workstream-kit.source"
check "no worktree located: silent, no Kit line (degrades rather than guesses)" \
  "! WORKSTREAM_KIT_DIR=\"\$T/nokit\" HOME=\"\$T/nohome\" CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q '^Kit:'"
rm -f "$T/.claude/workstream-kit.version"
check "no installed stamp: no Kit line" \
  "! WORKSTREAM_KIT_DIR=\"\$T/kit\" CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -q '^Kit:'"

echo "== The roster survives an unpointed project"
sed 's|^workstream: project/alpha|workstream: none|' "$T/.state/ACTIVE.md" > "$T/a.tmp"
mv "$T/a.tmp" "$T/.state/ACTIVE.md"
OUT2=$(CLAUDE_PROJECT_DIR="$T" sh "$HOOK")
printf '%s\n' "$OUT2" > "$T/out2.txt"
check "roster still prints with pointer none" "grep -q 'Workstreams (6)' \"\$T/out2.txt\""
check "SIZE still reaches an unpointed workstream" "grep -q 'project/beta.*SIZE' \"\$T/out2.txt\""
check "no active-detail line when unpointed" "! grep -q 'Active workstream:' \"\$T/out2.txt\""
check "hook exits 0 when unpointed" "CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" >/dev/null"

echo "== Degenerate inputs"
rm -rf "$T/.state/workstreams"
check "no workstreams: exits 0, prints no roster" \
  "CLAUDE_PROJECT_DIR=\"\$T\" sh \"\$HOOK\" | grep -qv 'Workstreams ('"
check "missing .state: exits 0 silently" \
  "[ -z \"\$(CLAUDE_PROJECT_DIR=\"\$T/nope\" sh \"\$HOOK\")\" ]"

echo
if [ "$RESULT" -eq 0 ]; then
  echo "SESSION-START ACCEPTANCE: ALL CHECKS PASS"
else
  echo "SESSION-START ACCEPTANCE: FAILURES ABOVE"
fi
exit "$RESULT"
