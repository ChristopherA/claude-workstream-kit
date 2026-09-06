#!/bin/sh
# Offline acceptance test for `workstream-record.py refs`: does every
# cited ID in live content resolve where it says it lives. Builds a git
# fixture with an archive tag so a tag home is read with `git show`.
# Cases from the review skill's own history: D17 cited in a workstream
# carrying thirteen Decisions, with the home an archive tag that holds
# it; the same with the tag absent; a `- [x] #XX-N (dated note)`
# definition with no colon; a metavariable skipped; a homed ID whose
# home directory exists and lacks the line; an unhomed cross-boundary
# ID in a critical-path paragraph; a bare ID in a completed task's
# note, correctly out of scope. Plus the non-conforming fixture and an
# ACTIVE.md block lifted from the corpus.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-refs-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

cd "$T"
git init -q -b main
git config user.email fixture@example.invalid
git config user.name Fixture
git config commit.gpgsign false
mkdir -p .state/workstreams/project/old .state/workstreams/feature/live .state/workstreams/feature/other

# old: the workstream that will be archived at a tag, defining D17 and #OL-3.
cat > .state/workstreams/project/old/workstream.md <<'FIX'
---
name: old
type: project
status: done
---
## Backlog
### Old (OL)
- [x] #OL-3 (DONE 2026-01-01, the parenthesised note form without a colon)

## Decisions
### D17 (2026-01-01): The decision that moved to the tag
Reasoning.
FIX
git add -A && git commit -q -m "old workstream"
git tag -a ws/old -m "archive old"
git rm -q -r .state/workstreams/project/old && git commit -q -m "archive old"

# live: thirteen Decisions of its own (so D17 is NOT defined here), a
# wrapped open line citing D17 at the tag, an indented sub-task citing
# #OL-3 at the tag, a phase heading with a suffix, a done task whose
# note carries a bare #ZZ-9 (out of scope), a metavariable #XX-N and a
# literal #G-XX (skipped), a homed ID whose home exists and lacks it, a
# critical-path paragraph with an unhomed cross-boundary ID, a struck
# reference, an unresolved OQ citing its own task, and a STANDING
# criterion citing L2 with no home.
{
  cat <<'FIX'
---
name: live
type: feature
status: active
---
## Purpose
Live exercises reference resolution.

## Backlog
**Critical path.** The order runs #LV-1 then the split, and the tag
push waits for #SW-4, which no home is named for.

### Live (LV) -- the heading carries a suffix, as real files do
- [ ] #LV-1: the first task, reasoning in D17 in ws/old, written
across a wrap against the convention; the template's #XX-N and #G-XX
are metavariables and not references
  - [ ] #LV-1a: an indented sub-task, routed from #OL-3 in ws/old
- [ ] #LV-2: cites #OT-7 in feature/other, which does not define it, and D22 in ws/gone
- [ ] #LV-3: ~~superseded by D9~~ now reads D1 here
- [x] #LV-4: done, its note citing #ZZ-9 bare, frozen provenance
- [ ] #G-LV: USER CHECKPOINT -- decided against D1 and OQ-1
- [ ] #LV-5: two homes in one sentence: #OT-1 lives in ws/old, which is read as #OL-3 in feature/other
- [ ] #LV-6: cites D17 in ws/old first. Later in the block D17 recurs where `feature/other`'s row is the only name in the sentence, a possessive and not a home.

## Decisions
FIX
  i=1; while [ "$i" -le 13 ]; do printf '### D%s (2026-01-01): Decision %s\nReasoning.\n\n' "$i" "$i"; i=$((i + 1)); done
  cat <<'FIX'
## Learnings
- L1 (2026-01-01): An insight. APPLIED 2026-01-02 to docs/x.md.

## Open Questions
- OQ-1: Resolve at #LV-2, which is defined here.
- ~~OQ-2: Resolved, citing #QQ-1 in feature/nowhere.~~ RESOLVED 2026-01-01.

## Deletion Criteria
- [ ] STANDING: no orphaned Learnings, per L2 -- HOLDS 2026-01-01
- [x] Done criterion citing #ZZ-8, out of scope once ticked
FIX
} > .state/workstreams/feature/live/workstream.md

