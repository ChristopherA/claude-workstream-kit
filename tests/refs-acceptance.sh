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
push waits for #QW-4, which no home is named for.

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
- [ ] #LV-7: names #OT-1 bare first. Then #OT-1 in feature/other, homed. Then #OT-1 bare again, covered by the homed mention.

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
(the triage map), #G-QX in project/user-config-stewardship (the live
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
check "D17 in ws/old resolves at the tag (three times from live: #LV-1 and both mentions on #LV-6)" '[ "$(cls homed_resolved D17 | sort -u)" = "live ws/old" ] && [ "$(cls homed_resolved D17 | wc -l | tr -d " ")" = "3" ]'
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
check "#OT-1 in a two-home sentence resolves at feature/other, the home that defines it, not the nearer ws/old" '[ "$(cls homed_resolved \#OT-1 | sort -u)" = "live feature/other" ]'
check "#OL-3 in the same sentence resolves at ws/old, not the nearer feature/other" '[ "$(cls homed_resolved \#OL-3 | grep -c "^live ws/old")" = "2" ]'
check "neither ID of the two-home sentence is reported as home-lacking" '[ "$(q "[.classes.homed_home_lacks[] | select(.id == \"#OT-1\" or .id == \"#OL-3\")] | length")" = "0" ]'
check "a two-home entry lists both candidates" '[ "$(q "[.classes.homed_resolved[] | select(.id == \"#OT-1\" and has(\"candidates\")) | .candidates | join(\",\")] | .[0]")" = "ws/old,feature/other" ]'
check "a one-home entry carries no candidates field" '[ "$(q "[.classes.homed_resolved[] | select(.id == \"D17\") | has(\"candidates\")] | .[0]")" = "false" ]'
check "#QW-4 in the critical-path paragraph is unhomed" '[ "$(cls unhomed \#QW-4)" = "live null" ]'
check "L2 in the STANDING criterion is unhomed" '[ "$(cls unhomed L2)" = "live null" ]'
check "the metavariable #XX-N and the literal #G-XX appear in no class" \
  '[ "$(q "[.classes[][] | select(.id == \"#XX-N\" or .id == \"#G-XX\")] | length")" = "0" ]'
check "the struck ~~superseded by D9~~ is not a reference" '[ "$(q "[.classes[][] | select(.id == \"D9\")] | length")" = "0" ]'

echo "== A possessive type/name is not a home, and a home is named once per block"
check "#LV-6: D17's second mention, whose sentence names only feature/other's, is not home-lacking at feature/other" \
  '[ "$(q "[.classes.homed_home_lacks[] | select(.id == \"D17\")] | length")" = "0" ]'
LV6=$(grep -n '^- \[ \] #LV-6' .state/workstreams/feature/live/workstream.md | cut -d: -f1)
check "#LV-6: D17's second mention inherits the first mention's home, naming the line that homed it, and is not unhomed" \
  '[ "$(q "[.classes.unhomed[] | select(.id == \"D17\")] | length")" = "0" ] && [ "$(q "[.classes.homed_resolved[] | select(.id == \"D17\" and .homed_by_line == '"$LV6"')] | length")" = "1" ]'
check "#LV-7: the bare mention BEFORE the homed one stays unhomed; the one after inherits (one unhomed, two resolved)" \
  '[ "$(q "[.classes.unhomed[] | select(.id == \"#OT-1\")] | length")" = "1" ] && [ "$(q "[.classes.homed_resolved[] | select(.id == \"#OT-1\" and .line == '"$(grep -n '^- \[ \] #LV-7' .state/workstreams/feature/live/workstream.md | cut -d: -f1)"')] | length")" = "2" ]'
check "the possessive is still a workstream reference elsewhere: feature/other homes #OT-7 on #LV-2" '[ "$(cls homed_home_lacks \#OT-7 | grep -c "feature/other")" = "1" ]'

echo "== Out of scope: completed tasks, done criteria, resolved Open Questions"
check "#ZZ-9 (a done task's note), #ZZ-8 (a done criterion) and #QQ-1 (a struck OQ) appear in no class" \
  '[ "$(q "[.classes[][] | select(.id == \"#ZZ-9\" or .id == \"#ZZ-8\" or .id == \"#QQ-1\")] | length")" = "0" ]'
# Vary one input that must change the class: tick #LV-2 done and its #OT-7 reference leaves the report.
sed -i.bak 's/^- \[ \] #LV-2:/- [x] #LV-2:/' .state/workstreams/feature/live/workstream.md && rm -f .state/workstreams/feature/live/workstream.md.bak
check "ticking #LV-2 removes #OT-7 from every class (the scope is live content)" \
  '[ "$(python3 "$SCRIPT" refs "$T" | jq -r "[.classes[][] | select(.id == \"#OT-7\")] | length")" = "0" ]'
git checkout -q -- .state/workstreams/feature/live/workstream.md

