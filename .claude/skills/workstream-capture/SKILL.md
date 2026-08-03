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

A session is about to cross a boundary -- most often `/clear`, then `/workstream-work` again. `/clear` fires no hook, so this is the manual sweep that would otherwise be skipped, and the one boundary the SessionEnd and PreCompact nudges cannot reach. Before crossing it, make sure nothing from this session is lost. Capture should not depend on the user asking for it.

Run the workstreams-rule **capture sweep** over this session against the durable files, and act on each finding -- do not just list them:

1. **Detection** -- what was decided, learned, or flagged this session that is not yet in the active `workstream.md`, `ACTIVE.md`, memory, or a commit?
2. **Cascade** -- for each item, where does it belong: this workstream's Backlog, Decisions, or Learnings; another workstream's backlog; another project (a `/handoff`); or a named file? Route it there now.
3. **Synthesis** -- what general rule or pattern do this session's instances suggest, and does it extend or supersede an existing Decision or Learning? Capture that too.

Then close the boundary cleanly:

- Update `ACTIVE.md` -- `task`, `Now`, `Next`, `Blockers` -- so the next session resumes in one read.
- Check off any Backlog items completed this session, each with its one-line evidence (a commit, a passing command, a count).
- Commit the state files, signed and scoped to `.state/`; do not sweep unrelated working changes into the commit.

When everything is captured and committed, say it is safe to cross the boundary and name what `Next` points at, so the next session knows where `/workstream-work` picks up. If nothing this session needs capturing, say so plainly -- do not invent items to look thorough.

## Context status, last

If the kit's status line is installed it writes a per-session JSON file that carries this session's context budget. Read the newest record for this project and report it as the **very last line** of the capture, so the decision the user is about to make -- `/clear`, `/compact`, or keep going -- is made against a number rather than a guess:

```sh
find /tmp/ -maxdepth 1 -name 'claude-*-context.json' -exec jq -s --arg p "$PWD" \
  '[.[]|select(.project_dir==$p)]|sort_by(.updated)|last
   |if . then "context: \(.usable_consumed_pct)% of usable consumed, \(.remaining_pct)% of window remaining" else empty end' {} +
```

The trailing slash on `/tmp/` is required where `/tmp` is a symlink (macOS): `find /tmp` without it descends nothing and returns falsely empty. No output means no status line or no record for this project -- say nothing about context in that case rather than reporting zero.

Report the two numbers and what they imply: under 40% consumed, crossing is optional and there is room to keep working; 40-59%, cross now while capture is fresh; 60% or more, cross immediately -- auto-compact is close enough to interrupt the next task mid-write.
