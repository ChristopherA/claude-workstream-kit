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
| Lifecycle skills | `.claude/skills/workstream-create/`, `workstream-work/`, `workstream-capture/`, `workstream-review/`, `workstream-extract/`, `workstream-close/` |
| Cross-project handoffs | `.claude/skills/handoff/` |
| Cross-workstream status | `.claude/skills/workstream-status/` (read-only, on demand) |
| Tiered agents | `.claude/agents/scout.md` (haiku), `worker.md` (sonnet), `verifier.md` |
| Session resume | `.claude/hooks/session-start.sh` + `settings.json` hook registration |
| Boundary capture | workstreams-rule capture sweep + `.claude/skills/workstream-capture/` + `.claude/hooks/capture-nudge.sh` (SessionEnd/PreCompact nudge) |
| State seed | `.state/` (ACTIVE.md, workstreams/, handoffs/) |
| Status line | `.claude/scripts/status-line.sh`, registered set-if-absent by `install.sh` |

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

Idempotent: safe to re-run for updates. It copies the `.claude/` payload, seeds `.state/` (never overwriting existing state), merges the kit's hooks into the project's `settings.json` (or tells you what to add), and stamps the installed version and source commit. A re-run stops rather than overwriting a payload file you edited locally, so an unrouted improvement is not lost by re-running without looking (`--force` discards it deliberately). Run it with `--dry-run` (alias `--check`) first to see exactly what a real run would change; it writes nothing and exits non-zero when anything is out of sync (1 for drift or a behind stamp, 3 when the payload cannot be tracked in your project).

If your project already has a `.claude/CLAUDE.md`, the kit's conventions are appended under a marker block instead of overwriting.

### Payload visibility

The payload has to be trackable by your project's git, because the whole point is that the work tracking travels with the repo. If your `.gitignore` hides `.claude/`, the install still writes every file and none of it can be committed — so `--dry-run` reports them as `untrackable` and exits 3 instead of saying "In sync", and a real run names them and withdraws its own "commit the new files" advice.

That combination is worth naming, because it presents as success: `.state/` is seeded separately from the payload, so a project that tracks `.state/` while ignoring `.claude/` gets the case where **the state travels and the machinery does not**. A clone on another machine holds `ACTIVE.md` and `workstream.md` with no session hook, no rule, and no skills — readable as text, with nothing operating on them.

One trap when relaxing the pattern: a bare `settings.json` line, common in a secrets denylist, matches `.claude/settings.json` at any depth, and **the last matching pattern wins**, so the negation has to come after the entry it undoes:

```gitignore
settings.json                 # denylist entry
!.claude/settings.json        # negation AFTER it -- the payload file is trackable
```

Reversing those two lines leaves the file ignored.

### What the overwrite refusal does and does not cover

A re-run refuses to overwrite a payload file you edited locally, and `--force` discards it deliberately. That guarantee covers `install.sh` and **cannot cover the same file arriving over git**, because git's protection against clobbering a working-tree file does not extend to an ignored one.

Run as a paired collision, differing only in whether the path is ignored: with `.claude/` ignored, a local hand-edited payload file shows nothing in `git status`, and `git pull` reports a fast-forward, exits 0, and the local content is gone — no error, no conflict, no prompt. With the identical collision on a path that is merely untracked, `git pull` refuses with "untracked working tree files would be overwritten by merge", exits 1, and the content survives. Ignoring the path is exactly what removes the protection.

Tracking the payload is therefore not only how the kit travels; it is the condition that restores git's own safety net under it.

## Upgrading

There is no sync layer: upgrading is re-running `install.sh` from a newer copy, and your `.state/` is never touched. Always update by running the installer, not by hand-copying files. The installer runs under `#!/bin/sh`, so it is immune to the macOS interactive `cp -i` / `mv -i` aliases that silently no-op a copy in a non-interactive shell and leave you thinking an update applied when it did not.

