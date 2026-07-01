#!/bin/sh
# status-line.sh - Claude Code status line
#
# Two-line display:
#   Line 1: project » branch » workstream
#   Line 2: [Model] remaining-to-compact% (colored)
#
# Environment variables:
#   CLAUDE_AUTOCOMPACT_PCT_OVERRIDE - compact at this % used (default: 80)
#   CLAUDE_SHOW_COST                - set to show session cost

set -eu

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

COMPACT_AT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-80}"

if command -v timeout >/dev/null 2>&1; then
    input=$(timeout 1 cat 2>/dev/null) || input=""
else
    input=$(cat 2>/dev/null) || input=""
fi
[ -z "$input" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
    echo "jq required"
    exit 0
fi

_tsv=$(echo "$input" | jq -r '[
  .model.display_name // "",
  .workspace.project_dir // "",
  ((.context_window.used_percentage // 0) | floor),
  (.cost.total_cost_usd // 0)
] | @tsv')

model_name=$(printf '%s' "$_tsv" | cut -f1)
project_dir=$(printf '%s' "$_tsv" | cut -f2)
used_pct=$(printf '%s' "$_tsv" | cut -f3)
total_cost=$(printf '%s' "$_tsv" | cut -f4)

project_name=""
[ -n "$project_dir" ] && project_name=$(basename "$project_dir")

branch=""
if [ -n "$project_dir" ] && command -v git >/dev/null 2>&1; then
    branch=$(git -C "$project_dir" branch --show-current 2>/dev/null) || branch=""
fi

workstream=""
if [ -n "$project_dir" ]; then
    active_file="${project_dir}/.state/ACTIVE.md"
    if [ -f "$active_file" ]; then
        workstream=$(head -10 "$active_file" 2>/dev/null | grep -E '^workstream:' | sed 's/workstream: *//' | tr -d '"')
    fi
    [ -z "$workstream" ] && workstream="none"
fi

line1=""
if [ -n "$project_name" ]; then
    line1="${project_name}"
    [ -n "$branch" ] && line1="${line1} » ${branch}"
    [ -n "$workstream" ] && line1="${line1} » ${workstream}"
fi

if [ "$used_pct" -eq 0 ] 2>/dev/null; then
    echo "$line1"
    echo ""
    exit 0
fi

remaining_to_compact=$((COMPACT_AT - used_pct))
[ "$remaining_to_compact" -lt 0 ] && remaining_to_compact=0

model_prefix=""
[ -n "$model_name" ] && model_prefix="[${model_name}] "

cost_suffix=""
if [ -n "${CLAUDE_SHOW_COST:-}" ] && [ "$total_cost" != "0" ]; then
    cost_formatted=$(printf "%.2f" "$total_cost")
    cost_suffix=" \$${cost_formatted}"
fi

echo "$line1"
if [ "$remaining_to_compact" -le 20 ]; then
    printf '%s%b%s%s%b %s\n' "$model_prefix" "$RED" "$remaining_to_compact" "%" "$RESET" "⚠️${cost_suffix}"
elif [ "$remaining_to_compact" -le 45 ]; then
    printf '%s%b%s%s%b%s\n' "$model_prefix" "$YELLOW" "$remaining_to_compact" "%" "$RESET" "$cost_suffix"
else
    printf '%s%b%s%s%b%s\n' "$model_prefix" "$GREEN" "$remaining_to_compact" "%" "$RESET" "$cost_suffix"
fi
