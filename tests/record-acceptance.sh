#!/bin/sh
# Offline acceptance test for workstream-record.py: the record
# (workstream-status SKILL.md, Move 2), derived for every workstream.md
# under a fixture project plus ACTIVE.md's hold lines and cross refs and
# the per-field coverage. Every prose-bearing field is fired at a WRAPPED
# instance as well as an unwrapped one: the suite stayed green across
# three releases while every such field was broken on wrapped input,
# because it held no wrapped fixture.
#
# Every check that has two sides is fired both ways, and the fixture state
# a negative check depends on is asserted before the check itself -- a
# negative result is only evidence when the positive condition it rules
# out has been confirmed absent.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-record-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

echo "== Setup: fixture project at $T"
mkdir -p "$T/.state/workstreams/project/alpha"
mkdir -p "$T/.state/workstreams/feature/beta"

# alpha: two phases, three open tasks (one indented two spaces), one open
# gate carrying SATISFIED text, one hold line, a hard-wrapped critical-path
# paragraph naming ws/old-one, three Decisions out of order (D3 before D1),
# two Learnings (one APPLIED), two open + one done deletion criterion, and
# one open task line sitting above the first ### heading (outside any phase).
cat > "$T/.state/workstreams/project/alpha/workstream.md" <<'EOF'
---
name: alpha
type: project
status: active
created: 2026-01-01
updated: 2026-01-01
---
## Purpose
This is the alpha workstream covering project redesign work. Done means the
design phase is delivered and integrated cleanly.

## Backlog
- [ ] #ZZ-1: an orphan task sitting outside any phase heading

### Design (DR)
- [ ] #DR-1: draft the design outline
- [ ] #G-DR: USER CHECKPOINT -- release readiness SATISFIED 2026-01-01 pending final confirmation

### Build (BD) -- the phase heading carries a suffix, as real files do
  - [ ] #BD-1: implement the core module
- [ ] #BD-2: blocked on feature/beta for the shared schema work

## Decisions
### D3 (2026-01-01): Third decision
Some rationale.

### D1 (2026-01-01): First decision
Some rationale.

### D2 (2026-01-01): Second decision
Some rationale.

## Learnings
- L1 (2026-01-01): Insight one. APPLIED 2026-01-02 to somewhere.
- L2 (2026-01-01): Insight two with no disposition yet.

## Open Questions
- OQ-1: some question.

**Critical path**: alpha's flow runs from the design phase
through implementation and finally to release, referencing
ws/old-one for historical continuity across projects.

## Deletion Criteria
- [ ] Criterion one not yet met
- [ ] Criterion two also pending
- [x] Criterion three already satisfied by earlier work
- [ ] STANDING: the inbox stays empty -- HOLDS 2026-01-01, HOLDS 2026-02-02
- [ ] STANDING: no orphaned Learnings, never yet re-checked
EOF

# beta: Purpose with no "Done means" sentence; its only prose containing
# the letters h-o-l-d is "threshold", which must NOT register as a hold
# line (word-boundary requirement); a second open gate with no
# satisfied-text, to fire the negative side of that branch.
cat > "$T/.state/workstreams/feature/beta/workstream.md" <<'EOF'
---
name: beta
type: feature
status: active
created: 2026-01-01
updated: 2026-01-01
---
## Purpose
This workstream covers the beta feature integration effort across two
subsystems. It focuses on raising the alert threshold safely without
regressions. The final sentence marks completion criteria for this section.

## Backlog
### Design (DN)
- [ ] #DN-1: raise the alert threshold before shipping
- [ ] #G-DN: USER CHECKPOINT -- pending review before shipment

## Decisions

## Learnings

## Deletion Criteria
- [ ] Criterion pending
EOF

# gamma: the WRAPPED instance of every prose-bearing field, plus every
# pattern case the consumers reported. Two same-code headings (PX) each
# holding one task; a task whose code (MV) no heading declares, sitting
# under a PX heading; a multi-code heading (QK / HW); a phase heading that
# states a hold; a hold on the THIRD line of a wrapped open task; a
# hyphenated compound (Held-out) and a negated clause that must not
# register; a wrapped gate whose marker sits on its fourth line, a gate
# with a bare MENTION of the word, and a gate marked READY with a date; a
# heading-form critical path; a repository name (ml-explore/mlx) that must
# not become a reference and a dotted name that must be captured whole;
# Learnings with EXTRACTED on a continuation, QUEUED, and nothing.
mkdir -p "$T/.state/workstreams/project/gamma"
cat > "$T/.state/workstreams/project/gamma/workstream.md" <<'EOF'
---
name: gamma
type: project
status: active
created: 2026-01-01
---
## Purpose
Gamma exercises the wrapped shape of every field. Done means every
field reads a folded block.

## Backlog
### Pass 1 (PX)
- [ ] #PX-1: first pass task
- [ ] #MV-1: a task moved in from elsewhere, keeping its ID

### Pass 2 (PX)
- [ ] #PX-2: second pass task whose description wraps over three lines
because the author wrapped it against the convention, and its third
line is blocked on feature/beta for the shared schema, citing #PX-9
- [ ] #PX-3: evaluate the Held-out validation set before the release
- [ ] #PX-4: ~~blocked on feature/beta for the old schema~~ (STALE 2026-02-02), and the two retired checkpoints held, so conditions that hold here carry no live hold

### Split (QK / HW)
- [ ] #QK-1: a task under a multi-code heading
- [ ] #HW-1: another task under the same multi-code heading
- [ ] #G-QK: USER CHECKPOINT -- the split review, whose line wraps over
several lines because a gate accretes agenda, and the marker that
matters is not on the first line but here, the exit criterion is
SATISFIED 2026-03-03 with the evidence recorded beside it
- [ ] #G-HW: USER CHECKPOINT -- the build note reads "the wrap sentence
and the SATISFIED sentence quoted", which is a mention and not a marking
- [ ] #G-QK2: USER CHECKPOINT -- READY 2026-02-02, decided in the record

### Deferred (DF) -- blocked on the condensed evaluation
- [ ] #DF-1: waits for the upstream fix in ml-explore/mlx#3856 to land,
then finalize in project/omlx-0.4.x-finalize

## Decisions
### D1 (2026-01-01): Only decision
Some rationale, with a list under it:
- L9 is not a Learning: a list item inside a Decision that begins with L

## Learnings
- L1 (2026-01-01): An insight whose disposition marker sits on its second
line. EXTRACTED 2026-01-02 to docs/design.md.
- L2 (2026-01-01): An insight that is tracked work. QUEUED 2026-01-02 for #PX-2.
- L3 (2026-01-01): An insight with no disposition at all.
- L4 (2026-01-01): An insight that is spent. SPENT 2026-01-02 -- routed to docs/design.md.
- L5 (2026-01-01): DISPOSITION 2026-01-03: ROUTED to #PX-1, the date
  before the marker, as the corpus writes it.
- L6 (2026-01-01): An insight whose two-word marker wraps across the
  70-column break, so a line-scoped read sees neither word. HANDED
  OFF 2026-01-04 to project/omlx-0.4.x-finalize.
