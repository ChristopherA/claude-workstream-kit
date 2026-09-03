---
name: workstream-close
description: >-
  Closes a workstream: narrative summary, extraction via /workstream-extract,
  deletion-criteria gate with evidence, then archive.
  WHEN: the user says "close workstream", "/workstream-close", or the
  backlog is complete and deletion criteria look satisfiable.
  WHEN NOT: work still in progress (keep working); pausing
  (set status: paused in workstream.md); a `maintain` workstream or any other
  with no closure milestone (use /workstream-extract — Move 1 below turns the
  request around); capturing a session at a /clear, /compact, or pause
  boundary (use /workstream-capture); creating (use /workstream-create).
---

# Workstream Close

Closure is where insights either reach a durable home or die with the archive. The user decides closure; your job is to make that decision easy to take on evidence.

Draining the record is not closure's own work. `/workstream-extract` owns it and runs periodically whether or not anything is ending; what stays here is what only an ending needs — the narrative, the gate, and the archive.

## Move 1 — Is this a closure at all?

Read the workstream's `type` and its Deletion Criteria before anything else. A `maintain` workstream, or any whose criteria are standing health conditions rather than an exit, has no closure milestone to reach. A request to close one is usually right about the need and wrong about the operation: the file has grown unreadable and ending it is the reflex.

Say so, and offer `/workstream-extract` instead — it drains the record, moves completed phases to an in-file archive, and re-checks the standing criteria, which is what the request was after. Closing a continuous identity to escape its accumulated record is churn, and the successor inherits the accumulation within a few cycles. Proceed below only if the user, told that, still wants the workstream ended.

The opposite case is a closure that does not look like one. A workstream ABSORBED by a decision taken elsewhere — its scope carried on by a successor rather than finished — is a closure too, and runs this skill rather than being declared closed in the successor's Decisions: the declaration is container-level, and only Move 2's map checks it at the task level.

## Move 2 — Narrative summary

Present: (1) the Purpose verbatim from workstream.md, (2) what was actually accomplished, with pointers to the artifacts and commits, (3) why it is ready to close, (4) what remains open after archive and where each open item goes — as a task-level map, a list with one open task per line, each named against the successor task that now holds it or dropped by name, never a container-level statement that the scope moved: an absorbed workstream's tasks vanish from the working tree the moment its directory is removed, so a task the map missed is unrecoverable by reading. Lead with anything NOT done. Name every reference that crosses a workstream or project boundary with a few words saying what it is (workstreams-rule, Task IDs), in ACTIVE.md and in what you say to the user alike.

## Move 3 — Extraction (delegated)

Run `/workstream-extract`. It dispositions every Learning and Open Question as applied, handed off, or dropped; verifies each recorded disposition against the named file rather than trusting it; sweeps outward for findings belonging to other workstreams or projects; moves durable artifacts out of `.state/`; dispositions any `notes.md` beside workstream.md; and gathers the per-criterion evidence Move 4 needs. Its condensation and in-file archive moves are optional under a close — the tag preserves the file either way, though condensing first is a kindness to anyone who returns to it.

Two things only an ending has. The first constrains that run and its closure path states it too; the second is yours to do once it returns.

**This is the last run.** Nothing may be deferred to a later pass, because there is no later pass: an insight not routed now dies in the tag. A disposition that names a future task is not a disposition here — extract's periodic mode tolerates one, and closure does not.

**Sweep inward.** Extract sweeps outward, for findings this workstream owes elsewhere. Closure also has to sweep the other direction, because other workstreams have already written down what they expect from this one and archiving breaks those references. `rg --hidden` the state tree and any docs for this workstream's name and its task-ID prefixes, then read each hit for which way it points. A reference naming one of these tasks as a SOURCE ("routed from ...") survives fine: the tag preserves what it points at. One naming it as a BLOCKER ("blocked on #XX-N") loses its referent the moment the directory is removed, and the next session has no way to know which tag to look in. Carry every live dependency to a durable home first — usually as its own task in the workstream that depends on it — and re-point the reference there.

## Move 4 — Deletion-criteria gate (USER decides)

