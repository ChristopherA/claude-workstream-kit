#!/bin/sh
# Clean-account acceptance test for the workstream kit.
# Run ON the clean account, from anywhere: ~/claude-workstream-kit/tests/va3-acceptance.sh
#
# Prerequisites on the clean account (one-time, interactive):
#   1. Claude Code installed:  curl -fsSL https://claude.ai/install.sh | bash
#   2. Logged in:              claude  (then /login in the UI, once)
#   3. Git identity:           git config --global user.name "VA3" ;
#                              git config --global user.email "va3@example.invalid"
# The account must have NO ~/.claude content beyond what /login creates.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJ="$HOME/va3-proj"
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

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
claude -p --dangerously-skip-permissions 'As the user I approve the #G-BD gate: the deliverable works. Check it off, then close the workstream following .claude/skills/workstream-close/SKILL.md (read it and .claude/rules/workstreams-rule.md first). This is a non-interactive session: present the Move 1 narrative summary and the Move 3 per-criterion evidence in your output, and take this message as my closure approval at the Move 3 gate PROVIDED every deletion criterion genuinely has evidence -- if any lacks evidence, stop and say so instead. Work the Completion tasks (#CL-1..#CL-3): disposition any Learnings/Open Questions (if none exist, state that), confirm durable artifacts live outside .state/, then archive exactly per Move 4 (ARCHIVE.md line, annotated tag ws/greeting-script, remove the workstream directory, reset ACTIVE.md fully, commit -- plain git commit, no signing flags).'

check "archive tag exists" "git tag -l | grep -q '^ws/greeting-script$'"
check "ARCHIVE.md line appended" "grep -q 'greeting-script' .state/workstreams/ARCHIVE.md"
check "workstream dir removed" "[ ! -d .state/workstreams/project/greeting-script ]"
check "ACTIVE.md reset" "grep -q '^workstream: none' .state/ACTIVE.md"
check "working tree clean" "[ -z \"\$(git status --porcelain)\" ]"
check "deliverable survives" "sh test/smoke.sh >/dev/null 2>&1"

echo
if [ "$RESULT" -eq 0 ]; then
  echo "VA-3 ACCEPTANCE: ALL CHECKS PASS"
else
  echo "VA-3 ACCEPTANCE: FAILURES ABOVE -- inspect $PROJ"
fi
exit "$RESULT"
