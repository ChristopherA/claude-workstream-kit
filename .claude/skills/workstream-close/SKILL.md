---
name: workstream-close
description: >-
  Closes a workstream: narrative summary, learning extraction with
  dispositions, deletion-criteria gate with evidence, then archive.
  WHEN: the user says "close workstream", "/workstream-close", or the
  backlog is complete and deletion criteria look satisfiable.
  WHEN NOT: work still in progress (keep working); pausing
  (set status: paused in workstream.md); capturing a session at a
  /clear, /compact, or pause boundary (use /workstream-capture);
  creating (use /workstream-create).
---

# Workstream Close

Closure is where insights either reach a durable home or die with the archive. The user decides closure; your job is to make that decision easy to take on evidence.

## Move 1 — Narrative summary

Present, in prose: (1) the Purpose verbatim from workstream.md, (2) what was actually accomplished, with pointers to the artifacts and commits, (3) why it is ready to close, (4) what remains open after archive and where each open item goes. Lead with anything NOT done.

## Move 2 — Extraction

Disposition every Learning and every Open Question — each one ends in exactly one of:

- **Applied**: the insight is in a named file outside `.state/` (cite the file; make the edit now if it is missing).
- **Handed off**: sent to another project via `/handoff` (do it now, not "later").
- **Dropped**: with stated rationale, in place.

Verify each recorded disposition instead of trusting it — a Learning's claim is reliable in proportion to what it cites. One citing a **commit** ("integrated at `<sha>`") can be spot-checked and usually holds. One citing a **task** ("integration target: `<file>`, at #XX-N") is aspirational until that task actually ran, and a closure task deferred session after session takes every Learning routed to it down with it. Sweep all of them rather than reconstructing what an earlier session checked: an already-applied item simply reads present, so a full pass is self-correcting and cheaper than working out where the last one stopped. Verify with `rg --hidden` whenever the named target sits under a dot-directory — a default ripgrep sweep skips `.claude/` and returns falsely clean.

Deploy any durable artifacts still living under `.state/` (docs, reference material, decisions other projects need) to their permanent homes. Decisions stay in workstream.md — the archive tag preserves them; `.state/workstreams/ARCHIVE.md` will carry the pointer. If a `notes.md` sits beside workstream.md, disposition every section — summarized into workstream.md, routed to a named home, or dropped by declaration — so nothing load-bearing dies with the archive.

## Move 2.5 — Cross-workstream cascade

Sweep this session — not just this workstream's recorded Learnings — for findings that belong to OTHER active workstreams or projects: a decision, a sibling fix, an open question raised in passing. Route each before archive: to another workstream's Backlog with provenance, or out as a handoff. Closure is the last chance; an insight not routed here dies in the tag.

An origin's word for a routing is not evidence that the routing exists. For every item recorded as absorbed, routed, or covered downstream — here or in the Decisions — grep the DESTINATION for it. If the receiving task or its Deletion Criteria do not name it, it is not routed: edit them so they do, then continue. This is cheap and it is the one check that catches an absorption declared at the origin and accepted nowhere else.

That check runs outward. Run it inward too, because other workstreams have already written down what they expect from this one. Before archive, `rg --hidden` the state tree and any docs for this workstream's name and its task-ID prefixes, then read each hit for which way it points. A reference naming one of these tasks as a SOURCE ("routed from ...") survives fine: the tag preserves what it points at. One naming it as a BLOCKER ("blocked on #XX-N") loses its referent the moment the directory is removed, and the next session has no way to know which tag to look in. Carry every live dependency to a durable home first — usually as its own task in the workstream that depends on it — and re-point the reference there.

## Move 3 — Deletion-criteria gate (USER decides)

For each deletion criterion, show the criterion and its evidence (file, commit, test output). A criterion declared covered by a downstream gate is satisfied only if that gate names it — check the destination, not the declaration; a criterion whose whole point is a judgment call is not discharged by a receiving task's mechanical checks. Unsatisfied criteria mean the workstream is not ready — say so and stop. When all criteria have evidence, ask the user to approve closure. Never self-certify.

## Move 4 — Archive

After approval, `ls` the workstream directory before removing anything: `workstream.md` is not always the only file there, and whatever else sits beside it needs a disposition (Move 2) rather than a discovery at `git rm`. Then:

1. Append to `.state/workstreams/ARCHIVE.md`: `- YYYY-MM-DD type/name -- <one-line outcome> (tag: ws/<name>)`
2. `git tag -m "<one-line outcome>" ws/<name>` on the final state commit
3. `git rm -r` the workstream directory
4. Reset `.state/ACTIVE.md` **only if it names the workstream being closed**: `workstream: none`, `task: none`, fresh Now/Next/Blockers. If it points somewhere else — most often a successor that has already inherited this workstream's residue — leave it and say in the closure notes that it was left, so the deviation is visible rather than inferred. Resetting a live pointer discards the next session's resume target immediately after the closure summary named it.
5. Commit