cat > .state/workstreams/feature/other/workstream.md <<'FIX'
---
name: other
type: feature
status: active
---
## Backlog
### Other (OT)
- [ ] #OT-1: the only task here
FIX

# ACTIVE.md, lifted 2026-09-05 from the project that built this
# sub-command: every ID carries its home and a few words saying what it is.
cat > .state/ACTIVE.md <<'FIX'
---
workstream: feature/live
task: "#LV-1 - the first task"
---
## Now
#LV-1 in feature/live (the first task) is in flight.

## Blockers
The three estate gates -- #G-TR in project/workspace-config-migration
(the triage map), #G-EX in project/user-config-stewardship (the live
tier result) -- are presented in the gaps of the build chain; L45 in
ws/old holds the goal-authoring rule.
FIX
git add -A && git commit -q -m "live"

python3 "$SCRIPT" refs "$T" > "$T/out.json"
q() { jq -r "$1" "$T/out.json"; }
cls() { jq -r ".classes.$1[] | select(.id == \"$2\") | \"\\(.file | split(\"/\") | .[-2]) \\(.home)\"" "$T/out.json"; }

echo "== Sanity"
check "the tag ws/old exists and the old directory is gone from the tree" \
  "[ \"\$(git tag -l ws/old)\" = ws/old ] && [ ! -d .state/workstreams/project/old ]"
check "live carries thirteen Decisions, none of them D17" \
  "[ \"\$(grep -c '^### D' .state/workstreams/feature/live/workstream.md)\" = 13 ] && ! grep -q '^### D17' .state/workstreams/feature/live/workstream.md"

echo "== Homed and resolved through an archive tag (two git reads)"
check "D17 in ws/old resolves at the tag (twice from live: #LV-1 and #LV-6)" '[ "$(cls homed_resolved D17 | sort -u)" = "live ws/old" ] && [ "$(cls homed_resolved D17 | wc -l | tr -d " ")" = "2" ]'
check "#OL-3 in ws/old resolves through the no-colon definition form (cited twice, both at ws/old)" '[ "$(cls homed_resolved \#OL-3 | sort -u)" = "live ws/old" ]'
check "L45 in ws/old (from ACTIVE.md) is homed, home lacks it -- the tag holds old and old defines no L45" \
  '[ "$(cls homed_home_lacks L45)" = ".state ws/old" ]'

echo "== Homes that are missing or lack the line"
check "D22 in ws/gone: tag absent, home missing" '[ "$(cls homed_home_missing D22)" = "live ws/gone" ]'
check "#OT-7 in feature/other: directory exists, lacks the line" '[ "$(cls homed_home_lacks \#OT-7)" = "live feature/other" ]'
check "#G-TR in project/workspace-config-migration (ACTIVE.md): home missing" \
  '[ "$(cls homed_home_missing \#G-TR)" = ".state project/workspace-config-migration" ]'

