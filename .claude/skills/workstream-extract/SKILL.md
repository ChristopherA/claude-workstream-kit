---
name: workstream-extract
description: >-
  Drains an accreting workstream: extracts durable content to permanent homes,
  condenses what is spent, moves completed phases to an in-file archive, and
  re-checks standing-health criteria. The periodic half of closure, for
  workstreams that are not closing.
  WHEN: a workstream.md has accreted — resolved Learnings with no disposition,
  a completed phase, an undispositioned notes.md, durable artifacts still under
  `.state/`, or the session-start hook's SIZE line; also called by
  /workstream-review and /workstream-close.
  WHEN NOT: the workstream is actually closing (use /workstream-close, which
  calls this); the backlog no longer matches what has been decided (that is
  drift — use /workstream-review); capturing one session at a boundary
  (/workstream-capture).
---

# Workstream Extract

A workstream accumulates faster than anyone drains it, and nothing in the toolset fires on accumulation. Closure drains a workstream once, at the end; the workstreams that need draining most are the ones that never reach it. This is that drain, run on symptoms instead of on an ending: durable content out to permanent homes, spent reasoning condensed, finished phases moved out of the live reader's way, standing criteria re-checked against current evidence.

Review asks whether the PLAN is right. Extract asks whether the RECORD has been drained. Both are periodic and they fire on different symptoms, so run whichever the symptoms name — neither implies the other.

## When it fires

Not a schedule. Any of these is enough:

- A Learning is resolved but carries no disposition marker (applied / handed off / dropped), especially where its siblings carry one. In a never-closing workstream that marker is owed the moment the Learning resolves, not at a closure that never comes.
- A phase has no open tasks left, so its completed records now compete with live ones for the reader.
- The session-start hook prints its SIZE line, or the file feels heavy while measuring light — the checkbox convention puts a completion note on one line however long it runs, so line count under-reads the cost.
- A `notes.md` sits beside workstream.md with sections nobody has dispositioned.
- A durable artifact — a doc, reference material, a spec another project needs — is still living under `.state/`.
- A never-closing workstream's standing-health Deletion Criteria have gone a cycle or more unverified.

If none holds, say so and stop. A drain that moves nothing means the symptoms were absent, not that the workstream is clean.

## Move 1 — Extract

Every resolved Learning and settled Open Question ends in exactly one of: **applied** to a named file outside `.state/` (cite it; make the edit now if it is missing), **handed off** via `/handoff` (send it now, not "later"), or **dropped** with stated rationale, in place. Mark the disposition on the entry itself so the next pass can see it. An entry still live — an open question waiting on the task named to resolve it — stays: dispositioning it early hides open work, the same damage Move 3 refuses for a phase with an open task.

Verify each recorded disposition rather than trusting it. A Learning citing a commit can be spot-checked and usually holds. One citing a task is aspirational until that task ran. One citing a task DESCRIPTION is inside `.state/` however landed it reads: a pre-build description is precisely what Move 2 exists to remove, so the disposition expires silently the next time this skill runs — a completion note is the part of a record a drain keeps, and the only part safe to cite. One citing an Open Question never lands at all, because an OQ resolves into a decision rather than an artifact — treat it as unrouted and write the substance to a file. One citing a file this project does not GOVERN — an installed copy, a generated file, a vendored template — is provisional, not done, until the change reaches whatever governs the file; verify it there. Sweep every entry instead of reconstructing where the last pass stopped: an already-applied item simply reads present, so a full pass is self-correcting. Use `rg --hidden` whenever the named target sits under a dot-directory; a default sweep skips `.claude/` and returns falsely clean.

Then sweep outward. Findings belonging to OTHER workstreams or projects — a decision made in passing, a sibling fix, a question raised and left — go to that workstream's Backlog with provenance, or out as a handoff. For anything recorded as absorbed or covered downstream, grep the DESTINATION: if the receiving task or its criteria do not name it, it is not routed. Edit them so they do.

Finally, move durable artifacts out of `.state/` to their permanent homes, and disposition every `notes.md` section — summarized into workstream.md, routed to a named home, or dropped by declaration.

## Move 2 — Condense

Only after Move 1, and the order is load-bearing: trimming before extracting destroys the insight you were about to route, and the trim looks successful either way. Always extract, then trim.

