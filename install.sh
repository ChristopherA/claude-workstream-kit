#!/bin/sh
# Install (or update) the Claude Workstream Kit into a target project.
# Usage: ./install.sh /path/to/project
# Idempotent: re-run to update the .claude/ payload; existing .state/ is never touched.
set -eu

# Normalize to absolute paths at entry.
KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/project" >&2
  exit 2
fi
TARGET=$(CDPATH= cd -- "$1" 2>/dev/null && pwd) || {
  echo "ERROR: target directory '$1' does not exist" >&2
  exit 2
}

VERSION=$(cat "$KIT_DIR/VERSION")
MARKER_BEGIN="<!-- workstream-kit:begin -->"
MARKER_END="<!-- workstream-kit:end -->"

echo "Installing claude-workstream-kit $VERSION into $TARGET"

# --- .claude/ payload (skills, agents, hooks, rule) -------------------------
mkdir -p "$TARGET/.claude"
for d in rules skills agents hooks; do
  mkdir -p "$TARGET/.claude/$d"
  cp -R "$KIT_DIR/.claude/$d/." "$TARGET/.claude/$d/"
done
chmod +x "$TARGET/.claude/hooks/session-start.sh"

# --- CLAUDE.md: write fresh, or append once under markers -------------------
if [ ! -f "$TARGET/.claude/CLAUDE.md" ]; then
  {
    echo "$MARKER_BEGIN"
    cat "$KIT_DIR/.claude/CLAUDE.md"
    echo "$MARKER_END"
  } > "$TARGET/.claude/CLAUDE.md"
  echo "  wrote .claude/CLAUDE.md"
elif grep -q "$MARKER_BEGIN" "$TARGET/.claude/CLAUDE.md"; then
  # Replace the marker block with the current version (POSIX awk).
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" -v src="$KIT_DIR/.claude/CLAUDE.md" '
    $0 == begin { print; while ((getline line < src) > 0) print line; close(src); skip=1; next }
    $0 == end   { skip=0 }
    !skip { print }
  ' "$TARGET/.claude/CLAUDE.md" > "$TARGET/.claude/CLAUDE.md.tmp"
  mv "$TARGET/.claude/CLAUDE.md.tmp" "$TARGET/.claude/CLAUDE.md"
  echo "  updated kit block in existing .claude/CLAUDE.md"
else
  {
    echo ""
    echo "$MARKER_BEGIN"
    cat "$KIT_DIR/.claude/CLAUDE.md"
    echo "$MARKER_END"
  } >> "$TARGET/.claude/CLAUDE.md"
  echo "  appended kit block to existing .claude/CLAUDE.md"
fi

# --- settings.json: merge hook registration ---------------------------------
HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/session-start.sh'
if [ ! -f "$TARGET/.claude/settings.json" ]; then
  cp "$KIT_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"
  echo "  wrote .claude/settings.json (session-start hook registered)"
elif grep -q "session-start.sh" "$TARGET/.claude/settings.json"; then
  echo "  settings.json already registers the session-start hook"
elif command -v jq >/dev/null 2>&1; then
  jq --arg cmd "$HOOK_CMD" \
     '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$cmd}]}])' \
     "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"
  mv "$TARGET/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
  echo "  merged session-start hook into existing settings.json"
else
  echo "  ACTION REQUIRED: add to .claude/settings.json hooks.SessionStart:"
  echo "    {\"hooks\":[{\"type\":\"command\",\"command\":$HOOK_CMD}]}"
fi

# --- .state/ seed (never overwrite existing state) --------------------------
mkdir -p "$TARGET/.state/workstreams" "$TARGET/.state/handoffs"
[ -f "$TARGET/.state/ACTIVE.md" ] || cp "$KIT_DIR/.state-seed/ACTIVE.md" "$TARGET/.state/ACTIVE.md"
[ -f "$TARGET/.state/workstreams/ARCHIVE.md" ] || cp "$KIT_DIR/.state-seed/workstreams/ARCHIVE.md" "$TARGET/.state/workstreams/ARCHIVE.md"

# --- version stamp -----------------------------------------------------------
printf '%s\n' "$VERSION" > "$TARGET/.claude/workstream-kit.version"

echo "Done. Commit the new files, then start a Claude Code session and run /workstream-create."
