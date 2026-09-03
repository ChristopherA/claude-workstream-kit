#!/bin/sh
# Install (or update) the Claude Workstream Kit into a target project.
# Usage: ./install.sh [--dry-run] /path/to/project
#   --dry-run    (alias --check) report per-file drift and exit WITHOUT writing
#   --force      overwrite locally modified payload files instead of refusing
# Exit codes: 0 in sync / installed, 1 drift or stamp-behind, 2 usage,
#             3 payload untrackable in the target (see ignored_payload_paths).
# Idempotent: re-run to update the .claude/ payload; existing .state/ is never touched.
# --dry-run compares the kit payload against the target and reports, per file,
# whether the target is in sync, behind the kit (stale), or ahead of it (locally
# modified -- a change to route back to the kit before re-installing), and names
# any RETIRED payload file (one the kit once shipped and no longer does) that a
# real run would remove, its hook registrations with it.
set -eu

# Normalize to absolute paths at entry.
KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

USAGE="Usage: $0 [--dry-run] [--force] /path/to/project"
DRY_RUN=0
FORCE=0
TARGET_ARG=""
for arg in "$@"; do
  case "$arg" in
    --dry-run|--check) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
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

# The settings.json hook program -- single source of truth for both the real
# install and the --dry-run no-op check. It adds the session-start registration
# if its command is absent (idempotent), and REMOVES the registrations of a hook
# the kit no longer ships: capture-nudge.sh printed the capture sweep on
# PreCompact and SessionEnd, two events whose hook output reaches only the
# debug log, so it never reached the model, and a registration left behind
# would run a script the payload no longer carries. Groups emptied by the
# removal go, and so does an event key left with no groups.
SS_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/session-start.sh'
RETIRED_HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/capture-nudge.sh'
# Retired payload paths, space-separated: present in a target, a real run removes
# each one (refusing a locally modified copy without --force, like any payload).
RETIRED_PAYLOAD='.claude/hooks/capture-nudge.sh'
HOOK_MERGE_JQ='
  .hooks //= {}
  | (if any((.hooks.SessionStart // [])[]?.hooks[]?; .command == $ss) then . else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$ss}]}]) end)
  | .hooks |= with_entries(
      if (.key == "PreCompact" or .key == "SessionEnd") and ((.value | type) == "array") then
        .value |= (map(.hooks |= map(select(.command != $cn))) | map(select((.hooks | length) > 0)))
      else . end)
  | .hooks |= with_entries(select(((.value | type) == "array" and (.value | length) == 0) | not))
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

# Payload paths the TARGET's git cannot track. The kit's stated value is
# durability that travels with the repo like tests or docs, and a payload hidden
# by the target's .gitignore defeats exactly that while presenting as success:
# every file is written, the run reports done, and none of it can be committed.
#
# Only check-ignore answers this. `git status --porcelain` and `git diff` are
# both EMPTY over an ignored file, so a guard built on "uncommitted changes"
# sees nothing and concludes the overwrite is safe -- inverting precisely where
# the cost is highest, since a committed edit is recoverable and an ignored one
# never was. check-ignore does not report a path the target already tracks
# (tracking beats a matching pattern), so a force-added payload stays silent.
#
# Prints repo-relative paths, one per line; empty when the target is not a git
# repo, which is a target with nothing to track rather than a defect.
ignored_payload_paths() {
  if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi
  {
    for ip_d in rules skills agents hooks scripts; do
      find "$KIT_DIR/.claude/$ip_d" -type f
    done | while IFS= read -r ip_f; do echo "${ip_f#"$KIT_DIR"/}"; done
    # The merged files and the provenance stamps live under .claude/ too, so an
    # ignored .claude/ takes the version and source stamps with it.
    echo ".claude/CLAUDE.md"
    echo ".claude/settings.json"
    echo ".claude/workstream-kit.version"
    echo ".claude/workstream-kit.source"
  } | sort | while IFS= read -r ip_rel; do
    if git -C "$TARGET" check-ignore -q "$ip_rel" 2>/dev/null; then
      echo "$ip_rel"
    fi
  done
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
  # Retired payload: shipped by an earlier kit, present here, removed by a real run.
  for rp in $RETIRED_PAYLOAD; do
    if [ -f "$TARGET/$rp" ]; then
      echo "  - $rp  (retired -- would be removed; $(classify_direction "$rp" "$TARGET/$rp"))"
      pdrift=$((pdrift + 1))
    fi
  done
  echo "  payload: $checked files checked, $((checked - pdrift)) in sync, $pdrift drifted"
  [ "$pdrift" -eq 0 ] || drift=1

  # A third condition beside in-sync and drift: a payload the target CANNOT
  # track. These files may match the kit byte for byte and still be invisible
  # to git, so it is reported on its own rather than folded into drift.
  untrackable=0
  ign_list=$(mktemp)
  ignored_payload_paths > "$ign_list"
  if [ -s "$ign_list" ]; then
    untrackable=1
    echo "  ! untrackable: $(wc -l < "$ign_list" | tr -d ' ') payload path(s) ignored by the target's git:"
    sed 's/^/        /' "$ign_list"
  fi
  rm -f "$ign_list"

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
    jq --arg ss "$SS_CMD" --arg cn "$RETIRED_HOOK_CMD" "$HOOK_MERGE_JQ" "$tsj" | jq -S . > "$merged"
    jq -S . "$tsj" > "$cur"
    if cmp -s "$merged" "$cur"; then
      echo "  = .claude/settings.json  hook merge is a no-op (session-start registered, nothing retired)"
    else
      echo "  ~ .claude/settings.json  hook merge would change registrations:"
      diff "$cur" "$merged" | sed 's/^/        /' || true
      drift=1
    fi
    rm -f "$merged" "$cur"
  else
    echo "  ? .claude/settings.json  jq absent -- cannot check the hook merge"
  fi

  # Status-line merge (set-if-absent, never clobber).
  if [ -f "$tsj" ] && command -v jq >/dev/null 2>&1; then
    if jq -e '.statusLine' "$tsj" >/dev/null 2>&1; then
      echo "  = statusLine  already set (kept as-is, never clobbered)"
    else
      echo "  ~ statusLine  would be registered (none set)"
      drift=1
    fi
  fi

  # Version + source stamps a real install WOULD write, compared against the
  # target's current stamps. A version stamp behind the kit VERSION, or an absent
  # .source, is "stamp-behind" -- out of sync (a real install rewrites it), but a
  # SAFE stamp-only apply when the payload is otherwise in sync. A source commit
  # merely older than kit HEAD while the version matches is CURRENCY (reported
  # above as "kit is N ahead"), not drift -- it stays exit 0.
  sdrift=0
  stamp_reason=""
  if [ "$tgt_ver" != "$VERSION" ]; then
    sdrift=1
    stamp_reason="version $tgt_ver -> $VERSION"
  fi
  if [ ! -f "$TARGET/.claude/workstream-kit.source" ]; then
    sdrift=1
    stamp_reason="${stamp_reason:+$stamp_reason; }.source absent -> would be created"
  fi
  if [ "$sdrift" -eq 1 ]; then
    echo "  ~ stamp-behind ($stamp_reason) -- SAFE stamp-only apply"
    echo "        real install would write .version -> $VERSION, .source -> source: $SRC_SHA, ref: $SRC_DESC"
  else
    echo "  = stamp current (version $VERSION); a real install refreshes .source to $SRC_SHA (provenance only)"
  fi

  if [ "$untrackable" -eq 1 ]; then
    echo "Untrackable: the target's git ignores the payload paths listed above, so an install there cannot be committed and the kit does not travel with the repo -- on another machine the state files arrive with no hook, no rule and no skills to operate on them. Make .claude/ trackable (see README, 'Payload visibility'), then re-run. This dry run made no changes."
    exit 3
  elif [ "$drift" -eq 0 ] && [ "$sdrift" -eq 0 ]; then
    echo "In sync: payload, merges, and version stamp match the kit; a real install would make no required change (it may refresh .source provenance -- see any currency note above). This dry run made no changes."
    exit 0
  elif [ "$drift" -eq 0 ]; then
    echo "Stamp-behind: payload and merges match the kit, but the version/source stamp is behind -- a re-install updates only the stamp (safe stamp-only apply). This dry run made no changes."
    exit 1
  else
    echo "Drift above. Re-run without --dry-run to apply; route any 'instance-ahead' file to the kit FIRST. Nothing written."
    exit 1
  fi
fi

# --- refuse to overwrite locally modified payload files ---------------------
# The dry run reports drift direction to whoever asks for it. This fires
# whether or not anyone asked, because the real run is where an unrouted
# local improvement is actually lost.
if [ "$FORCE" -eq 0 ] && [ "$KIT_IS_GIT" -eq 1 ]; then
  ahead_file=$(mktemp)
  for d in rules skills agents hooks scripts; do
    find "$KIT_DIR/.claude/$d" -type f
  done | sort | while IFS= read -r f; do
    rel=${f#"$KIT_DIR"/}
    tf="$TARGET/$rel"
    if [ ! -f "$tf" ]; then
      continue
    elif cmp -s "$f" "$tf"; then
      continue
    fi
    case "$(classify_direction "$rel" "$tf")" in
      instance-ahead*)
        if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 &&
           ! git -C "$TARGET" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
          echo "  $rel  (UNTRACKED in the target -- no baseline to restore from)" >> "$ahead_file"
        else
          echo "  $rel" >> "$ahead_file"
        fi
        ;;
    esac
  done
  for rp in $RETIRED_PAYLOAD; do
    [ -f "$TARGET/$rp" ] || continue
    case "$(classify_direction "$rp" "$TARGET/$rp")" in
      instance-ahead*) echo "  $rp  (RETIRED in this kit and locally modified -- --force removes it)" >> "$ahead_file" ;;
    esac
  done
  if [ -s "$ahead_file" ]; then
    echo "ERROR: refusing to overwrite locally modified payload files:" >&2
    cat "$ahead_file" >&2
    echo "Route them to the kit first, or re-run with --force to discard them." >&2
    echo "A line marked UNTRACKED has no copy in the target's git, so --force discards it" >&2
    echo "permanently -- the recovery this message otherwise assumes does not exist there." >&2
    echo "If a change of yours was already adopted upstream, this is expected: the kit may" >&2
    echo "carry it reworded, or in a different file, so your copy no longer matches. Check the" >&2
    echo "current release for the substance before assuming it is unrouted -- if it is there," >&2
    echo "--force discards a redundant copy rather than your work." >&2
    rm -f "$ahead_file"
    exit 1
  fi
  rm -f "$ahead_file"
fi

if [ "$FORCE" -eq 1 ]; then
  force_ign=$(mktemp)
  ignored_payload_paths | while IFS= read -r fi_rel; do
    if [ -f "$TARGET/$fi_rel" ] && ! cmp -s "$KIT_DIR/$fi_rel" "$TARGET/$fi_rel"; then
      echo "  $fi_rel" >> "$force_ign"
    fi
  done
  if [ -s "$force_ign" ]; then
    echo "WARNING: --force is about to overwrite payload files the target's git never tracked:" >&2
    cat "$force_ign" >&2
    echo "There is no committed baseline for these, so the discard is permanent." >&2
  fi
  rm -f "$force_ign"
fi

echo "Installing claude-workstream-kit $VERSION ($SRC_DESC) into $TARGET"

# --- .claude/ payload (skills, agents, hooks, rule) -------------------------
mkdir -p "$TARGET/.claude"
for d in rules skills agents hooks scripts; do
  mkdir -p "$TARGET/.claude/$d"
  cp -R "$KIT_DIR/.claude/$d/." "$TARGET/.claude/$d/"
done
for rp in $RETIRED_PAYLOAD; do
  if [ -f "$TARGET/$rp" ]; then
    rm -f "$TARGET/$rp"
    echo "  removed retired $rp"
  fi
done
for x in "$KIT_DIR"/.claude/hooks/* "$KIT_DIR"/.claude/scripts/*; do
  [ -f "$x" ] && chmod +x "$TARGET/${x#"$KIT_DIR"/}"
done

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
  echo "  wrote .claude/settings.json (session-start hook registered)"
elif command -v jq >/dev/null 2>&1; then
  jq --arg ss "$SS_CMD" --arg cn "$RETIRED_HOOK_CMD" "$HOOK_MERGE_JQ" \
    "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"
  mv "$TARGET/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
  echo "  merged the session-start hook into existing settings.json (retired registrations removed)"
else
  echo "  ACTION REQUIRED: edit .claude/settings.json by hand:"
  echo "    SessionStart -> command: $SS_CMD"
  echo "    remove any PreCompact or SessionEnd entry running: $RETIRED_HOOK_CMD"
fi

# --- statusLine: workstream-aware status line (set-if-absent) ----------------
# Registered on every install, but only when the target has no status line of its
# own -- an existing statusLine is never clobbered. statusLine commands get no
# $CLAUDE_PROJECT_DIR, so the command derives the project dir from the JSON on
# stdin and re-pipes it to the project-local script.
SL_CMD='i=$(cat); d=$(printf %s "$i" | jq -r .workspace.project_dir); printf %s "$i" | sh "$d/.claude/scripts/status-line.sh"'
if command -v jq >/dev/null 2>&1; then
  jq --arg cmd "$SL_CMD" '
    if .statusLine then . else .statusLine = {"type":"command","command":$cmd} end
  ' "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"
  mv "$TARGET/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
  echo "  registered status line (or kept an existing one) in settings.json"
else
  echo "  ACTION REQUIRED: install jq and re-run, or add this statusLine"
  echo "  command to .claude/settings.json manually:"
  printf '    %s\n' "$SL_CMD"
fi

# --- .state/ seed (never overwrite existing state) --------------------------
mkdir -p "$TARGET/.state/workstreams" "$TARGET/.state/handoffs"
[ -f "$TARGET/.state/handoffs/.gitkeep" ] || touch "$TARGET/.state/handoffs/.gitkeep"
[ -f "$TARGET/.state/ACTIVE.md" ] || cp "$KIT_DIR/.state-seed/ACTIVE.md" "$TARGET/.state/ACTIVE.md"
[ -f "$TARGET/.state/PROJECT.md" ] || cp "$KIT_DIR/.state-seed/PROJECT.md" "$TARGET/.state/PROJECT.md"
[ -f "$TARGET/.state/workstreams/ARCHIVE.md" ] || cp "$KIT_DIR/.state-seed/workstreams/ARCHIVE.md" "$TARGET/.state/workstreams/ARCHIVE.md"

# --- version + source stamps -------------------------------------------------
# .version stays a bare semver (existence- and value-checked by adopters).
# .source records the exact commit installed from -- the currency signal the
# semver alone cannot give.
printf '%s\n' "$VERSION" > "$TARGET/.claude/workstream-kit.version"
printf 'version: %s\nsource: %s\nref: %s\n' "$VERSION" "$SRC_SHA" "$SRC_DESC" \
  > "$TARGET/.claude/workstream-kit.source"

post_ign=$(mktemp)
ignored_payload_paths > "$post_ign"
if [ -s "$post_ign" ]; then
  echo
  echo "WARNING: the target's git ignores these installed payload paths:" >&2
  sed 's/^/  /' "$post_ign" >&2
  echo "The usual 'commit the new files' step cannot be followed for them: they are" >&2
  echo "installed and invisible to git, so the kit does not travel with the repo. A" >&2
  echo "clone elsewhere gets .state/ with no hook, no rule and no skills to run on it." >&2
  echo "Relax the target's .gitignore for .claude/ and re-run -- see README, 'Payload" >&2
  echo "visibility'. Note also that this installer's refusal to overwrite a locally" >&2
  echo "modified payload file CANNOT extend to the same file arriving over git: an" >&2
  echo "ignored path loses git's own protection, so a pull replaces it silently and" >&2
  echo "exits 0. Tracking the payload is what restores that protection." >&2
  # The closing line must not repeat an instruction this warning just said
  # cannot be followed.
  echo "Done, but the payload above is not committable as the target stands. Fix its .gitignore, re-run, then commit."
  rm -f "$post_ign"
  exit 0
fi
rm -f "$post_ign"

echo "Done. Commit the new files, then start a Claude Code session and run /workstream-create."
