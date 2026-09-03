# Workstreams

State-file formats and constraints for workstream tracking. Two file classes, both committed to git.

## .state/ACTIVE.md — per-project session state

```markdown
---
workstream: explore/kit-design
task: "#DR-2 - state-file formats"
updated: 2026-06-11
---
## Now
One or two lines: what is in flight.

## Next
The single next action on resume.

## Blockers
None
```

`workstream` is `type/name` or `none`; `task` is the current task pointer or `none`. Nothing follows a value on its line: the session-start hook reads each with `cut`, and a trailing comment becomes part of the path. Keep it under ~15 lines. It is session state, not a journal — git history is the journal. It carries the SCOPE of any goal a session derived — the task or phase and the turn bound — and never whether one is armed or cleared: the file cannot know that, and a status it asserts is a claim the next session cannot verify.

## .state/workstreams/\<type\>/\<name\>/workstream.md — one file per workstream

`type` is one of: `explore`, `feature`, `fix`, `project`, `maintain`, `docs`.

```markdown
---
name: kit-design
type: explore
status: active                         # active | paused | done
created: 2026-06-11
updated: 2026-06-11
---
## Purpose
Why this exists, scope boundaries, and what done means — one paragraph.

## Backlog
### Design (DR)
- [ ] #DR-1: Task description
- [ ] #G-DR: USER CHECKPOINT -- what the user approves here

## Decisions
### D1 (2026-06-11): Title
Decided X because Y. Rationale survives the archive; record the WHY.

## Learnings
- L1 (2026-06-11): Insight about HOW the work goes -- integration target: <where it should land>.

## Open Questions
- OQ-1: Question (resolve at #XX-N). Mark resolved in place: ~~question~~ RESOLVED <date> via #XX-N: answer. A resolution that became a standing constraint is also promoted to a Decision — this section reads as what is NOT yet settled and is skimmed that way, while Decisions are read before work; strike-through alone is for a question that resolved into an action already taken.

## Deletion Criteria
- [ ] Verifiable condition that must hold before this workstream is archived
```

Frontmatter is flat `key: value` only — it is parsed with `head` and `grep`, not a YAML library. `updated:` is informational: every date the session-start hook reports is DERIVED from git history (`git log -1 --format=%ct` on the file), because nothing in the kit writes the field back and a hand-maintained date drifts silently, always understating, so a reader who trusts it flags active work as stale. Where you do set it, it means the last SUBSTANTIVE change; a lagging value is not a defect to chase.

Prose in `.state/` files is HARD-WRAPPED at roughly 70 columns. This is the opposite of the one-line-per-paragraph rule for published prose, which exists because published text is pasted and re-wrapped downstream; state files are diffed and reviewed every session instead, and wrapping makes a diff line-scoped — an append to a one-line paragraph rewrites the whole line, while an append to a wrapped paragraph adds a few lines and deletes none. "Prose" means the narrative sections — Purpose, Decisions, Learnings, Open Questions, and ACTIVE.md's Now, Next and Blockers. **Backlog lines and Deletion Criteria are EXEMPT and stay on one line each**, however long they run, because every count the kit performs anchors at line start and a wrapped task line puts its own continuation beyond the reach of the pattern that found it. A workstream path, a task ID, a tag name or a file path is never split across lines: a wrap that would split one carries the whole token to the next line, since a search for the name misses a split one and a cross-reference check reports a phantom. The cost of wrapping runs one way — a multi-word grep returns FALSE EMPTIES, because any phrase has an even chance of straddling a break — so search one distinctive word rather than a phrase, or read the section; and anchor a string-replace on a single line, asserting exactly one match before replacing, which turns a silent false-empty into a loud failure at the point of edit.

## Conventions

