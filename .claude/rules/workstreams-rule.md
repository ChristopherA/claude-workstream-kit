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
- **Decisions record reasoning**, not just outcomes. A decision that routes work to a future task also updates that task's description in the same commit. When a later decision supersedes an earlier one, mark the earlier in place at that moment (e.g. `~~superseded by D7~~`) so a stale decision never reads as current.
- **Learnings are insights, not work items.** Route work to the Backlog; give each learning an integration target and disposition it at closure — or, in a never-closing workstream, the moment it is resolved (see Constraints).
- **ARCHIVE.md**: closure appends one line per workstream: `- YYYY-MM-DD type/name -- outcome (tag: ws/<name>)`.

## Constraints

- Never auto-start work after creating a workstream; the user chooses when work begins.
- Durable artifacts (docs, code, reference material) live in the repo proper from the start — never inside `.state/`. Optional `notes.md` beside workstream.md holds session-scoped research only; closure dispositions every notes.md section (summarized into workstream.md, routed to a named home, or dropped by declaration) so nothing load-bearing dies with the archive.
- Durable insights leave `.state/` before archive: every Learning is applied to a named file, sent as a handoff, or dropped with stated rationale.
- Never-closing workstreams (`maintain`, or any without a closure milestone) extract each Learning to its destination the moment it is resolved, not at a closure that never comes, and re-check their standing-health Deletion Criteria each review cycle.
- One tracker per tier: workstream.md Backlog for cross-session work; native Tasks/plan mode within a session. Never both for the same items.
- State files are committed in the session that changes them — uncommitted state does not survive to other machines or future triage.
- A workstream.md that outgrows a few hundred lines is a signal to split the workstream, not the file.
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