For each deletion criterion, show the criterion and the evidence Move 3 gathered — file, commit, or command output — in the message itself, since output printed from a tool call is displayed to you and not reliably to the user. A criterion parked against a downstream gate counts only if that gate names it — extract's Move 4 checks that at the destination rather than taking the declaration's word, so an unnamed one arrives here as unsatisfied. What is left to judge is whether the evidence answers the criterion, and a criterion whose whole point is a judgment call is not discharged by a receiving task's mechanical checks. Unsatisfied criteria mean the workstream is not ready — say so and stop. When all criteria have evidence, ask the user to approve closure. Never self-certify.

## Move 5 — Archive

After approval, `ls` the workstream directory before removing anything: `workstream.md` is not always the only file there, and whatever else sits beside it needs a disposition (Move 3) rather than a discovery at `git rm`. Then:

1. Append to `.state/workstreams/ARCHIVE.md`: `- YYYY-MM-DD type/name -- <one-line outcome> (tag: ws/<name>)`
2. `git tag -m "<one-line outcome>" ws/<name>` on the final state commit
3. `git rm -r` the workstream directory
4. Reset `.state/ACTIVE.md` **only if it names the workstream being closed**: `workstream: none`, `task: none`, fresh Now/Next/Blockers. If it points somewhere else — most often a successor that has already inherited this workstream's residue — leave it and say in the closure notes that it was left, so the deviation is visible rather than inferred. Resetting a live pointer discards the next session's resume target immediately after the closure summary named it.
5. Commit
6. Push the tag — a separate gate, never folded into the commit above. `ARCHIVE.md` hands a reader a tag NAME and nothing else, so for a closed workstream that tag is the only resolvable route back to a record the working tree no longer holds. The tagged commit ships with the state commits, so the record is reachable by SHA, but no clone can get to the SHA from the ledger: the line reads as resolvable and is not. Pushing is shared-visible, so surface it with the closure summary and push only on the user's go — and while it is unpushed, say plainly in the summary that the ledger line does not resolve outside this machine yet.

   **First, is there a remote at all?** `git remote get-url <remote>` failing means there is nowhere to push and nothing to compare against — a repo with no elsewhere, not a defect. Its `ARCHIVE.md` rows are not broken: with no clone anywhere, the tag resolves wherever the repo exists. Say that in the closure summary and skip both the push and the sweep below. Do not run the sweep anyway to see what it says: with no remote it exits 0, sends its `fatal:` to stderr where the pipeline discards it, and prints every local tag as dangling — the doubling below pointed the other way, and worse, because it invents work rather than hiding it. If a remote is ever added, the backfill is owed at that moment: every row that resolved locally becomes machine-local the day the repo acquires an elsewhere.

   **Then, does the remote already have the tagged commit?** This is a PRECONDITION to check, not a fact to assume. When it holds, the push adds a ref and nothing else. When it does not, the push publishes that commit and its unpushed ancestors through a tag, without the branch that should carry them — a materially different act, and the user's to decide separately. It is not an exotic case: any repo that closes workstreams faster than it pushes has it.

   ```sh
   git branch -r --contains "$(git rev-list -n1 ws/<name>)"
   ```

   Empty output means the commit is not on the remote. Split the gate rather than offering one list: the ref-only tags as a set, and each tag that would carry unpushed commits on its own, with its count from `git rev-list --count <remote>/<branch>..ws/<name>`, so the user is deciding about publishing history rather than about repairing a pointer. **`git push --dry-run` cannot see this** — it prints `* [new tag]` for both cases — so the containment check is the only pre-flight that catches it.

   Take the same moment to catch earlier closures that have been dangling since:

   ```sh
   comm -23 <(git tag -l 'ws/*' | sort) \
            <(git ls-remote --tags <remote> 'refs/tags/ws/*' \
              | sed -n 's|.*refs/tags/\(.*\)|\1|p' | grep -v '\^{}$' | sort)
   ```

   Anything it prints is a closure tag that exists only here. **The `^{}` filter is load-bearing.** An annotated tag appears twice in `ls-remote` output — once as the tag ref, once dereferenced — so an unfiltered remote listing reads roughly double and looks like "the remote has more than local, nothing is missing" even when closure tags have never left this machine.