- **Task IDs**: `#XX-N` where XX is a 2-3 letter phase code unique in the workstream — unique THERE and not across the project, so the same code may recur in two workstreams and denote different tasks in each, which is what makes naming the home a resolution requirement. For a code the template mints — the Completion phase and every `#G-` gate — recurrence is guaranteed, so they carry their home across a boundary unconditionally. IDs are stable references; never renumber. Sub-tasks `#XX-Na`; deferred `#XX-Nd` with a "Blocked by / unblocks when" line. A sub-task line sits at TOP LEVEL like any other and is never indented under its parent: every count the kit runs anchors at line start, and while the session-start hook tolerates leading indentation so such a line is not dropped, a goal condition or a scout that anchors strictly returns 0 and declares a phase finished while the indented task is still open. An ID is a pointer, not a name: every reference to one outside its own backlog line carries a few words saying what it is — `#G-DR (design review)`, "the schema-migration task, #MG-2" — in chat, in ACTIVE.md, in cross-references, in commit messages and in handoffs, the words for the reader rather than a copy of the task line; the backlog line itself is the exception, since its description follows the ID. Any per-workstream ID reads the same way — a Learning's `L7`, an Open Question's `OQ-4`, a Decision's `D12` — because every workstream numbers each from one — a Decision most of all, since policy is cited TO a Decision and a wrong resolution mis-attributes authority while reading as settled. Adopting the convention includes one pass over live content — ACTIVE.md, open backlog items, the critical path, current gate text — owed while live content still carries bare IDs and visibly done when it does not; bare IDs in completed-task notes and closed Decisions are frozen provenance and stay as written. A reference that crosses a workstream or project boundary carries its home as well as its name — `#MG-2 in feature/schema-migration (the column backfill)` — because the reader cannot scroll to a definition that is not in the file; when the home is a closed workstream, name its archive tag, the only resolvable pointer left, since the name survives the closure and the file does not. A reference that resolves to no defining line anywhere is a defect to fix at its source, not a name to invent. Name once per readable unit — a backlog item, an ACTIVE.md section, a commit message — not at every repetition inside one.
- **Gates**: `#G-XX` tasks are USER CHECKPOINTS: decided by the user, presented with a substantive summary and evidence, and autonomous sessions stop at them. The summary has to reach the user before the decision does — finish the stage's tool calls first and let the summary open the message that carries the question — since a gate decided against a summary the user never saw is not a gate. A summary built from bare IDs is not one either: if a sentence loses its meaning when the IDs are stripped out, it carried no content of its own, and that is won or lost at the SOURCE, because a summary inherits the density of the text it is drawn from — deletion criteria and gate task descriptions are read aloud to a decider, so they carry names rather than pointers, and the tell is the user asking what the codes are, at which point the fix is the criteria, not the sentence. An option description at a gate carries an outcome claim like any other sentence and gets the same check before it is offered: it is written last, compressed to fit a menu, and is the one part of a decision the user cannot check against anything, so it draws the least scrutiny, from its author most of all. A gate whose exit criterion is met before it is presented records that on the gate line as `SATISFIED <date>`: the session-start hook flags the row GATE-READY and the status skill lists it first, so a decided-but-unpresented gate cannot sit behind an accreting backlog with a truthful open count beside it.
- **Checkboxes** are the progress mechanism: `- [ ]` open, `- [x]` done with a one-line completion note (date + evidence). Counts anchor on the task-ID form and tolerate leading indentation, `grep -cE '^ *- \[ \] #'` — a bare `^- \[ \]` also matches Deletion Criteria, which are standing conditions rather than backlog items, so it overstates remaining work by however many criteria the workstream carries. Unmet criteria are counted in their own section and reported separately.
- **Decisions record reasoning**, not just outcomes. A decision that routes work to a future task updates that task's description in the same commit, or creates the task when none exists — the clause otherwise presumes a task that is there and a writer who will return to it — and a gate deciding N items writes N lines before the Decision is recorded. When the destination is a completion-phase task, name the workstream the work will live in rather than the task, since that phase ends by deleting the directory; findings get routed out of a closing workstream as a matter of course, and a decision parked in one is the case that gets missed, because it was correctly written where it was taken. A decision that ABSORBS another workstream — its scope carried on here rather than finished there — closes that workstream and runs `/workstream-close` on it, whose narrative maps each open task to the task that now holds it, since a container-level declaration checks nothing at the task level and the tasks vanish when the directory is removed. When a later decision supersedes an earlier one, mark the earlier in place at that moment (`~~superseded by D7~~`) so a stale decision never reads as current. A decision that retires or replaces a shared artifact — a path, a component, a convention other work names — greps the state tree for that artifact in the same commit and marks every hit superseded in place, including hits in completed tasks and other workstreams' Decisions; a shared artifact has TWO names, its ID and its description, and the sweep runs on both, since the ID sweep is the cheap half and the half that reads as complete. It reaches only what the author knows about; the detector for the rest is comparative, at review time. A decision to HOLD for another workstream's task reads that workstream's STATUS and not only the task's checkbox: an open task in a paused workstream is a wish rather than a dependency with a date, and a hold that names one silently becomes the gate on everything behind it. Say the pause out loud in the hold, or pair the hold with a decision to resume; it costs one look at the frontmatter of the file the task already cites.
- **Learnings are insights, not work items.** Route work to the Backlog; give each learning an integration target — a file, a commit, or a task, and nothing else: another Learning moves the insight nowhere, and an Open Question resolves into a decision rather than an artifact, so there is no file for the insight to land in and no moment anyone notices it did not; a target naming none of the three is not a routing. Send the finding to a file and the question to whoever decides it. Disposition it with `/workstream-extract`, at closure — or, in a never-closing workstream, the moment it is resolved (see Constraints).
- **A deletion criterion referencing a set this workstream does not own** names what limits it to this workstream's members; an unscoped reference silently retargets when that set changes. A deletion criterion whose verification depends on a decision taken outside this workstream is a wait, not a test, and it will still be a wait at closure. Prefer writing it as something checkable from inside; where that is not possible, closure amends it to what IS checkable and lodges the real check as an obligation in the task that owns the decision, so the check runs whether or not this workstream still exists. Ruling such a criterion satisfied on stated grounds is the expensive option: a generous reading is precedent, and the next stale criterion inherits it; amendment leaves no such residue. Flag an outside-dependent criterion when it is WRITTEN, so closure has a decision to take instead of a surprise to absorb.
- **Cite source by name, not by line.** A `file.c:1419` in a Decision or task is a claim about a file that is still being edited, and it rots with no event marking it — the line still exists and now says something else, so the citation reads as resolvable and is wrong. Cite the function, symbol, or a distinctive quoted phrase; those survive the edit that moves them. A count, file list, or enumeration cited in a LIVE task description carries its as-of date and the command that re-derives it inline, beside the number — a date says the number is old, a command says how to replace it — mandatory where the cited target is one other sessions write, since such a target can drift inside the session that measured it; and a session that keeps working on the thing it measured re-derives the number at the END of its work, because the author is the one who invalidates it and a date stamped today warns nobody. A measurement already written inside a completed task record is frozen provenance and stays as written; note once that it is historical rather than rewriting it. At a gate, RE-RUN the measurement and cite the fresh figure beside the frozen one, saying which is which, since a mismatch reads as a regression rather than as a date.
- **`.state/workstreams/ARCHIVE.md`**: closure appends one line per workstream: `- YYYY-MM-DD type/name -- outcome (tag: ws/<name>)`. The cited tag has to reach the remote, or the citation resolves only on the machine that closed the workstream — pushing the tag is its own step at closure, separate from the archive commit. A closure line that records a measurement says where the measured artifact is preserved, so the next baseline is findable on purpose rather than by accident. Cite the ledger by its full path: an unqualified "ARCHIVE.md" can resolve to a stale duplicate elsewhere under `.state/`, and a check run against the wrong file reports correctly-recorded closures as missing.
- **A convention owes a pass over what is already written.** A change describing how to WRITE something — a naming form, a citation style, a record shape — governs text that already exists, so shipping it includes one pass over live content and is not finished when the wording lands — for any convention, an extension to one already adopted included; mechanism changes carry no such shadow, since they are inert until a session next runs. A migration owes the same pass: folding files into one moves the content and none of the references to it, so sweep the repo — outside `.state/` too — for the absorbed filenames, and read the last heading before each numbered run to see whether the numbering restarts across it. A merge is verified by resolution and placement, not by census: count checks prove arrival, and arrival was never the thing at risk.

