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

Frontmatter is flat `key: value` only — it is parsed with `head` and `grep`, not a YAML library.

## Conventions

- **Task IDs**: `#XX-N` where XX is a 2-3 letter phase code unique in the workstream. IDs are stable references; never renumber. Sub-tasks `#XX-Na`; deferred `#XX-Nd` with a "Blocked by / unblocks when" line.
- **Gates**: `#G-XX` tasks are USER CHECKPOINTS. They are decided by the user, presented with a substantive summary and evidence. Autonomous sessions stop at them.
- **Checkboxes** are the progress mechanism: `- [ ]` open, `- [x]` done with a one-line completion note (date + evidence). Counts come from `grep -c '^- \[ \]'`.
- **Decisions record reasoning**, not just outcomes. A decision that routes work to a future task also updates that task's description in the same commit.
- **Learnings are insights, not work items.** Route work to the Backlog; give each learning an integration target and disposition it at closure.
- **ARCHIVE.md**: closure appends one line per workstream: `- YYYY-MM-DD type/name -- outcome (tag: ws/<name>)`.

## Constraints

- Never auto-start work after creating a workstream; the user chooses when work begins.
- Durable artifacts (docs, code, reference material) live in the repo proper from the start — never inside `.state/`. Optional `notes.md` beside workstream.md holds session-scoped research only.
- Durable insights leave `.state/` before archive: every Learning is applied to a named file, sent as a handoff, or dropped with stated rationale.
- One tracker per tier: workstream.md Backlog for cross-session work; native Tasks/plan mode within a session. Never both for the same items.
- State files are committed in the session that changes them — uncommitted state does not survive to other machines or future triage.
- A workstream.md that outgrows a few hundred lines is a signal to split the workstream, not the file.
- Scripts that touch `.state/` normalize to absolute paths at entry.

## Handoffs — .state/handoffs/

Cross-project transfer: `from-<source>-<YYYYMMDD-HHMMSS>.md`, flat frontmatter (`from`, `date`, `blocking`, `items`), then self-contained items — the receiver cannot see the sender's conversation or repo. Receive = triage each item (do now / route to a workstream backlog with provenance / decline with rationale), then delete the file. The session-start hook reports inbox count and oldest age; an aging inbox is state to reconcile, not background noise.
