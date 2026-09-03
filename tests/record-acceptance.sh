#!/bin/sh
# Offline acceptance test for workstream-record.py: the eleven-field record
# (workstream-status SKILL.md, Move 2), derived for every workstream.md
# under a fixture project plus ACTIVE.md's hold lines and cross refs.
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
check "deletion_criteria open is 2" '[ "$alpha_del_open" = "2" ]'
check "deletion_criteria done is 1" '[ "$alpha_del_done" = "1" ]'

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
