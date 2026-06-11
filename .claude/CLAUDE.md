# Workstream Conventions

This project tracks multi-session work as **workstreams**: durable state in git-versioned files under `.state/`. Formats and constraints: `.claude/rules/workstreams-rule.md`.

## Session resume

At session start the hook prints `ACTIVE.md` plus a one-line status of the active workstream. Respond to it before other work:

1. If a workstream is active: read its `workstream.md`, announce "Resuming <name> at <task>", and continue from ACTIVE.md's Next.
2. If the hook reports a staleness signal (state lags recent commits, or the workstream is untouched for 14+ days): reconcile first — update, pause, or close the workstream — before new task work.
3. If the hook reports handoffs: mention the count and offer `/handoff` receive.

## Working

- **Interactive or autonomous** — both are supported. For autonomous sessions, `/workstream-work` derives a `/goal` condition from the active backlog phase and states the session boundaries.
- **One tracker per tier**: the workstream.md Backlog is the durable cross-session tracker; use native Tasks or plan mode for within-session steps. Never mirror one into the other.
- **Grounded claims**: a task is "done" only with citable evidence — a commit, a passing command, a count. Claims without evidence don't close checkboxes.
- **Delegate mechanical work**: scout (read-only scans/counts), worker (bounded packets), verifier (fresh-context check) — defined in `.claude/agents/`.
- **User gates**: `#G-` checkpoint tasks stop autonomous work and get a substantive summary. Never auto-pass them.

## Session exit

Before stopping: update ACTIVE.md (task, Now, Next, Blockers), check off completed backlog items, and **commit the state files**. Uncommitted state is invisible to the next session and to other machines.

## Native capabilities the kit does not duplicate

Planning -> plan mode. Within-session steps -> Tasks. Incremental lessons -> memory. Recurring work -> /loop, /schedule. Keep-working discipline -> /goal.
