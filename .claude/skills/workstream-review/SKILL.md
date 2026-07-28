---
name: workstream-review
description: >-
  Periodically re-coheres a workstream: detects drift between the backlog and
  the accumulated decisions/learnings, surfaces hidden framing assumptions,
  refreshes the critical path, audits cross-workstream task placement, and
  restructures the backlog behind user gates.
  WHEN: the user says "review workstream", "/workstream-review", the session-start
  hook flags drift, or a long-running workstream's backlog no longer matches what
  has been decided.
  WHEN NOT: executing the backlog (use /workstream-work); capturing one session's
  items (that is the capture sweep in the workstreams rule); creating
  (/workstream-create) or closing (/workstream-close) a workstream.
---

# Workstream Review

Work accumulates decisions and learnings faster than the backlog is restructured to match. Review is the periodic re-coherence pass that closes that gap — distinct from working the backlog and from the per-session capture sweep. Its output is a backlog that reflects what is now known, plus any cross-workstream findings routed to their homes. The user decides every substantive restructure; you make the case on evidence.

## When it is worth running

Drift signals, not a schedule: the session-start hook reports staleness; the backlog no longer reflects recent Decisions or Learnings; an intake stream has accreted; the critical path is implicit; or a never-closing workstream has gone several cycles without one. If none holds, say so and stop — a review that changes nothing is the wrong cadence, not a clean bill.

## Move 1 — Drift scan

Read workstream.md and ACTIVE.md. Compare the Backlog against the Decisions and Learnings: does every settled Decision show in task wording and status? Has any Learning's integration target rotted, already been satisfied, or — the subtler case — been captured but never applied? A Learning that names an integration target yet carries no disposition marker (DONE / routed / dropped), especially when its siblings all carry one, is presumptively unexecuted: verify it against the named file, not against the backlog's silence. Is the critical path derivable from the backlog, or only implicit? List the drift you find. If there is none, stop here and say so.

## Move 2 — Assumption surface

Name the framing assumptions the backlog carries — especially ones baked into task descriptions that a later Decision may have overtaken. For each load-bearing assumption that is unclear or possibly stale, put the analysis to the user and ask one question at a time. Do not restructure on an assumption you have not surfaced; an option set the user reframes in free text is the signal the framing, not the options, was wrong.

## Move 3 — Placement audit

For each open task, ask whether it belongs in this workstream or another. Misplaced tasks move to the right workstream's Backlog with provenance; cross-project findings go out as handoffs. Record what moved and why — a placement audit that finds nothing still names what it checked.

## Move 4 — Restructure (USER decides substantive changes)

Make the backlog reflect what is now known: add a critical-path note if the order is implicit; reframe task wording a Decision has overtaken (never renumber IDs); mark superseded Decisions in place; split an over-grown workstream rather than the file. Mechanical fixes (a rotted pointer, a stale status) proceed; substantive restructures are presented for approval with the drift evidence behind them.

## Optional move — Set-level deliverable review

When the workstream's deliverable is a multi-document set headed to an approval gate, review the SET, not just each document: per-document review structurally misses defects that live between documents — divergent vocabularies with no mapping, one document's acceptance gates depending on a sibling's deferred feature, a table breaching a sibling's stated doctrine, deferral loops where each document points a decision at the others, and cross-cutting claims no document verified. Run two passes before the gate: your own fresh-eye read of the whole set, front-to-back and back-to-front; and a fresh-context subagent prompted adversarially with no workstream priors, over the whole set. Calibrate the subagent's output: verify its quoted evidence before acting on it, and expect its severity ratings to run hot — the findings tend to be real, the labels inflated.

## Move 5 — Record

Commit the restructured state. Update ACTIVE.md with what the review changed and the next action. Route any cross-workstream work this surfaced before finishing — capture should not wait for the user to ask.
