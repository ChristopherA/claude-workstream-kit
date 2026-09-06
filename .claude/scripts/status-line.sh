#!/bin/sh
# status-line.sh - Claude Code context monitor
#
# Two-line display:
#   Line 1: project » branch » workstream
#   Line 2: [Model] XX% [$0.00]
#
# Line 2 shares the row with system notifications (token warnings, MCP errors)
# which appear flush right. Since line 2 shows context info, overlap is harmless.
# Line 1 stays clean.
#
# Writes /tmp/claude-{session_id}-context.json for programmatic context access.
# Sessions read this file to make context budget decisions, through
#   status-line.sh --context <project-dir>
# which prints the newest record for that project as one line --
#   context: N% of usable consumed, M% of window remaining
# -- and nothing when no record exists (no status line, or none for this
# project), so a caller says nothing rather than reporting zero. The read
# lives beside the writer because both name the same directory and the
# same fields; the trailing slash on the find is required where /tmp is a
# symlink (macOS): without it find descends nothing and returns falsely
# empty. WORKSTREAM_KIT_CONTEXT_DIR overrides the directory for both
# sides, which is how the suite exercises the read without touching /tmp.
#
# Color thresholds by usable context consumed (usable_consumed_pct):
#   <40% consumed - Green (normal)
#   40-59% consumed - Yellow (wrap up)
#   >=60% consumed - Red + warning (compact/clear)
#
# Environment variables:
#   CLAUDE_AUTOCOMPACT_PCT_OVERRIDE - Compact at this % used (default: 80)
#   CLAUDE_SHOW_COST        - Set to any value to show session cost (hidden by default)

set -eu

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Compact threshold: what % used triggers auto-compact (matches settings.json env)
COMPACT_AT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-80}"
CONTEXT_DIR="${WORKSTREAM_KIT_CONTEXT_DIR:-/tmp}"

# === --context <project-dir>: the read side ===
if [ "${1:-}" = "--context" ]; then
    [ -n "${2:-}" ] || { echo "usage: status-line.sh --context <project-dir>" >&2; exit 2; }
    command -v jq >/dev/null 2>&1 || exit 0
    # The record carries the path as the host passed it; a doubled slash
    # or a trailing one must not hide a match, so both sides are
    # normalised in the comparison rather than resolved through the
    # filesystem, and a directory that no longer exists still reads.
    pdir=$2
    find "${CONTEXT_DIR%/}/" -maxdepth 1 -name 'claude-*-context.json' -exec jq -rs --arg p "$pdir" \
      'def norm: gsub("/+"; "/") | rtrimstr("/");
       [.[]|select((.project_dir|norm)==($p|norm))]|sort_by(.updated)|last
       |if . then "context: \(.usable_consumed_pct)% of usable consumed, \(.remaining_pct)% of window remaining" else empty end' {} + 2>/dev/null
    exit 0
fi

# Read JSON from stdin with timeout (prevents hang if stdin is slow/empty)
# timeout may not exist on macOS without coreutils — fall back to plain cat
if command -v timeout >/dev/null 2>&1; then
    input=$(timeout 1 cat 2>/dev/null) || input=""
else
    input=$(cat 2>/dev/null) || input=""
fi

# Exit silently if no input received
if [ -z "$input" ]; then
    exit 0
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "jq required"
    exit 0
fi

