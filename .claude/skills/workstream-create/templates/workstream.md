---
name: <kebab-case-name>
type: <explore|feature|fix|project|maintain|docs>
status: active
created: <YYYY-MM-DD>
---
## Purpose

<Why this exists, scope boundaries, and what done means -- one paragraph.>
<!-- A paused workstream says here what resumes it; the hook's NO-RESUME flag reads only the frontmatter and this section. -->

**Critical path.** <Order only -- the phases or tasks that unblock the rest; status and measurements live on the gate line.>

## Backlog

### <Phase Name> (<XX>)

- [ ] #<XX>-1: <first task>
<!-- A gate met before it is presented appends `SATISFIED YYYY-MM-DD` to its line: the hook then flags the row GATE-READY. -->
- [ ] #G-<XX>: USER CHECKPOINT -- <what the user approves here>

### Completion (CL)

- [ ] #CL-1: Disposition all Learnings and Open Questions; deploy durable artifacts out of .state/
- [ ] #CL-2: Verify deletion criteria with evidence; user closure gate
- [ ] #CL-3: Archive (`.state/workstreams/ARCHIVE.md` line, tag ws/<name>, remove directory, reset ACTIVE.md only if it points here; the tag push is its own gate after)

## Decisions

<!-- ### D1 (YYYY-MM-DD): Title -->
<!-- Decided X because Y. -->

## Learnings

<!-- - L1 (YYYY-MM-DD): insight -- integration target: <destination>. -->

## Open Questions

<!-- - OQ-1: question (resolve at #XX-N) -->

## Deletion Criteria

- [ ] <verifiable condition>
<!-- A never-closing workstream's health condition: `- [ ] STANDING: <condition> -- HOLDS YYYY-MM-DD`, re-stamped at each re-check; the hook counts it apart from closure criteria. -->
