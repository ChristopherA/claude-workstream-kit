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

## Move 2 — Narrative summary

Present, in prose: (1) the Purpose verbatim from workstream.md, (2) what was actually accomplished, with pointers to the artifacts and commits, (3) why it is ready to close, (4) what remains open after archive and where each open item goes. Lead with anything NOT done.

## Move 3 — Extraction (delegated)

Run `/workstream-extract`. It dispositions every Learning and Open Question as applied, handed off, or dropped; verifies each recorded disposition against the named file rather than trusting it; sweeps outward for findings belonging to other workstreams or projects; moves durable artifacts out of `.state/`; dispositions any `notes.md` beside workstream.md; and gathers the per-criterion evidence Move 4 needs. Its condensation and in-file archive moves are optional under a close — the tag preserves the file either way, though condensing first is a kindness to anyone who returns to it.

Two things only an ending has. The first constrains that run and its closure path states it too; the second is yours to do once it returns.

**This is the last run.** Nothing may be deferred to a later pass, because there is no later pass: an insight not routed now dies in the tag. A disposition that names a future task is not a disposition here — extract's periodic mode tolerates one, and closure does not.

**Sweep inward.** Extract sweeps outward, for findings this workstream owes elsewhere. Closure also has to sweep the other direction, because other workstreams have already written down what they expect from this one and archiving breaks those references. `rg --hidden` the state tree and any docs for this workstream's name and its task-ID prefixes, then read each hit for which way it points. A reference naming one of these tasks as a SOURCE ("routed from ...") survives fine: the tag preserves what it points at. One naming it as a BLOCKER ("blocked on #XX-N") loses its referent the moment the directory is removed, and the next session has no way to know which tag to look in. Carry every live dependency to a durable home first — usually as its own task in the workstream that depends on it — and re-point the reference there.

## Move 4 — Deletion-criteria gate (USER decides)

For each deletion criterion, show the criterion and the evidence Move 3 gathered: file, commit, or command output. A criterion parked against a downstream gate counts only if that gate names it — extract's Move 4 checks that at the destination rather than taking the declaration's word, so an unnamed one arrives here as unsatisfied. What is left to judge is whether the evidence answers the criterion, and a criterion whose whole point is a judgment call is not discharged by a receiving task's mechanical checks. Unsatisfied criteria mean the workstream is not ready — say so and stop. When all criteria have evidence, ask the user to approve closure. Never self-certify.

## Move 5 — Archive

After approval, `ls` the workstream directory before removing anything: `workstream.md` is not always the only file there, and whatever else sits beside it needs a disposition (Move 3) rather than a discovery at `git rm`. Then:

1. Append to `.state/workstreams/ARCHIVE.md`: `- YYYY-MM-DD type/name -- <one-line outcome> (tag: ws/<name>)`
2. `git tag -m "<one-line outcome>" ws/<name>` on the final state commit
3. `git rm -r` the workstream directory
4. Reset `.state/ACTIVE.md` **only if it names the workstream being closed**: `workstream: none`, `task: none`, fresh Now/Next/Blockers. If it points somewhere else — most often a successor that has already inherited this workstream's residue — leave it and say in the closure notes that it was left, so the deviation is visible rather than inferred. Resetting a live pointer discards the next session's resume target immediately after the closure summary named it.
5. Commit
