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
PAUSED_DAYS=60

# Dates are derived from git history, never read from a frontmatter field.
# Nothing in the kit writes such a field back, so it drifts silently and
# always UNDERSTATES -- pushing an actively-worked workstream toward a
# staleness signal it has not earned, which trains a reader to ignore this
# hook's most useful output. A derived date cannot drift because nobody
# maintains it. Falls back to mtime for a file not yet committed.
file_epoch() {
  _e=$(git -C "$PROJECT_DIR" log -1 --format=%ct -- "$1" 2>/dev/null || true)
  if [ -z "$_e" ]; then
    _e=$(date -r "$1" +%s 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo "$NOW_S")
  fi
  echo "$_e"
}

# Substantive age: the last commit that changed a CHECKBOX or a DECISION
# heading in the file. Any commit at all is the wrong measure -- a
# whitespace-only reflow of the prose took a workstream from 15d STALE to
# 0d without changing a task, a decision or a word, and the flag then
# reported the healthy state for the file carrying the oldest unpresented
# gate. Checkbox-or-Decision is a content test on the two things the kit
# already parses, needing neither a commit convention nor a diff heuristic.
substantive_epoch() {
  _e=$(git -C "$PROJECT_DIR" log -1 --format=%ct -G'^ *- \[[ xX]\] #|^### D[0-9]+' -- "$1" 2>/dev/null || true)
  [ -n "$_e" ] || _e=$(file_epoch "$1")
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

# A gate decided in the record and never presented carries the DATED marker
# the rule names -- SATISFIED <date>, READY <date>, or "criterion is met
# <date>" -- somewhere in its BLOCK, the gate line plus every continuation
# under it, since a gate accretes agenda and wraps. The date is what tells a
# marking from a mention: a build note quoting "the SATISFIED sentence"
# fired this flag on the kit's own gate, and a marker on the fourth line of a
# fourteen-line gate was invisible to a first-line grep for weeks. Same
# predicate as the record script's `satisfied_text`, written twice because
# this is shell. Prints 1 or 0.
gate_ready() {
  awk '
    function check() { if (blk ~ /(SATISFIED|READY|criterion is met) [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) found = 1 }
    /^ *- \[ \] #G-/ { if (ingate) check(); blk = $0; ingate = 1; next }
    ingate && (/^ *$/ || /^#/ || /^ *- /) { check(); ingate = 0; blk = ""; next }
    ingate { blk = blk " " $0; next }
    END { if (ingate) check(); print found + 0 }
  ' "$1"
}

file_kb() { echo $(( $(wc -c < "$1" | tr -d ' ') / 1024 )); }
file_bytes() { wc -c < "$1" | tr -d ' '; }
age_days() { echo $(( (NOW_S - $(substantive_epoch "$1")) / 86400 )); }
frontmatter_value() { grep "^$2:" "$1" 2>/dev/null | head -1 | cut -d' ' -f2 || true; }

echo "--- Workstreams ---"

# ACTIVE.md: print whole file (kept short by convention).
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
    STATUS=$(frontmatter_value "$WS_FILE" status)
    echo "Active workstream: $WS (status: $STATUS, open tasks: $OPEN, open gates: $GATES, unmet criteria: $CRIT)"

    # Size: a completion note is one line however long it runs, so line count
    # understates reading cost. Warn on bytes, well before a single read fails.
    WS_BYTES=$(file_bytes "$WS_FILE")
    if [ "$WS_BYTES" -gt "$SIZE_BYTES" ]; then
      echo "SIZE: workstream.md is $((WS_BYTES / 1024))KB -- past comfortable single-read size. Drain it with /workstream-extract, or split the workstream (/workstream-review) if what grew is live scope."
    fi

    # Staleness: ACTIVE.md last changed well before the repo's last commit
    # (work happening outside the workstream), or workstream.md's checkboxes
    # and Decisions untouched -- for an active workstream; a paused one is
    # judged below by whether its pause names a resume trigger.
    ACT_S=$(file_epoch "$STATE/ACTIVE.md")
    LAST_COMMIT_S=$(git -C "$PROJECT_DIR" log -1 --format=%ct 2>/dev/null || true)
    [ -n "$LAST_COMMIT_S" ] || LAST_COMMIT_S=$NOW_S
    LAG_D=$(( (LAST_COMMIT_S - ACT_S) / 86400 ))
    if [ "$LAG_D" -gt 7 ]; then
      echo "STALENESS: ACTIVE.md last changed ${LAG_D}d before the repo's last commit -- work may be happening outside the workstream. Reconcile before new task work."
    fi
    AGE_D=$(age_days "$WS_FILE")
    if [ "$STATUS" != "paused" ] && [ "$AGE_D" -gt "$STALE_DAYS" ]; then
      echo "STALENESS: no checkbox or Decision changed in ${AGE_D}d. Reconcile: update, pause, or close."
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

# The archive ledger, for the ghost check: a name the ledger records as
# closed and a directory that is still present are the two halves of a
# closure that did not finish, and nothing else compares them. A
# half-closed workstream sat fifteen days counted as live that way.
LEDGER="$STATE/workstreams/ARCHIVE.md"

if [ "$WS_COUNT" -gt 0 ]; then
  echo "Workstreams ($WS_COUNT) -- '->' marks the active pointer:"
  FLAGGED=0
  for f in "$STATE"/workstreams/*/*/workstream.md; do
    [ -f "$f" ] || continue
    WS_DIR=${f%/workstream.md}
    WS_ID="$(basename "$(dirname "$WS_DIR")")/$(basename "$WS_DIR")"
    R_STATUS=$(frontmatter_value "$f" status)
    R_TYPE=$(frontmatter_value "$f" type)
    [ -n "$R_TYPE" ] || R_TYPE=$(basename "$(dirname "$WS_DIR")")
    R_OPEN=$(count_open "$f")
    R_GATES=$(count_gates "$f")
    R_KB=$(file_kb "$f")
    R_AGE=$(age_days "$f")
    R_MARK="  "
    if [ "$WS_ID" = "${WS:-}" ]; then R_MARK="->"; fi
    R_FLAGS=""
    if [ "$(file_bytes "$f")" -gt "$SIZE_BYTES" ]; then R_FLAGS="$R_FLAGS SIZE"; FLAGGED=1; fi
    if [ "$R_STATUS" = "paused" ]; then
      # A paused row is not stale for being old -- the legend's remedy would
      # tell it to pause. Its question is whether the pause names what
      # resumes it; one that does not is a wish, and the longer threshold
      # gives it a date.
      if [ "$R_AGE" -gt "$PAUSED_DAYS" ] && ! grep -qiE 'resum(e|es|ed|ing)|unpause|re-?open' "$f" 2>/dev/null; then
        R_FLAGS="$R_FLAGS NO-RESUME"; FLAGGED=1
      fi
    elif [ "$R_AGE" -gt "$STALE_DAYS" ]; then
      R_FLAGS="$R_FLAGS STALE"; FLAGGED=1
    fi
    if [ "$R_STATUS" = "done" ] || { [ -f "$LEDGER" ] && grep -qE "^- [0-9]{4}-[0-9]{2}-[0-9]{2} $WS_ID( |$)" "$LEDGER" 2>/dev/null; }; then
      R_FLAGS="$R_FLAGS GHOST"; FLAGGED=1
    fi
    if [ "$(gate_ready "$f")" = "1" ]; then R_FLAGS="$R_FLAGS GATE-READY"; FLAGGED=1; fi
    printf '%s %-36s %-8s %-7s %3s open %2s gate %5sKB %4sd%s\n' \
      "$R_MARK" "$WS_ID" "$R_TYPE" "$R_STATUS" "$R_OPEN" "$R_GATES" "$R_KB" "$R_AGE" "$R_FLAGS"
  done
  if [ "$FLAGGED" -eq 1 ]; then
    echo "SIZE = past single-read size, drain with /workstream-extract. STALE = no checkbox or Decision changed in ${STALE_DAYS}d+, update/pause/close. NO-RESUME = paused ${PAUSED_DAYS}d+ naming no resume trigger; name one or close. GHOST = in the archive ledger or marked done yet still present; finish the closure. GATE-READY = an open gate records its exit criterion met (dated marker); present it."
  fi
fi

# Handoff inbox count + oldest age. The directory is NAMED: a project whose
# deletion criteria spoke of a different inbox read "inbox is empty" as
# true for eleven days while a real handoff sat untriaged elsewhere.
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
  echo "Handoffs pending in .state/handoffs/: $HCOUNT (oldest: ${OLDEST_D}d). Triage with /handoff before new task work if aging."
fi

# Installed kit version against the kit worktree's VERSION, where a
# worktree can be located: WORKSTREAM_KIT_DIR, or the fleet's worktree
# layouts under $HOME/Workspace. One external fact every kit-using project
# shares, surfaced to every reader; SILENT where no worktree is found, since
# a consumer outside the fleet cannot answer the question and a guess
# would read as a fact.
INSTALLED=$(head -1 "$PROJECT_DIR/.claude/workstream-kit.version" 2>/dev/null | tr -d ' ' || true)
if [ -n "$INSTALLED" ]; then
  KIT_VERSION_FILE=""
  for cand in "${WORKSTREAM_KIT_DIR:-}" \
              "$HOME"/Workspace/WORKTREES/GITHUB/*/claude-workstream-kit/main \
              "$HOME"/Workspace/claude-workstream-kit; do
    [ -n "$cand" ] && [ -f "$cand/VERSION" ] && { KIT_VERSION_FILE="$cand/VERSION"; break; }
  done
  if [ -n "$KIT_VERSION_FILE" ]; then
    AVAILABLE=$(head -1 "$KIT_VERSION_FILE" | tr -d ' ')
    if [ "$AVAILABLE" = "$INSTALLED" ]; then
      echo "Kit: $INSTALLED installed, matches the worktree."
    else
      echo "Kit: $INSTALLED installed, worktree has $AVAILABLE -- /workstream-upgrade when the consumer's session is closed."
    fi
  fi
fi

exit 0