- L7 (2026-09-04): `workstream-record.py`'s disposition matching is
  correct BECAUSE it folds a Learning into a block and matches the
  marker against the joined text, so the multi-word `HANDED OFF`
  survives the 70-column wrap that splits it. An ad-hoc classifier
  written this session against the same file scored L47 as
  undispositioned for exactly that reason. Integration target: the
  fixture set (lifted 2026-09-04 from feature/kit-script-core L9 in
  the project that built this rule; a MENTION of a marker, mid-sentence).
- L8 (2026-01-01): An insight with the marker at sentence start and
  no date anywhere in that sentence. APPLIED to docs/design.md, the
  author forgetting the date.
- ~~L9 (2026-01-01): An insight struck through whole, retired in place.~~

## Open Questions
- OQ-1: is a `### D7` heading outside Decisions a Decision? It is not:

### D7 (2026-01-01): a heading outside ## Decisions, which must not count
Prose under it.

### Critical path
Nothing in this file is held by another workstream; the order runs
PX-1, then PX-2, then the split, referencing ws/old-two for history.

## Deletion Criteria
- [ ] Criterion pending
EOF

# ACTIVE.md: Blockers paragraph wraps feature/beta cleanly on one line and
# contains "waiting for #G-BD".
cat > "$T/.state/ACTIVE.md" <<'EOF'
---
workstream: project/alpha
task: "#BD-2 - shared schema work"
updated: 2026-01-01
---
## Now
Fixture project for acceptance testing.

## Next
Continue alpha's design phase.

## Blockers
Release is waiting for #G-BD in feature/beta before we can proceed with the next steps here.
EOF

OUT=$(python3 "$SCRIPT" "$T")
printf '%s\n' "$OUT" > "$T/out.json"

echo "== Sanity: fixture actually contains what the checks depend on"
check "beta fixture literally contains the word threshold" \
  "grep -q 'threshold' \"$T/.state/workstreams/feature/beta/workstream.md\""
check "beta's second gate line carries no satisfied-text (sanity)" \
  "! grep -qE 'SATISFIED|READY|criterion is met' \"$T/.state/workstreams/feature/beta/workstream.md\""

echo "== Phases, open counts, tasks outside phases"
alpha_open_total=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .open_total' "$T/out.json")
alpha_tasks_outside=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .tasks_outside_phases' "$T/out.json")
alpha_build_open_tasks=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | (.phases[] | select(.code=="BD") | .open_tasks)' "$T/out.json")

check "alpha open_total is 5 (four in phases plus the one outside)" '[ "$alpha_open_total" = "5" ]'
check "alpha tasks_outside_phases is 1" '[ "$alpha_tasks_outside" = "1" ]'
check "the two-space-indented task is counted (Build phase open_tasks is 2)" '[ "$alpha_build_open_tasks" = "2" ]'
# Phases carry their done counts beside the open ones, so a completed
# phase is visible without a second scan.
mkdir -p "$T/donephase/.state/workstreams/project/p"
printf -- '## Backlog\n### Done (DN)\n- [x] #DN-1: done\n- [x] #DN-2: done\n- [x] #DN-3: done\n- [x] #G-DN: USER CHECKPOINT -- decided\n### Live (LV)\n- [x] #LV-1: done\n- [ ] #LV-2: open\n' > "$T/donephase/.state/workstreams/project/p/workstream.md"
check "a phase with three done tasks, a done gate and nothing open reports done_tasks 3, done_gates 1, open 0" \
  '[ "$(python3 "$SCRIPT" "$T/donephase" | jq -r ".workstreams[0].phases[0] | \"\\(.done_tasks) \\(.done_gates) \\(.open_tasks) \\(.open_gates)\"")" = "3 1 0 0" ]'
check "the live phase beside it reports done 1, open 1" \
  '[ "$(python3 "$SCRIPT" "$T/donephase" | jq -r ".workstreams[0].phases[1] | \"\\(.done_tasks) \\(.open_tasks)\"")" = "1 1" ]'

# An open task OUTSIDE ## Backlog is invisible to every phase count and
# counted by the roster; the record names it by line and ID.
mkdir -p "$T/outside/.state/workstreams/project/o"
printf -- '## Backlog\n### Live (LV)\n- [ ] #LV-1: open\n\n## Decisions\n- [ ] #QW-9: appended after the Backlog ended\n### D1 (2026-01-01): a decision\n' > "$T/outside/.state/workstreams/project/o/workstream.md"
check "an open task under ## Decisions is reported in open_outside_backlog with its line, ID and section" \
  '[ "$(python3 "$SCRIPT" "$T/outside" | jq -r ".workstreams[0].open_outside_backlog[] | \"\\(.line) \\(.id) \\(.section)\"")" = "6 #QW-9 ## Decisions" ]'
check "the same file: open_total 2 while the phases sum to 1 -- the gap the field names" \
  '[ "$(python3 "$SCRIPT" "$T/outside" | jq -r ".workstreams[0] | \"\\(.open_total) \\([.phases[].open_tasks] | add)\"")" = "2 1" ]'
check "alpha, whose orphan sits inside Backlog, reports open_outside_backlog empty" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"project/alpha/workstream.md\")) | .open_outside_backlog | length" "$T/out.json")" = "0" ]'

echo "== Open gates"
alpha_gate_satisfied=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .open_gates[0].satisfied_text' "$T/out.json")
beta_gate_satisfied=$(jq -r '.workstreams[] | select(.path | endswith("feature/beta/workstream.md")) | .open_gates[0].satisfied_text' "$T/out.json")

check "alpha's gate satisfied_text is true (SATISFIED text present)" '[ "$alpha_gate_satisfied" = "true" ]'
check "beta's gate satisfied_text is false (no satisfied-text, negative side)" '[ "$beta_gate_satisfied" = "false" ]'

echo "== Hold lines"
alpha_hold_count=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | (.hold_lines | length)' "$T/out.json")
alpha_hold_match=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .hold_lines[0].match' "$T/out.json")
beta_hold_count=$(jq -r '.workstreams[] | select(.path | endswith("feature/beta/workstream.md")) | (.hold_lines | length)' "$T/out.json")

check "alpha has exactly one hold line" '[ "$alpha_hold_count" = "1" ]'
check "alpha's hold line match is 'blocked on'" '[ "$alpha_hold_match" = "blocked on" ]'
check "beta has zero hold lines despite containing threshold (word boundary)" '[ "$beta_hold_count" = "0" ]'

echo "== Cross-workstream references"
alpha_fb_kind=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | (.cross_refs[] | select(.target=="feature/beta") | .kind)' "$T/out.json")
alpha_fb_precid=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | (.cross_refs[] | select(.target=="feature/beta") | .preceding_id)' "$T/out.json")
alpha_wsold_kind=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | (.cross_refs[] | select(.target=="ws/old-one") | .kind)' "$T/out.json")

check "cross ref on the hold line has target feature/beta, kind workstream" '[ "$alpha_fb_kind" = "workstream" ]'
check "cross ref on the hold line has preceding_id #BD-2" '[ "$alpha_fb_precid" = "#BD-2" ]'
check "ws/old-one ref (from the critical path) is kind tag" '[ "$alpha_wsold_kind" = "tag" ]'

