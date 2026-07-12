#!/bin/sh
# Install (or update) the Claude Workstream Kit into a target project.
# Usage: ./install.sh [--dry-run] [--status-line] /path/to/project
#   --dry-run    (alias --check) report per-file drift and exit WITHOUT writing
#   --status-line  also register the opt-in workstream-aware status line
# Idempotent: re-run to update the .claude/ payload; existing .state/ is never touched.
# --dry-run compares the kit payload against the target and reports, per file,
# whether the target is in sync, behind the kit (stale), or ahead of it (locally
# modified -- a change to route back to the kit before re-installing).
set -eu

# Normalize to absolute paths at entry.
KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

USAGE="Usage: $0 [--dry-run] [--status-line] /path/to/project"
STATUS_LINE=0
DRY_RUN=0
TARGET_ARG=""
for arg in "$@"; do
  case "$arg" in
    --dry-run|--check) DRY_RUN=1 ;;
    --status-line) STATUS_LINE=1 ;;
    -*) echo "ERROR: unknown option '$arg'" >&2
        echo "$USAGE" >&2
        exit 2 ;;
    *) if [ -n "$TARGET_ARG" ]; then
         echo "ERROR: multiple target paths given" >&2
         exit 2
       fi
       TARGET_ARG="$arg" ;;
  esac
done
if [ -z "$TARGET_ARG" ]; then
  echo "$USAGE" >&2
  exit 2
fi
TARGET=$(CDPATH= cd -- "$TARGET_ARG" 2>/dev/null && pwd) || {
  echo "ERROR: target directory '$TARGET_ARG' does not exist" >&2
  exit 2
}

VERSION=$(cat "$KIT_DIR/VERSION")
MARKER_BEGIN="<!-- workstream-kit:begin -->"
MARKER_END="<!-- workstream-kit:end -->"

# Source provenance: the exact kit commit this payload comes from. The semver
# stamp answers "which release", this answers "which commit" -- the only stamp
# that stays honest when installing from a mid-stream worktree or after a
# content change under a fixed VERSION.
if git -C "$KIT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  KIT_IS_GIT=1
  SRC_SHA=$(git -C "$KIT_DIR" rev-parse --short HEAD)
  SRC_DESC=$(git -C "$KIT_DIR" describe --tags --always 2>/dev/null || echo "$SRC_SHA")
else
  KIT_IS_GIT=0
  SRC_SHA="unknown"
  SRC_DESC="unknown (kit is not a git checkout)"
fi

