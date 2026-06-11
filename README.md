# Claude Workstream Kit

A standalone, portable workstream system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Copy it into any project and that project gains durable, git-versioned work tracking that survives `/clear`, `/compact`, session ends, and account moves — with zero dependency on user-level (`~/.claude/`) configuration.

Designed for Claude Fable 5: principle-level instructions instead of step enumerations, `/goal`-driven autonomous sessions, and delegation to cheap pinned subagents (Haiku scout, Sonnet worker, fresh-context verifier).

## What is a workstream?

A workstream is a unit of multi-session work — a feature, an exploration, a migration — tracked in two small markdown files committed to your repo:

- `.state/workstreams/<type>/<name>/workstream.md` — everything durable about the work: purpose, task backlog (checkboxes, phase-prefixed IDs), decisions with reasoning, learnings, and the deletion criteria that gate closure.
- `.state/ACTIVE.md` — the per-project session pointer: which workstream is active, the current task, what's next, what's blocked.

Because the state is plain files in git, it is portable across machines, accounts, and time. Nothing lives in harness-local storage.

## What the kit ships

| Piece | Files |
|---|---|
| Conventions | `.claude/CLAUDE.md`, `.claude/rules/workstreams-rule.md` |
| Lifecycle skills | `.claude/skills/workstream-create/`, `workstream-work/`, `workstream-close/` |
| Cross-project handoffs | `.claude/skills/handoff/` |
| Tiered agents | `.claude/agents/scout.md` (haiku), `worker.md` (sonnet), `verifier.md` |
| Session resume | `.claude/hooks/session-start.sh` + `settings.json` hook registration |
| State seed | `.state/` (ACTIVE.md, workstreams/, handoffs/) |

What the kit deliberately does NOT carry — use the native capability instead:

| Need | Native capability |
|---|---|
| Within-session step tracking | Harness Tasks / plan mode |
| Incremental lesson capture | Harness memory |
| Planning | Plan mode + plan files |
| Keep-working discipline | `/goal` (the workstream-work skill derives the condition) |
| Recurring work | `/loop`, `/schedule` |
| Distribution/updates | Re-run `install.sh`; plugin packaging is a planned follow-up |

## Install

```sh
./install.sh /path/to/your/project
```

Idempotent: safe to re-run for updates. It copies the `.claude/` payload, seeds `.state/` (never overwriting existing state), merges the session-start hook into the project's `settings.json` (or tells you the one line to add), and stamps `.claude/workstream-kit.version`.

If your project already has a `.claude/CLAUDE.md`, the kit's conventions are appended under a marker block instead of overwriting.

## Lifecycle

1. **Create** — `/workstream-create`: a short interview (purpose, deletion criteria, first tasks), then the two state files are written and committed. Work never auto-starts.
2. **Work** — `/workstream-work`: derives a `/goal` condition from the active backlog phase (mechanical checks: checkbox counts, test exit codes, commit presence), states the autonomous-session boundaries, and works the backlog — delegating scans to the scout, bounded packets to the worker, and verification to the verifier. Every progress claim cites its evidence. Stops at `#G-` user checkpoints.
3. **Hand off** — `/handoff`: write a self-contained item file into another project's `.state/handoffs/`; receive by triaging your own inbox.
4. **Close** — `/workstream-close`: narrative summary, learnings dispositioned to destinations outside `.state/`, per-criterion evidence at the user gate, then archive (one line in `ARCHIVE.md`, a git tag, the directory removed).

## Team-scale alternative

For teams that want handoffs with notifications, search, and ownership, GitHub Issues with cross-repo references (`owner/repo#N`) are the right tool; this kit's file-based handoffs are optimized for single-operator multi-project accounts.

## License

License to be chosen by the repository owner.
