---
from: deepcontext-dev
date: 2026-08-08
blocking: no
items: 1
---

## Deletion criteria that count a set retarget themselves when the set changes

A workstream review found the same defect in two deletion criteria and one
backlog task, all authored the same day and all correct when written.

Each read some variant of "both Decision Log Open Questions are resolved in
place or extracted to nodes." At authoring time the holding-zone file held
exactly two open questions, and both were the workstream's own. Later, one
of the two matured into a graph node and was removed from the log, which is
the documented lifecycle for that file. An unrelated question that had been
sitting in the same file since May then occupied the vacancy.

Nothing edited the criteria. They were still grammatical, still verifiable,
and now bound the workstream to resolving another project's work before it
could close. The defect is invisible on re-reading, because the sentence
that was true still parses as true -- you have to go count the set to see
that the members changed.

The fix that worked was enumeration: name the members, not the count. A
criterion phrased "the two questions THIS workstream raised: X, and Y" goes
visibly stale when X or Y moves, instead of silently resolving to whatever
occupies the slot. The same holds for any criterion phrased over a mutable
collection -- "all open handoffs", "every task in the phase", "both
remaining files."

Where this seems to belong: the `workstreams-rule` Deletion Criteria
section, which currently specifies the shape (`- [ ] <verifiable
condition>`) without saying what makes a condition durable. The
`workstream-close` skill already handles the adjacent problem well -- it
tells you to check the destination rather than trusting a declaration of
routing -- but that fires at closure, and by then the criterion has been
wrong for however long the set has been changing. This is an authoring-time
constraint, not a verification-time one.

Two things worth weighing against adopting it. The rule is already dense on
criteria, and this is a narrow failure that needs a long set-lifetime to
bite -- it may not earn its lines. And there is a cheaper framing available
if you want one: the review-time habit of re-reading each criterion against
its referent rather than for its wording, which needs no rule change at all
and would have caught this.

Provenance: `deepcontext-dev`, workstream `project/vocabulary-and-root-alignment`,
recorded there as L9. Installed kit version at the time was 0.8.0.