Preview first with `--dry-run` (alias `--check`). It compares the kit against your project file by file, reports what a real run would change, and exits without writing:

```sh
./install.sh --dry-run /path/to/your/project   # preview, writes nothing
./install.sh           /path/to/your/project   # apply
```

Paste this to your agent:

> Upgrade the claude-workstream-kit in this project. If I have a local clone of github.com/ChristopherA/claude-workstream-kit, `cd` there and `git pull`; otherwise clone it. Run its `install.sh --dry-run` against this project's root and show me the report. If it looks right, run it again without `--dry-run`, show me the diff to `.claude/`, and commit it.

### What the dry run reports

For each kit-managed file it prints one line:

- **in sync** — your copy matches the kit.
- **instance-behind** — your copy is an older kit version; a real run updates it. Safe to apply.
- **instance-ahead** — your copy was edited locally and matches no kit version. Port it back into the kit before you apply.

The `instance-ahead` case is why the dry run exists. An improvement made directly to an installed copy is invisible until something compares it against the kit. A real run refuses to overwrite such a file: it lists what it found and exits non-zero, so the loss cannot happen by simply not looking. Route the edit into the kit, or pass `--force` to discard it deliberately.

The version and source stamps are checked too:

- **stamp-behind** — the payload matches the kit, but the recorded version is behind or the `.source` stamp is missing. A real run updates only the stamp, so it is safe to apply. It still exits non-zero, so a fleet upgrade that keys on the exit code does not skip a project that is a release behind on nothing but its stamp.

A source commit merely older than the kit you hold, while the version matches, is reported as currency rather than drift: the dry run stays in sync and exits zero, because between releases the `.source` stamp is provenance to compare, not a required update (see Version and source stamps below).

### Version and source stamps

Each install writes two stamps under `.claude/`:

- `workstream-kit.version` — the released version, e.g. `0.4.0`.
- `workstream-kit.source` — the exact source commit installed from (`source:` short SHA, `ref:` `git describe`).

They certify which kit release and which commit produced the payload now on disk. They do **not** certify that the payload is unmodified since install (local edits leave the stamp untouched — `--dry-run` reports them, and a real run refuses to overwrite them), nor that it is the newest kit (a stamp records the source at install time; compare its `source:` commit against the kit you hold to judge currency). The version can read current while the payload sits a commit or two behind: installing from a mid-stream checkout does this, and so does a content change shipped under an unchanged version number. Recording the source commit alongside the version is what makes that difference visible.

### Versioning

While the kit is pre-1.0, `VERSION` moves by the kind of change a release carries:

- a new SKILL bumps the minor version (`0.4.0` to `0.5.0`) -- a new capability the kit did not have, not merely a large change;
- everything else bumps the patch version (`0.5.0` to `0.5.1`), including rule and skill text however substantial the diff: reworded guidance is a clarification, not a feature;
- the major version stays at `0`.

`VERSION` marks curated releases. Between releases the `workstream-kit.source` stamp records the exact commit, so a project installed from a mid-stream checkout still reports precise provenance even when the version number has not moved.

A release is soft until its tag reaches the remote. While `git ls-remote --tags origin` does not show it, approved work arriving late folds into the pending release — re-cutting costs a deleted local tag and a reset. The release commit is the TIP of the range being published: a fix approved after it is reordered ahead of it before the tag is cut, because `install.sh` reports its version from `git describe`, and a tag below the tip has every consumer installing from `main` read as commits past the release. Once the tag is public, the same work takes a new patch release instead, because a project may already have installed from it.

A release that changes the kit's model of itself — a skill added or removed, a lifecycle boundary moved, a move retired — reads `docs/design.md` against the release diff before the tag is cut and fixes what the release falsified. A rationale document is cited more often than it is opened and produces no diff at the moment it becomes wrong. Other releases owe no such pass.

## Status line

