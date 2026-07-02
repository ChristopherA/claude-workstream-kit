# Claude Workstream Kit

A standalone, portable workstream system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Copy it into any project and that project gains durable, git-versioned work tracking that survives `/clear`, `/compact`, session ends, and account moves — with zero dependency on user-level (`~/.claude/`) configuration.

Designed for frontier agentic models (Fable-, Opus-, and Sonnet-class): principle-level instructions instead of step enumerations, `/goal`-driven autonomous sessions, and delegation to cheap pinned subagents (Haiku scout, Sonnet worker, fresh-context verifier).

## Why workstreams

A Claude Code session is ephemeral. Its context vanishes at `/clear`, gets rounded off by auto-compaction, and dies with a closed terminal or a move to another machine. The work usually is not ephemeral: a feature lands across a week of sessions, a migration takes a dozen, a research question evolves for a month. Every session that starts without durable state pays a reconstruction tax — re-explaining the goal, re-discovering what was decided and why, sometimes re-litigating choices that were already settled.

Claude Code ships several capabilities that each cover a slice of this, and several community patterns cover other slices. None of them give you project-scoped work state that lives in your repository:

| Approach | Survives /clear + compaction | Lives in your repo | Moves with the repo | Resume pointer + closure |
|---|---|---|---|---|
| Re-explain each session | no | — | — | no |
| Growing CLAUDE.md | yes | yes | yes | no |
| Harness Tasks / plan mode | session-scoped | no | no | no |
| Harness memory | yes | no (account-side) | no | lessons, not work state |
| GitHub Issues / PRs | yes | service-side | needs network + auth | partial |
| SPEC.md in the repo | yes | yes | yes | no |
| **Workstreams (this kit)** | yes | yes | yes | yes |

A workstream is the missing row: the goal, the task backlog, the decisions with their reasoning, and the conditions for being done — as two small markdown files committed to git, where they survive everything the harness can do and travel with the repo like tests or docs. The full argument, including what each alternative is genuinely good at and what a much larger predecessor system taught us to leave out, is in [docs/design.md](docs/design.md).

## What is a workstream?

A workstream is a unit of multi-session work — a feature, an exploration, a migration — tracked in two small markdown files committed to your repo:

- `.state/workstreams/<type>/<name>/workstream.md` — everything durable about the work: purpose, task backlog (checkboxes, phase-prefixed IDs), decisions with reasoning, learnings, and the deletion criteria that gate closure.
- `.state/ACTIVE.md` — the per-project session pointer: which workstream is active, the current task, what's next, what's blocked.

Because the state is plain files in git, it is portable across machines, accounts, and time. Nothing lives in harness-local storage.

## What the kit ships

| Piece | Files |
|---|---|
| Conventions | `.claude/CLAUDE.md`, `.claude/rules/workstreams-rule.md` |
| Lifecycle skills | `.claude/skills/workstream-create/`, `workstream-work/`, `workstream-review/`, `workstream-close/` |
| Cross-project handoffs | `.claude/skills/handoff/` |
| Tiered agents | `.claude/agents/scout.md` (haiku), `worker.md` (sonnet), `verifier.md` |
| Session resume | `.claude/hooks/session-start.sh` + `settings.json` hook registration |
| Boundary capture | workstreams-rule capture sweep + `.claude/hooks/capture-nudge.sh` (SessionEnd/PreCompact nudge) |
| State seed | `.state/` (ACTIVE.md, workstreams/, handoffs/) |
| Status line (opt-in) | `.claude/scripts/status-line.sh`, enabled with `install.sh --status-line` |

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

Clone the kit and run its installer against your project:

```sh
git clone https://github.com/ChristopherA/claude-workstream-kit
claude-workstream-kit/install.sh /path/to/your/project
```

Idempotent: safe to re-run for updates. It copies the `.claude/` payload, seeds `.state/` (never overwriting existing state), merges the kit's hooks into the project's `settings.json` (or tells you what to add), and stamps `.claude/workstream-kit.version`.

If your project already has a `.claude/CLAUDE.md`, the kit's conventions are appended under a marker block instead of overwriting.

## Upgrading

There is no sync layer: upgrading is re-running `install.sh` from a newer copy, and your `.state/` is never touched. Paste this to your agent:

> Upgrade the claude-workstream-kit in this project. If I have a local clone of github.com/ChristopherA/claude-workstream-kit, `cd` there and `git pull`; otherwise clone it. Then run its `install.sh` against this project's root, show me the diff to `.claude/`, and commit it.

## Status line (opt-in)

The kit ships a self-contained status line that shows `project » branch » workstream` and the percent of context remaining before auto-compaction, reading the active workstream from `.state/ACTIVE.md`. It needs only `jq`.

It is **off by default** — adopters may already run their own — so enable it with the flag:

```sh
./install.sh --status-line /path/to/your/project
```

The script is always copied into `.claude/scripts/`; the flag additionally registers it in `settings.json`, and only when no status line is already set, so it never overrides one you run. Enable it later by re-running with the flag; remove it by deleting the `statusLine` block from `.claude/settings.json`.

Or paste this to your agent:

> Enable the workstream kit's status line in this project: run the kit's `install.sh --status-line` against this project's root, then commit the `settings.json` change.

## Lifecycle

1. **Create** — `/workstream-create`: a short interview (purpose, deletion criteria, first tasks), then the two state files are written and committed. Work never auto-starts.
2. **Work** — `/workstream-work`: derives a `/goal` condition from the active backlog phase (mechanical checks: checkbox counts, test exit codes, commit presence), states the autonomous-session boundaries, and works the backlog — delegating scans to the scout, bounded packets to the worker, and verification to the verifier. Every progress claim cites its evidence. Stops at `#G-` user checkpoints.
3. **Review** — `/workstream-review`: periodic re-coherence for a long-running workstream — detect drift between the backlog and the accumulated decisions/learnings, surface stale framing assumptions, refresh the critical path, and audit cross-workstream placement, restructuring behind user gates. Runs on drift signals, not a schedule.
4. **Hand off** — `/handoff`: write a self-contained item file into another project's `.state/handoffs/`; receive by triaging your own inbox.
5. **Close** — `/workstream-close`: narrative summary, learnings dispositioned to destinations outside `.state/`, per-criterion evidence at the user gate, then archive (one line in `ARCHIVE.md`, a git tag, the directory removed).

## Team-scale alternative

For teams that want handoffs with notifications, search, and ownership, GitHub Issues with cross-repo references (`owner/repo#N`) are the right tool; this kit's file-based handoffs are optimized for single-operator multi-project accounts.

## License

[BSD-2-Clause-Patent](LICENSE) — BSD 2-Clause with a patent grant.
