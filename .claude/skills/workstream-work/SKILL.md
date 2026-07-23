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

- Single task: "Task #XX-N is checked in workstream.md with its output committed (cite the commit), ACTIVE.md advanced past #XX-N (its task pointer no longer names #XX-N), and state files are committed." (When the following task is a gate the user may answer this session, do not pin "Next names #G-XX" -- recording the gate's decision advances the pointer and erases that state; "advanced past #XX-N" holds whether the gate is still open or already decided.)
- Phase: "Every XX-phase work task is checked with a committed artifact (`grep -cE '^- \[ \] #XX-' workstream.md` returns 0 -- this pattern counts work tasks only; the gate `#G-XX` is not matched by `#XX-` and is not counted), the session presents #G-XX with a substantive summary and never auto-passes it, and state files are committed." (Count work tasks only, never the gate: a "returns 1 -- only the gate open" check deadlocks the /goal hook the moment the user answers the gate in-session, because recording the decision checks `#G-XX` and flips the count to 0. `returns 0` over `#XX-` alone stays true whether the gate is open or already decided.)
- Build/fix with tests: "<test command> exits 0, the change and state files are committed, and #XX-N is checked."

Always include: mechanical checks over judgment phrasing; the state-commit clause; "without compromising requirements; stop at user gates"; and a turn bound ("or, if blocked or not converging after ~N turns, checkpoint state and stop with a status report" -- roughly 20 turns for a single task, 50 for a phase). Phrase every condition to hold at the moment the session actually tries to stop, and to stay satisfied if the session did more than the minimum: the /goal stop-hook re-checks the condition only on stop attempts, never during AskUserQuestion, so a condition that pins pre-gate state (a count that requires the gate still open, "Next names #G-XX", "Blockers names the gate") goes permanently unsatisfiable the moment an in-session gate decision erases it. One condition, under 4000 characters.

**`/goal` is a poor fit for user-gated interactive work** — provisioning that needs repeated sudo passwords, GUI steps, device approvals, or biometric taps. The Stop hook re-fires every turn while the condition is unmet, so it churns at each gate (and overnight, if the user steps away). For such work, present the plan and drive it step-by-step **without** setting a `/goal`. If a goal is already set and you hit a user gate the user can't clear soon, recommend they run `/goal clear` (it does not auto-clear until met). Reserve `/goal` for work that is mostly autonomous between checks.

Present the derived condition. Then — unless already in a goal session (just proceed under the active condition) — ask the user how to proceed, with AskUserQuestion:

- **Copy to clipboard** (recommended): on selection, place the full `/goal <condition>` on the clipboard (`pbcopy` on macOS; on any other platform print it in a fenced block instead) for the user to paste, so the harness stop-hook enforces it.
- **Process interactively**: work toward the condition now, in this session, without arming a `/goal` hook.
- **Refine the goal together**: adjust scope, checks, or the turn bound before committing to it.

Never touch the clipboard until the user selects **Copy to clipboard** — it is a shared resource that may hold unrelated content, so presenting the condition or the question must not write it. On selection, copy the exact text — a mistyped or mis-pasted condition is unenforceable. Do not set the goal yourself; `/goal` is the user's to issue.

## Autonomous boundaries

- Reads, edits, sub-agent delegation: proceed.
- Commits and state updates: proceed, one logical unit per commit so each is independently reversible.
- Deferred decisions ("X vs Y, decide during this task"): take the reversible side, record the rationale at the decision site, flag for the next gate.
- `#G-` checkpoints: STOP with a substantive summary and the evidence. Never auto-pass.
- Shared-visible or irreversible actions (pushing to shared remotes, opening PRs/issues, deleting non-session files, scope changes): STOP and surface, unless standing authorization names the specific action.

## Delegate; claim with evidence

- **scout** — read-only scans, counts, staleness, inventories: anything `grep`/`head` over files can answer. A scout's inventory is a starting hypothesis, not the punch list: verify cited line numbers before editing from them, and for an exhaustive-edit sweep read the target files in full and run an independent `grep -rn` across the whole surface (including references/ subdirectories) — a scout scoped to the primary files under-reports.
- **worker** — bounded packets only. A packet states: objective, file scope, verification command, stop conditions. Never open-ended.
- **verifier** — fresh-context check of worker output against its packet before you accept it.

Every "done" claim cites its evidence: a commit hash, a passing command's output, a count. No evidence, no checked checkbox. Findings from sub-agents are inputs to verify, not conclusions to repeat.

## Session exit

Run the capture sweep (workstreams-rule) over the session against the durable files — detection / cascade / synthesis — and route each finding; capture should not depend on the user asking. Then check off completed tasks with one-line evidence notes, update ACTIVE.md (task, Now, Next, Blockers), and commit state files. If the session ends with a gate still open, ACTIVE.md Blockers names the gate; if the user decided a gate this session, record it (check #G-XX with the decision's provenance) and advance ACTIVE.md past it -- never revert a recorded user decision to satisfy a /goal hook, use /goal clear instead.
