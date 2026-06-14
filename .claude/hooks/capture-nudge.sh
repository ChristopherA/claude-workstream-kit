#!/bin/sh
# Workstream kit: nudge the capture sweep before a session boundary.
# Fires on SessionEnd (/exit) and PreCompact (/compact). /clear emits no event
# (no PreClear hook exists), so the workstreams-rule capture sweep and the
# /workstream-work session-exit step carry the sweep there.
# A hook can only emit a reminder, not author captures -- this is that reminder.
set -eu

PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}
[ -d "$PROJECT_DIR/.state" ] || exit 0

echo "--- Capture sweep (workstreams-rule) ---"
echo "Before this boundary, sweep the session against the durable files and route each finding:"
echo "  1. Detection -- what decided/learned/flagged is not yet in workstream.md, ACTIVE.md, memory, or a commit?"
echo "  2. Cascade   -- where does each belong: this workstream, another workstream, another project (handoff), or a named file?"
echo "  3. Synthesis -- what general rule do the session's instances suggest; does it extend or supersede a Decision/Learning?"
echo "Commit state before crossing the boundary."

exit 0
