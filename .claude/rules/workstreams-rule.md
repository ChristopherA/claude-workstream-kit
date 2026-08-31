# Workstreams

State-file formats and constraints for workstream tracking. Two file classes, both committed to git.

## .state/ACTIVE.md — per-project session state

```markdown
---
workstream: explore/kit-design        # type/name, or "none"
task: "#DR-2 - state-file formats"    # current task pointer, or "none"
updated: 2026-06-11
---
## Now
One or two lines: what is in flight.

## Next
The single next action on resume.

## Blockers
None
```

Keep it under ~15 lines. It is session state, not a journal — git history is the journal.

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
- OQ-1: Question (resolve at #XX-N). Mark resolved in place: ~~question~~ RESOLVED <date> via #XX-N: answer.

## Deletion Criteria
- [ ] Verifiable condition that must hold before this workstream is archived
```

Frontmatter is flat `key: value` only — it is parsed with `head` and `grep`, not a YAML library. `updated:` is informational: every date the session-start hook reports is DERIVED from git history (`git log -1 --format=%ct` on the file), because nothing in the kit writes the field back and a hand-maintained date drifts silently. The drift runs one way — it understates — so a field trusted for staleness pushes an actively-worked workstream toward a signal it has not earned. Where you do set it, it means the last SUBSTANTIVE change, so a commit touching only frontmatter does not bump it; a lagging value is not a defect to chase.

## Conventions

- **Task IDs**: `#XX-N` where XX is a 2-3 letter phase code unique in the workstream — unique THERE and not across the project, so the same code may recur in two workstreams and denote different tasks in each. That is what makes naming the home below a resolution requirement rather than a courtesy. For a code the template mints — the Completion phase and every `#G-` gate — recurrence is guaranteed rather than possible, so there is no judgment to make: they carry their home across a boundary even where a distinctive project code would read unambiguously alone. IDs are stable references; never renumber. Sub-tasks `#XX-Na`; deferred `#XX-Nd` with a "Blocked by / unblocks when" line. An ID is a pointer, not a name: every reference to one outside its own backlog line carries a few words saying what it is — `#G-DR (design review)`, "the schema-migration task, #MG-2" — in chat, in ACTIVE.md, in cross-references inside workstream.md, in commit messages, and in handoffs. The name is for the reader and need not match the task line's wording. The backlog line itself is the exception, since its description already follows the ID. Learning and Open Question IDs (`L7`, `OQ-4`) are references too and read the same way. Adopting the convention includes one pass over live content — ACTIVE.md, open backlog items, the critical path, current gate text — naming the references already sitting there. Bare IDs in completed-task notes and closed Decisions are frozen provenance and stay as written. The pass is owed while live content still carries bare IDs and is visibly done when it does not, so it needs no marker beyond looking. A reference that crosses a workstream or project boundary carries its home as well as its name — `#MG-2 in feature/schema-migration (the column backfill)` — because the reader cannot scroll to a definition that is not in the file. When the home is a closed workstream, name its archive tag: that is the only resolvable pointer left, and it is the case that bites most often — the workstream name survives the closure while the thing it names does not, so the reference reads as resolvable and is not. A reference that resolves to no defining line anywhere is a defect to fix at its source, not a name to invent. Name once per readable unit — a backlog item, an ACTIVE.md section, a commit message — not at every repetition inside one; the unit is whatever gets read on its own.
- **Gates**: `#G-XX` tasks are USER CHECKPOINTS. They are decided by the user, presented with a substantive summary and evidence. Autonomous sessions stop at them. The summary has to reach the user before the decision does: text written between tool calls is not guaranteed to render, so finish the stage's tool calls first and let the summary open the message that carries the question. A gate decided against a summary the user never saw is not a gate. A summary built from bare IDs is not one either — if a sentence loses its meaning when the IDs are stripped out, it was carrying no content of its own.
- **Checkboxes** are the progress mechanism: `- [ ]` open, `- [x]` done with a one-line completion note (date + evidence). Counts anchor on the task-ID form, `grep -cE '^- \[ \] #'` — a bare `^- \[ \]` also matches Deletion Criteria, which are standing conditions rather than backlog items, so it overstates remaining work by however many criteria the workstream carries. Unmet criteria are counted in their own section and reported separately.
- **Decisions record reasoning**, not just outcomes. A decision that routes work to a future task also updates that task's description in the same commit. When a later decision supersedes an earlier one, mark the earlier in place at that moment (e.g. `~~superseded by D7~~`) so a stale decision never reads as current. A decision that retires or replaces a shared artifact — a path, a component, a convention other work names — greps the state tree for that artifact in the same commit and marks every hit superseded in place, including hits in completed tasks and other workstreams' Decisions. This only reaches what the author knows about; the detector for the rest is comparative, at review time.
- **Learnings are insights, not work items.** Route work to the Backlog; give each learning an integration target — a file, a commit, or a task, and nothing else: a target naming an Open Question is not a routing, because an OQ resolves into a decision rather than an artifact, so there is no file for the insight to land in and no moment anyone notices it did not. Send the finding to a file and the question to whoever decides it. Disposition it with `/workstream-extract`, at closure — or, in a never-closing workstream, the moment it is resolved (see Constraints).
- **A deletion criterion referencing a set this workstream does not own** names what limits it to this workstream's members; an unscoped reference silently retargets when that set changes.
- **`.state/workstreams/ARCHIVE.md`**: closure appends one line per workstream: `- YYYY-MM-DD type/name -- outcome (tag: ws/<name>)`. The cited tag has to reach the remote, or the citation resolves only on the machine that closed the workstream — pushing the tag is its own step at closure, separate from the archive commit. Cite the ledger by its full path. An unqualified "ARCHIVE.md" can resolve to a stale duplicate elsewhere under `.state/`, and a check run against the wrong file reports correctly-recorded closures as missing.
- **A convention owes a pass over what is already written.** A change describing how to WRITE something — a naming form, a citation style, a record shape — governs text that already exists, so shipping it includes one pass over live content and is not finished when the wording lands. Mechanism changes carry no such shadow; they are inert until a session next runs. The Task IDs bullet states this for itself, and it holds for any convention, including an extension to one already adopted.

## Constraints

- Never auto-start work after creating a workstream; the user chooses when work begins.
- Durable artifacts (docs, code, reference material) live in the repo proper from the start — never inside `.state/`. Optional `notes.md` beside workstream.md holds session-scoped research only; `/workstream-extract` dispositions every notes.md section (summarized into workstream.md, routed to a named home, or dropped by declaration) and moves anything durable to its permanent home, so nothing load-bearing dies with the archive.
- Durable insights leave `.state/` before archive: every Learning is applied to a named file, sent as a handoff, or dropped with stated rationale. Executed by `/workstream-extract`, which `/workstream-close` runs before its gate.
- Never-closing workstreams (`maintain`, or any without a closure milestone) extract each Learning to its destination the moment it is resolved, not at a closure that never comes, and re-check their standing-health Deletion Criteria each review cycle. Both are `/workstream-extract`: a workstream with no ending has no other moment when they happen.
- One tracker per tier: workstream.md Backlog for cross-session work; native Tasks/plan mode within a session. Never both for the same items.
- State files are committed in the session that changes them — uncommitted state does not survive to other machines or future triage.
- A workstream.md that outgrows a few hundred lines is a signal to split the workstream, not the file. Judge that by reading cost rather than line count: a completion note is one line however long it runs, so a file can sit inside a line threshold while having become too large to read in a single pass. The session-start hook detects the size; `/workstream-extract` drains and archives completed records in place, and `/workstream-review` decides a split when what grew is live scope rather than finished work.
- Size an `explore` workstream to a short arc — research to a checkpoint, then close — not the multi-phase backlog a `project` workstream carries. An oversized explore container invites scope drift, where real work happens untracked beside a stalled exploration task; when findings are ready to act on, close the exploration and open a `feature` or `project` workstream for the build.
- Scripts that touch `.state/` normalize to absolute paths at entry.

## Capture sweep

Before a session boundary (`/clear`, `/compact`, `/exit`) and at closure, run a three-question sweep over the session against the durable files — capture should not depend on the user asking:

1. **Detection** — what decided, learned, or flagged this session is not yet in `workstream.md`, `ACTIVE.md`, memory, or a commit?
2. **Cascade** — for each, where does it belong: this workstream, another workstream's Backlog, another project (a handoff), or a named file?
3. **Synthesis** — what general rule or pattern do this session's instances suggest, and does it extend or supersede an existing Decision or Learning?

Route each finding before crossing the boundary. The sweep is a few questions, not a process: it surfaces what capture-as-you-go misses — the cross-cutting and synthesis-level items that appear only when you step back.

## Handoffs — .state/handoffs/

Cross-project transfer: `from-<source>-<YYYYMMDD-HHMMSS>.md`, flat frontmatter (`from`, `date`, `blocking`, `items`), then self-contained items — the receiver cannot see the sender's conversation or repo. Receive = triage each item (do now / route to a workstream backlog with provenance / decline with rationale), then delete the file. The session-start hook reports inbox count and oldest age; an aging inbox is state to reconcile, not background noise.
