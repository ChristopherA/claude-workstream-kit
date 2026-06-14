---
name: workstream-close
description: >-
  Closes a workstream: narrative summary, learning extraction with
  dispositions, deletion-criteria gate with evidence, then archive.
  WHEN: the user says "close workstream", "/workstream-close", or the
  backlog is complete and deletion criteria look satisfiable.
  WHEN NOT: work still in progress (keep working); pausing
  (set status: paused in workstream.md); creating (use /workstream-create).
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

Deploy any durable artifacts still living under `.state/` (docs, reference material, decisions other projects need) to their permanent homes. Decisions stay in workstream.md — the archive tag preserves them; ARCHIVE.md will carry the pointer. If a `notes.md` sits beside workstream.md, disposition every section — summarized into workstream.md, routed to a named home, or dropped by declaration — so nothing load-bearing dies with the archive.

## Move 2.5 — Cross-workstream cascade

Sweep this session — not just this workstream's recorded Learnings — for findings that belong to OTHER active workstreams or projects: a decision, a sibling fix, an open question raised in passing. Route each before archive: to another workstream's Backlog with provenance, or out as a handoff. Closure is the last chance; an insight not routed here dies in the tag.

## Move 3 — Deletion-criteria gate (USER decides)

For each deletion criterion, show the criterion and its evidence (file, commit, test output). Unsatisfied criteria mean the workstream is not ready — say so and stop. When all criteria have evidence, ask the user to approve closure. Never self-certify.

## Move 4 — Archive

After approval:

1. Append to `.state/workstreams/ARCHIVE.md`: `- YYYY-MM-DD type/name -- <one-line outcome> (tag: ws/<name>)`
2. `git tag -m "<one-line outcome>" ws/<name>` on the final state commit
3. `git rm -r` the workstream directory
4. Reset `.state/ACTIVE.md`: `workstream: none`, `task: none`, fresh Now/Next/Blockers
5. Commit
