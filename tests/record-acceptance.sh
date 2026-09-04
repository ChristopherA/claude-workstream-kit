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
- L1 (2026-01-01): Insight one APPLIED to somewhere.
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
# under a PX heading; a multi-code heading (SK / HW); a phase heading that
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

### Split (SK / HW)
- [ ] #SK-1: a task under a multi-code heading
- [ ] #HW-1: another task under the same multi-code heading
- [ ] #G-SK: USER CHECKPOINT -- the split review, whose line wraps over
several lines because a gate accretes agenda, and the marker that
matters is not on the first line but here, the exit criterion is
SATISFIED 2026-03-03 with the evidence recorded beside it
- [ ] #G-HW: USER CHECKPOINT -- the build note reads "the wrap sentence
and the SATISFIED sentence quoted", which is a mention and not a marking
- [ ] #G-SK2: USER CHECKPOINT -- READY 2026-02-02, decided in the record

### Deferred (DF) -- blocked on the condensed evaluation
- [ ] #DF-1: waits for the upstream fix in ml-explore/mlx#3856 to land,
then finalize in project/omlx-0.4.x-finalize

## Decisions
### D1 (2026-01-01): Only decision
Some rationale, with a list under it:
- L9 is not a Learning: a list item inside a Decision that begins with L

## Learnings
- L1 (2026-01-01): An insight whose disposition marker sits on its second
line, EXTRACTED to docs/design.md.
- L2 (2026-01-01): An insight that is tracked work, QUEUED for #PX-2.
- L3 (2026-01-01): An insight with no disposition at all.
- L4 (2026-01-01): An insight that is SPENT -- routed to docs/design.md.

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
check "learnings.undispositioned has one entry (L1 carries APPLIED)" '[ "$alpha_learn_undisp" = "1" ]'

echo "== Deletion criteria"
alpha_del_open=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.open' "$T/out.json")
alpha_del_done=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.done' "$T/out.json")
check "deletion_criteria open is 2 (the two STANDING lines are not unmet)" '[ "$alpha_del_open" = "2" ]'
check "deletion_criteria done is 1" '[ "$alpha_del_done" = "1" ]'
alpha_del_standing=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.standing' "$T/out.json")
alpha_del_oldest=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.standing_oldest_holds' "$T/out.json")
alpha_del_never=$(jq -r '.workstreams[] | select(.path | endswith("project/alpha/workstream.md")) | .deletion_criteria.standing_never_rechecked' "$T/out.json")
check "deletion_criteria standing is 2" '[ "$alpha_del_standing" = "2" ]'
check "standing_oldest_holds reads each line's LAST date (2026-02-02, not 2026-01-01)" '[ "$alpha_del_oldest" = "2026-02-02" ]'
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
check "gamma: #G-SK's marker is on a continuation line, not the gate's first line" \
  "grep -q '^SATISFIED 2026-03-03' \"$T/.state/workstreams/project/gamma/workstream.md\" && ! grep -q '#G-SK:.*SATISFIED' \"$T/.state/workstreams/project/gamma/workstream.md\""
check "gamma: #G-HW carries the bare word SATISFIED with no date after it" \
  "grep -q 'the SATISFIED sentence quoted' \"$T/.state/workstreams/project/gamma/workstream.md\""
check "gamma: two headings carry the same code PX" \
  "[ \"\$(grep -c '(PX)' \"$T/.state/workstreams/project/gamma/workstream.md\")\" = 2 ]"

echo "== Phases are position-keyed: same-code headings, mismatches, named missing codes"
check "gamma has four phase rows (two PX rows, one SK / HW, one DF; none for MV)" '[ "$(gq ".phases | length")" = "4" ]'
check "each PX heading counts only the tasks under it (Pass 1: 2 open, Pass 2: 3 open)" \
  '[ "$(gq ".phases[0].open_tasks")" = "2" ] && [ "$(gq ".phases[1].open_tasks")" = "3" ]'
check "the multi-code heading (SK / HW) matches and counts 2 tasks and 3 gates" \
  '[ "$(gq ".phases[2].code")" = "SK / HW" ] && [ "$(gq ".phases[2].open_tasks")" = "2" ] && [ "$(gq ".phases[2].open_gates")" = "3" ]'
check "tasks_outside_phases is 0 (never negative: per-heading sum plus outside equals the total)" \
  '[ "$(gq ".tasks_outside_phases")" = "0" ] && [ "$(gq ".open_total")" = "$(gq "[.phases[] | .open_tasks + .open_gates] | add")" ]'
check "the code no heading declares is NAMED (MV), not reported as a number" '[ "$(gq ".codes_without_heading | join(\",\")")" = "MV" ]'
check "the moved-in task is reported as a code/heading mismatch (one, code MV under PX)" \
  '[ "$(gq ".code_heading_mismatches | length")" = "1" ] && [ "$(gq ".code_heading_mismatches[0].code")" = "MV" ]'
check "alpha reports no mismatch and no missing code except the orphan ZZ" \
  '[ "$(jq -r ".workstreams[] | select(.path | endswith(\"project/alpha/workstream.md\")) | .codes_without_heading | join(\",\")" "$T/out.json")" = "ZZ" ]'

echo "== Gate markers: the whole block is read, and only the DATED form marks"
check "#G-SK (marker on its fourth line) is satisfied" '[ "$(gq ".open_gates[] | select(.text | contains(\"#G-SK:\")) | .satisfied_text")" = "true" ]'
check "#G-HW (bare mention of SATISFIED, no date) is NOT satisfied" '[ "$(gq ".open_gates[] | select(.text | contains(\"#G-HW\")) | .satisfied_text")" = "false" ]'
check "#G-SK2 (READY with a date) is satisfied" '[ "$(gq ".open_gates[] | select(.text | contains(\"#G-SK2\")) | .satisfied_text")" = "true" ]'

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
check "learnings.count is 4 (the '- L9' item under Decisions is not counted)" '[ "$(gq ".learnings.count")" = "4" ]'
check "latest_decision stays D1 x1 (the '### D7' heading outside Decisions is not counted)" \
  '[ "$(gq ".latest_decision.max")" = "1" ] && [ "$(gq ".latest_decision.count")" = "1" ]'
check "EXTRACTED on L1's second line and SPENT on L4 count as terminal (2)" '[ "$(gq ".learnings.terminal")" = "2" ]'
check "QUEUED (L2) is deferred, not undispositioned" '[ "$(gq ".learnings.deferred | length")" = "1" ] && gq ".learnings.deferred[0]" | grep -q "^- L2"'
check "L3 alone is undispositioned" '[ "$(gq ".learnings.undispositioned | length")" = "1" ] && gq ".learnings.undispositioned[0]" | grep -q "^- L3"'

echo "== Conformance detector: continuation lines under open items, column 0 and indented alike"
check "gamma reports wrapped open items (2 continuations under #PX-2, 3 under #G-SK, 1 each under #G-HW and #DF-1)" '[ "$(gq ".wrapped_lines.open_items")" = "7" ]'
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