## Which check a claim wants

Wherever a session verifies a claim, it first names what KIND of claim it is and picks the check from the kind. "Verify" with no named target resolves to re-reading the record by default, because re-reading is what is in front of you and it feels like checking — and the session that has just written a claim is the least able to see which kind it wrote. The kinds that recur, and the check each wants:

- **A completion note's evidence** — read what the cited suite or command actually asserts, or write the missing assertion. A passing run is true and says nothing about whether the behaviour is among what it tests.
- **A recorded count, site inventory, or enumeration** — re-derive it from the tree using the behaviour's own vocabulary; it records where the author looked, not where the thing is. An enumeration one item short reads as complete, because every item in it is true and nothing marks the absence, so hold the requirement's list against the system's list and count.
- **State that refers to other state** — a citation, an ID, a path — open the cited place. Counting entities proves arrival, never resolution or placement.
- **A defect list about pure code** — execute the code against the format's full case set; reading supplies its inputs from the same head that wrote the list.
- **A document sweep** — refuse to scope it to the diff; the neighbours' debts are what it finds. Contradictions and omissions need different checks: a contradiction announces itself beside the behaviour, an omission does not.
- **A task description asserting external state** — re-read the world it describes before working it, and read `.state/workstreams/ARCHIVE.md` for a closure that already produced what the task proposes to produce.
- **A summary sentence** — a tool's, a probe's, or your own — run the one authoritative command. This covers the claims a session AUTHORS as much as the ones it inherits: a task written an hour after the finding it rests on can still invent the mechanism, and a summary spreads faster than a measurement because nobody re-measures a summary.

