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

Work accumulates decisions and learnings faster than the backlog is restructured to match. Review is the periodic re-coherence pass that closes that gap — distinct from working the backlog and from the per-session capture sweep. Its output is a backlog that reflects what is now known, plus any cross-workstream findings routed to their homes. The user decides every substantive restructure; you make the case on evidence. The reason behind each move is in `references/failures.md` under the move's heading; read it when a move is doubted.

## When it is worth running

Drift signals, not a schedule: the session-start hook reports staleness; the backlog no longer reflects recent Decisions or Learnings; an intake stream has accreted; the critical path is implicit; or a never-closing workstream has gone several cycles without one. If none holds, say so and stop — a review that changes nothing is the wrong cadence, not a clean bill.

Those are signals that the PLAN has drifted. A workstream whose RECORD has not been drained — `python3 .claude/scripts/workstream-record.py fires <project root> <type/name>` names the symptoms — is `/workstream-extract`'s case; the two are independent, either can fire alone, and when both do, run both. Do not restructure a backlog to relieve a file that is merely undrained — moving live tasks around does not touch the accumulation.

Takes an optional `type/name`. Invoked bare, review the ACTIVE workstream; where that one was reviewed this session or the last, present the candidates instead — each workstream with the signal it shows — and let the user pick.

## Move 1 — Drift scan

Read workstream.md and ACTIVE.md.

- Where a fact is stated in more than one place, read every copy, and prefer collapsing the copies to re-syncing them — a re-synced copy is stale again within a day.
- Ask whether any open gate's exit criterion is already met, and mark the line `SATISFIED <date>` by hand when it is, so the hook flags it — a gate's own text can say both things it held have resolved while nothing marks it.
- Read each open gate block WHOLE before it is presented: an insertion into a wrapped block can land between the two halves of a sentence, and every count still passes — the line above ends in a full stop and the continuation opens lowercase. `workstream-record.py fires` names the shape as `severed sentence` with its line; a lowercase proper noun is the false positive to expect, and a gate line that ended mid-clause for five days is the miss.
- Compare the Backlog against the Decisions and Learnings: does every settled Decision show in task wording and status? Does every task a Decision routes work to EXIST — a Decision that says "as a separate task" with no line minted is drift with no line to show it, and a gate that decided many items and updated none of their lines leaves them reading as undecided.
- Has any Learning's integration target rotted, been satisfied, or been captured but never applied? A Learning's disposition is a fact about ANOTHER file: a missing marker is presumptive evidence of an unexecuted routing, a present marker is evidence of nothing, so verify every entry against the artifact it names, in both directions, and read the entries rather than counting them. `workstream-record.py record` scores the markers; it cannot see the other file, so say what the scoring did not check.
- Is the critical path derivable from the backlog, or only implicit? And is it FOLLOWED — compare what the path says leads against what actually got checked off, and when; `workstream-record.py decay <project root>` names every open task minted after the paragraph's last edit — this needs no view on whether the sessions were disciplined.

List the drift you find. If there is none, stop here and say so. Several undispositioned Learnings at once is accretion, not drift: hand it to `/workstream-extract` and continue the scan.

## Move 2 — Still-true scan

Move 1 asks what is new and unrecorded. This asks what is recorded and no longer true — the pass nothing else runs, because staleness has no event: nothing changes at the moment a Decision becomes false, so the detector has to be comparative, and wider than this file. Take each Decision's and completed task's date, and ask what has been decided, shipped, deleted, or committed SINCE — in the repo, in sibling workstreams, in other projects this one names.