echo "== Critical path (hard-wrapped over three lines, joined)"
alpha_critpath=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .critical_path' "$T/out.json")
EXPECTED_CP="**Critical path**: alpha's flow runs from the design phase through implementation and finally to release, referencing ws/old-one for historical continuity across projects."
check "critical path is the joined three-line paragraph" '[ "$alpha_critpath" = "$EXPECTED_CP" ]'

echo "== Latest Decision (numeric max, not file order)"
alpha_dec_max=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .latest_decision.max' "$T/out.json")
alpha_dec_count=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .latest_decision.count' "$T/out.json")
check "latest_decision.max is 3 (headings are D3, D1, D2 in file order)" '[ "$alpha_dec_max" = "3" ]'
check "latest_decision.count is 3" '[ "$alpha_dec_count" = "3" ]'

echo "== Learnings"
alpha_learn_count=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .learnings.count' "$T/out.json")
alpha_learn_undisp=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | (.learnings.undispositioned | length)' "$T/out.json")
check "learnings.count is 2" '[ "$alpha_learn_count" = "2" ]'
check "learnings.undispositioned has one entry (L1 carries a dated APPLIED at sentence start)" '[ "$alpha_learn_undisp" = "1" ]'

echo "== Deletion criteria"
alpha_del_open=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.open' "$T/out.json")
alpha_del_done=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.done' "$T/out.json")
check "deletion_criteria open is 2 (the two STANDING lines are not unmet)" '[ "$alpha_del_open" = "2" ]'
check "deletion_criteria done is 1" '[ "$alpha_del_done" = "1" ]'
alpha_del_standing=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.standing' "$T/out.json")
alpha_del_oldest=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.standing_oldest_holds' "$T/out.json")
alpha_del_never=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.standing_never_rechecked' "$T/out.json")
check "deletion_criteria standing is 2" '[ "$alpha_del_standing" = "2" ]'
check "standing_oldest_holds reads each line's NEWEST date (2026-02-02, not 2026-01-01)" '[ "$alpha_del_oldest" = "2026-02-02" ]'
check "standing_never_rechecked is 1" '[ "$alpha_del_never" = "1" ]'
beta_del_oldest=$(jq -r '.workstreams[] | select(.path | endswith("feature/beta/workstream.md")) | .deletion_criteria.standing_oldest_holds' "$T/out.json")
check "a file with no STANDING line reports standing_oldest_holds null" '[ "$beta_del_oldest" = "null" ]'

echo "== Purpose (Done means present vs absent)"
beta_purpose_done=$(jq -r '.workstreams[] | select(.path | endswith("feature/beta/workstream.md")) | .purpose.done' "$T/out.json")
EXPECTED_BETA_DONE="The final sentence marks completion criteria for this section."
if printf '%s' "$beta_purpose_done" | grep -q "Done means"; then beta_has_donemeans=yes; else beta_has_donemeans=no; fi
check "beta purpose.done is the last sentence of its Purpose" '[ "$beta_purpose_done" = "$EXPECTED_BETA_DONE" ]'
check "beta purpose.done carries no 'Done means' (its Purpose lacks that sentence)" '[ "$beta_has_donemeans" = "no" ]'

alpha_purpose_done=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .purpose.done' "$T/out.json")
if printf '%s' "$alpha_purpose_done" | grep -q "Done means"; then alpha_has_donemeans=yes; else alpha_has_donemeans=no; fi
check "alpha purpose.done DOES carry 'Done means' (positive side)" '[ "$alpha_has_donemeans" = "yes" ]'

echo "== ACTIVE.md hold lines"
active_hold_count=$(jq -r '.active | (.hold_lines | length)' "$T/out.json")
active_hold_match=$(jq -r '.active.hold_lines[0].match' "$T/out.json")
check "active.hold_lines has one entry" '[ "$active_hold_count" = "1" ]'
check "active.hold_lines entry matches 'waiting for'" '[ "$active_hold_match" = "waiting for" ]'

G='.workstreams[] | select(.path | endswith("project/gamma/workstream.md"))'
gq() { jq -r "$G | $1" "$T/out.json"; }

echo "== Sanity: gamma's fixture carries each planted case"
check "gamma: the hold on #PX-2 sits on the task's THIRD line, not its first" \
  "grep -q '^line is blocked on feature/beta' \"$T/.state/workstreams/project/gamma/workstream.md\" && ! grep -q '#PX-2.*blocked' \"$T/.state/workstreams/project/gamma/workstream.md\""
check "gamma: #G-QK's marker is on a continuation line, not the gate's first line" \
  "grep -q '^SATISFIED 2026-03-03' \"$T/.state/workstreams/project/gamma/workstream.md\" && ! grep -q '#G-QK:.*SATISFIED' \"$T/.state/workstreams/project/gamma/workstream.md\""
check "gamma: #G-HW carries the bare word SATISFIED with no date after it" \
  "grep -q 'the SATISFIED sentence quoted' \"$T/.state/workstreams/project/gamma/workstream.md\""
check "gamma: two headings carry the same code PX" \
  "[ \"\$(grep -c '(PX)' \"$T/.state/workstreams/project/gamma/workstream.md\")\" = 2 ]"

echo "== Phases are position-keyed: same-code headings, mismatches, named missing codes"
check "gamma has four phase rows (two PX rows, one QK / HW, one DF; none for MV)" '[ "$(gq ".phases | length")" = "4" ]'
check "each PX heading counts only the tasks under it (Pass 1: 2 open, Pass 2: 3 open)" \
  '[ "$(gq ".phases[0].open_tasks")" = "2" ] && [ "$(gq ".phases[1].open_tasks")" = "3" ]'
check "the multi-code heading (QK / HW) matches and counts 2 tasks and 3 gates" \
  '[ "$(gq ".phases[2].code")" = "QK / HW" ] && [ "$(gq ".phases[2].open_tasks")" = "2" ] && [ "$(gq ".phases[2].open_gates")" = "3" ]'
check "tasks_outside_phases is 0 (never negative: per-heading sum plus outside equals the total)" \
  '[ "$(gq ".tasks_outside_phases")" = "0" ] && [ "$(gq ".open_total")" = "$(gq "[.phases[] | .open_tasks + .open_gates] | add")" ]'
check "the code no heading declares is NAMED (MV), not reported as a number" '[ "$(gq ".codes_without_heading | join(\",\")")" = "MV" ]'
check "the moved-in task is reported as a code/heading mismatch (one, code MV under PX)" \
  '[ "$(gq ".code_heading_mismatches | length")" = "1" ] && [ "$(gq ".code_heading_mismatches[0].code")" = "MV" ]'
check "alpha reports no mismatch and no missing code except the orphan ZZ" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"project/alpha/workstream.md\")) | .codes_without_heading | join(\",\")" "$T/out.json")" = "ZZ" ]'

