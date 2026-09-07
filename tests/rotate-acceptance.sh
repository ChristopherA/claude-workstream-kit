#!/bin/sh
# Offline acceptance test for `workstream-rewrite.py rotate`: the
# extract skill's Move 3b by script, with the three checks the hand
# rotation of 2026-09-04 passed while losing content. Builds a git
# fixture and tags it. Cases: the L6 case, a dropped intake-channel
# note cited as "the note below" by the surviving critical-path
# paragraph, refused; the L7 case, a criterion citing a Learnings
# count while the Learnings section rotates out, reported with both
# figures and refused without --allow-stale-claims; a clean rotation
# writes and the three counts hold; the tag absent, exit 1 before any
# write; a file whose open lines are wrapped, refused as
# non-conforming; a reference from ANOTHER workstream's live content to
# a leaving Decision, refused, and the same re-pointed at the tag,
# allowed; a second run changes nothing. The removed side is asserted
# throughout. The Backlog head is lifted from the corpus.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-rewrite.py"
RECORD="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-rotate-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

cd "$T"
git init -q -b main
git config user.email fixture@example.invalid
git config user.name Fixture
git config commit.gpgsign false
git config tag.gpgsign false
git config tag.forceSignAnnotated false
mkdir -p .state/workstreams/maintain/kit .state/workstreams/feature/other
W=.state/workstreams/maintain/kit/workstream.md
O=.state/workstreams/feature/other/workstream.md

