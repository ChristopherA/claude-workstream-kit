#!/bin/sh
# Offline acceptance test for the session-start hook's three signals: the
# open-task count, the derived dates, and the roster. Fast and self-contained
# -- it builds a fixture repo and fires the hook against it, so a release can
# verify these without the three-session va3 run.
#
# Every check is fired red-then-green where a branch has two sides: a detector
# that has never run against a case it must match has not been tested.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HOOK="$KIT_DIR/.claude/hooks/session-start.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-hook-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

NOW=$(date +%s)
OLD=$((NOW - 40 * 86400))

mk_ws() { # <path> <status> <open-tasks> <gates> <criteria>
  mkdir -p "$(dirname "$1")"
  {
    echo "---"
    echo "name: $(basename "$(dirname "$1")")"
    echo "status: $2"
    # Deliberately wrong: the hook must NOT read this field.
    echo "updated: 2020-01-01"
    echo "---"
    echo "## Backlog"
    i=1; while [ "$i" -le "$3" ]; do echo "- [ ] #BD-$i: task $i"; i=$((i + 1)); done
    i=1; while [ "$i" -le "$4" ]; do echo "- [ ] #G-B$i: USER CHECKPOINT -- gate $i"; i=$((i + 1)); done
    echo "- [x] #BD-99: a done task"
    echo
    echo "## Deletion Criteria"
    i=1; while [ "$i" -le "$5" ]; do echo "- [ ] criterion $i"; i=$((i + 1)); done
  } > "$1"
}

echo "== Setup: fixture project at $T"
mkdir -p "$T/.state/handoffs"
cd "$T"
git init -q -b main
git config user.name "kit tests"; git config user.email "tests@example.invalid"
git config commit.gpgsign false

mk_ws "$T/.state/workstreams/project/alpha/workstream.md" active 3 1 2
mk_ws "$T/.state/workstreams/project/beta/workstream.md"  active 2 0 1
mk_ws "$T/.state/workstreams/maintain/gamma/workstream.md" paused 1 0 0
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

git add -A
GIT_COMMITTER_DATE="@$NOW +0000" GIT_AUTHOR_DATE="@$NOW +0000" git commit -q -m 'fixture'
# gamma alone is committed 40 days back, so STALE fires for it and nothing else.
echo "- [ ] #BD-2: another" >> "$T/.state/workstreams/maintain/gamma/workstream.md"
# gamma also carries a gate decided in the record and never presented (the
# GATE-READY green side); beta carries a gate whose lower-case "satisfied" is
# ordinary prose (the red side: the predicate is case-sensitive on the marker).
echo "- [ ] #G-BX: USER CHECKPOINT -- exit criterion SATISFIED 2026-01-01, not yet presented" >> "$T/.state/workstreams/maintain/gamma/workstream.md"
echo "- [ ] #G-BB: USER CHECKPOINT -- once the user is satisfied with the draft" >> "$T/.state/workstreams/project/beta/workstream.md"
git add -A
GIT_COMMITTER_DATE="@$OLD +0000" GIT_AUTHOR_DATE="@$OLD +0000" git commit -q -m 'age gamma'

OUT=$(CLAUDE_PROJECT_DIR="$T" sh "$HOOK")
printf '%s\n' "$OUT" > "$T/out.txt"

echo "== The open count anchors on the task-ID form"
# 3 tasks + 1 gate = 4 backlog lines; the 2 criteria are excluded, not folded in.
check "open tasks excludes Deletion Criteria (4, not 6)" \
  "grep -q 'open tasks: 4,' \"\$T/out.txt\""
check "criteria reported separately (2)" \
  "grep -q 'unmet criteria: 2' \"\$T/out.txt\""
check "bare-anchor count (6) does not appear" \
  "! grep -q 'open tasks: 6' \"\$T/out.txt\""
check "gate counted" "grep -q 'open gates: 1' \"\$T/out.txt\""

echo "== Dates derive from git, not the frontmatter field"
check "no false STALENESS from a 2020 updated: field" \
  "! grep -q 'workstream untouched' \"\$T/out.txt\""
check "no false ACTIVE.md lag from a 2020 updated: field" \
  "! grep -q 'ACTIVE.md last changed' \"\$T/out.txt\""
check "genuinely old workstream IS flagged STALE (green side)" \
  "grep -q 'maintain/gamma.*STALE' \"\$T/out.txt\""
check "recently-committed workstream is NOT flagged STALE (red side)" \
  "! grep -q 'project/alpha.*STALE' \"\$T/out.txt\""

echo "== The roster reports every workstream"
check "roster header names all three" "grep -q 'Workstreams (3)' \"\$T/out.txt\""
check "unpointed workstream listed" "grep -q 'project/beta' \"\$T/out.txt\""
check "active pointer marked" "grep -q '^-> project/alpha' \"\$T/out.txt\""
check "oversized UNPOINTED workstream flagged SIZE" \
  "grep -q 'project/beta.*SIZE' \"\$T/out.txt\""
check "status surfaced per workstream" "grep -q 'maintain/gamma *paused' \"\$T/out.txt\""

echo "== A gate decided in the record is flagged, a lower-case satisfied is not"
check "fixture: gamma's gate line carries the SATISFIED marker" \
  "grep -qE '^- \[ \] #G-BX.*SATISFIED' \"\$T/.state/workstreams/maintain/gamma/workstream.md\""
check "GATE-READY on the row whose gate is recorded satisfied (green side)" \
  "grep -q 'maintain/gamma.*GATE-READY' \"\$T/out.txt\""
check "fixture: beta's gate line says satisfied in lower case only" \
  "grep -q '#G-BB.*satisfied' \"\$T/.state/workstreams/project/beta/workstream.md\" && ! grep -q '#G-BB.*SATISFIED' \"\$T/.state/workstreams/project/beta/workstream.md\""
check "no GATE-READY on the lower-case row (red side)" \
  "! grep -q 'project/beta.*GATE-READY' \"\$T/out.txt\""
check "no GATE-READY on a plain open gate (alpha)" \
  "! grep -q 'project/alpha.*GATE-READY' \"\$T/out.txt\""
check "legend explains GATE-READY" "grep -q 'GATE-READY = ' \"\$T/out.txt\""

echo "== The roster survives an unpointed project"
sed 's|^workstream: project/alpha|workstream: none|' "$T/.state/ACTIVE.md" > "$T/a.tmp"
mv "$T/a.tmp" "$T/.state/ACTIVE.md"
OUT2=$(CLAUDE_PROJECT_DIR="$T" sh "$HOOK")
printf '%s\n' "$OUT2" > "$T/out2.txt"
check "roster still prints with pointer none" "grep -q 'Workstreams (3)' \"\$T/out2.txt\""
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
