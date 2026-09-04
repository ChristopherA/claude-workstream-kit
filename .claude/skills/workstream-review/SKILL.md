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

Invoked bare, review the ACTIVE workstream; where that one was reviewed this session or the last, present the candidates instead — each workstream with the signal it shows (staleness, an undrained record, an accreted intake, an implicit path) — and let the user pick, rather than re-reviewing the one just done.

## Move 1 — Drift scan

Read workstream.md and ACTIVE.md. Where a fact is stated in more than one place — a count in the Purpose and in a task, a status in ACTIVE.md and in a Decision, a critical path in a paragraph and in a gate's agenda — read every copy, and prefer collapsing the copies to re-syncing them: a critical-path paragraph rewritten by one review was stale again twenty-four hours later, and the pass that had just corrected five such claims missed the same class two hours on. Ask whether any open gate's exit criterion is already met, and mark the line `SATISFIED <date>` when it is, so the hook flags it; the marker was absent from ten files carrying twelve open gates, one of whose own text said in plain English that both things it held had resolved. Compare the Backlog against the Decisions and Learnings: does every settled Decision show in task wording and status? Does every task a Decision routes work to EXIST — a Decision that says "as a separate task" with no line minted is drift with no line to show it, and a gate that decided many items and updated none of their lines leaves them reading as undecided. Has any Learning's integration target rotted, already been satisfied, or — the subtler case — been captured but never applied? A Learning's disposition is a fact about ANOTHER file, so no pattern over this one can establish it. A missing marker is presumptive evidence of an unexecuted routing — especially when its siblings all carry one — but a PRESENT marker is not evidence of anything: "applied", "routed" and "done" occur in ordinary prose about a learning's own subject, so a scan that scores their presence scores the discussion with them. Verify every entry against the artifact it names, in both directions, and read the entries rather than counting them. That is the rule's "which check a claim wants" at one site: state referring to other state is checked by opening the cited place, and a check that cannot see the other file has to say so. Is the critical path derivable from the backlog, or only implicit? And is it FOLLOWED: compare what the path says leads against what actually got checked off, and when — a path can be derivable and still be the wrong order, and this comparison needs no view on whether the sessions were disciplined, which is what otherwise stalls the question for another cycle. List the drift you find. If there is none, stop here and say so.

Several undispositioned Learnings at once is not drift but accretion, and the remedy is `/workstream-extract` rather than a restructure. Hand it over and continue the scan; the two passes compose in either order.

## Move 2 — Still-true scan

Move 1 asks what is new and unrecorded. This asks the opposite question: what is recorded and no longer true. They are not the same pass, and the second is the one nothing else runs.

Staleness has no event. A Decision that becomes false is not edited, and a file the world moved past does not change, so there is no diff, no timestamp, and nothing to notice at the moment of failure — which makes it invisible to any check that reads an artifact on its own terms. The detector has to be comparative, and Move 1's comparison is internal: the backlog against this same file's Decisions and Learnings. Widen the frame. Take each Decision's and completed task's date, and ask what has been decided, shipped, deleted, or committed SINCE — in the repo, in sibling workstreams, in other projects this one names.

Completion has no event either. Read the Purpose's stated done condition and each Deletion Criterion against current evidence, because a done condition can become satisfied with nothing firing, after which the container keeps accreting follow-on rows that quietly redefine what it is. A workstream whose done condition is met is a closure candidate, not a home for the next arc — say so, and route the arc to its own workstream.

Read state against the project's DESIGNATED-AUTHORITY documents as well as against the world — the ADR, the design note, the spec — in both directions, because a deletion criterion and an ADR can contradict each other with neither referencing the other, and sessions re-read the criterion while taking the ADR as given: across two such cases the criterion won once and the ADR was simply wrong once. Authority is not accuracy, and neither is recency. And keep the two operations apart: verifying that a premise is STILL TRUE is a measurement, while concluding that it therefore NO LONGER MATTERS is not — a review re-measured a premise correctly, downgraded its consequence on evidence that was a workaround at one call site, and six days later the failure the task had predicted in the sentence below cost a fleet run.

Start where it is cheapest: a Decision naming a filesystem path is checkable in one command, and paths are what move. Then widen to named components, conventions, and external commitments. Mark every stale hit in place at the moment you find it (`~~superseded by ...~~`, or a dated note saying what overtook it) rather than collecting them for a later pass.

The exposed case is the workstream nobody is reading — paused, idle, or merely quiet — which cannot mark what it does not see and is also the one most likely to be cited from elsewhere rather than opened. If this review covers a workstream that names another's artifacts, check those too.

**Check that cited IDs still resolve** — task IDs, and `D<n>`, `L<n>` and `OQ-<n>` sent with a home, by the same test and the same false-positive guard; the case that prompted it was a task citing D17 in a workstream carrying thirteen Decisions, where D17 belonged to one archived three weeks earlier and reachable only at its tag. A reference of the form `#XX-N` reads as resolvable whether or not anything defines it, so this rots exactly like a stale path and with the same absence of an event. The question is NOT "is this ID defined in this project" -- run that and you drown, because the convention explicitly endorses references that cross into other workstreams, into closed ones reachable only by archive tag, and into other projects entirely. The question is **does the reference name a home, and does that home contain it**. A bare ID that names no home is the defect the conventions describe. A homed one whose home exists and holds the task is correct. The case that bites is between them: a reference naming a home that EXISTS while the task inside it does not, which is the closed-or-paused workstream surviving the thing it named.