echo "== Gate markers: the whole block is read, and only the DATED form marks"
check "#G-QK (marker on its fourth line) is satisfied" '[ "$(gq ".open_gates[] | select(.text | contains(\"#G-QK:\")) | .satisfied_text")" = "true" ]'
check "#G-HW (bare mention of SATISFIED, no date) is NOT satisfied" '[ "$(gq ".open_gates[] | select(.text | contains(\"#G-HW\")) | .satisfied_text")" = "false" ]'
check "#G-QK2 (READY with a date) is satisfied" '[ "$(gq ".open_gates[] | select(.text | contains(\"#G-QK2\")) | .satisfied_text")" = "true" ]'

echo "== Hold lines read folded blocks and phase headings, and reject compounds and negations"
gamma_hold_matches=$(gq '[.hold_lines[].match] | join("|")')
check "the hold on #PX-2's third line is found (blocked on)" 'printf "%s" "$gamma_hold_matches" | grep -q "blocked on"'
check "that hold cites the THIRD line, the one holding the phrase, not the block's first line" \
  '[ "$(gq ".hold_lines[] | select(.context | contains(\"shared schema, citing\")) | .line")" = "$(grep -n "^line is blocked on feature/beta" "$T/.state/workstreams/project/gamma/workstream.md" | cut -d: -f1)" ]'
check "fixture: #PX-4 carries a struck-through hold and two bare verbs (planted noise)" \
  "grep -q '~~blocked on feature/beta' \"$T/.state/workstreams/project/gamma/workstream.md\" && grep -q 'checkpoints held, so conditions that hold' \"$T/.state/workstreams/project/gamma/workstream.md\""
check "a struck-through hold does not count, nor a bare held/hold (no hit on #PX-4's line)" \
  '[ "$(gq ".hold_lines[] | select(.line == $(grep -n "#PX-4:" "$T/.state/workstreams/project/gamma/workstream.md" | cut -d: -f1)) | .match" | wc -l | tr -d " ")" = "0" ]'
check "the hold on #DF-1's first line is found (waits for)" 'printf "%s" "$gamma_hold_matches" | grep -q "waits for"'
check "the hold stated on the DF phase heading is found, attributed to the heading's line" \
  '[ "$(gq ".hold_lines[] | select(.line == $(grep -n "^### Deferred" "$T/.state/workstreams/project/gamma/workstream.md" | cut -d: -f1)) | .match")" = "blocked on" ]'
check "Held-out (hyphenated compound) is NOT a hold" '! printf "%s" "$gamma_hold_matches" | grep -qi "held"'
check "the negated critical-path clause (Nothing ... is held by) is NOT a hold" \
  '[ "$(gq ".hold_lines | map(select(.context | contains(\"Nothing in this file\"))) | length")" = "0" ]'
check "gamma's hold count is exactly 3" '[ "$(gq ".hold_lines | length")" = "3" ]'

echo "== Cross references: wrapped continuation, repository names, dotted names, heading-form critical path"
gamma_targets=$(gq '[.cross_refs[].target] | join("|")')
check "feature/beta on #PX-2's third line is found with preceding id #PX-2" \
  '[ "$(gq ".cross_refs[] | select(.target == \"feature/beta\") | .preceding_id")" = "#PX-2" ]'
check "a struck-through reference (#PX-4's ~~feature/beta~~) is not an edge" \
  '[ "$(gq ".cross_refs[] | select(.preceding_id == \"#PX-4\") | .target" | wc -l | tr -d " ")" = "0" ]'
check "ml-explore/mlx does NOT manufacture explore/mlx" '! printf "%s" "$gamma_targets" | grep -q "explore/mlx"'
check "project/omlx-0.4.x-finalize is captured whole" 'printf "%s" "$gamma_targets" | grep -q "project/omlx-0.4.x-finalize|\|project/omlx-0.4.x-finalize$"'
check "critical path under a ### heading is found and joined" \
  '[ "$(gq ".critical_path")" = "Nothing in this file is held by another workstream; the order runs PX-1, then PX-2, then the split, referencing ws/old-two for history." ]'
check "ws/old-two from the heading-form critical path is found (the cascade is closed)" 'printf "%s" "$gamma_targets" | grep -q "ws/old-two"'

echo "== Learnings: block-scoped markers, terminal split from deferred"
check "fixture: a list item beginning '- L9' sits under ## Decisions (planted)" \
  "grep -q '^- L9 is not a Learning' \"$T/.state/workstreams/project/gamma/workstream.md\""
check "learnings.count is 9 (the '- L9' item under Decisions is not counted)" '[ "$(gq ".learnings.count")" = "9" ]'
check "latest_decision stays D1 x1 (the '### D7' heading outside Decisions is not counted)" \
  '[ "$(gq ".latest_decision.max")" = "1" ] && [ "$(gq ".latest_decision.count")" = "1" ]'
check "EXTRACTED on L1's second line, SPENT on L4, the DISPOSITION-date-marker form on L5, the wrapped HANDED OFF on L6 and the struck L9 count as terminal (5)" '[ "$(gq ".learnings.terminal")" = "5" ]'
check "QUEUED (L2) is deferred, not undispositioned" '[ "$(gq ".learnings.deferred | length")" = "1" ] && gq ".learnings.deferred[0]" | grep -q "^- L2"'
check "L3 (no marker), L7 (a mention of HANDED OFF mid-sentence, lifted from the corpus) and L8 (marker with no date in its sentence) are undispositioned" \
  '[ "$(gq ".learnings.undispositioned | length")" = "3" ] && gq ".learnings.undispositioned[0]" | grep -q "^- L3" && gq ".learnings.undispositioned[1]" | grep -q "^- L7" && gq ".learnings.undispositioned[2]" | grep -q "^- L8"'
check "fixture: L7 literally carries the two-word marker mid-sentence (the mention is planted)" \
  "grep -q 'multi-word \`HANDED OFF\`' \"$T/.state/workstreams/project/gamma/workstream.md\""
# Vary one input that must change the verdict: give L8's sentence its date.
mkdir -p "$T/dated/.state/workstreams/project/d"
printf -- '## Learnings\n- L1 (2026-01-01): An insight. APPLIED to docs/design.md, undated.\n- L2 (2026-01-01): An insight. APPLIED 2026-01-02 to docs/design.md.\n' > "$T/dated/.state/workstreams/project/d/workstream.md"
check "the same marker scores undispositioned without a date in its sentence and terminal with one (1 and 1)" \
  '[ "$(python3 "$SCRIPT" "$T/dated" | jq -r ".workstreams[0].learnings | \"\\(.terminal) \\(.undispositioned | length)\"")" = "1 1" ]'

echo "== Holds written as imperative or temporal prose are found"
mkdir -p "$T/holds/.state/workstreams/maintain/h"
printf -- '## Backlog\n### Work (BD)\n- [ ] #BD-1: the upgrade. Do not start before #BD-2 closes.\n- [ ] #BD-2: the pin. Do not upgrade npm until OQ-3 resolves.\n- [ ] #BD-3: the post, which stays deprioritized until P3 ships.\n- [ ] #BD-4: the probe. Orphans exist only after the text is set, so measure then.\n' > "$T/holds/.state/workstreams/maintain/h/workstream.md"
hq() { python3 "$SCRIPT" "$T/holds" | jq -r ".workstreams[0].hold_lines | $1"; }
check "three holds found, on lines 3, 4 and 5; the non-hold 'only after the text is set' on line 6 is not" \
  '[ "$(hq "[.[].line] | join(\",\")")" = "3,4,5" ]'