echo "== ACTIVE.md: an ID its own workstream defines needs no home; a homed one resolves"
check "#LV-1 in feature/live (ACTIVE.md's Now) is homed and resolved" '[ "$(cls homed_resolved \#LV-1 | grep -c "^.state feature/live")" = "1" ]'
check "the report lists classes with lines, and a line number is an integer" '[ "$(q ".classes.homed_resolved[0].line")" -gt 0 ]'
check "no count field is reported" '[ "$(q "keys | join(\",\")")" = "classes" ]'

echo "== The refs family: what counts as a reference, and where a home is read"
# A second archive tag over the WHOLE tree as it stands now (live and
# other), then the citations added after it.
git tag -a ws/snap -m "snapshot of the whole tree"
cat > .state/ACTIVE.md <<'FIX'
---
workstream: feature/live
task: "#LV-1 - the first task"
---
## Now
D1 and #LV-2 frame the week, beside #OT-1 in feature/other (the only
task there).

Then #OT-9 waits, which holds #OT-1 in feature/other (the only task).
FIX
printf -- '\n## Decisions\n### D1 (2026-01-01): Other numbers its Decisions from one too\nReasoning.\n' >> .state/workstreams/feature/other/workstream.md
printf -- '- [ ] #OT-2: a second task there\n' > "$T/ot2.txt"
sed '/^- \[ \] #OT-1:/r '"$T/ot2.txt" .state/workstreams/feature/other/workstream.md > "$T/o.tmp" && mv "$T/o.tmp" .state/workstreams/feature/other/workstream.md
cat > "$T/lv.txt" <<'FIX'
- [ ] #LV-8: the gloss form quoted as an example, `#QZ-4 in feature/zz (a gloss)`, and a real citation in a code span, `#OT-2` in feature/other
- [ ] #LV-9: moved in (was feature/old #OL-3.) and see feature/other for the rest
- [ ] #LV-10: reads #OT-1 in ws/snap, a tag naming no workstream, whose tree holds other's file
FIX
sed '/^- \[ \] #LV-7:/r '"$T/lv.txt" .state/workstreams/feature/live/workstream.md > "$T/l.tmp" && mv "$T/l.tmp" .state/workstreams/feature/live/workstream.md
printf -- '- L3 (2026-01-01): A routed insight. ROUTED 2026-01-02 to #OT-5 in feature/other, which never defined it.\n' > "$T/l3.txt"
sed '/^- L1 (2026-01-01):/r '"$T/l3.txt" .state/workstreams/feature/live/workstream.md > "$T/l.tmp" && mv "$T/l.tmp" .state/workstreams/feature/live/workstream.md
sed 's/^### D2 (2026-01-01): Decision 2$/&\
Reasoning in D17 in ws\/old, and a bare #ZZ-7 as frozen provenance./' .state/workstreams/feature/live/workstream.md > "$T/l.tmp" && mv "$T/l.tmp" .state/workstreams/feature/live/workstream.md
git add -A && git -c commit.gpgsign=false commit -q -m "refs family cases"
python3 "$SCRIPT" refs "$T" > "$T/out.json"
LV9=$(grep -n '^- \[ \] #LV-9' .state/workstreams/feature/live/workstream.md | cut -d: -f1)
check "fixture: the snapshot tag holds other's file and names no workstream" \
  "git ls-tree -r --name-only ws/snap | grep -q 'feature/other/workstream.md' && ! git ls-tree -r --name-only ws/snap | grep -q '/snap/'"
check "fixture: other defines D1, and the ACTIVE.md sentence names D1 beside a home in feature/other" \
  "grep -q '^### D1 ' .state/workstreams/feature/other/workstream.md && grep -q '^D1 and #LV-2 frame' .state/ACTIVE.md"
check "ACTIVE.md: #LV-2, which its own workstream defines, is defined here and not homed at the sentence's feature/other" \
  '[ "$(q "[.classes.defined_here[] | select(.id == \"#LV-2\" and .file == \".state/ACTIVE.md\")] | length")" = "1" ] && [ "$(q "[.classes[][] | select(.id == \"#LV-2\" and .home == \"feature/other\")] | length")" = "0" ]'
check "ACTIVE.md: D1 is its own workstream's, never resolved at feature/other though other defines a D1 (the false success)" \
  '[ "$(q "[.classes.defined_here[] | select(.id == \"D1\" and .file == \".state/ACTIVE.md\")] | length")" = "1" ] && [ "$(q "[.classes.homed_resolved[] | select(.id == \"D1\")] | length")" = "0" ]'
check "an ID quoted inside a longer code span is no reference: #QZ-4 is in no class" \
  '[ "$(q "[.classes[][] | select(.id == \"#QZ-4\")] | length")" = "0" ]'
check "a code span that IS an ID still cites: #OT-2 in backticks, in feature/other, resolves" \
  '[ "$(cls homed_resolved \#OT-2)" = "live feature/other" ]'
check "a provenance note is history: #OL-3 on #LV-9 is in no class, and not home-lacking at the later feature/other" \
  '[ "$(q "[.classes[][] | select(.id == \"#OL-3\" and .line == $LV9)] | length")" = "0" ]'
