#!/bin/sh
# Install (or update) the Claude Workstream Kit into a target project.
# Usage: ./install.sh [--status-line] /path/to/project
#   --status-line  also register the opt-in workstream-aware status line
# Idempotent: re-run to update the .claude/ payload; existing .state/ is never touched.
set -eu

# Normalize to absolute paths at entry.
KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

STATUS_LINE=0
TARGET_ARG=""
for arg in "$@"; do
  case "$arg" in
    --status-line) STATUS_LINE=1 ;;
    -*) echo "ERROR: unknown option '$arg'" >&2
        echo "Usage: $0 [--status-line] /path/to/project" >&2
        exit 2 ;;
    *) if [ -n "$TARGET_ARG" ]; then
         echo "ERROR: multiple target paths given" >&2
         exit 2
       fi
       TARGET_ARG="$arg" ;;
  esac
done
if [ -z "$TARGET_ARG" ]; then
  echo "Usage: $0 [--status-line] /path/to/project" >&2
  exit 2
fi
TARGET=$(CDPATH= cd -- "$TARGET_ARG" 2>/dev/null && pwd) || {
  echo "ERROR: target directory '$TARGET_ARG' does not exist" >&2
  exit 2
}

VERSION=$(cat "$KIT_DIR/VERSION")
MARKER_BEGIN="<!-- workstream-kit:begin -->"
MARKER_END="<!-- workstream-kit:end -->"

echo "Installing claude-workstream-kit $VERSION into $TARGET"

# --- .claude/ payload (skills, agents, hooks, rule) -------------------------
mkdir -p "$TARGET/.claude"
for d in rules skills agents hooks scripts; do
  mkdir -p "$TARGET/.claude/$d"
  cp -R "$KIT_DIR/.claude/$d/." "$TARGET/.claude/$d/"
done
chmod +x "$TARGET/.claude/hooks/session-start.sh" "$TARGET/.claude/hooks/capture-nudge.sh" "$TARGET/.claude/scripts/status-line.sh"

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

# --- settings.json: merge hook registrations --------------------------------
SS_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/session-start.sh'
CN_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/capture-nudge.sh'
if [ ! -f "$TARGET/.claude/settings.json" ]; then
  cp "$KIT_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"
  echo "  wrote .claude/settings.json (session-start + capture-nudge hooks registered)"
elif command -v jq >/dev/null 2>&1; then
  # Per-hook idempotent merge: add each registration only if its command is absent.
  jq --arg ss "$SS_CMD" --arg cn "$CN_CMD" '
    .hooks //= {}
    | (if any((.hooks.SessionStart // [])[]?.hooks[]?; .command == $ss) then . else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$ss}]}]) end)
    | (if any((.hooks.PreCompact // [])[]?.hooks[]?; .command == $cn) then . else .hooks.PreCompact = ((.hooks.PreCompact // []) + [{"hooks":[{"type":"command","command":$cn}]}]) end)
    | (if any((.hooks.SessionEnd // [])[]?.hooks[]?; .command == $cn) then . else .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"hooks":[{"type":"command","command":$cn}]}]) end)
  ' "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"
  mv "$TARGET/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
  echo "  merged session-start + capture-nudge hooks into existing settings.json"
else
  echo "  ACTION REQUIRED: register these hooks in .claude/settings.json:"
  echo "    SessionStart -> command: $SS_CMD"
  echo "    PreCompact, SessionEnd -> command: $CN_CMD"
fi

# --- statusLine: opt-in via --status-line -----------------------------------
# Not registered by default -- adopters may run their own status line. statusLine
# commands get no $CLAUDE_PROJECT_DIR, so the command derives the project dir from
# the JSON on stdin and re-pipes it to the project-local script.
if [ "$STATUS_LINE" -eq 1 ]; then
  SL_CMD='i=$(cat); d=$(printf %s "$i" | jq -r .workspace.project_dir); printf %s "$i" | sh "$d/.claude/scripts/status-line.sh"'
  if command -v jq >/dev/null 2>&1; then
    # Set-if-absent: register only when no status line exists (never clobber).
    jq --arg cmd "$SL_CMD" '
      if .statusLine then . else .statusLine = {"type":"command","command":$cmd} end
    ' "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"
    mv "$TARGET/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
    echo "  registered opt-in status line (or kept an existing one) in settings.json"
  else
    echo "  ACTION REQUIRED: install jq and re-run with --status-line, or add this"
    echo "  statusLine command to .claude/settings.json manually:"
    printf '    %s\n' "$SL_CMD"
  fi
fi

# --- .state/ seed (never overwrite existing state) --------------------------
mkdir -p "$TARGET/.state/workstreams" "$TARGET/.state/handoffs"
[ -f "$TARGET/.state/handoffs/.gitkeep" ] || touch "$TARGET/.state/handoffs/.gitkeep"
[ -f "$TARGET/.state/ACTIVE.md" ] || cp "$KIT_DIR/.state-seed/ACTIVE.md" "$TARGET/.state/ACTIVE.md"
[ -f "$TARGET/.state/workstreams/ARCHIVE.md" ] || cp "$KIT_DIR/.state-seed/workstreams/ARCHIVE.md" "$TARGET/.state/workstreams/ARCHIVE.md"

# --- version stamp -----------------------------------------------------------
printf '%s\n' "$VERSION" > "$TARGET/.claude/workstream-kit.version"

echo "Done. Commit the new files, then start a Claude Code session and run /workstream-create."