Two matcher details decide whether this is usable:

- Treat any word boundary after the ID as a definition, not just a colon. A backlog that writes its completed tasks as `- [x] #XX-N (dated note in parentheses)` is conforming, and a matcher demanding `#XX-N:` scores every one of them as undefined.
- Require the ID to contain a digit, or every metavariable in the prose -- `#XX-N`, `#RS-N`, `#SW-n` -- is reported as a dangling reference.

Without both, most of what the check reports is false and the report gets ignored, which is worse than not running it; with both, nearly every undefined-here reference is legitimately homed and the true defects are few. **Report classes, never a count**: "one reference names a home that does not contain it" is actionable, and "26 unresolved IDs" is noise that will be dismissed on sight.

The same care applies to any probe over a workstream.md, because the format defeats line-oriented tools by design: a completion note is one line however long it runs, a Learning or Decision spans many lines, and record prose is full of ID-shaped text that reads like a definition. Parse records as blocks delimited by their leading marker rather than by line; anchor an ID match to line start, since a coverage or completeness check that scores occurrence scores the discussion along with the assignment; and treat any classification count as unverified until one known-positive case has been run through the same probe and come out right. A first-line-only scan, an unanchored ID regex, and a multi-file `grep -q` with an optional file absent each return a plausible wrong answer rather than an error.

## Move 3 — Assumption surface

Name the framing assumptions the backlog carries — especially ones baked into task descriptions that a later Decision may have overtaken. For each load-bearing assumption that is unclear or possibly stale, put the analysis to the user and ask one question at a time. Do not restructure on an assumption you have not surfaced; an option set the user reframes in free text is the signal the framing, not the options, was wrong.

## Move 4 — Placement audit

For each open task, ask whether it belongs in this workstream or another. Ask also what its wording was DERIVED from — a symptom or a diagnosis. A membership test cannot catch a task written from the symptom, because the wording it tests is the artifact carrying the error: a failure seen on three machines reads as machine state and routes to a per-machine home, when the deliverable was a schema change. Misplaced tasks move to the right workstream's Backlog with provenance; cross-project findings go out as handoffs. Record what moved and why — a placement audit that finds nothing still names what it checked.

## Move 5 — Restructure (USER decides substantive changes)

Make the backlog reflect what is now known: add a critical-path note if the order is implicit — ORDER ONLY, never status or measurements, which go stale within a day and belong on the phase's gate line where the gate's own dated entries carry them: a note re-derived at a morning gate with 'Next: BUILD' and section percentages was false by evening; reframe task wording a Decision has overtaken (never renumber IDs); mark superseded Decisions in place; split an over-grown workstream rather than the file. Splitting is this skill's call and a substantive one — but try `/workstream-extract` first when the growth is completed records rather than live scope, since a workstream that is merely undrained does not need two identities. Mechanical fixes (a rotted pointer, a stale status) proceed; substantive restructures are presented for approval with the drift evidence behind them. Moving items out of a workstream fixes the population and not the process that deposited them, so ask what put them there and whether it will do so again before the next review. Where the answer is a recurring process — a scheduled watch, an inbox, an upstream feed — the restructure is incomplete until that process has a destination that exists, and creating the destination comes before wiring the routing to it; the tell is a backlog task carrying its own relocation instructions, which is a task saying it has no home and expecting a future session to notice. When a task is minted from a measurement — a count, an absence, a "none" — record the command it was measured with in the task, so the executor can re-run it rather than re-invent it, and say that the executor re-measures by a DIFFERENT method before acting: a minted task reads as a specification, two records written from one sweep read as corroboration, and re-running the same wrong pattern reproduces the same wrong answer.

## Optional move — Set-level deliverable review

When the workstream's deliverable is a multi-document set headed to an approval gate, review the SET, not just each document: per-document review structurally misses defects that live between documents — divergent vocabularies with no mapping, one document's acceptance gates depending on a sibling's deferred feature, a table breaching a sibling's stated doctrine, deferral loops where each document points a decision at the others, and cross-cutting claims no document verified. Run two passes before the gate: your own fresh-eye read of the whole set, front-to-back and back-to-front; and a fresh-context subagent prompted adversarially with no workstream priors, over the whole set. Where the documents delegate to each other, have that reader judge each delegating document BEFORE opening its delegate, and say what it could not execute alone — that is the reader's actual situation, and a verifier that reads everything first reconstructs the author's context and finds nothing, since every seam gap was filled from the other document sitting in context. Calibrate the subagent's output: verify its quoted evidence before acting on it, and expect its severity ratings to run hot — the findings tend to be real, the labels inflated.

## Move 6 — Record

Commit the restructured state. Update ACTIVE.md with what the review changed and the next action. Name every reference that crosses a workstream or project boundary with a few words saying what it is (workstreams-rule, Task IDs), in ACTIVE.md and in what you say to the user alike. Route any cross-workstream work this surfaced before finishing — capture should not wait for the user to ask.