# Extract all fields in a single jq call (TSV format)
_tsv=$(echo "$input" | jq -r '[
  .model.display_name // "",
  .workspace.project_dir // "",
  ((.context_window.used_percentage // 0) | floor),
  (.cost.total_cost_usd // 0),
  .session_id // "",
  ((.context_window.remaining_percentage // 0) | floor),
  (.context_window.context_window_size // 0)
] | @tsv')

model_name=$(printf '%s' "$_tsv" | cut -f1)
project_dir=$(printf '%s' "$_tsv" | cut -f2)
used_pct=$(printf '%s' "$_tsv" | cut -f3)
total_cost=$(printf '%s' "$_tsv" | cut -f4)
session_id=$(printf '%s' "$_tsv" | cut -f5)
remaining_pct=$(printf '%s' "$_tsv" | cut -f6)
context_size=$(printf '%s' "$_tsv" | cut -f7)

# Extract project name (basename of project_dir)
project_name=""
if [ -n "$project_dir" ]; then
    project_name=$(basename "$project_dir")
fi

# Extract git branch
branch=""
if [ -n "$project_dir" ] && command -v git >/dev/null 2>&1; then
    branch=$(git -C "$project_dir" branch --show-current 2>/dev/null) || branch=""
fi

# Extract workstream from ACTIVE.md if it exists
workstream=""
if [ -n "$project_dir" ]; then
    active_file="${project_dir}/.state/ACTIVE.md"
    # Fallback to old location during migration
    [ -f "$active_file" ] || active_file="${project_dir}/.claude/ACTIVE.md"
    if [ -f "$active_file" ]; then
        workstream=$(head -10 "$active_file" 2>/dev/null | grep -E '^workstream:' | sed 's/workstream: *//' | tr -d '"')
    fi
    # Default to "none" when project exists but no workstream
    [ -z "$workstream" ] && workstream="none"
fi

# === Line 1: project » branch » workstream ===
line1=""
if [ -n "$project_name" ]; then
    line1="${project_name}"
    if [ -n "$branch" ]; then
        line1="${line1} » ${branch}"
    fi
    if [ -n "$workstream" ]; then
        line1="${line1} » ${workstream}"
    fi
fi

# No percentage data yet — show line 1 only
if [ "$used_pct" -eq 0 ] 2>/dev/null; then
    echo "$line1"
    echo ""
    exit 0
fi

# === Calculate context budget (used for both display colors and JSON file) ===
remaining_to_compact=$((COMPACT_AT - used_pct))
[ "$remaining_to_compact" -lt 0 ] && remaining_to_compact=0

# Calculate usable_consumed_pct from start_remaining
compact_remaining=$((100 - COMPACT_AT))
start_remaining="$remaining_pct"
usable_consumed=0
status_file=""

if [ -n "$session_id" ] && [ "$remaining_pct" -gt 0 ] 2>/dev/null; then
    status_file="${CONTEXT_DIR%/}/claude-${session_id}-context.json"

    # First-write-wins: preserve start_remaining_pct for same session
    if [ -f "$status_file" ]; then
        saved_start=$(jq -r '.start_remaining_pct // 0' "$status_file" 2>/dev/null) || saved_start=0
        if [ "$saved_start" -gt 0 ] 2>/dev/null; then
            start_remaining="$saved_start"
        fi
    fi

    usable_range=$((start_remaining - compact_remaining))
    consumed=$((start_remaining - remaining_pct))
    if [ "$usable_range" -gt 0 ]; then
        usable_consumed=$((consumed * 100 / usable_range))
        [ "$usable_consumed" -lt 0 ] && usable_consumed=0
        [ "$usable_consumed" -gt 100 ] && usable_consumed=100
    fi
fi

# === Line 2: [Model] XX% with color ===
model_prefix=""
if [ -n "$model_name" ]; then
    model_prefix="[${model_name}] "
fi

cost_suffix=""
if [ -n "${CLAUDE_SHOW_COST:-}" ] && [ "$total_cost" != "0" ]; then
    cost_formatted=$(printf "%.2f" "$total_cost")
    cost_suffix=" \$${cost_formatted}"
fi

# Display remaining_to_compact — percentage of usable context still available.
# High = lots of room (green), low = running out (red).
# Color thresholds at 40%/60%/80% usable context consumed.
echo "$line1"
if [ "$usable_consumed" -ge 60 ]; then
    printf '%s%b%s%s%b %s\n' "$model_prefix" "$RED" "$remaining_to_compact" "%" "$RESET" "⚠️${cost_suffix}"
elif [ "$usable_consumed" -ge 40 ]; then
    printf '%s%b%s%s%b%s\n' "$model_prefix" "$YELLOW" "$remaining_to_compact" "%" "$RESET" "$cost_suffix"
else
    printf '%s%b%s%s%b%s\n' "$model_prefix" "$GREEN" "$remaining_to_compact" "%" "$RESET" "$cost_suffix"
fi

# === Write context-status JSON for session consumption ===
if [ -n "$status_file" ]; then
    tmp_file="${status_file}.tmp"
    jq -n \
      --arg sid "$session_id" \
      --arg pdir "$project_dir" \
      --argjson csz "$context_size" \
      --argjson rem "$remaining_pct" \
      --argjson srem "$start_remaining" \
      --argjson crem "$compact_remaining" \
      --argjson ucon "$usable_consumed" \
      --arg mdl "$model_name" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        session_id: $sid,
        project_dir: $pdir,
        context_window_size: $csz,
        remaining_pct: $rem,
        start_remaining_pct: $srem,
        compact_remaining_pct: $crem,
        usable_consumed_pct: $ucon,
        model: $mdl,
        updated: $ts
      }' > "$tmp_file" 2>/dev/null && command mv -f "$tmp_file" "$status_file" 2>/dev/null
fi
