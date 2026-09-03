#!/bin/sh
# Workstream kit session-start hook: surface ACTIVE state, the active
# workstream's detail, a roster of every workstream, the handoff inbox, and
# staleness signals. Output is bounded: a fixed preamble plus one line per
# workstream. Registered with no matcher, so it fires on every SessionStart
# event -- startup, resume, clear and compact -- and after a compaction it is
# the re-grounding: ACTIVE.md and the roster reach the model again. (Hook
# output on PreCompact and SessionEnd goes to the debug log and nowhere else,
# which is why the kit ships no nudge on those events.)
set -eu

# Normalize to absolute paths at entry.
PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}
[ -d "$PROJECT_DIR" ] || exit 0
PROJECT_DIR=$(CDPATH= cd -- "$PROJECT_DIR" && pwd)
STATE="$PROJECT_DIR/.state"

[ -d "$STATE" ] || exit 0

NOW_S=$(date +%s)
SIZE_BYTES=65536
STALE_DAYS=14

# Dates are derived from git history, never read from the `updated:`
# frontmatter field. Nothing in the kit writes that field back, so it drifts
# silently and always UNDERSTATES -- pushing an actively-worked workstream
# toward a staleness signal it has not earned, which trains a reader to ignore
# this hook's most useful output. A derived date cannot drift because nobody
# maintains it. Falls back to mtime for a file not yet committed.
file_epoch() {
  _e=$(git -C "$PROJECT_DIR" log -1 --format=%ct -- "$1" 2>/dev/null || true)
  if [ -z "$_e" ]; then
    _e=$(date -r "$1" +%s 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo "$NOW_S")
  fi
  echo "$_e"
}

# Counts anchor on the task-ID form, and tolerate leading indentation so an
# indented sub-task is not silently dropped -- the rule says such lines sit at
# top level, and the counter no longer punishes the file that ignores it. This
# stops UNDER-COUNTING; it does not make a checkbox a unit of pending work.
# A bare `^- \[ \]` also matches Deletion
# Criteria, which are standing conditions rather than backlog items, so it
# overstates remaining work by however many criteria a workstream carries --
# for every workstream, permanently.
count_open()  { grep -cE '^ *- \[ \] #'   "$1" 2>/dev/null || true; }
count_gates() { grep -cE '^ *- \[ \] #G-' "$1" 2>/dev/null || true; }

# Criteria are counted in their own section and reported SEPARATELY rather than
# folded into the task count: a satisfied-but-unticked criterion is a signal
# worth seeing, not noise to hide.
count_criteria() {
  awk '/^## Deletion Criteria/ {f=1; next} /^## / {f=0} f && /^ *- \[ \]/ {n++} END {print n+0}' "$1"
}

file_kb() { echo $(( $(wc -c < "$1" | tr -d ' ') / 1024 )); }
file_bytes() { wc -c < "$1" | tr -d ' '; }
age_days() { echo $(( (NOW_S - $(file_epoch "$1")) / 86400 )); }

echo "--- Workstreams ---"

# ACTIVE.md: print whole file (kept <15 lines by convention).
if [ -f "$STATE/ACTIVE.md" ]; then
  cat "$STATE/ACTIVE.md"
else
  echo "No ACTIVE.md; run /workstream-create or the kit installer."
fi

# Active workstream detail + staleness.
WS=$(grep '^workstream:' "$STATE/ACTIVE.md" 2>/dev/null | head -1 | cut -d' ' -f2- || true)
if [ -n "${WS:-}" ] && [ "$WS" != "none" ]; then
  WS_FILE="$STATE/workstreams/$WS/workstream.md"
  if [ -f "$WS_FILE" ]; then
    OPEN=$(count_open "$WS_FILE")
    GATES=$(count_gates "$WS_FILE")
    CRIT=$(count_criteria "$WS_FILE")
    STATUS=$(grep '^status:' "$WS_FILE" | head -1 | cut -d' ' -f2 || true)
    echo "Active workstream: $WS (status: $STATUS, open tasks: $OPEN, open gates: $GATES, unmet criteria: $CRIT)"

    # Size: a completion note is one line however long it runs, so line count
    # understates reading cost. Warn on bytes, well before a single read fails.
    WS_BYTES=$(file_bytes "$WS_FILE")
    if [ "$WS_BYTES" -gt "$SIZE_BYTES" ]; then
      echo "SIZE: workstream.md is $((WS_BYTES / 1024))KB -- past comfortable single-read size. Drain it with /workstream-extract, or split the workstream (/workstream-review) if what grew is live scope."
    fi

    # Staleness: ACTIVE.md last changed well before the repo's last commit
    # (work happening outside the workstream), or workstream.md untouched.
    ACT_S=$(file_epoch "$STATE/ACTIVE.md")
    LAST_COMMIT_S=$(git -C "$PROJECT_DIR" log -1 --format=%ct 2>/dev/null || true)
    [ -n "$LAST_COMMIT_S" ] || LAST_COMMIT_S=$NOW_S
    LAG_D=$(( (LAST_COMMIT_S - ACT_S) / 86400 ))
    if [ "$LAG_D" -gt 7 ]; then
      echo "STALENESS: ACTIVE.md last changed ${LAG_D}d before the repo's last commit -- work may be happening outside the workstream. Reconcile before new task work."
    fi
    AGE_D=$(age_days "$WS_FILE")
    if [ "$AGE_D" -gt "$STALE_DAYS" ]; then
      echo "STALENESS: workstream untouched for ${AGE_D}d. Reconcile: update, pause, or close."
    fi
  else
    echo "WARNING: ACTIVE.md points at $WS but $WS_FILE is missing."
  fi
