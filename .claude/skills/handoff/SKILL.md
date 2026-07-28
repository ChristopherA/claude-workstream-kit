---
name: handoff
description: >-
  Cross-project handoffs via .state/handoffs/ files. Create: write a
  self-contained item file into another project's inbox. Receive: triage
  this project's inbox and delete processed files.
  WHEN: the user says "/handoff", "send this to <project>", "hand off",
  "process handoffs", or the session-start hook reports pending handoffs.
  WHEN NOT: same-project work (use the workstream backlog); team-scale
  tracking with notifications and ownership (use GitHub Issues instead).
---

# Handoff

Format: `.state/handoffs/from-<source>-<YYYYMMDD-HHMMSS>.md` in the RECEIVER's project.

```markdown
---
from: <source-project>
date: YYYY-MM-DD
blocking: no            # yes only if the receiver's work cannot proceed without acting
items: 2
---
> Cross-project handoff. Process: act on each item, route it into a
> workstream backlog, or decline with rationale; then delete this file.

## Item 1: <title>
Self-contained context and the requested action.
```

## Create

1. Gather the items. The self-containment test for each: could someone act on it with NO access to this conversation or this repo? Include file contents, decisions, and rationale inline as needed.
2. Confirm the destination project path with the user — writing into another project is a cross-project action and gets its own confirmation.
3. Write the file (`mkdir -p <dest>/.state/handoffs/` first). One file per destination; bundle multiple items.
4. Commit the file in the receiver's repo (scoped: `git -C <dest> add` the file, then commit only it). An uncommitted handoff is invisible to the receiver's other machines and one `git clean` from gone — state files are committed in the session that writes them, and that includes state written into another project. If the receiver's repo has staged work, do not sweep it up; commit only the handoff path.
5. If the destination project does not exist yet, do NOT create a holding pen — record the items in the sender's own workstream.md (backlog or open question) until it does.

## Receive

1. Read each file in this project's `.state/handoffs/`.
2. Triage per item, with the user when interactive: **do now** (small, in scope), **route** to a workstream backlog as `- [ ] #XX-N: <task> (from <source>, <date>)`, or **decline** with rationale — if the sender needs to know, reply with a handoff back.
3. Delete each fully processed file; items routed into a backlog count as processed.
4. An aging inbox (hook reports oldest age) is state to reconcile, not background noise — triage before new task work.