The criterion is whether the content still does work, not its age or completion. A shipped proposal is **spent** — its wording now lives wherever it shipped, where it is authoritative, and its reasoning lives in its Decision — so the block condenses to a line naming the proposal, the Decision, and the release. A protocol is **reusable** — it governs the next instance as much as it governed the last — so it survives verbatim. The test is whether a future session would consult it. Git holds the full drafting history for whatever the record drops. A Learning that carries a terminal disposition — applied, handed off, dropped, struck through — owes nobody anything and condenses in the same pass to its statement and its marker: disposition answers whether an entry still owes something, condensation answers whether it still needs to be read, and a drain that does only the first leaves the reader's problem where it was while every checkable signal reports success. Before condensing any block, grep the file for what cites it: a disposition that named the block as its home is otherwise left pointing at nothing, and the file reads clean afterward.

Mark a superseded Decision in place rather than deleting it; a stale Decision that reads as current is worse than a long file.

When a script does the rewriting, diff the STRUCTURE as well as the content — extract the heading set before and after and compare it. A splice that cuts one line short drops a heading while every content check still passes. The same discipline applies to every probe over the file: parse records as blocks by their leading marker rather than by line, anchor ID matches to line start, and run one known-positive case through any classification count before believing it — a first-line-only scan of multi-line Learnings misclassifies most of them, and it returns a number rather than an error.

## Move 3 — Archive completed phases in place

What is frozen in a completed task record is its ID, its checkbox state, and the evidence its completion note cites — not the evaluation prose, options, and build notes the record accumulated while it was open. A completed record longer than the rule's one-line note (ID, what it was, date, evidence) condenses to that note, whether or not its phase is ready to move: a record written onto its own line while live is correctly long until the moment it closes, and owes its condensation then. Verify the pass with a diff of IDs and checkbox states before and after, which must be identical, and leave the working detail in git at the preceding commit. Deleting a record loses it and an archive tag hides it, so neither is the instrument. Beyond that, move: add an `## Archive` section at the end of workstream.md and relocate each fully-completed phase's backlog block under it, heading intact, checkboxes and condensed notes in place. The phase stops competing with live work for attention and stays resolvable in place, at its original IDs, without a tag to look in. Moving text within a file changes no bytes, so this move cannot answer a size signal by construction — condensation can, and the composition report under Record says which one a file needs.

Move a phase only when every task in it is checked. A phase with one open task stays live — a partly-archived phase hides work.

## Move 4 — Criteria evidence

Re-check each Deletion Criterion against current evidence: file, commit, or command output. In a closing workstream this is the material for the user gate, which stays with `/workstream-close`. In a never-closing one it is the standing-health check the rule requires each cycle and nothing else runs — the criteria are health conditions rather than an exit, and a criterion that has drifted out of true is the finding. So is a criterion SATISFIED and unticked, which looks identical on the page: read the Purpose's done condition alongside the criteria, because completion has no event either, and a workstream whose done condition is met is a closure candidate that should not go on accreting follow-on rows.

A criterion satisfied by a downstream gate is satisfied only if that gate names it. Check the destination, not the declaration. A note that parks an item against a PENDING or WINDING-DOWN destination is a deferral, not a disposition: re-verify each cycle that the destination is still real and reachable.

## Invocation paths

- **From `/workstream-review`**, when the drift scan surfaces accretion symptoms rather than plan drift. Review restructures the backlog; this drains the record. Run both when both sets of symptoms are present.
- **From `/workstream-close`**, as the periodic half of a true close. Closure keeps the narrative summary, the deletion-criteria user gate, the archive, and its own inward sweep for references that break when the directory is removed; extraction and the outward cascade are this skill. Under a close this is the LAST run: nothing may be deferred, and a disposition naming a future task is not a disposition, because the tag lands before that task does.
- **From `/workstream-close` on a workstream that should not close.** Closure's own first move turns that request around and sends it here. Arriving by this path, expect a file whose bulk is completed records rather than live scope, and expect Move 3 and Move 4 to be the substance of the run.

## Record

Commit the drained state in the session that changes it, and update ACTIVE.md with what moved and what is next. Report what was extracted, what was condensed, what was archived in place, every criterion that failed its re-check, and the file's composition — bytes per section, with the completed-to-open ratio beside the total — since a file that is mostly finished work and still oversized is a condensation backlog while one that is mostly open work is live scope, and the size signal alone cannot tell them apart; "already extracted, still large" is never by itself a reason to split a workstream — a drain that names nothing it moved did not run.