Then say what the chosen check CANNOT see, and decide whether that matters for this change — a change to what an artifact structurally contains is not verified by a check that only reads its contents. And validate the instrument before trusting its verdict: fire it once at a case it must catch and once at a case it must let through, and after any sweep whose result will be acted on, vary one input that must change the count and confirm it does. A checker that has only ever agreed with you has been run, not tested, and the tell of a broken one is a count that did not move.

## Constraints

- Never auto-start work after creating a workstream; the user chooses when work begins.
- Durable artifacts (docs, code, reference material) live in the repo proper from the start — never inside `.state/`. Optional `notes.md` beside workstream.md holds session-scoped research only; `/workstream-extract` dispositions every notes.md section (summarized into workstream.md, routed to a named home, or dropped by declaration) and moves anything durable to its permanent home, so nothing load-bearing dies with the archive.
- Durable insights leave `.state/` before archive: every Learning is applied to a named file, sent as a handoff, or dropped with stated rationale. Applied to a file is terminal only for a file this project governs; where something else writes the file — an installer, a generator, a vendored copy, an upstream template — the disposition is provisional until the change reaches whatever governs the file, and the entry names that governing artifact rather than only the path, because a record reading DONE over a clause the next sync reverts is worse than an open one. Executed by `/workstream-extract`, which `/workstream-close` runs before its gate.
- Never-closing workstreams (`maintain`, or any without a closure milestone) extract each Learning to its destination the moment it is resolved, not at a closure that never comes, and re-check their standing-health Deletion Criteria each review cycle. Both are `/workstream-extract`: a workstream with no ending has no other moment when they happen.
- One tracker per tier: workstream.md Backlog for cross-session work; native Tasks/plan mode within a session. Never both for the same items.
- State files are committed in the session that changes them — uncommitted state does not survive to other machines or future triage.
- A workstream.md that outgrows a few hundred lines is a signal to split the workstream, not the file. Judge that by reading cost rather than line count: a completion note is one line however long it runs, so a file can sit inside a line threshold while having become too large to read in a single pass. The session-start hook detects the size; `/workstream-extract` drains and archives completed records in place, and `/workstream-review` decides a split when what grew is live scope rather than finished work.
- Size an `explore` workstream to a short arc — research to a checkpoint, then close — not the multi-phase backlog a `project` workstream carries. An oversized explore container invites scope drift, where real work happens untracked beside a stalled exploration task; when findings are ready to act on, close the exploration and open a `feature` or `project` workstream for the build.
- Scripts that touch `.state/` normalize to absolute paths at entry.

## Capture sweep

Before a session boundary (`/clear`, `/compact`, `/exit`) and at closure, run a three-question sweep over the session against the durable files — capture should not depend on the user asking:

1. **Detection** — what decided, learned, or flagged this session is not yet in `workstream.md`, `ACTIVE.md`, memory, or a commit? And what ARRIVED: a handoff filed into `.state/handoffs/` while the session ran is already a commit, so this question cannot see it — list the inbox and read `git log` for commits the session did not author before answering, since the session-start hook reported the inbox once and cannot fire again.
2. **Cascade** — for each, where does it belong: this workstream, another workstream's Backlog, another project (a handoff), or a named file?
3. **Synthesis** — what general rule or pattern do this session's instances suggest, and does it extend or supersede an existing Decision or Learning?

Route each finding before crossing the boundary. The sweep is three questions, not a process; it surfaces what capture-as-you-go misses — the cross-cutting and synthesis-level items that appear only when you step back.

## Handoffs — .state/handoffs/

Cross-project transfer: `from-<source>-<YYYYMMDD-HHMMSS>.md`, flat frontmatter (`from`, `date`, `blocking`, `items`), then self-contained items — the receiver cannot see the sender's conversation or repo. Receive = triage each item (do now / route to a workstream backlog with provenance / decline with rationale), then delete the file. The session-start hook reports inbox count and oldest age; an aging inbox is state to reconcile, not background noise.
