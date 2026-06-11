#!/bin/sh
# Workstream kit session-start hook: surface ACTIVE state, workstream status,
# handoff inbox, and staleness signals. Output is bounded (<2KB).
set -eu

# Normalize to absolute paths at entry.
PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}
PROJECT_DIR=$(CDPATH= cd -- "$PROJECT_DIR" && pwd)
STATE="$PROJECT_DIR/.state"

[ -d "$STATE" ] || exit 0

echo "--- Workstreams ---"

# ACTIVE.md: print whole file (kept <15 lines by convention).
if [ -f "$STATE/ACTIVE.md" ]; then
  cat "$STATE/ACTIVE.md"
else
  echo "No ACTIVE.md; run /workstream-create or the kit installer."
fi

# Active workstream summary + staleness.
WS=$(grep '^workstream:' "$STATE/ACTIVE.md" 2>/dev/null | head -1 | cut -d' ' -f2- || true)
if [ -n "${WS:-}" ] && [ "$WS" != "none" ]; then
  WS_FILE="$STATE/workstreams/$WS/workstream.md"
  if [ -f "$WS_FILE" ]; then
    OPEN=$(grep -c '^- \[ \]' "$WS_FILE" || true)
    GATES=$(grep -c '^- \[ \] #G-' "$WS_FILE" || true)
    STATUS=$(grep '^status:' "$WS_FILE" | head -1 | cut -d' ' -f2 || true)
    echo "Active workstream: $WS (status: $STATUS, open tasks: $OPEN, open gates: $GATES)"

    # Staleness: state updated long before the repo's last commit, or untouched 14+ days.
    UPDATED=$(grep '^updated:' "$WS_FILE" | head -1 | cut -d' ' -f2 || true)
    NOW_S=$(date +%s)
    if [ -n "$UPDATED" ]; then
      UPD_S=$(date -j -f '%Y-%m-%d' "$UPDATED" +%s 2>/dev/null || date -d "$UPDATED" +%s 2>/dev/null || echo "$NOW_S")
      AGE_D=$(( (NOW_S - UPD_S) / 86400 ))
      LAST_COMMIT_S=$(git -C "$PROJECT_DIR" log -1 --format=%ct 2>/dev/null || echo "$NOW_S")
      LAG_D=$(( (LAST_COMMIT_S - UPD_S) / 86400 ))
      if [ "$LAG_D" -gt 7 ]; then
        echo "STALENESS: workstream state is ${LAG_D}d older than the last commit -- work may be happening outside the workstream. Reconcile before new task work."
      elif [ "$AGE_D" -gt 14 ]; then
        echo "STALENESS: workstream untouched for ${AGE_D}d. Reconcile: update, pause, or close."
      fi
    fi
  else
    echo "WARNING: ACTIVE.md points at $WS but $WS_FILE is missing."
  fi
fi

# Handoff inbox count + oldest age.
HCOUNT=0
OLDEST_D=0
for f in "$STATE/handoffs"/*.md; do
  [ -f "$f" ] || continue
  HCOUNT=$((HCOUNT + 1))
  F_S=$(date -r "$f" +%s 2>/dev/null || stat -c %Y "$f" 2>/dev/null || date +%s)
  D=$(( ($(date +%s) - F_S) / 86400 ))
  [ "$D" -gt "$OLDEST_D" ] && OLDEST_D=$D
done
if [ "$HCOUNT" -gt 0 ]; then
  echo "Handoffs pending: $HCOUNT (oldest: ${OLDEST_D}d). Triage with /handoff before new task work if aging."
fi

exit 0