fi

# Roster: EVERY workstream, not only the one ACTIVE.md points at. The pointer
# names what a session is working, not what is open, so gating this on it hid
# every unpointed workstream -- including the accreting and abandoned ones the
# SIZE and STALE signals exist to surface.
WS_COUNT=0
for f in "$STATE"/workstreams/*/*/workstream.md; do
  [ -f "$f" ] || continue
  WS_COUNT=$((WS_COUNT + 1))
done

if [ "$WS_COUNT" -gt 0 ]; then
  echo "Workstreams ($WS_COUNT) -- '->' marks the active pointer:"
  FLAGGED=0
  for f in "$STATE"/workstreams/*/*/workstream.md; do
    [ -f "$f" ] || continue
    WS_DIR=${f%/workstream.md}
    WS_ID="$(basename "$(dirname "$WS_DIR")")/$(basename "$WS_DIR")"
    R_STATUS=$(grep '^status:' "$f" | head -1 | cut -d' ' -f2 || true)
    R_OPEN=$(count_open "$f")
    R_GATES=$(count_gates "$f")
    R_KB=$(file_kb "$f")
    R_AGE=$(age_days "$f")
    R_MARK="  "
    if [ "$WS_ID" = "${WS:-}" ]; then R_MARK="->"; fi
    R_FLAGS=""
    if [ "$(file_bytes "$f")" -gt "$SIZE_BYTES" ]; then R_FLAGS="$R_FLAGS SIZE"; FLAGGED=1; fi
    if [ "$R_AGE" -gt "$STALE_DAYS" ]; then R_FLAGS="$R_FLAGS STALE"; FLAGGED=1; fi
    # A gate decided in the record and never presented: its open line carries the
    # marker the rule names (SATISFIED, READY, or "criterion is met" -- the same
    # predicate the status skill uses), while the count beside it stays truthful.
    if grep -E '^ *- \[ \] #G-' "$f" 2>/dev/null | grep -qE 'SATISFIED|READY|criterion is met'; then R_FLAGS="$R_FLAGS GATE-READY"; FLAGGED=1; fi
    printf '%s %-36s %-7s %3s open %2s gate %5sKB %4sd%s\n' \
      "$R_MARK" "$WS_ID" "$R_STATUS" "$R_OPEN" "$R_GATES" "$R_KB" "$R_AGE" "$R_FLAGS"
  done
  if [ "$FLAGGED" -eq 1 ]; then
    echo "SIZE = past single-read size, drain with /workstream-extract. STALE = untouched ${STALE_DAYS}d+, update/pause/close. GATE-READY = an open gate records its exit criterion met; present it."
  fi
fi

# Handoff inbox count + oldest age.
HCOUNT=0
OLDEST_D=0
for f in "$STATE/handoffs"/*.md; do
  [ -f "$f" ] || continue
  HCOUNT=$((HCOUNT + 1))
  F_S=$(date -r "$f" +%s 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo "$NOW_S")
  D=$(( (NOW_S - F_S) / 86400 ))
  [ "$D" -gt "$OLDEST_D" ] && OLDEST_D=$D || true
done
if [ "$HCOUNT" -gt 0 ]; then
  echo "Handoffs pending: $HCOUNT (oldest: ${OLDEST_D}d). Triage with /handoff before new task work if aging."
fi

exit 0