echo "== Entries outside their own section are reported"
# Must flag: a Learning under ## Open Questions, an Open Question under
# ## Learnings, a Decision heading under ## Backlog. Must pass: each in
# its own section, a list item in a Decision that mentions L4, and an
# entry quoted inside a fence.
mkdir -p "$T/place/.state/workstreams/maintain/p" "$T/placeok/.state/workstreams/maintain/p"
printf -- '## Backlog\n### Work (BD)\n- [ ] #BD-1: a task\n### D9 (2026-01-01): a Decision filed in the Backlog\n\n## Decisions\n### D1 (2026-01-01): first\n- L4'"'"'s bug becomes load-bearing here, a mention\n\n## Learnings\n- L1 (2026-01-01): placed right. APPLIED 2026-01-02 to docs/x.md.\n- OQ-7 (2026-01-01): an Open Question filed under Learnings?\n\n## Open Questions\n- OQ-1: placed right?\n- L2 (2026-01-01): an undispositioned Learning filed under Open Questions.\n' > "$T/place/.state/workstreams/maintain/p/workstream.md"
printf -- '## Backlog\n### Work (BD)\n- [ ] #BD-1: a task\n\n## Decisions\n### D1 (2026-01-01): first\n- L4'"'"'s bug becomes load-bearing here, a mention\n\n## Learnings\n- L1 (2026-01-01): placed right. APPLIED 2026-01-02 to docs/x.md.\n\n```\n- L2 (2026-01-01): an entry quoted in a fence\n```\n\n## Open Questions\n- ~~OQ-1~~: resolved in place\n' > "$T/placeok/.state/workstreams/maintain/p/workstream.md"
pq() { python3 "$SCRIPT" "$1" | jq -r ".workstreams[0].misplaced_entries | map(\"\\(.id)@\\(.section)\") | join(\",\")"; }
check "the three misfiled entries are reported with the section each sits in" \
  '[ "$(pq "$T/place")" = "D9@## Backlog,OQ-7@## Learnings,L2@## Open Questions" ]'
check "the placed file reports none: a mention of L4 in a Decision and an entry quoted in a fence are not entries" '[ "$(pq "$T/placeok")" = "" ]'
check "fires names the symptom with each line" \
  'python3 "$SCRIPT" fires "$T/place" | grep -q "entry outside its section line 4 (D9 under ## Backlog), line 12 (OQ-7 under ## Learnings), line 16 (L2 under ## Open Questions)"'
check "the misfiled L2 is exempt from the Learnings count, which is why the placement check exists (count 1)" \
  '[ "$(python3 "$SCRIPT" "$T/place" | jq -r ".workstreams[0].learnings.count")" = "1" ]'

echo "== A terminal disposition's referent: the cheap cases are flagged, the score unchanged"
mkdir -p "$T/target/.state/workstreams/maintain/t"
printf -- '## Backlog\n### Work (BD)\n- [ ] #BD-1: an open task\n- [x] #BD-2: a done task\n\n## Learnings\n- L1 (2026-01-01): to the repo. APPLIED 2026-01-02 to docs/x.md.\n- L2 (2026-01-01): to a state file. APPLIED 2026-01-02 to .state/notes.md, beside the record.\n- L3 (2026-01-01): to an open task here. ROUTED 2026-01-02 to #BD-1.\n- L4 (2026-01-01): to a done task here. ROUTED 2026-01-02 to #BD-2.\n- L5 (2026-01-01): nowhere. APPLIED 2026-01-02.\n- L6 (2026-01-01): handed off. HANDED OFF 2026-01-02 as .state/handoffs/from-x-20260102-000000.md in docs-site.\n- L7 (2026-01-01): to an open task in another workstream. ROUTED 2026-01-02 to #BD-1 in feature/other.\n- L8 (2026-01-01): named in words. Integration target: the patch README. APPLIED 2026-01-02.\n' > "$T/target/.state/workstreams/maintain/t/workstream.md"
tf() { python3 "$SCRIPT" "$T/target" | jq -r ".workstreams[0].learnings | $1"; }
check "the score is unchanged: all eight are terminal" '[ "$(tf ".terminal")" = "8" ]'
check "flagged: L2 state_path, L3 open_task_here, L5 no_target, and nothing else" \
  '[ "$(tf "[.target_flags[] | \"\\(.id):\\(.kind)\"] | join(\",\")")" = "L2:state_path,L3:open_task_here,L5:no_target" ]'
check "the flag names what it found: the .state/ path and the open task" \
  '[ "$(tf ".target_flags[0].detail")" = ".state/notes.md" ] && [ "$(tf ".target_flags[1].detail")" = "#BD-1" ]'

echo "== Learnings: the last marker decides"
mkdir -p "$T/last/.state/workstreams/maintain/q"
printf -- '---\nname: q\ntype: maintain\nstatus: active\ncreated: 2026-01-01\n---\n## Purpose\nA fixture.\n\n## Backlog\n### Work (BD)\n- [ ] #BD-1: a task\n- [ ] #BD-2: another\n\n## Learnings\n- L1 (2026-01-01): The first statement of the insight. A middle sentence the condenser would drop. APPLIED 2026-01-02 to #BD-1 and #BD-2. QUEUED 2026-01-03 on #BD-2, since the second half reopened when its build found a gap.\n- L2 (2026-01-01): The second insight. A middle sentence the condenser would drop. APPLIED 2026-01-02 to docs/x.md. EXTENDED 2026-01-03: a further case, still owed to a file.\n- L3 (2026-01-01): The control insight. A middle sentence the condenser would drop. APPLIED 2026-01-02 to docs/x.md.\n' > "$T/last/.state/workstream-tmp.md"
mv "$T/last/.state/workstream-tmp.md" "$T/last/.state/workstreams/maintain/q/workstream.md"
lq() { python3 "$SCRIPT" "$T/last" | jq -r ".workstreams[0].learnings | $1"; }
check "terminal then QUEUED scores deferred, terminal then EXTENDED undispositioned, the control terminal (1 1 1)" \
  '[ "$(lq "\"\\(.terminal) \\(.deferred | length) \\(.undispositioned | length)\"")" = "1 1 1" ] && lq ".deferred[0]" | grep -q "^- L1 " && lq ".undispositioned[0]" | grep -q "^- L2 "'
check "fires names the reopened L2 as undispositioned" \
  'python3 "$SCRIPT" fires "$T/last" | grep -q "undispositioned Learnings 1"'

