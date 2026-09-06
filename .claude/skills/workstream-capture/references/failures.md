# Workstream Capture -- the failures behind the moves

Each heading names a move in SKILL.md; the text under it is the narrative the move's one-line reason condenses, kept verbatim from the skill as it read before the split. Read a section when its move is doubted. Nothing here adds a step.

## Why this skill exists

`/clear` fires no hook, so this is the manual sweep that would otherwise be skipped, and the one boundary the SessionEnd and PreCompact nudges cannot reach. Before crossing it, make sure nothing from this session is lost.

## Move 1 -- Sweep

A disagreement a `/workstream-status` run reported for ANOTHER workstream is such an item: it becomes one Backlog line in the owning workstream, with its provenance (`from /workstream-status <date>`), so that workstream's session-start hook shows it -- never a paragraph in ACTIVE.md's Now, Next or Blockers, where hand-written cross-workstream prose is what the status skill exists to replace.

Synthesis is a different question from detection, not a harder pass at it, and running detection more carefully converges on more instances and never on a rule; the tell that step three has not run is that nothing in the sweep's output would change how a DIFFERENT piece of work is done. Read the output and ask that; if the answer is nothing, the step is still owed.

Detection includes the claims this session AUTHORED: for each state change the session made -- a pause, a checkbox, a decision, a routing -- grep the state tree once for claims about the thing changed, the session's own included. A session wrote "blocked because this workstream is paused" and the user un-paused it half an hour later; the mechanisms that catch stale claims all assume the claim predates the session, and the author is the reader least likely to re-open what they wrote an hour ago. Capture is the one place in the flow that sees the whole session.

The grep is now the record script's `cites` sub-command, which folds hard-wrapped blocks before matching so a claim split across a wrap is still found, and walks `.state/` by python rather than by a tool whose defaults skip dot-directories.

## Move 2 -- Close the boundary

An artifact the sweep PRODUCES outside `.state/` -- a script, a doc, a fixture -- gets its own commit in the repo proper before the state commit, and the state that cites it names the path: a tool left in the scratchpad is invisible to the next session, and swept into the state commit it breaks the scope below.

Mark any Learning that RESOLVED this session -- its integration target shipped, its handoff sent, its question settled -- with its disposition now, in the same commit. A never-closing workstream extracts each Learning the moment it resolves, and the drain that would otherwise do it is periodic; this is the skill that runs at that moment.

## Move 3 -- Context status, last

If the kit's status line is installed it writes a per-session JSON file that carries this session's context budget. Read the newest record for this project and report it as the **very last line** of the capture, so the decision the user is about to make -- `/clear`, `/compact`, or keep going -- is made against a number rather than a guess.

The read once stood in this skill as a `find` over `/tmp/` piped to `jq`. The trailing slash on `/tmp/` is required where `/tmp` is a symlink (macOS): `find /tmp` without it descends nothing and returns falsely empty. No output means no status line or no record for this project -- say nothing about context in that case rather than reporting zero. Both facts now live in `status-line.sh --context`, beside the writer of the record it reads, so the two cannot drift apart.
