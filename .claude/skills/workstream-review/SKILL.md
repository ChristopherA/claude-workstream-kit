---
name: workstream-review
description: >-
  Periodically re-coheres a workstream: detects drift between the backlog and
  the accumulated decisions/learnings, scans for what is recorded and no longer
  true, surfaces hidden framing assumptions, refreshes the critical path,
  audits cross-workstream task placement, and restructures the backlog behind
  user gates.
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

Those are signals that the PLAN has drifted. A workstream whose RECORD has not been drained — resolved Learnings carrying no disposition, a completed phase, durable artifacts still under `.state/`, the hook's SIZE line — is `/workstream-extract`'s case, not this one. The two are independent: either can fire alone, and when both do, run both. Do not restructure a backlog to relieve a file that is merely undrained; the reader's problem is the accumulation, and moving live tasks around does not touch it.

## Move 1 — Drift scan

Read workstream.md and ACTIVE.md. Compare the Backlog against the Decisions and Learnings: does every settled Decision show in task wording and status? Has any Learning's integration target rotted, already been satisfied, or — the subtler case — been captured but never applied? A Learning that names an integration target yet carries no disposition marker (DONE / routed / dropped), especially when its siblings all carry one, is presumptively unexecuted: verify it against the named file, not against the backlog's silence. Is the critical path derivable from the backlog, or only implicit? List the drift you find. If there is none, stop here and say so.

Several undispositioned Learnings at once is not drift but accretion, and the remedy is `/workstream-extract` rather than a restructure. Hand it over and continue the scan; the two passes compose in either order.

## Move 2 — Still-true scan

Move 1 asks what is new and unrecorded. This asks the opposite question: what is recorded and no longer true. They are not the same pass, and the second is the one nothing else runs.

Staleness has no event. A Decision that becomes false is not edited, and a file the world moved past does not change, so there is no diff, no timestamp, and nothing to notice at the moment of failure — which makes it invisible to any check that reads an artifact on its own terms. The detector has to be comparative, and Move 1's comparison is internal: the backlog against this same file's Decisions and Learnings. Widen the frame. Take each Decision's and completed task's date, and ask what has been decided, shipped, deleted, or committed SINCE — in the repo, in sibling workstreams, in other projects this one names.

Start where it is cheapest: a Decision naming a filesystem path is checkable in one command, and paths are what move. Then widen to named components, conventions, and external commitments. Mark every stale hit in place at the moment you find it (`~~superseded by ...~~`, or a dated note saying what overtook it) rather than collecting them for a later pass.

The exposed case is the workstream nobody is reading — paused, idle, or merely quiet — which cannot mark what it does not see and is also the one most likely to be cited from elsewhere rather than opened. If this review covers a workstream that names another's artifacts, check those too.

## Move 3 — Assumption surface

Name the framing assumptions the backlog carries — especially ones baked into task descriptions that a later Decision may have overtaken. For each load-bearing assumption that is unclear or possibly stale, put the analysis to the user and ask one question at a time. Do not restructure on an assumption you have not surfaced; an option set the user reframes in free text is the signal the framing, not the options, was wrong.

## Move 4 — Placement audit

For each open task, ask whether it belongs in this workstream or another. Misplaced tasks move to the right workstream's Backlog with provenance; cross-project findings go out as handoffs. Record what moved and why — a placement audit that finds nothing still names what it checked.

## Move 5 — Restructure (USER decides substantive changes)

Make the backlog reflect what is now known: add a critical-path note if the order is implicit; reframe task wording a Decision has overtaken (never renumber IDs); mark superseded Decisions in place; split an over-grown workstream rather than the file. Splitting is this skill's call and a substantive one — but try `/workstream-extract` first when the growth is completed records rather than live scope, since a workstream that is merely undrained does not need two identities. Mechanical fixes (a rotted pointer, a stale status) proceed; substantive restructures are presented for approval with the drift evidence behind them.

## Optional move — Set-level deliverable review

When the workstream's deliverable is a multi-document set headed to an approval gate, review the SET, not just each document: per-document review structurally misses defects that live between documents — divergent vocabularies with no mapping, one document's acceptance gates depending on a sibling's deferred feature, a table breaching a sibling's stated doctrine, deferral loops where each document points a decision at the others, and cross-cutting claims no document verified. Run two passes before the gate: your own fresh-eye read of the whole set, front-to-back and back-to-front; and a fresh-context subagent prompted adversarially with no workstream priors, over the whole set. Calibrate the subagent's output: verify its quoted evidence before acting on it, and expect its severity ratings to run hot — the findings tend to be real, the labels inflated.

## Move 6 — Record

Commit the restructured state. Update ACTIVE.md with what the review changed and the next action. Route any cross-workstream work this surfaced before finishing — capture should not wait for the user to ask.