echo "== Deletion Criteria are read as blocks: a wrapped STANDING criterion still scores"
mkdir -p "$T/wrapped/.state/workstreams/maintain/w"
printf -- '## Deletion Criteria\n- [ ] STANDING: the inbox stays empty and the roster\n  reads clean -- HOLDS 2026-01-01, HOLDS 2026-02-02\n- [ ] the split lands, wrapped\nacross a line\n- [x] done criterion\n' > "$T/wrapped/.state/workstreams/maintain/w/workstream.md"
wq() { python3 "$SCRIPT" "$T/wrapped" | jq -r ".workstreams[0].deletion_criteria | $1"; }
check "fixture: the STANDING marker is on the first line and every HOLDS on the continuation" \
  "grep -q '^- \\[ \\] STANDING' \"$T/wrapped/.state/workstreams/maintain/w/workstream.md\" && ! grep -q '^- .*HOLDS' \"$T/wrapped/.state/workstreams/maintain/w/workstream.md\""
check "standing is 1, open is 1, done is 1 (the wrapped criteria score as their blocks)" '[ "$(wq "\"\\(.standing) \\(.open) \\(.done)\"")" = "1 1 1" ]'
check "standing_oldest_holds reads the NEWEST date of the wrapped block (2026-02-02) and never_rechecked is 0" '[ "$(wq "\"\\(.standing_oldest_holds) \\(.standing_never_rechecked)\"")" = "2026-02-02 0" ]'
check "wrapped reports the two continuation lines under criteria" '[ "$(wq ".wrapped")" = "2" ]'
check "alpha's one-line criteria report wrapped 0" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"project/alpha/workstream.md\")) | .deletion_criteria.wrapped" "$T/out.json")" = "0" ]'

echo "== Purpose done: a qualified done sentence, and the critical path is not the Purpose's prose"
mkdir -p "$T/purp/.state/workstreams/feature/p" "$T/purp2/.state/workstreams/feature/p"
printf -- '## Purpose\nBuilds the thing. Done for the first release means the thing ships. Later releases are reviewed at the gate.\n\n**Critical path.** #DR-1 then #G-DR (the gate).\n' > "$T/purp/.state/workstreams/feature/p/workstream.md"
printf -- '## Purpose\nBuilds the thing. It closes when the gate passes.\n\n**Critical path.** #DR-1 then #G-DR (the gate).\n' > "$T/purp2/.state/workstreams/feature/p/workstream.md"
check "fixture: the last sentence of each Purpose section is the critical path's" \
  'tail -1 "$T/purp/.state/workstreams/feature/p/workstream.md" | grep -q "^\*\*Critical path" && tail -1 "$T/purp2/.state/workstreams/feature/p/workstream.md" | grep -q "^\*\*Critical path"'
check "a qualified done sentence (Done for the first release means) is the done field" \
  '[ "$(python3 "$SCRIPT" "$T/purp" | jq -r ".workstreams[0].purpose.done")" = "Done for the first release means the thing ships." ]'
check "with no done sentence, done is the last sentence BEFORE the critical path" \
  '[ "$(python3 "$SCRIPT" "$T/purp2" | jq -r ".workstreams[0].purpose.done")" = "It closes when the gate passes." ]'
check "first is still the Purpose's first sentence" \
  '[ "$(python3 "$SCRIPT" "$T/purp2" | jq -r ".workstreams[0].purpose.first")" = "Builds the thing." ]'

echo "== An uncoded ### heading ends the coded phase above it"
mkdir -p "$T/uncoded/.state/workstreams/feature/u"
printf -- '## Backlog\n### Draft (DR)\n- [ ] #DR-1: a task\n### Gates\n- [ ] #G-QK: USER CHECKPOINT -- a gate no heading declares\n- [ ] #G-DR: USER CHECKPOINT -- a gate its code declares elsewhere\n- [x] #DR-2: a done task under the uncoded heading\n### Next (PX)\n- [ ] #PX-1: a task after it\n' > "$T/uncoded/.state/workstreams/feature/u/workstream.md"
uq() { python3 "$SCRIPT" "$T/uncoded" | jq -r ".workstreams[0] | $1"; }
check "fixture: #G-QK sits under the uncoded Gates heading, after the DR heading" \
  'awk "/^### Draft/{c=1} /^### Gates/{g=c} /^- \\[ \\] #G-QK/{print g}" "$T/uncoded/.state/workstreams/feature/u/workstream.md" | grep -q 1'
check "no code/heading mismatch: neither gate is attributed to Draft" '[ "$(uq ".code_heading_mismatches | length")" = "0" ]'
check "Gates is its own phase row, code null, with both gates and the done task" \
  '[ "$(uq ".phases[1] | \"\\(.name) \\(.code) \\(.open_gates) \\(.done_tasks)\"")" = "Gates null 2 1" ]'
check "Draft keeps only its own task" '[ "$(uq ".phases[0] | \"\\(.open_tasks) \\(.open_gates) \\(.done_tasks)\"")" = "1 0 0" ]'
check "the code no heading declares is still named (QK), the declared DR is not" '[ "$(uq ".codes_without_heading | join(\",\")")" = "QK" ]'
check "a coded heading after it attributes again (#PX-1 under Next), and nothing is outside" \
  '[ "$(uq ".phases[2] | \"\\(.code) \\(.open_tasks)\"")" = "PX 1" ] && [ "$(uq .tasks_outside_phases)" = "0" ]'
check "control: a task under the WRONG coded heading is still a mismatch" \
  'mkdir -p "$T/uncoded2/.state/workstreams/feature/u" && printf -- "## Backlog\n### Draft (DR)\n- [ ] #MV-1: moved in\n" > "$T/uncoded2/.state/workstreams/feature/u/workstream.md" && [ "$(python3 "$SCRIPT" "$T/uncoded2" | jq -r ".workstreams[0].code_heading_mismatches[0].code")" = "MV" ]'
printf -- '## Backlog\n### Done work\n- [x] #DN-1: finished\n' > "$T/uncoded/.state/workstreams/feature/u/workstream.md"
check "fires names an uncoded completed phase by its name alone" \
  'python3 "$SCRIPT" fires "$T/uncoded" | grep -q "completed phase Done work$"'

echo "== An HTML comment under a criterion is guidance, not the criterion"
mkdir -p "$T/tmpl/.state/workstreams/feature/t"
TEMPLATE="$KIT_DIR/.claude/skills/workstream-create/templates/workstream.md"
cp "$TEMPLATE" "$T/tmpl/.state/workstreams/feature/t/workstream.md"
tq() { python3 "$SCRIPT" "$T/tmpl" | jq -r ".workstreams[0].deletion_criteria | $1"; }
check "fixture: the create template carries a STANDING example in a comment directly under its criterion" \
  'grep -A1 "^- \[ \] <verifiable condition>" "$TEMPLATE" | grep -q "^<!--.*STANDING:"'
check "the template reads one open criterion and no STANDING one" '[ "$(tq "\"\\(.open) \\(.standing) \\(.standing_never_rechecked)\"")" = "1 0 0" ]'
check "the comment line is not counted as a wrapped criterion" '[ "$(tq .wrapped)" = "0" ]'
check "fires names no STANDING symptom on the template" '! python3 "$SCRIPT" fires "$T/tmpl" | grep -q STANDING'
mkdir -p "$T/tmpl2/.state/workstreams/feature/t"
printf -- '## Deletion Criteria\n- [ ] STANDING: the inbox stays empty -- HOLDS 2026-02-02\n<!-- an aside -->\n- [ ] a real one\n<!-- a longer aside\nover two lines -->\n' > "$T/tmpl2/.state/workstreams/feature/t/workstream.md"
check "control: a real STANDING criterion followed by a comment still scores, and a two-line comment is dropped whole" \
  '[ "$(python3 "$SCRIPT" "$T/tmpl2" | jq -r ".workstreams[0].deletion_criteria | \"\\(.standing) \\(.standing_oldest_holds) \\(.open) \\(.wrapped)\"")" = "1 2026-02-02 1 0" ]'

