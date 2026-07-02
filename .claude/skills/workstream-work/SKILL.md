---
name: workstream-work
description: >-
  Works the active workstream's backlog. Derives a /goal condition from the
  current phase, states autonomous-session boundaries, delegates mechanical
  passes to scout/worker/verifier, and makes only grounded progress claims.
  WHEN: the user says "/workstream-work", "work the workstream", "continue the
  workstream", or starts an autonomous session against the active backlog.
  WHEN NOT: no active workstream (use /workstream-create); all tasks done
  (use /workstream-close); one-off tasks unrelated to the backlog.
---

# Workstream Work

Read `.state/ACTIVE.md` and the active `workstream.md` first. If the session-start hook reported a staleness signal, reconcile before any task work: update the state to match reality, set `status: paused`, or recommend `/workstream-close`. Also check coherence: if the backlog no longer reflects the accumulated Decisions and Learnings, or the critical path is not derivable from it, recommend `/workstream-review` before working — do not work a drifted backlog.

## Derive the goal condition

Identify the critical path through the open backlog (the ordered tasks that unblock the rest); if it is not derivable from the backlog, that is a drift signal — recommend `/workstream-review` first. Scope the session to a task, phase, or named fix on that path, then draft ONE /goal condition — a measurable end state plus its check:

- Single task: "Task #XX-N is checked in workstream.md with its output committed (cite the commit), ACTIVE.md Next names the following task, and state files are committed."
- Phase: "Every XX-phase checkbox except #G-XX is checked, each work task with a committed artifact (`grep -cE '^- \[ \] #(XX-|G-XX)' workstream.md` returns 1 — only the gate remains open), the session stops AT #G-XX with a summary, and state files are committed." (The gate ID is `#G-XX`, which `#XX-` alone does not match; the pattern must include the gate, or the count reads 0 when the phase is done.)
- Build/fix with tests: "<test command> exits 0, the change and state files are committed, and #XX-N is checked."

Always include: mechanical checks over judgment phrasing; the state-commit clause; "without compromising requirements; stop at user gates"; and a turn bound ("or, if blocked or not converging after ~N turns, checkpoint state and stop with a status report" -- roughly 20 turns for a single task, 50 for a phase). One condition, under 4000 characters.

Present the derived condition. Then — unless already in a goal session (just proceed under the active condition) — ask the user how to proceed, with AskUserQuestion:

- **Copy to clipboard** (recommended): put the full `/goal <condition>` on the clipboard (`pbcopy` on macOS; otherwise print it in a fenced block) for the user to paste, so the harness stop-hook enforces it.
- **Process interactively**: work toward the condition now, in this session, without arming a `/goal` hook.
- **Refine the goal together**: adjust scope, checks, or the turn bound before committing to it.

Copy the exact text — a mistyped or mis-pasted condition is unenforceable. Do not set the goal yourself; `/goal` is the user's to issue.

## Autonomous boundaries

- Reads, edits, sub-agent delegation: proceed.
- Commits and state updates: proceed, one logical unit per commit so each is independently reversible.
- Deferred decisions ("X vs Y, decide during this task"): take the reversible side, record the rationale at the decision site, flag for the next gate.
- `#G-` checkpoints: STOP with a substantive summary and the evidence. Never auto-pass.
- Shared-visible or irreversible actions (pushing to shared remotes, opening PRs/issues, deleting non-session files, scope changes): STOP and surface, unless standing authorization names the specific action.

## Delegate; claim with evidence

- **scout** — read-only scans, counts, staleness, inventories: anything `grep`/`head` over files can answer.
- **worker** — bounded packets only. A packet states: objective, file scope, verification command, stop conditions. Never open-ended.
- **verifier** — fresh-context check of worker output against its packet before you accept it.

Every "done" claim cites its evidence: a commit hash, a passing command's output, a count. No evidence, no checked checkbox. Findings from sub-agents are inputs to verify, not conclusions to repeat.

## Session exit

Run the capture sweep (workstreams-rule) over the session against the durable files — detection / cascade / synthesis — and route each finding; capture should not depend on the user asking. Then check off completed tasks with one-line evidence notes, update ACTIVE.md (task, Now, Next, Blockers), and commit state files. If the session ends at a gate, ACTIVE.md Blockers names the gate.
