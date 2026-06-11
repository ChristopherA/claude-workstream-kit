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

Read `.state/ACTIVE.md` and the active `workstream.md` first. If the session-start hook reported a staleness signal, reconcile before any task work: update the state to match reality, set `status: paused`, or recommend `/workstream-close`.

## Derive the goal condition

Scope the session (current task, current phase, or a named fix), then draft ONE /goal condition — a measurable end state plus its check:

- Single task: "Task #XX-N is checked in workstream.md with its output committed (cite the commit), ACTIVE.md Next names the following task, and state files are committed."
- Phase: "Every XX-phase checkbox except #G-XX is checked, each with a committed artifact (`grep -c '^- \[ \] #XX-' workstream.md` returns 1), the session stops AT #G-XX with a summary, and state files are committed."
- Build/fix with tests: "<test command> exits 0, the change and state files are committed, and #XX-N is checked."

Always include: mechanical checks over judgment phrasing; the state-commit clause; "without compromising requirements; stop at user gates"; and a turn bound ("or, if blocked or not converging after ~N turns, checkpoint state and stop with a status report"). One condition, under 4000 characters.

Present the condition for the user to start with `/goal <condition>` — or, if already in a goal session, proceed under it.

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

Check off completed tasks with one-line evidence notes, update ACTIVE.md (task, Now, Next, Blockers), commit state files. If the session ends at a gate, ACTIVE.md Blockers names the gate.
