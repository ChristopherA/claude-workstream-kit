#!/bin/sh
# End-to-end acceptance test for the workstream kit: three `claude -p` sessions
# create, work, and close a demo workstream in a throwaway project.
# Run from anywhere: <kit-checkout>/tests/va3-acceptance.sh
#
# It runs on a fully configured account as well as a clean one -- user-level
# rules simply load into the three sessions -- and it takes between ten and
# twenty-five minutes as measured across runs, so start it in the background
# as soon as the tree it should test is committed, rather than at the push
# gate where it becomes the thing everything waits on. The install step copies
# the kit at start, so a run tests what the tree held when it began. It is the
# only end-to-end coverage of the closure path.
#
# The suite is also an intake channel for guidance defects: the unattended
# work session hits them, and the closure session records them as the
# fixture's own Learnings and applies them to its installed skill copies. Read
# Session C's output and the fixture's Learnings (in its git log, since the
# closure archives the workstream file) before deleting the fixture -- both
# findings from the first two runs were visible only there, while the summary
# said ALL CHECKS PASS.
#
# Prerequisites (one-time, interactive):
#   1. Claude Code installed:  curl -fsSL https://claude.ai/install.sh | bash
#   2. Logged in:              claude  (then /login in the UI, once)
#   3. Git identity:           git config --global user.name  <name> ;
#                              git config --global user.email <email>
# On a clean account, ~/.claude holds nothing beyond what /login creates.
#
# Outcomes: exit 0 with ALL CHECKS PASS; exit 1 with FAILURES; exit 2 with
# HELD AT A GATE, which means the closure session stopped at a gate it was
# right to hold, so the archive checks were not exercised and the run is not
# evidence either way. A HELD run is a scenario problem, never a kit regression.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJ="$HOME/va3-proj"
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

# A closure session that stops at a gate it is right to hold -- a shared-visible
# send chosen during extraction, say -- leaves the workstream directory in place
# and names the gate in ACTIVE.md's Blockers. That is conforming behaviour, and a
# plain check cannot tell it from a broken skill: the archive assertions fail
# either way. Detect the hold from STATE, never from the session's prose, and
# report those checks as HELD with their own exit code instead of as failures.
HELD=0
closure_held() {
  [ -d .state/workstreams/project/greeting-script ] &&
  awk '/^## Blockers/{f=1;next} /^## /{f=0} f&&NF' .state/ACTIVE.md | grep -qv '^None$'
}
check_or_held() {
  if closure_held; then echo "HELD: $1 -- closure stopped at a gate named in ACTIVE.md Blockers"; HELD=1
  else check "$1" "$2"; fi
}

echo "== Setup: fresh project at $PROJ"
rm -rf "$PROJ"
mkdir -p "$PROJ" && cd "$PROJ"
git init -q -b main && git commit -q --allow-empty -m init
"$KIT_DIR/install.sh" "$PROJ"
git add -A && git commit -q -m 'install workstream kit'

echo "== Session A: create"
claude -p --dangerously-skip-permissions 'I want a workstream for this small deliverable. Follow .claude/skills/workstream-create/SKILL.md (read it and its templates first, plus .claude/rules/workstreams-rule.md). This is a non-interactive session, so take these as my interview answers and as my approval at the review gate: Purpose: produce a greeting script with a passing smoke test. Type: project, name: greeting-script. Deletion criteria: (1) scripts/hello.sh exists and prints "hello, workstream" with exit 0; (2) test/smoke.sh exists, runs hello.sh, and exits 0; (3) both committed. First tasks, phase Build (BD): #BD-1 write scripts/hello.sh; #BD-2 write test/smoke.sh and verify it passes; #G-BD USER CHECKPOINT -- deliverable works. Create the state files exactly per the templates and commit them (plain git commit, no signing flags).'

check "workstream.md created" "[ -f .state/workstreams/project/greeting-script/workstream.md ]"
check "work NOT auto-started" "[ ! -f scripts/hello.sh ]"

echo "== Session B: /goal-style work with delegation"
claude -p --dangerously-skip-permissions 'Work the active workstream. Follow .claude/skills/workstream-work/SKILL.md (read it, .claude/rules/workstreams-rule.md, .state/ACTIVE.md, and the active workstream.md first). Derive the goal condition for the Build phase and state it; this non-interactive session stands in for the /goal session, so proceed under that condition. Requirements: delegate the implementation of #BD-1 and #BD-2 to the worker agent as bounded packets, verify the result with the verifier agent before accepting, make only grounded progress claims (cite commits and command output), check off completed tasks with evidence notes, STOP AT #G-BD with a substantive summary (do not check the gate), update ACTIVE.md, and commit work and state files (plain git commit, no signing flags).'

check "smoke test passes" "sh test/smoke.sh >/dev/null 2>&1"
check "stopped AT gate (G-BD unchecked)" "grep -q '^- \[ \] #G-BD' .state/workstreams/project/greeting-script/workstream.md"
check "tasks have evidence notes" "grep -q '^- \[x\] #BD-2.*commit' .state/workstreams/project/greeting-script/workstream.md"

echo "== Session C: close and archive"
claude -p --dangerously-skip-permissions 'As the user I approve the #G-BD gate: the deliverable works. Check it off, then close the workstream following .claude/skills/workstream-close/SKILL.md (read it and .claude/rules/workstreams-rule.md first). This is a non-interactive session: present the Move 2 narrative summary and the Move 4 per-criterion evidence in your output, and take this message as my closure approval at the Move 4 gate PROVIDED every deletion criterion genuinely has evidence -- if any lacks evidence, stop and say so instead. Work the Completion tasks (#CL-1..#CL-3): run the Move 3 extraction per .claude/skills/workstream-extract/SKILL.md, dispositioning any Learnings/Open Questions (if none exist, state that) -- disposition each Learning by APPLYING it to a named file in this repository or DROPPING it with stated rationale, never by handoff, since this throwaway project has no sibling project to send to -- and confirming durable artifacts live outside .state/, then archive exactly per Move 5 (ARCHIVE.md line, annotated tag ws/greeting-script, remove the workstream directory, reset ACTIVE.md fully, commit -- plain git commit, no signing flags).'

check_or_held "archive tag exists" "git tag -l | grep -q '^ws/greeting-script$'"
check_or_held "ARCHIVE.md line appended" "grep -q 'greeting-script' .state/workstreams/ARCHIVE.md"
check_or_held "workstream dir removed" "[ ! -d .state/workstreams/project/greeting-script ]"
check_or_held "ACTIVE.md reset" "grep -q '^workstream: none' .state/ACTIVE.md"
check "working tree clean" "[ -z \"\$(git status --porcelain)\" ]"
check "deliverable survives" "sh test/smoke.sh >/dev/null 2>&1"

echo
if [ "$RESULT" -eq 0 ] && [ "$HELD" -eq 0 ]; then
  echo "VA-3 ACCEPTANCE: ALL CHECKS PASS"
elif [ "$RESULT" -eq 0 ]; then
  echo "VA-3 ACCEPTANCE: HELD AT A GATE -- no check failed, but the archive path was not exercised; not evidence either way. Inspect $PROJ"
  exit 2
else
  echo "VA-3 ACCEPTANCE: FAILURES ABOVE -- inspect $PROJ"
fi
exit "$RESULT"
