---
name: workstream-capture
description: >-
  Capture-sweep the current session before a boundary -- surface what was
  decided, learned, or flagged this session that is not yet durable, route each
  finding, update ACTIVE.md, and commit state, so nothing is lost crossing
  /clear, /compact, or a pause.
  WHEN: the user signals a session boundary -- "session capture", "close the
  session", "wrap up the session", "prepare to /clear or /compact", "before I
  exit" -- or a work session is ending and /clear is next.
  WHEN NOT: closing or archiving a WORKSTREAM (use /workstream-close); mid-task
  work with no boundary in sight (keep working).
---

# Workstream Capture

A session is about to cross a boundary -- most often `/clear`, then `/workstream-work` again. `/clear` fires no hook, so this is the manual sweep that would otherwise be skipped. Capture should not depend on the user asking for it. It takes no argument: the session is the unit. The reason behind each move below is in `references/failures.md`, under the move's heading; read it when a move is doubted, not on every run.

## Move 1 -- Sweep

Run the workstreams-rule **capture sweep** -- detection, cascade and synthesis as that section states them, arrived handoffs included -- over this session against the durable files, and act on each finding rather than listing it: route every item to its home now, and write any synthesis-level pattern where it extends or supersedes an existing Decision or Learning.

- A disagreement a `/workstream-status` run reported for ANOTHER workstream becomes one Backlog line in the owning workstream, with its provenance (`from /workstream-status <date>`), never a paragraph in ACTIVE.md's Now, Next or Blockers -- the hook shows a backlog line; hand-written cross-workstream prose is what the status skill replaces.
- Synthesis is a different question from detection, not a harder pass at it; the test is whether anything in the sweep's output would change how a DIFFERENT piece of work is done -- if nothing would, the step is still owed.
- Detection includes the claims this session AUTHORED: for each state change the session made -- a pause, a checkbox, a decision, a routing -- run `python3 .claude/scripts/workstream-record.py cites <project root> "<the thing changed>"` once, the session's own claims included -- the author is the reader least likely to re-open what they wrote an hour ago, and capture is the one place that sees the whole session.

## Move 2 -- Close the boundary

- An artifact the sweep PRODUCES outside `.state/` -- a script, a doc, a fixture -- gets its own commit in the repo proper before the state commit, and the state that cites it names the path -- a tool left in the scratchpad is invisible to the next session.
- Update `ACTIVE.md` -- `task`, `Now`, `Next`, `Blockers` -- so the next session resumes in one read. Gloss every ID in the canonical form, `#EX-37 (the phase split question)`, with its home when it crosses a workstream or project boundary (workstreams-rule, Task IDs), in ACTIVE.md and in what you say to the user alike; `python3 .claude/scripts/workstream-record.py bare-ids <root> --text` lists what is still bare, and the file is committed when its line is absent from that output.
- Check off any Backlog items completed this session, each with its one-line evidence (a commit, a passing command, a count).
- Mark any Learning that RESOLVED this session -- its integration target shipped, its handoff sent, its question settled -- with its disposition now, in the same commit -- in a never-closing workstream this is the moment the marker is owed, and the drain that would otherwise write it is periodic.
- Commit the state files per the repository's own commit conventions, scoped to `.state/`; do not sweep unrelated working changes into the commit.

When everything is captured and committed, say it is safe to cross the boundary and name what `Next` points at, so the next session knows where `/workstream-work` picks up. If nothing this session needs capturing, say so plainly -- do not invent items to look thorough.

## Move 3 -- Context status, last

Report this session's context budget as the **very last line** of the capture, so the decision the user is about to make -- `/clear`, `/compact`, or keep going -- is made against a number rather than a guess:

```sh
sh .claude/scripts/status-line.sh --context "$PWD"
```

It prints the two numbers from the newest status-line record for this project, or nothing when there is no status line or no record -- say nothing about context in that case rather than reporting zero. Report the two numbers and how close auto-compact is. The decision is the user's, and a capture that has just committed is a safe moment to make it either way.
