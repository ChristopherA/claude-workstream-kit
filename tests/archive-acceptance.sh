#!/bin/sh
# Offline acceptance test for `workstream-rewrite.py archive`: the
# extract skill's Move 3 relocation of completed phases from the Backlog
# to `## Archive`. Cases: a dry run reports and changes nothing; a write
# moves one phase under a newly created `## Archive`, with the heading
# multiset (the new heading excluded) and the checkbox ID-and-state
# multiset identical and every other section unchanged; a second phase
# appends after the first under the same heading; a phase holding an
# open line, indented included, refuses; a code no Backlog heading
# declares refuses; a phase-shaped Decision heading past the Backlog is
# never read as a phase; an ID the task grammar cannot parse is reported
# and still moves; a second run with the same codes reports them as
# already archived and changes nothing; --headings moves one of two
# headings declaring the same code, refuses a text matching none or
# two, refuses an open line, and reports a second run as already
# archived; usage. The multisets are read
# here with grep, not with the script's own patterns, so the check does
# not share the code it checks.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-rewrite.py"
STATE_DIR="$KIT_DIR/.claude/scripts"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-archive-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

# The lines of `## <name>` up to the next `## ` heading, trailing blank
# lines dropped (a section that was last in the file is followed by a
# blank line once `## Archive` is created after it).
section() { awk -v h="## $1" '
  $0 == h { on = 1; next }
  on && /^## / { exit }
  on { if ($0 ~ /^[ \t]*$/) { buf = buf $0 "\n"; next } printf "%s", buf; buf = ""; print }' "$2"; }
# From stdin: the `### ... (<code>)` block, to the next heading of level
# 3 or above, trailing blank lines dropped.
block() { awk -v c="($1)" '
  index($0, "### ") == 1 && index($0, c) { on = 1; print; next }
  on && /^(#|##|###) / { exit }
  on { if ($0 ~ /^[ \t]*$/) { buf = buf $0 "\n"; next } printf "%s", buf; buf = ""; print }'; }
front() { awk '/^## /{ exit } { print }' "$1"; }
heads() { grep -E '^#{1,6} ' "$1" | grep -vx '## Archive' | sort; }
boxes() { grep -oE '^ *- \[[ xX]\] #[A-Za-z][A-Za-z0-9]*-[A-Za-z0-9]+' "$1" | sed 's/^ *//' | sort; }
# Both invariants are read only after a move, so each first requires
# that the file changed: on an unchanged file they would pass vacuously.
same_multisets() { # <before> <after>
  ! cmp -s "$1" "$2" || return 1
  heads "$1" > "$T/h1"; heads "$2" > "$T/h2"; boxes "$1" > "$T/b1"; boxes "$2" > "$T/b2"
  cmp -s "$T/h1" "$T/h2" && cmp -s "$T/b1" "$T/b2" && [ -s "$T/b1" ]
}
others_same() { # <before> <after>: frontmatter and every section but Backlog and Archive
  ! cmp -s "$1" "$2" || return 1
  front "$1" > "$T/s1"; front "$2" > "$T/s2"; cmp -s "$T/s1" "$T/s2" || return 1
  for s in Purpose Decisions Learnings 'Deletion Criteria'; do
    section "$s" "$1" > "$T/s1"; section "$s" "$2" > "$T/s2"
    [ -s "$T/s1" ] && cmp -s "$T/s1" "$T/s2" || return 1
  done
}

mkdir -p "$T/.state/workstreams/maintain/fx"
W="$T/.state/workstreams/maintain/fx/workstream.md"
cat > "$W" <<'FIX'
---
name: fx
type: maintain
status: active
---
## Purpose
A fixture workstream. Done means nothing; it never closes.

## Backlog

**Critical path.** The live phase (QB) is next.

### First done phase (QA)
- [x] #QA-1: the first task
  Done 2026-01-01 at abc1234; `sh tests/x.sh` passes.
- [x] #QA-2: the second task
- [x] #G-QA: USER CHECKPOINT -- approved 2026-01-02

### Live phase (QB)
- [x] #QB-1: a done task
- [x] #QB-2: a done parent
  - [ ] #QB-2a: an indented open sub-task

### Verify phase (P8)
- [x] #P8-1: a verify task
- [x] #P8-V: a verify task whose ID the task grammar cannot parse

### Last done phase (QC)
- [x] #QC-1: a done task
- [x] #QC-2: another

## Decisions
### D3 (2026-01-01): The closing call for the last phase (QC)
Reasoning that stays where it is.

## Learnings
- L1 (2026-01-01): A finding. APPLIED 2026-01-02 to docs/x.md.

## Deletion Criteria
- [ ] STANDING: the fixture holds -- HOLDS 2026-01-01
FIX
cp "$W" "$T/original.md"

echo "== Dry run"
rc=0; python3 "$SCRIPT" archive "$W" --phases QA >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "the dry run exits 0, reports the move and writes nothing" \
  '[ "$rc" -eq 0 ] && grep -q "^archive: 1 phase block(s) to ## Archive (created)" "$T/o.txt" && grep -q "^MOVE line 13-17 .*### First done phase (QA)" "$T/o.txt" && ! grep -q "WRITTEN" "$T/o.txt" && cmp -s "$W" "$T/original.md"'

echo "== Write: one phase under a new ## Archive"
check "fixture: no ## Archive yet" '! grep -q "^## Archive" "$W"'
cp "$W" "$T/before.md"
rc=0; python3 "$SCRIPT" archive "$W" --phases QA --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "--write exits 0 and prints WRITTEN" '[ "$rc" -eq 0 ] && [ "$(tail -1 "$T/o.txt")" = WRITTEN ]'
check "heading multiset (minus ## Archive) and checkbox ID-and-state multiset identical" 'same_multisets "$T/before.md" "$W"'
section Backlog "$T/before.md" | block QA > "$T/blk-before"
section Archive "$W" | block QA > "$T/blk-after"
check "the QA block sits under ## Archive, byte-identical" '[ -s "$T/blk-before" ] && cmp -s "$T/blk-before" "$T/blk-after" && [ "$(tail -1 "$W")" = "- [x] #G-QA: USER CHECKPOINT -- approved 2026-01-02" ]'
check "the Backlog no longer holds it" '! section Backlog "$W" | grep -q "(QA)\|#QA-\|#G-QA" && section Backlog "$W" | grep -q "### Live phase (QB)"'
check "every other section is byte-identical" 'others_same "$T/before.md" "$W"'

echo "== A second phase appends to the existing ## Archive"
cp "$W" "$T/before.md"
rc=0; python3 "$SCRIPT" archive "$W" --phases QC --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
qa=$(grep -n '^### First done phase (QA)$' "$W" | cut -d: -f1)
qc=$(grep -n '^### Last done phase (QC)$' "$W" | cut -d: -f1)
ar=$(grep -n '^## Archive$' "$W" | cut -d: -f1)
check "exit 0, appended after the first, one ## Archive heading" \
  '[ "$rc" -eq 0 ] && grep -q "(appended)" "$T/o.txt" && [ "$(grep -c "^## Archive" "$W")" -eq 1 ] && [ "$ar" -lt "$qa" ] && [ "$qa" -lt "$qc" ]'
check "the multisets hold and every other section is unchanged" 'same_multisets "$T/before.md" "$W" && others_same "$T/before.md" "$W"'
check "the last Backlog phase moved without taking the Decisions heading after it" \
  'section Archive "$W" | grep -q "^### Last done phase (QC)$" && section Decisions "$W" | grep -q "^### D3 (2026-01-01): The closing call for the last phase (QC)$" && ! section Archive "$W" | grep -q "D3"'

echo "== Refusal: an open line in the block, indented"
check "fixture: QB holds an indented open task line" 'grep -q "^  - \[ \] #QB-2a" "$W"'
cp "$W" "$T/before.md"
n=$(grep -n '^  - \[ \] #QB-2a' "$W" | cut -d: -f1)
rc=0; python3 "$SCRIPT" archive "$W" --phases QB --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "exit 1, naming the open line by number, file unchanged" \
  '[ "$rc" -eq 1 ] && grep -q "line $n:   - \[ \] #QB-2a" "$T/e.txt" && cmp -s "$W" "$T/before.md"'

echo "== An ID the task grammar cannot parse"
check "fixture: the P8 block holds #P8-V" 'section Backlog "$W" | block P8 | grep -q "#P8-V"'
n=$(grep -n '#P8-V' "$W" | cut -d: -f1)
cp "$W" "$T/before.md"
rc=0; python3 "$SCRIPT" archive "$W" --phases P8 --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "reported with its line, and the block still moves" \
  '[ "$rc" -eq 0 ] && grep -q "^UNPARSABLE #P8-V line $n:" "$T/o.txt" && grep -q "1 unparsable ID" "$T/o.txt" && section Archive "$W" | grep -q "#P8-V" && ! section Backlog "$W" | grep -q "#P8-"'
check "the multisets hold" 'same_multisets "$T/before.md" "$W"'

echo "== A second run with the same codes"
cp "$W" "$T/before.md"
rc=0; python3 "$SCRIPT" archive "$W" --phases P8,QA --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "exit 0, each code reported ALREADY ARCHIVED, NO CHANGE, file unchanged" \
  '[ "$rc" -eq 0 ] && grep -q "^ALREADY ARCHIVED P8 " "$T/o.txt" && grep -q "^ALREADY ARCHIVED QA " "$T/o.txt" && [ "$(tail -1 "$T/o.txt")" = "NO CHANGE" ] && cmp -s "$W" "$T/before.md"'

echo "== A code no Backlog heading declares"
W2="$T/.state/workstreams/maintain/fx/two.md"
cat > "$W2" <<'FIX'
## Backlog
### Only phase (QA)
- [x] #QA-1: done

## Decisions
### D3 (2026-01-01): The closing call (QC)
Reasoning.
FIX
cp "$W2" "$T/before.md"
check "fixture: QB is declared nowhere" '! grep -q "(QB)" "$W2"'
rc=0; python3 "$SCRIPT" archive "$W2" --phases QB --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "exit 1, naming the code, file unchanged" '[ "$rc" -eq 1 ] && grep -q "declares QB" "$T/e.txt" && cmp -s "$W2" "$T/before.md"'

echo "== A Decision heading past the Backlog is never a phase"
check "fixture: the D3 heading after the Backlog parses as a phase heading for QC" \
  'python3 -c "import sys; sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[1]); import workstream_state as s; m = s.PHASE_HEADING_RE.match(sys.argv[2]); sys.exit(0 if m and m.group(2) == \"QC\" else 1)" "$STATE_DIR" "### D3 (2026-01-01): The closing call (QC)" 2>/dev/null && ! section Backlog "$W2" | grep -q "(QC)"'
rc=0; python3 "$SCRIPT" archive "$W2" --phases QC --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "exit 1, naming QC as declared by no Backlog heading, file unchanged" \
  '[ "$rc" -eq 1 ] && grep -q "no phase heading under ## Backlog declares QC" "$T/e.txt" && cmp -s "$W2" "$T/before.md"'

echo "== Selection by heading: a code declared by two headings"
W3="$T/.state/workstreams/maintain/fx/three.md"
cat > "$W3" <<'FIX'
## Backlog
### 1. Part one (QD) -- all done
- [x] #QD-1: done
- [x] #QD-2: done

### 2. Part two (QD) -- still live
- [ ] #QD-3: open

### Twin (QE)
- [x] #QE-1: done

### Twin (QE)
- [x] #QE-2: done

## Decisions
### D1 (2026-01-01): A call
Reasoning.
FIX
cp "$W3" "$T/before.md"
check "fixture: QD is declared by two headings, one holding an open line" \
  '[ "$(grep -c "^### .*(QD)" "$W3")" -eq 2 ] && grep -q "^- \[ \] #QD-3" "$W3"'
rc=0; python3 "$SCRIPT" archive "$W3" --phases QD >/dev/null 2>"$T/e.txt" || rc=$?
check "--phases QD refuses on the open line of the second heading" '[ "$rc" -eq 1 ] && grep -q "#QD-3" "$T/e.txt" && cmp -s "$W3" "$T/before.md"'
rc=0; python3 "$SCRIPT" archive "$W3" --headings "1. Part one (QD) -- all done" --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "--headings moves only the named heading, exit 0, WRITTEN" \
  '[ "$rc" -eq 0 ] && [ "$(tail -1 "$T/o.txt")" = WRITTEN ] && grep -q "^MOVE line 2-4 .*### 1. Part one (QD) -- all done" "$T/o.txt" && section Archive "$W3" | grep -q "^- \[x\] #QD-2: done$" && section Backlog "$W3" | grep -q "^### 2. Part two (QD) -- still live$" && ! section Backlog "$W3" | grep -q "#QD-1"'
check "the multisets hold and the Decisions are unchanged" \
  'same_multisets "$T/before.md" "$W3" && section Decisions "$T/before.md" > "$T/s1" && section Decisions "$W3" > "$T/s2" && cmp -s "$T/s1" "$T/s2"'
cp "$W3" "$T/before.md"
rc=0; python3 "$SCRIPT" archive "$W3" --headings "### 1. Part one (QD) -- all done" --write >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "a second run, the ### form accepted: ALREADY ARCHIVED, NO CHANGE" \
  '[ "$rc" -eq 0 ] && grep -q "^ALREADY ARCHIVED heading line [0-9]*: ### 1. Part one (QD) -- all done$" "$T/o.txt" && [ "$(tail -1 "$T/o.txt")" = "NO CHANGE" ] && cmp -s "$W3" "$T/before.md"'
rc=0; python3 "$SCRIPT" archive "$W3" --headings "2. Part two (QD) -- still live" --write >/dev/null 2>"$T/e.txt" || rc=$?
check "a named heading holding an open line refuses, naming the line" \
  '[ "$rc" -eq 1 ] && grep -q "line [0-9]*: - \[ \] #QD-3" "$T/e.txt" && cmp -s "$W3" "$T/before.md"'
rc=0; python3 "$SCRIPT" archive "$W3" --headings "Part one" --write >/dev/null 2>"$T/e.txt" || rc=$?
check "a heading text matching no Backlog heading exactly refuses, naming it" \
  '[ "$rc" -eq 1 ] && grep -q "no ### heading under ## Backlog reads \"Part one\"" "$T/e.txt" && cmp -s "$W3" "$T/before.md"'
t1=$(grep -n '^### Twin (QE)$' "$W3" | sed -n 1p | cut -d: -f1)
t2=$(grep -n '^### Twin (QE)$' "$W3" | sed -n 2p | cut -d: -f1)
rc=0; python3 "$SCRIPT" archive "$W3" --headings "Twin (QE)" --write >/dev/null 2>"$T/e.txt" || rc=$?
check "a heading text matching two Backlog headings refuses, naming both lines" \
  '[ "$rc" -eq 1 ] && [ -n "$t1" ] && [ -n "$t2" ] && grep -q "\"Twin (QE)\" matches 2 headings under ## Backlog" "$T/e.txt" && grep -q "line $t1: ### Twin" "$T/e.txt" && grep -q "line $t2: ### Twin" "$T/e.txt" && cmp -s "$W3" "$T/before.md"'

echo "== Usage"
rc=0; python3 "$SCRIPT" archive "$W2" >/dev/null 2>"$T/e.txt" || rc=$?
check "archive without --phases or --headings: exit 2, naming both" '[ "$rc" -eq 2 ] && grep -q "archive needs --phases CODE\[,CODE...\] or --headings" "$T/e.txt"'

echo
if [ "$RESULT" -eq 0 ]; then echo "ARCHIVE ACCEPTANCE: ALL CHECKS PASS"; else echo "ARCHIVE ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