write_fixture() { # <with-note: yes|no>
{
  cat <<'FIX'
---
name: kit
type: maintain
status: active
---
## Purpose
The kit's never-closing maintenance workstream. Done means kit
maintenance has moved to a dedicated home.

## Backlog

**Critical path.** Order only, by design (D80): status and
measurements live on the #G-OG gate line, which every gate updates.
Triage of new arrivals runs in parallel over both inboxes (the
intake-channel note below); no cadence rule (D47).

FIX
  if [ "$1" = yes ]; then
    cat <<'FIX'
**The intake-channel note.** The kit worktree has its own
`.state/handoffs/` and nothing watches it, so triage covers BOTH
inboxes (one handoff sat there unseen and became #OG-84).

FIX
  fi
  cat <<'FIX'
### Observed Kit Gaps (OG)
- [x] #OG-1: an evaluation, DECIDED 2026-01-01 (D1), built and released
- [x] #OG-2: another, DECIDED 2026-01-02 (D2)
- [ ] #OG-3: an open evaluation, reasoning in D3
- [ ] #G-OG: USER CHECKPOINT -- approve kit changes; the queue is one item

### Done phase (DP)
- [x] #DP-1: the only task of a finished phase

## Decisions
### D1 (2026-01-01): Shipped and uncited
Reasoning that only a done task cites.

### D2 (2026-01-02): Shipped, cited by another workstream
Reasoning the other workstream's open task still names.

### D3 (2026-01-03): Cited by the open task
Reasoning a live task cites.

### D47 (2026-01-04): No cadence rule
Cited by the critical path.

### D80 (2026-01-05): Order only
Cited by the critical path.

## Learnings
- L1 (2026-01-01): A terminal insight. APPLIED 2026-01-02 to docs/x.md.
- L2 (2026-01-01): A second terminal insight. ROUTED 2026-01-02 to #OG-3.
- L3 (2026-01-01): Tracked work. QUEUED 2026-01-02 for #OG-3.

## Open Questions
- ~~OQ-1: Resolved question.~~ RESOLVED 2026-01-01 via #OG-1.
- OQ-2: Still open, resolve at #OG-3.

## Deletion Criteria
- [ ] kit maintenance has moved to a dedicated home
- [ ] STANDING: every Learning reached a terminal disposition, 2 of 2 Learnings terminal at the last re-check -- HOLDS 2026-01-01
- [ ] STANDING: both inboxes empty -- HOLDS 2026-01-01

## Analysis -- reusable protocol
A section the kit does not know, carried verbatim.
FIX
} > "$W"
}
write_fixture yes
cat > "$O" <<'FIX'
---
name: other
type: feature
status: active
---
## Backlog
- [ ] #OT-1: builds on D2 in maintain/kit, the shipped decision

## Decisions
### D1 (2026-01-01): Other's own
Reasoning.
FIX
git add -A && git commit -q -m "before rotation"
git tag -a ws/kit-2026-02-02 -m "rotation"
cp "$W" "$T/original.md"

echo "== The tag must exist"
rc=0; python3 "$SCRIPT" rotate "$W" --tag ws/kit-2099-01-01 --write --date 2026-02-02 >/dev/null 2>"$T/e.txt" || rc=$?
check "an absent tag: exit 1 naming the tag, file unchanged" '[ "$rc" -eq 1 ] && grep -q "ws/kit-2099-01-01" "$T/e.txt" && cmp -s "$W" "$T/original.md"'

echo "== The L6 case: a dropped note the surviving critical path cites"
rc=0; python3 "$SCRIPT" rotate "$W" --tag ws/kit-2026-02-02 --write --date 2026-02-02 >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "refused (exit 1), naming the surviving critical-path line and the leaving paragraph" \
  '[ "$rc" -eq 1 ] && grep -q "intake-channel note" "$T/e.txt" && grep -q "leaving paragraph" "$T/e.txt" && cmp -s "$W" "$T/original.md"'
check "the same run also names the other workstream's live reference to leaving D2" 'grep -q "feature/other/workstream.md.*leaving decision .D2." "$T/e.txt"'
# The phrase "the intake-channel note" starts on the line ending "(the"
# and wraps; the citing line is where the match STARTS.
CP_LINE=$(grep -n 'both inboxes (the$' "$W" | cut -d: -f1)
CP_BLOCK=$(grep -n '^\*\*Critical path' "$W" | cut -d: -f1)
check "the surviving-text hit cites the citing line and the block's first line as they sit ON DISK (the Rotated paragraph would shift them by two), and the header says so" \
  'grep -q "kit/workstream.md:$CP_LINE (block $CP_BLOCK, surviving text) cites leaving paragraph" "$T/e.txt" && grep -q "index the files on disk" "$T/e.txt" && [ "$CP_LINE" -eq "$((CP_BLOCK + 2))" ]'

echo "== --keep carries the note; the other workstream's D2 reference still refuses"
rc=0; python3 "$SCRIPT" rotate "$W" --tag ws/kit-2026-02-02 --write --date 2026-02-02 --keep "intake-channel note" >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "refused for D2 alone (exit 1), the note no longer named" \
  '[ "$rc" -eq 1 ] && grep -q "leaving decision .D2." "$T/e.txt" && ! grep -q "leaving paragraph" "$T/e.txt" && cmp -s "$W" "$T/original.md"'
# Re-point the other workstream's reference at the tag: the reference is no longer a hit.
sed -i.bak 's|builds on D2 in maintain/kit, the shipped decision|builds on D2 at ws/kit-2026-02-02, the shipped decision|' "$O" && rm -f "$O.bak"
git add -A && git commit -q -m "re-point"

echo "== The L7 case: a carried criterion's count the rotation makes false"
rc=0; python3 "$SCRIPT" rotate "$W" --tag ws/kit-2026-02-02 --write --date 2026-02-02 --keep "intake-channel note" >"$T/o.txt" 2>"$T/e.txt" || rc=$?
check "refused (exit 1): STALE CLAIM names learnings_terminal 2 claimed, now 0, with the criterion sentence" \
  '[ "$rc" -eq 1 ] && grep -q "STALE CLAIM.*learnings_terminal 2 claimed, now 0.*2 of 2 Learnings terminal" "$T/o.txt" && grep -q "allow-stale-claims" "$T/e.txt" && cmp -s "$W" "$T/original.md"'

echo "== Dry run with --allow-stale-claims reports and writes nothing"
OUT=$(python3 "$SCRIPT" rotate "$W" --tag ws/kit-2026-02-02 --date 2026-02-02 --keep "intake-channel note" --allow-stale-claims)
check "dry run reports the drops and the carried counts, file unchanged" \
  'printf "%s" "$OUT" | grep -q "^rotate: dropped decision=2, learning=2, open question=1, task=3 open=2 gates=1 standing=2" && ! printf "%s" "$OUT" | grep -q WRITTEN && cmp -s "$W" "$T/original.md"'

echo "== Write"
python3 "$RECORD" "$T" | jq '.workstreams[] | select(.path | endswith("kit/workstream.md"))' > "$T/rec-before.json"
OUT=$(python3 "$SCRIPT" rotate "$W" --tag ws/kit-2026-02-02 --write --date 2026-02-02 --keep "intake-channel note" --allow-stale-claims)
check "write reports WRITTEN" 'printf "%s" "$OUT" | grep -q WRITTEN'
check "the Rotated line is first under Purpose" \
  '[ "$(awk "/^## Purpose/{getline; print; exit}" "$W")" = "Rotated 2026-02-02; the record before it is at ws/kit-2026-02-02." ]'
check "removed side: the done tasks, the finished phase heading, D1, D2, L1, L2 and OQ-1 are gone" \
  '! grep -q "#OG-1:" "$W" && ! grep -q "#OG-2:" "$W" && ! grep -q "#DP-1" "$W" && ! grep -q "^### Done phase" "$W" && ! grep -q "^### D1 " "$W" && ! grep -q "^### D2 " "$W" && ! grep -q "^- L1 " "$W" && ! grep -q "^- L2 " "$W" && ! grep -q "OQ-1" "$W"'
check "kept: the open task, the gate, the critical path, the kept note, D3, D47, D80, L3, OQ-2, the criteria, the Analysis section" \
  'grep -q "^- \[ \] #OG-3:" "$W" && grep -q "^- \[ \] #G-OG:" "$W" && grep -q "^\*\*Critical path" "$W" && grep -q "^\*\*The intake-channel note" "$W" && grep -q "^### D3 " "$W" && grep -q "^### D47 " "$W" && grep -q "^### D80 " "$W" && grep -q "^- L3 " "$W" && grep -q "^- OQ-2:" "$W" && grep -q "STANDING: both inboxes" "$W" && grep -q "^## Analysis" "$W" && grep -q "carried verbatim" "$W"'
python3 "$RECORD" "$T" | jq '.workstreams[] | select(.path | endswith("kit/workstream.md"))' > "$T/rec-after.json"
check "the record's open count, gate count and STANDING count are identical before and after (2, 1, 2)" \
  '[ "$(jq -r "\"\(.open_total) \(.open_gates | length) \(.deletion_criteria.standing)\"" "$T/rec-before.json")" = "2 1 2" ] && [ "$(jq -r "\"\(.open_total) \(.open_gates | length) \(.deletion_criteria.standing)\"" "$T/rec-after.json")" = "2 1 2" ]'
check "every open line's ID is present in the new file" \
  'for id in "#OG-3" "#G-OG"; do grep -q "^- \[ \] $id:" "$W" || exit 1; done'
check "the file shrank" '[ "$(wc -c < "$W")" -lt "$(wc -c < "$T/original.md")" ]'
check "the tag still resolves every dropped ID (git show at the tag holds D1)" 'git show ws/kit-2026-02-02:"$W" | grep -q "^### D1 "'

echo "== A second run changes nothing"
cp "$W" "$T/after1.md"
git add -A && git commit -q -m "rotated"
OUT=$(python3 "$SCRIPT" rotate "$W" --tag ws/kit-2026-02-02 --write --date 2026-03-03 --keep "intake-channel note")
check "second run: dropped nothing, NO CHANGE, byte-identical, no second Rotated line" \
  'printf "%s" "$OUT" | grep -q "^rotate: dropped nothing" && printf "%s" "$OUT" | grep -q "NO CHANGE" && cmp -s "$W" "$T/after1.md" && [ "$(grep -c "^Rotated " "$W")" = 1 ]'

echo "== A non-conforming file (wrapped open line) is refused"
printf -- '- [ ] #OG-9: a new task wrapped against\nthe convention\n' >> "$W"
rc=0; python3 "$SCRIPT" rotate "$W" --tag ws/kit-2026-02-02 --write --date 2026-03-03 >/dev/null 2>"$T/e.txt" || rc=$?
check "exit 1 naming the continuation line, nothing written" '[ "$rc" -eq 1 ] && grep -q "non-conforming" "$T/e.txt" && grep -q "^the convention" "$W"'
git checkout -q -- "$W"

echo "== Usage"
rc=0; python3 "$SCRIPT" rotate "$W" >/dev/null 2>&1 || rc=$?
check "rotate without --tag: exit 2" '[ "$rc" -eq 2 ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "ROTATE ACCEPTANCE: ALL CHECKS PASS"; else echo "ROTATE ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