echo "== STANDING stamps: the newest date wins in either order, and a breach is a re-check"
# One criterion per shape, each in its own workstream so each field reads
# one criterion. Re-measured by writing the markers into criteria and
# reading the deletion_criteria block, not by firing the regex.
for c in newest:'HOLDS 2026-03-03, HOLDS 2026-01-01' oldest:'HOLDS 2026-01-01, HOLDS 2026-03-03' \
         fails:'FAILS 2026-03-03, HOLDS 2026-01-01' notheld:'HOLDS 2026-01-01. DOES NOT HOLD 2026-03-03' \
         nolonger:'NO LONGER HOLDS 2026-03-03' recovered:'HOLDS 2026-03-03, FAILS 2026-01-01' \
         sameday:'FAILS 2026-03-03, HOLDS 2026-03-03'; do
  n=${c%%:*}; stamps=${c#*:}
  mkdir -p "$T/stamps/.state/workstreams/maintain/s-$n"
  printf -- '## Deletion Criteria\n- [ ] STANDING: the inbox stays empty -- %s\n' "$stamps" > "$T/stamps/.state/workstreams/maintain/s-$n/workstream.md"
done
python3 "$SCRIPT" "$T/stamps" > "$T/stamps.json"
sq() { jq -r ".workstreams[] | select(.path | endswith(\"maintain/s-$1/workstream.md\")) | .deletion_criteria | \"\\(.standing_oldest_holds) \\(.standing_never_rechecked) \\(.standing_breached)\"" "$T/stamps.json"; }
check "fixture: seven STANDING criteria, one per workstream" '[ "$(jq -r ".workstreams | length" "$T/stamps.json")" = "7" ]'
check "stamped newest first: the newer date (2026-03-03), not breached" '[ "$(sq newest)" = "2026-03-03 0 0" ]'
check "stamped oldest first: the same answer" '[ "$(sq oldest)" = "2026-03-03 0 0" ]'
check "FAILS newest: re-checked 2026-03-03 and breached" '[ "$(sq fails)" = "2026-03-03 0 1" ]'
check "DOES NOT HOLD newest: re-checked and breached, not never re-checked" '[ "$(sq notheld)" = "2026-03-03 0 1" ]'
check "NO LONGER HOLDS alone: breached, never read as a clean HOLDS" '[ "$(sq nolonger)" = "2026-03-03 0 1" ]'
check "a HOLDS newer than the breach: recovered, not breached" '[ "$(sq recovered)" = "2026-03-03 0 0" ]'
check "a breach and a hold on the same day read as breached" '[ "$(sq sameday)" = "2026-03-03 0 1" ]'
check "standing_breaches names the breach date" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"maintain/s-fails/workstream.md\")) | .deletion_criteria.standing_breaches[0].date" "$T/stamps.json")" = "2026-03-03" ]'

echo "== Conformance detector: continuation lines under open items, column 0 and indented alike"
check "gamma reports wrapped open items (2 continuations under #PX-2, 3 under #G-QK, 1 each under #G-HW and #DF-1)" '[ "$(gq ".wrapped_lines.open_items")" = "7" ]'
check "alpha reports zero wrapped open items (its backlog lines are one line each)" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"project/alpha/workstream.md\")) | .wrapped_lines.open_items" "$T/out.json")" = "0" ]'
# Vary one input that must change the count: an indented continuation.
mkdir -p "$T/varied/.state/workstreams/project/v"
printf -- '## Backlog\n- [ ] #V-1: a task\n    with an indented continuation\n' > "$T/varied/.state/workstreams/project/v/workstream.md"
check "an indented continuation is counted too (varied fixture reports 1)" \
  '[ "$(python3 "$SCRIPT" "$T/varied" | jq -r ".workstreams[0].wrapped_lines.open_items")" = "1" ]'

echo "== Coverage: files per field, so a zero reads as calibration rather than data"
check "coverage.files is 3" '[ "$(jq -r ".coverage.files" "$T/out.json")" = "3" ]'
check "coverage.hold_lines is 2 (alpha and gamma; beta has none)" '[ "$(jq -r ".coverage.hold_lines" "$T/out.json")" = "2" ]'
check "coverage.gates_satisfied is 2 (alpha and gamma)" '[ "$(jq -r ".coverage.gates_satisfied" "$T/out.json")" = "2" ]'
check "coverage.critical_path is 2 (beta has none)" '[ "$(jq -r ".coverage.critical_path" "$T/out.json")" = "2" ]'

echo "== Composition: bytes per section and per checkbox block, summing to the file"
A='.workstreams[] | select(.path | endswith("project/alpha/workstream.md"))'
aq() { jq -r "$A | $1" "$T/out.json"; }
check "alpha's section bytes sum to its size_bytes" \
  '[ "$(aq "[.composition.sections[].bytes] | add")" = "$(aq ".size_bytes")" ]'
check "alpha's largest section is the Backlog" '[ "$(aq ".composition.sections[0].heading")" = "## Backlog" ]'
# The open side: every open checkbox line in alpha is one line (no continuation), so its
# byte count is the sum of those lines plus a newline each; done is the one ticked criterion
# plus its newline. Both derived here by a DIFFERENT method than the script's state machine.
alpha_file="$T/.state/workstreams/project/alpha/workstream.md"
exp_open=$(grep -E '^ *- \[ \]' "$alpha_file" | awk '{n += length($0) + 1} END {print n}')
exp_done=$(grep -E '^ *- \[x\]' "$alpha_file" | awk '{n += length($0) + 1} END {print n}')
check "alpha's open checkbox bytes match an independent grep-and-length count" '[ "$(aq ".composition.checkbox_bytes.open")" = "$exp_open" ]'
check "alpha's done checkbox bytes match an independent count" '[ "$(aq ".composition.checkbox_bytes.done")" = "$exp_done" ]'
# Vary one input: a completion-note continuation under a done line must score as done.
mkdir -p "$T/comp/.state/workstreams/project/c"
printf -- '## Backlog\n- [x] #C-1: done task\n  DONE 2026-01-01, commit abc1234\n- [ ] #C-2: open task\n\n## Learnings\n' > "$T/comp/.state/workstreams/project/c/workstream.md"
check "a completion note under a done line counts as done bytes (22+34), the open line as open (22)" \
  '[ "$(python3 "$SCRIPT" "$T/comp" | jq -r ".workstreams[0].composition.checkbox_bytes | \"\\(.done) \\(.open)\"")" = "56 22" ]'