- Completion has no event either: read the Purpose's done condition and each Deletion Criterion against current evidence — a met done condition makes the workstream a closure candidate, not a home for the next arc; say so and route the arc to its own workstream.
- Read state against the project's DESIGNATED-AUTHORITY documents — the ADR, the design note, the spec — in both directions — a criterion and an ADR can contradict each other with neither referencing the other, and authority is not accuracy. Keep verifying that a premise is STILL TRUE (a measurement) apart from concluding it NO LONGER MATTERS (not one) — a downgraded consequence cost a fleet run six days later.
- Start where it is cheapest: `workstream-record.py paths <project root>` lists every path a Decision or open task names with whether it exists — paths are what move. Read its `missing` list, not each row: a bare one-segment name (`CLAUDE.md`, `rules/`) sits under `bare` with `exists` null because it could resolve anywhere, and fourteen such rows once read as rot in a file that had none. Then widen to named components, conventions, and external commitments. Mark every stale hit in place at the moment you find it (`~~superseded by ...~~`, or a dated note saying what overtook it) rather than collecting them for a later pass.
- Widen by AGGREGATE as well as by date: for any task family that recurs per release or per cycle — a re-install sweep, a per-consumer push gate, a periodic re-check — count the cycles since the last review, count what each touched, and name the members that were dormant across them, BEFORE judging whether the phase still fits. A recurring cost is recorded as one done task at a time and rotated away one at a time, so no single record ever shows the sum: seven full sweeps across sixteen consumers in five days surfaced only when a holistic read re-derived every consumer's commit log.
- The exposed case is the workstream nobody is reading — paused, idle, or merely quiet — so if this review covers a workstream that names another's artifacts, check those too.
- Check that cited IDs still resolve: `workstream-record.py refs <project root>` classifies every task, D, L and OQ reference in live content as defined here, homed and resolved, homed with the home missing, homed with the home lacking it, or unhomed — the question is never "is this ID defined in this project" but "does the reference name a home, and does that home contain it". Read the classes, never a count: a bare unhomed ID is the defect the conventions describe, and a home that EXISTS while the ID inside it does not is the closed-or-paused workstream surviving the thing it named. The sub-command carries the two matcher details that make the check usable (any word boundary after the ID is a definition; an ID must contain a digit).
- Any probe over a workstream.md beyond the sub-commands reads blocks, not lines: parse records by their leading marker, anchor an ID match to line start, and run one known-positive case through any classification count before believing it — `workstream-record.py self-check` fires the record's own patterns.

## Move 3 — Assumption surface

Name the framing assumptions the backlog carries — especially ones baked into task descriptions that a later Decision may have overtaken. For each load-bearing assumption that is unclear or possibly stale, put the analysis to the user and ask one question at a time. Do not restructure on an assumption you have not surfaced; an option set the user reframes in free text is the signal the framing, not the options, was wrong.

## Move 4 — Placement audit

For each open task, ask whether it belongs in this workstream or another, and what its wording was DERIVED from — a symptom or a diagnosis — since a membership test cannot catch a task written from the symptom. Misplaced tasks move to the right workstream's Backlog with provenance; cross-project findings go out as handoffs. Record what moved and why — a placement audit that finds nothing still names what it checked.

## Move 5 — Restructure (USER decides substantive changes)

Make the backlog reflect what is now known:

- Add a critical-path note if the order is implicit — ORDER ONLY, never status or measurements, which belong on the phase's gate line where its dated entries carry them — a note with status was false by evening.
- Reframe task wording a Decision has overtaken (never renumber IDs); mark superseded Decisions in place.
- Split an over-grown workstream rather than the file — this skill's call, and a substantive one — but try `/workstream-extract` first when the growth is completed records rather than live scope.
- Mechanical fixes (a rotted pointer, a stale status) proceed; substantive restructures are presented for approval with the drift evidence behind them.
- Moving items out fixes the population, not the process that deposited them: ask what put them there and whether it will do so again before the next review. Where the answer is a recurring process, the restructure is incomplete until that process has a destination that exists, created before the routing is wired — a task carrying its own relocation instructions is a task saying it has no home.
- When a task is minted from a measurement — a count, an absence, a "none" — record the command it was measured with in the task, and say that the executor re-measures by a DIFFERENT method before acting — re-running the same wrong pattern reproduces the same wrong answer.

## Optional move — Set-level deliverable review

When the workstream's deliverable is a multi-document set headed to an approval gate, review the SET, not just each document — per-document review structurally misses the defects that live between documents. Run two passes before the gate: your own fresh-eye read of the whole set, front-to-back and back-to-front; and a fresh-context subagent prompted adversarially with no workstream priors, over the whole set, judging each delegating document BEFORE opening its delegate and saying what it could not execute alone — a verifier that reads everything first reconstructs the author's context and finds nothing. Verify the subagent's quoted evidence before acting on it, and expect its severity ratings to run hot.

## Move 6 — Record

Commit the restructured state. Update ACTIVE.md with what the review changed and the next action. Name every reference that crosses a workstream or project boundary with a few words saying what it is (workstreams-rule, Task IDs), in ACTIVE.md and in what you say to the user alike. Route any cross-workstream work this surfaced before finishing — capture should not wait for the user to ask.
