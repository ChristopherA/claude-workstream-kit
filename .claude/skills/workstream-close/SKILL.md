---
name: workstream-close
description: >-
  Closes a workstream: narrative summary, extraction via /workstream-extract,
  deletion-criteria gate with evidence, then archive.
  WHEN: the user says "close workstream", "/workstream-close", or the
  backlog is complete and deletion criteria look satisfiable.
  WHEN NOT: work still in progress (keep working); pausing
  (set status: paused in workstream.md, and say in its Purpose what resumes it -- the hook's NO-RESUME flag reads only the frontmatter and the Purpose); a `maintain` workstream or any other
  with no closure milestone (use /workstream-extract — Move 1 below turns the
  request around); capturing a session at a /clear, /compact, or pause
  boundary (use /workstream-capture); creating (use /workstream-create).
---

# Workstream Close

Closure is where insights either reach a durable home or die with the archive. The user decides closure; your job is to make that decision easy to take on evidence. Takes an optional `type/name`; bare means the active workstream. Draining the record is `/workstream-extract`'s work; what stays here is what only an ending needs — the narrative, the gate, and the archive. The reason behind each move is in `references/failures.md` under the move's heading; read it when a move is doubted.

## Move 1 — Is this a closure at all?

Read the workstream's `type` and its Deletion Criteria first. A `maintain` workstream, or any whose criteria are standing health conditions rather than an exit, has no closure milestone: say so and offer `/workstream-extract` instead — the request is usually right about the need (an unreadable file) and wrong about the operation, and a continuous identity closed to escape its record is churn the successor inherits. Proceed only if the user, told that, still wants the workstream ended.

A workstream ABSORBED by a decision taken elsewhere is a closure too, and runs this skill rather than being declared closed in the successor's Decisions — the declaration is container-level, and only Move 2's map checks it at the task level.

## Move 2 — Narrative summary

Present: (1) the Purpose verbatim from workstream.md, (2) what was actually accomplished, with pointers to the artifacts and commits, (3) why it is ready to close, (4) what remains open after archive and where each open item goes — as a task-level map, one open task per line, each named against the successor task that now holds it or dropped by name, never a container-level statement that the scope moved — a task the map missed is unrecoverable once the directory is removed. Lead with anything NOT done. Name every reference that crosses a workstream or project boundary with a few words saying what it is (workstreams-rule, Task IDs), in ACTIVE.md and in what you say to the user alike.

## Move 3 — Extraction (delegated)

Run `/workstream-extract`. It dispositions every Learning and Open Question, verifies each recorded disposition against the named file, sweeps outward, moves durable artifacts out of `.state/`, dispositions any `notes.md`, and gathers the per-criterion evidence Move 4 needs. Its condensation and in-file archive moves are optional under a close — the tag preserves the file either way. Two things only an ending has:

- **This is the last run.** Nothing may be deferred to a later pass — an insight not routed now dies in the tag. A disposition that names a future task in THIS workstream is not a disposition here, since the tag lands before that task does. A disposition naming an open task in ANOTHER live workstream whose line names this source IS one — that is how extract's outward sweep routes a finding — and it is verified the way extract prescribes: `cites` on the destination, which must name the source.
- **Sweep inward.** Run `python3 .claude/scripts/workstream-record.py cites <project root> <type/name> <each prefix this workstream minted, as #XX-> --repo` — the name plus the phase codes declared under its own Backlog, and NOT the codes the template mints for every workstream (`#CL-`, `#G-`), which hit every other workstream's closure and gate lines by construction (8 of 60 hits on one run) — and a code another live workstream also declares (`#EX-` sat in three at one closure) returns that workstream's own rows the same way, so read a prefix hit only where its block also names this workstream, and expect the NAME hits to be the ones that matter (both live citations at that closure were found by the name); a cross-boundary reference to this workstream's gate carries its home, so the name needle finds it — and read each hit for which way it points, using the `hold_before` field: a reference naming one of these tasks as a SOURCE survives (the tag preserves it); one naming it as a BLOCKER loses its referent when the directory is removed. Carry every live dependency to a durable home first — usually as its own task in the workstream that depends on it — and re-point the reference there.

## Move 4 — Deletion-criteria gate (USER decides)

For each deletion criterion, show the criterion and the evidence Move 3 gathered — file, commit, or command output — in the message itself, since tool output is not reliably shown to the user. A criterion parked against a downstream gate counts only if that gate names it. What is left to judge is whether the evidence answers the criterion, and a criterion whose whole point is a judgment call is not discharged by a receiving task's mechanical checks. Unsatisfied criteria mean the workstream is not ready — say so and stop. When all criteria have evidence, ask the user to approve closure. Never self-certify.

## Move 5 — Archive

After approval, `ls` the workstream directory before removing anything — `workstream.md` is not always the only file there, and whatever else sits beside it needs a disposition (Move 3) rather than a discovery at `git rm`. Then run the `cites` sweep of Move 3 again with `--repo` — `docs/` and the rest included — and repoint each live citation of this workstream by name or task prefix at the archive tag it is about to have (`#XX-N in ws/<name>`) — a name that stops resolving reads exactly like one that resolves, and the closing session is the only one that knows the name is going. Then:

1. Set `status: done` in `workstream.md`'s frontmatter, and append to `.state/workstreams/ARCHIVE.md`: `- YYYY-MM-DD type/name -- <one-line outcome> (tag: ws/<name>)`. The status edit is what makes the tagged snapshot read as closed: a `git show ws/<name>:...` reader otherwise gets a file claiming to be live.
2. Commit — this is the final state commit, the one the tag names.
3. `git tag -m "<one-line outcome>" ws/<name>` on that commit.
4. `git rm -r` the workstream directory
5. Reset `.state/ACTIVE.md` **only if it names the workstream being closed**: `workstream: none`, `task: none`, fresh Now/Next/Blockers. If it points somewhere else, leave it and say so in the closure notes — resetting a live pointer discards the next session's resume target.
6. Commit
7. Push the tag — a separate gate, never folded into the commit above: `ARCHIVE.md` hands a reader a tag NAME and nothing else, so an unpushed tag leaves the ledger line unresolvable outside this machine. Surface the push with the closure summary and push only on the user's go; while it is unpushed, say so in the summary. Before offering it, run `python3 .claude/scripts/workstream-record.py git <project root> --tags` (add `--remote <name>` when the branch has no upstream, or the counts read null) and read three things from it:
   - **Is there a remote at all?** `tags.remote` null means there is nowhere to push and nothing to compare against — a repo with no elsewhere, not a defect; its ledger rows resolve wherever the repo exists. Say that and skip the push. If a remote is ever added, the backfill is owed at that moment.
   - **Does the remote already have the tagged commit?** `commit_on_remote` false means the push would publish that commit and its unpushed ancestors through a tag, without the branch that should carry them — a materially different act. Split the gate: the `ref_only` tags as a set, and each tag in `carrying_unpushed` on its own with its `unpushed_commits` count, so the user decides about publishing history rather than about repairing a pointer. `git push --dry-run` cannot see this.
   - **Earlier closures dangling since:** every entry whose `tag_on_remote` is false is a closure tag that exists only here; the sub-command filters the annotated-tag `^{}` dereference so the remote is not counted double.