echo "== Digit-bearing phase codes parse; an ID-shaped token still unparsable is reported, not dropped"
# A heading `(W3)` the heading parser accepts, with tasks `#W3-1` and the
# gate `#G-W3a`: on 0.11.1 the task parsers refused them, so record named
# a code `W` with no heading, reported false mismatches, and decay counted
# fewer open tasks than the hook. `#G-QK2` keeps its old reading (phase QK,
# second gate), and `#P8-V` has no task number, so it cannot parse at all
# and must be NAMED. `#QX-3` is the must-parse control; a plain checkbox
# with no ID is the must-not-report control.
mkdir -p "$T/digits/.state/workstreams/project/d"
DW="$T/digits/.state/workstreams/project/d/workstream.md"
cat > "$DW" <<'FIX'
---
name: d
type: project
status: active
---
## Backlog
### Fleet upgrade (W3)
- [ ] #W3-1: first task
- [ ] #W3-6: sixth task
- [ ] #G-W3a: USER CHECKPOINT -- the W3 gate
### Pass (QX)
- [ ] #QX-3: the control task
### Split (QK)
- [ ] #G-QK2: second QK gate
### Eight (P8)
- [ ] #P8-V: a verification task with no number
- [ ] a plain checkbox with no ID

## Deletion Criteria
- [ ] Every task above is done
FIX
dq() { python3 "$SCRIPT" "$T/digits" | jq -r ".workstreams[0]$1"; }
hook_open=$(grep -cE '^ *- \[ \] #' "$DW")
check "the fixture's hook-form count is 6 (five tasks and gates plus #P8-V)" '[ "$hook_open" = "6" ]'
check "digits: no code is reported without a heading (W3 and QK are declared)" '[ "$(dq ".codes_without_heading | length")" = "0" ]'
check "digits: no code/heading mismatch for #W3-1, #W3-6, #G-W3a or #G-QK2" '[ "$(dq ".code_heading_mismatches | length")" = "0" ]'
check "digits: open_total equals the hook-form count" '[ "$(dq ".open_total")" = "$hook_open" ]'
check "digits: the per-heading sum equals open_total" '[ "$(dq " | [.phases[] | .open_tasks + .open_gates] | add")" = "$hook_open" ]'
check "digits: the W3 heading holds two tasks and one gate" \
  '[ "$(dq ".phases[] | select(.code == \"W3\") | \"\(.open_tasks) \(.open_gates)\"")" = "2 1" ]'
check "digits: #P8-V is reported as unparsable, with its line" \
  '[ "$(dq ".unparsable_ids | map(.token) | join(\",\")")" = "#P8-V" ] && [ "$(dq ".unparsable_ids[0].line")" = "$(grep -n "#P8-V" "$DW" | cut -d: -f1)" ]'
check "digits: #QX-3 and the plain checkbox are not reported as unparsable" \
  '! dq ".unparsable_ids[].token" | grep -qE "QX-3|plain"'
check "digits: fires names the unparsable ID" \
  'python3 "$SCRIPT" fires "$T/digits" | grep -q "unparsable task ID.*#P8-V"'
check "digits: decay counts every open task line (W3-1, W3-6, QX-3, P8-V) and names the unparsable one" \
  '[ "$(python3 "$SCRIPT" decay "$T/digits" | jq -r ".workstreams[0] | \"\(.open_tasks) \(.unparsable_ids | map(.token) | join(\",\"))\"")" = "4 #P8-V" ]'
check "digits: bare-ids flags an unglossed #W3-1 mention" \
  'mkdir -p "$T/digits-b/.state/workstreams/project/b" && printf -- "---\nname: b\n---\n## Purpose\nRoutes to #W3-1 next.\n\n## Backlog\n" > "$T/digits-b/.state/workstreams/project/b/workstream.md" && python3 "$SCRIPT" bare-ids "$T/digits-b" | grep -q "#W3-1"'

echo "== record's open_total skips a criterion that opens with a task ID, as the hook does"
printf -- '- [ ] #W3-1 in project/d (the first task) is checked off\n' >> "$DW"
check "the criterion is planted under Deletion Criteria" '[ "$(tail -1 "$DW" | cut -c1-12)" = "- [ ] #W3-1 " ]'
check "open_total stays 6 with the criterion added" '[ "$(dq ".open_total")" = "6" ]'
check "and still equals the per-heading sum" '[ "$(dq " | [.phases[] | .open_tasks + .open_gates] | add")" = "6" ]'

echo "== A Learning is scored WHOLE: a marker in an indented follow-on paragraph counts"
# fold_blocks ends a block at a blank line; on 0.11.5 an entry whose only
# terminal marker sat in a follow-on paragraph was scored undispositioned
# and fires reported it. The open entry beside it must stay open, so a
# follow-on paragraph that carries no marker disposes of nothing.
mkdir -p "$T/tail/.state/workstreams/maintain/t"
TL="$T/tail/.state/workstreams/maintain/t/workstream.md"
cat > "$TL" <<'EOF'
---
name: t
type: maintain
status: active
---
## Purpose
A fixture.

## Backlog
### Build (TB)
- [ ] #TB-1: an open task

## Learnings
- L1 (2026-01-01): The first insight. APPLIED 2026-01-02 to docs/x.md.
- L2 (2026-01-01): The second insight. A middle sentence.

  APPLIED 2026-01-02 to docs/y.md.
- L3 (2026-01-01): The third insight, still open.

  A follow-on paragraph naming no marker.

## Deletion Criteria
- [ ] A condition.
EOF
check "the fixture holds L2's marker on an indented line after a blank one" \
  'grep -B1 "^  APPLIED 2026-01-02 to docs/y.md" "$TL" | head -1 | grep -q "^$"'
check "record scores L1 and L2 terminal and L3 alone undispositioned" \
  '[ "$(python3 "$SCRIPT" record "$T/tail" | jq -c ".workstreams[0].learnings | [.count, .terminal, (.undispositioned | map(.[0:6]))]")" = "[3,2,[\"- L3 (\"]]" ]'
check "fires counts one undispositioned Learning, not two" \
  'python3 "$SCRIPT" fires "$T/tail" | grep -q "undispositioned Learnings.*1" && ! python3 "$SCRIPT" fires "$T/tail" | grep -q "undispositioned Learnings.*2"'

echo "== Missing .state exits 2 (not merely non-zero)"
mkdir -p "$T/nostate-root"
check "the nostate fixture genuinely has no .state directory" '[ ! -d "$T/nostate-root/.state" ]'
rc=0
python3 "$SCRIPT" "$T/nostate-root" >"$T/nostate-out.txt" 2>"$T/nostate-err.txt" || rc=$?
check "exit code is exactly 2 on a project root with no .state" '[ "$rc" -eq 2 ]'
check "stderr names the missing .state directory (the specific failure)" \
  "grep -q '\\.state' \"$T/nostate-err.txt\""
check "stdout is empty on the failure path" '[ ! -s "$T/nostate-out.txt" ]'

echo
if [ "$RESULT" -eq 0 ]; then
  echo "RECORD ACCEPTANCE: ALL CHECKS PASS"
else
  echo "RECORD ACCEPTANCE: FAILURES ABOVE"
fi
exit "$RESULT"