# The settings.json hook-merge program -- single source of truth for both the
# real install and the --dry-run no-op check. Adds each registration only if its
# command is absent (idempotent).
SS_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/session-start.sh'
CN_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/capture-nudge.sh'
HOOK_MERGE_JQ='
  .hooks //= {}
  | (if any((.hooks.SessionStart // [])[]?.hooks[]?; .command == $ss) then . else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$ss}]}]) end)
  | (if any((.hooks.PreCompact // [])[]?.hooks[]?; .command == $cn) then . else .hooks.PreCompact = ((.hooks.PreCompact // []) + [{"hooks":[{"type":"command","command":$cn}]}]) end)
  | (if any((.hooks.SessionEnd // [])[]?.hooks[]?; .command == $cn) then . else .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"hooks":[{"type":"command","command":$cn}]}]) end)
'

# Classify a target file that DIFFERS from the kit HEAD version. Walk the kit's
# history for that path: if the target's content equals any blob the kit ever
# shipped there, the target is merely BEHIND (an older kit version -- a re-install
# updates it safely). If it matches no shipped blob, the target is AHEAD (edited
# locally, never a kit version -- route the change to the kit before re-installing,
# or the re-install overwrites it). Needs no stamp; works on any consumer.
# Args: <repo-relative-path> <file-to-classify>
classify_direction() {
  cd_rel=$1
  cd_file=$2
  if [ "$KIT_IS_GIT" -ne 1 ]; then
    echo "direction unknown -- kit is not a git checkout"
    return
  fi
  cd_sha=$(git -C "$KIT_DIR" hash-object "$cd_file")
  for cd_c in $(git -C "$KIT_DIR" log --format=%H -- "$cd_rel"); do
    cd_blob=$(git -C "$KIT_DIR" rev-parse "$cd_c:$cd_rel" 2>/dev/null) || continue
    if [ "$cd_blob" = "$cd_sha" ]; then
      echo "instance-behind: an older kit version, re-install updates it"
      return
    fi
  done
  echo "instance-ahead: locally modified, route it to the kit before re-install"
}

# --- --dry-run: compare only, write nothing, then exit ----------------------
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: kit $VERSION ($SRC_DESC) vs $TARGET"
  echo "  legend: = in sync / no-op   ~ would change   + would create   ? indeterminate"

  # Currency summary from the target's own stamps.
  tgt_ver="(none)"
  [ -f "$TARGET/.claude/workstream-kit.version" ] && tgt_ver=$(head -n1 "$TARGET/.claude/workstream-kit.version")
  tgt_src=""
  if [ -f "$TARGET/.claude/workstream-kit.source" ]; then
    tgt_src=$(sed -n 's/^source: //p' "$TARGET/.claude/workstream-kit.source" | head -n1)
  fi
  echo "  target stamp: version $tgt_ver${tgt_src:+, source $tgt_src}"
  if [ "$KIT_IS_GIT" -eq 1 ] && [ -n "$tgt_src" ]; then
    if git -C "$KIT_DIR" merge-base --is-ancestor "$tgt_src" HEAD 2>/dev/null; then
      n=$(git -C "$KIT_DIR" rev-list --count "$tgt_src..HEAD" 2>/dev/null || echo '?')
      [ "$n" = "0" ] && echo "  currency: installed source is kit HEAD" \
                     || echo "  currency: kit is $n commit(s) ahead of the installed source"
    else
      echo "  currency: installed source $tgt_src is not in this kit's history"
    fi
  fi

  drift=0

  # Payload files (rules/skills/agents/hooks/scripts). In-sync files are silent;
  # a summary line affirms how many were checked.
  payload_list=$(mktemp)
  for d in rules skills agents hooks scripts; do
    find "$KIT_DIR/.claude/$d" -type f
  done | sort > "$payload_list"
  checked=0
  pdrift=0
  while IFS= read -r f; do
    rel=${f#"$KIT_DIR"/}
    tf="$TARGET/$rel"
    checked=$((checked + 1))
    if [ ! -f "$tf" ]; then
      echo "  + $rel  (absent in target -- would be created)"
      pdrift=$((pdrift + 1))
    elif cmp -s "$f" "$tf"; then
      :
    else
      echo "  ~ $rel  ($(classify_direction "$rel" "$tf"))"
      pdrift=$((pdrift + 1))
    fi
  done < "$payload_list"
  rm -f "$payload_list"
  echo "  payload: $checked files checked, $((checked - pdrift)) in sync, $pdrift drifted"
  [ "$pdrift" -eq 0 ] || drift=1

  # CLAUDE.md marker block.
  tcm="$TARGET/.claude/CLAUDE.md"
  if [ ! -f "$tcm" ]; then
    echo "  + .claude/CLAUDE.md  (absent -- would be created with the kit block)"
    drift=1
  elif grep -q "$MARKER_BEGIN" "$tcm"; then
    mb=$(mktemp)
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '$0==b{f=1;next} $0==e{f=0} f' "$tcm" > "$mb"
    if cmp -s "$mb" "$KIT_DIR/.claude/CLAUDE.md"; then
      echo "  = .claude/CLAUDE.md  marker block matches kit (merge is a no-op)"
    else
      echo "  ~ .claude/CLAUDE.md  marker block would update ($(classify_direction ".claude/CLAUDE.md" "$mb"))"
      drift=1
    fi
    rm -f "$mb"
  else
    echo "  + .claude/CLAUDE.md  (no kit marker -- block would be appended)"
    drift=1
  fi

  # settings.json hook merge (additive-only; no "ahead" case).
  tsj="$TARGET/.claude/settings.json"
  if [ ! -f "$tsj" ]; then
    echo "  + .claude/settings.json  (absent -- would be created from the kit)"
    drift=1
  elif command -v jq >/dev/null 2>&1; then
    merged=$(mktemp)
    cur=$(mktemp)
    jq --arg ss "$SS_CMD" --arg cn "$CN_CMD" "$HOOK_MERGE_JQ" "$tsj" | jq -S . > "$merged"
    jq -S . "$tsj" > "$cur"
    if cmp -s "$merged" "$cur"; then
      echo "  = .claude/settings.json  hook merge is a no-op (all hooks registered)"
    else
      echo "  ~ .claude/settings.json  hook merge would add registrations:"
      diff "$cur" "$merged" | sed 's/^/        /' || true
      drift=1
    fi
    rm -f "$merged" "$cur"
  else
    echo "  ? .claude/settings.json  jq absent -- cannot check the hook merge"
  fi

  # Status-line merge, only when the flag is present (set-if-absent, never clobber).
  if [ "$STATUS_LINE" -eq 1 ]; then
    if [ -f "$tsj" ] && command -v jq >/dev/null 2>&1; then
      if jq -e '.statusLine' "$tsj" >/dev/null 2>&1; then
        echo "  = statusLine  already set (--status-line would keep it, never clobber)"
      else
        echo "  ~ statusLine  would be registered (none set)"
        drift=1
      fi
    fi
  fi

  # Stamp that a real install WOULD write (never written in a dry run).
  echo "  stamp (not written in --dry-run):"
  echo "        .claude/workstream-kit.version -> $VERSION"
  echo "        .claude/workstream-kit.source  -> source: $SRC_SHA, ref: $SRC_DESC"

  if [ "$drift" -eq 0 ]; then
    echo "In sync: no file changes; CLAUDE.md and settings.json merges are no-ops. Nothing written."
    exit 0
  else
    echo "Drift above. Re-run without --dry-run to apply; route any 'instance-ahead' file to the kit FIRST. Nothing written."
    exit 1
  fi
fi

echo "Installing claude-workstream-kit $VERSION ($SRC_DESC) into $TARGET"

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
if [ ! -f "$TARGET/.claude/settings.json" ]; then
  cp "$KIT_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"
  echo "  wrote .claude/settings.json (session-start + capture-nudge hooks registered)"
elif command -v jq >/dev/null 2>&1; then
  jq --arg ss "$SS_CMD" --arg cn "$CN_CMD" "$HOOK_MERGE_JQ" \
    "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"
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

# --- version + source stamps -------------------------------------------------
# .version stays a bare semver (existence- and value-checked by adopters).
# .source records the exact commit installed from -- the currency signal the
# semver alone cannot give.
printf '%s\n' "$VERSION" > "$TARGET/.claude/workstream-kit.version"
printf 'version: %s\nsource: %s\nref: %s\n' "$VERSION" "$SRC_SHA" "$SRC_DESC" \
  > "$TARGET/.claude/workstream-kit.source"

echo "Done. Commit the new files, then start a Claude Code session and run /workstream-create."