The kit ships a self-contained status line that shows `project » branch » workstream` and the percent of context remaining before auto-compaction, reading the active workstream from `.state/ACTIVE.md`. It also writes a per-session context JSON to `/tmp` that sessions read for context-budget decisions. It needs only `jq`.

Install registers it in `settings.json` automatically — but only when no `statusLine` is already set, so a status line you already run is never overridden. Remove it by deleting the `statusLine` block from `.claude/settings.json` — but note a later re-install will register it again once the slot is empty, so to stay opted out across updates, point `statusLine` at your own command instead of leaving the slot absent.

## Lifecycle

1. **Create** — `/workstream-create`: a short interview (purpose, deletion criteria, first tasks), then the two state files are written and committed. Work never auto-starts.
2. **Status** — `/workstream-status`: reads every workstream, paused ones included, and states where the project is — a roster with each workstream's next task, the critical paths that run across workstreams, what is waiting on the user, and where the state files disagree with each other, each disagreement quoted from both sides with the skill that owns the fix. Read-only and on demand: it writes nothing and asks nothing. Project context comes only from `.state/PROJECT.md`, the project's own list of its unique skills and context files.
3. **Work** — `/workstream-work`: derives a `/goal` condition from the active backlog phase (mechanical checks: checkbox counts, test exit codes, commit presence), states the autonomous-session boundaries, and works the backlog — delegating scans to the scout, bounded packets to the worker, and verification to the verifier. Every progress claim cites its evidence. Stops at `#G-` user checkpoints.
4. **Capture** — `/workstream-capture`: at a session boundary (`/clear`, `/compact`, or a pause), sweep the session for anything decided, learned, or flagged that is not yet durable, route each finding, update the resume pointer, and commit state. `/clear` fires no hook, so this is the sweep that would otherwise be skipped.
5. **Review** — `/workstream-review`: periodic re-coherence for a long-running workstream — detect drift between the backlog and the accumulated decisions/learnings, scan for what is recorded and no longer true, surface stale framing assumptions, refresh the critical path, and audit cross-workstream placement, restructuring behind user gates. Runs on drift signals, not a schedule.
6. **Extract** — `/workstream-extract`: the periodic drain, for a workstream that has accreted rather than drifted — durable content out to permanent homes, spent reasoning condensed, completed phases moved to an in-file archive, standing criteria re-checked against current evidence. It is the half of closure that never needed an ending, which is why a `maintain` workstream that never closes still gets it. Runs on accretion symptoms, and under a close.
7. **Hand off** — `/handoff`: write a self-contained item file into another project's `.state/handoffs/`; receive by triaging your own inbox.
8. **Close** — `/workstream-close`: narrative summary, extraction delegated to `/workstream-extract`, per-criterion evidence at the user gate, then archive (one line in `.state/workstreams/ARCHIVE.md`, a git tag, the directory removed). Asked to close a workstream with no closure milestone, it offers extraction instead.

## Reporting a gap in the kit

Open an issue on this repository. That includes an edit you made to an installed payload file because you needed the behaviour now — the right immediate move, and one nothing routes afterward: report it the same session, with the diff, since the edit is invisible between upgrades, blocks your next upgrade under the overwrite refusal, and leaves every other consumer without it. A version stamp cannot see an in-place edit; only comparing the file's content against the kit can. Do not send a handoff: this repo is itself kit-installed, so it carries a tracked `.state/handoffs/` inbox, and a handoff committed there is committed to a public repository — while handoffs routinely name the private projects they come from. The inbox stays tracked because an uncommitted handoff does not reach the receiver's other machines, so the destination is documented rather than the inbox disabled.

## Team-scale alternative

For teams that want handoffs with notifications, search, and ownership, GitHub Issues with cross-repo references (`owner/repo#N`) are the right tool; this kit's file-based handoffs are optimized for single-operator multi-project accounts.

## License

[BSD-2-Clause-Patent](LICENSE) — BSD 2-Clause with a patent grant.