check "a tag home is read as the whole tree: #OT-1 in ws/snap resolves, in other's file" \
  '[ "$(q ".classes.homed_resolved[] | select(.id == \"#OT-1\" and .home == \"ws/snap\") | .resolved_in")" = ".state/workstreams/feature/other/workstream.md" ]'
check "Learnings are read for homed references: L3's #OT-5 in feature/other is home-lacking, its section named" \
  '[ "$(q ".classes.homed_home_lacks[] | select(.id == \"#OT-5\") | .section")" = "## Learnings" ]'
check "Decisions are read for homed references: D17 in ws/old in D2's paragraph resolves" \
  '[ "$(q "[.classes.homed_resolved[] | select(.id == \"D17\" and .section == \"## Decisions\")] | length")" = "1" ]'
check "an ID whose only home was written beside another ID is unhomed, not home-lacking at that home: #OT-9" \
  '[ "$(q ".classes.unhomed[] | select(.id == \"#OT-9\") | .home_beside | join(\",\")")" = "#OT-1" ] && [ "$(q "[.classes.homed_home_lacks[] | select(.id == \"#OT-9\")] | length")" = "0" ]'
check "a bare ID in a Decision stays frozen provenance: #ZZ-7 is in no class" \
  '[ "$(q "[.classes[][] | select(.id == \"#ZZ-7\")] | length")" = "0" ]'

echo "== A home written before the ID binds it"
# On 0.11.5 a home written BEFORE an ID -- `maintain/absent L2`, or with a
# noun of the ID's kind between, `maintain/absent Learning L2` -- was
# tried only after every home written after the ID, so a missing one lost
# to a later home in the same sentence: the class was right and the home
# it named was another workstream's. Its run (`... and its L8`) binds too,
# and one that exists still resolves there.
P="$T/pre"
mkdir -p "$P/.state/workstreams/maintain/beta" "$P/.state/workstreams/project/gamma" "$P/.state/workstreams/feature/live"
printf -- '---\nname: beta\ntype: maintain\nstatus: active\n---\n## Purpose\nx\n\n## Backlog\n### Live (LV)\n- [ ] #LV-9: x\n\n## Learnings\n- L2 (2026-01-01): the beta entry.\n' > "$P/.state/workstreams/maintain/beta/workstream.md"
printf -- '---\nname: gamma\ntype: project\nstatus: active\n---\n## Purpose\nx\n\n## Backlog\n### Live (LV)\n- [ ] #LV-8: x\n' > "$P/.state/workstreams/project/gamma/workstream.md"
cat > "$P/.state/workstreams/feature/live/workstream.md" <<'FIX'
---
name: live
type: feature
status: active
---
## Purpose
x

## Backlog
### Live (LV)
- [ ] #LV-1: cites maintain/absent Learning L2 (the paths check) and its L8 (the condensing loss), seen at project/gamma.
- [ ] #LV-2: cites maintain/absent L2 (the bare form), seen at project/gamma.
- [ ] #LV-3: cites maintain/beta Learning L2 (the beta entry), seen at project/gamma.
FIX
printf -- '---\nworkstream: feature/live\ntask: none\n---\n## Now\nx\n' > "$P/.state/ACTIVE.md"
python3 "$SCRIPT" refs "$P" > "$T/pre.json"
pq() { jq -r "[.classes.$1[] | select(.id == \"$2\" and .line == $3) | .home] | join(\",\")" "$T/pre.json"; }
check "the fixture's later home, project/gamma, exists, so a wrong binding to it would resolve nothing for L2" \
  '[ -f "$P/.state/workstreams/project/gamma/workstream.md" ] && ! grep -q "L2" "$P/.state/workstreams/project/gamma/workstream.md"'
check "Learning L2 after maintain/absent is home-missing at maintain/absent, not at project/gamma" \
  '[ "$(pq homed_home_missing L2 11)" = "maintain/absent" ]'
check "its L8, in the same run, binds to maintain/absent too" '[ "$(pq homed_home_missing L8 11)" = "maintain/absent" ]'
check "the bare form, maintain/absent L2, binds the same way" '[ "$(pq homed_home_missing L2 12)" = "maintain/absent" ]'
check "the control: maintain/beta Learning L2, a home that exists, resolves there" '[ "$(pq homed_resolved L2 13)" = "maintain/beta" ]'

echo "== Exit codes"
rc=0; python3 "$SCRIPT" refs >/dev/null 2>&1 || rc=$?
check "refs with no root: exit 2" '[ "$rc" -eq 2 ]'
rc=0; python3 "$SCRIPT" refs "$T/nowhere" >/dev/null 2>&1 || rc=$?
check "refs on a root with no .state: exit 2" '[ "$rc" -eq 2 ]'
check "the sweep wrote nothing (git status clean)" '[ -z "$(git status --porcelain -- .state)" ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "REFS ACCEPTANCE: ALL CHECKS PASS"; else echo "REFS ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