echo "== Defined here, unhomed, skipped"
check "#LV-2 cited by OQ-1 is defined here (with its own line's self-mention, two entries)" '[ "$(cls defined_here \#LV-2 | grep -c "^live null")" = "2" ]'
check "D1 cited by #LV-3 and #G-LV is defined here (two entries)" '[ "$(q "[.classes.defined_here[] | select(.id == \"D1\")] | length")" = "2" ]'
check "#OT-1 in a two-home sentence resolves at feature/other, the home that defines it, not the nearer ws/old" '[ "$(cls homed_resolved \#OT-1)" = "live feature/other" ]'
check "#OL-3 in the same sentence resolves at ws/old, not the nearer feature/other" '[ "$(cls homed_resolved \#OL-3 | grep -c "^live ws/old")" = "2" ]'
check "neither ID of the two-home sentence is reported as home-lacking" '[ "$(q "[.classes.homed_home_lacks[] | select(.id == \"#OT-1\" or .id == \"#OL-3\")] | length")" = "0" ]'
check "a two-home entry lists both candidates" '[ "$(q "[.classes.homed_resolved[] | select(.id == \"#OT-1\") | .candidates | join(\",\")] | .[0]")" = "ws/old,feature/other" ]'
check "a one-home entry carries no candidates field" '[ "$(q "[.classes.homed_resolved[] | select(.id == \"D17\") | has(\"candidates\")] | .[0]")" = "false" ]'
check "#SW-4 in the critical-path paragraph is unhomed" '[ "$(cls unhomed \#SW-4)" = "live null" ]'
check "L2 in the STANDING criterion is unhomed" '[ "$(cls unhomed L2)" = "live null" ]'
check "the metavariable #XX-N and the literal #G-XX appear in no class" \
  '[ "$(q "[.classes[][] | select(.id == \"#XX-N\" or .id == \"#G-XX\")] | length")" = "0" ]'
check "the struck ~~superseded by D9~~ is not a reference" '[ "$(q "[.classes[][] | select(.id == \"D9\")] | length")" = "0" ]'

echo "== A possessive type/name is not a home"
check "#LV-6: D17's first mention resolves at ws/old, on #LV-6's own line" \
  '[ "$(q "[.classes.homed_resolved[] | select(.id == \"D17\")] | length")" = "2" ]'
check "#LV-6: D17's second mention, whose sentence names only feature/other's, is unhomed rather than home-lacking at feature/other" \
  '[ "$(q "[.classes.homed_home_lacks[] | select(.id == \"D17\")] | length")" = "0" ] && [ "$(q "[.classes.unhomed[] | select(.id == \"D17\")] | length")" = "1" ]'
check "the possessive is still a workstream reference elsewhere: feature/other homes #OT-7 on #LV-2" '[ "$(cls homed_home_lacks \#OT-7 | grep -c "feature/other")" = "1" ]'

echo "== Out of scope: completed tasks, done criteria, resolved Open Questions"
check "#ZZ-9 (a done task's note), #ZZ-8 (a done criterion) and #QQ-1 (a struck OQ) appear in no class" \
  '[ "$(q "[.classes[][] | select(.id == \"#ZZ-9\" or .id == \"#ZZ-8\" or .id == \"#QQ-1\")] | length")" = "0" ]'
# Vary one input that must change the class: tick #LV-2 done and its #OT-7 reference leaves the report.
sed -i.bak 's/^- \[ \] #LV-2:/- [x] #LV-2:/' .state/workstreams/feature/live/workstream.md && rm -f .state/workstreams/feature/live/workstream.md.bak
check "ticking #LV-2 removes #OT-7 from every class (the scope is live content)" \
  '[ "$(python3 "$SCRIPT" refs "$T" | jq -r "[.classes[][] | select(.id == \"#OT-7\")] | length")" = "0" ]'
git checkout -q -- .state/workstreams/feature/live/workstream.md

echo "== ACTIVE.md: nothing is defined there, so every ID needs a home"
check "#LV-1 in feature/live (ACTIVE.md's Now) is homed and resolved" '[ "$(cls homed_resolved \#LV-1 | grep -c "^.state feature/live")" = "1" ]'
check "the report lists classes with lines, and a line number is an integer" '[ "$(q ".classes.homed_resolved[0].line")" -gt 0 ]'
check "no count field is reported" '[ "$(q "keys | join(\",\")")" = "classes" ]'

echo "== Exit codes"
rc=0; python3 "$SCRIPT" refs >/dev/null 2>&1 || rc=$?
check "refs with no root: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" refs "$T/nowhere" >/dev/null 2>&1 || rc=$?
check "refs on a root with no .state: exit 2" '[ "$rc" -eq 2 ]'
check "the sweep wrote nothing (git status clean)" '[ -z "$(git status --porcelain -- .state)" ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "REFS ACCEPTANCE: ALL CHECKS PASS"; else echo "REFS ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
