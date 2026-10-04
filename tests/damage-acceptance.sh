#!/bin/sh
# Offline acceptance test for the rewrite-damage fixes: the shapes that
# `workstream-rewrite.py records` and `learnings` damaged in 0.11.0, and
# the emphasised marker the disposition rule missed. Every fixture is a
# shape a consumer's real file carried when the damage was reported:
#
#   records, the leading-note shape: `- [x] #ID: *(<note>)* <description>`
#     with the description wrapped onto continuation lines. 0.11.0 cut
#     the description's first clause, orphaned its continuations, never
#     re-emitted the `)*`, and scraped dates and Decision IDs from the
#     description (an aside `pre-D26` became `reasoning in D26`).
#   records, the under-fire: the same shape whose FIRST line is short,
#     which a per-line 400-character trigger passed over entirely.
#   records, the note-below shape the rule prescribes: a long one-line
#     description with its completion note indented beneath. 0.11.0 cut
#     the DESCRIPTION at about 200 characters, wrote `DONE n.d.`, and
#     left the long note as it was.
#   records, an unrecognised multi-line record: left byte-identical and
#     named in the report, never guessed at.
#   learnings: EXTENDED is an append to an open Learning, not a
#     disposition; the latest terminal marker wins; an EXTENDED after
#     the last terminal marker leaves the entry whole; a leading
#     provenance sentence does not displace the insight.
#   the marker rule: an emphasised marker after an emphasised sentence.
#
# Each check names the old behaviour it rules out, so the suite fails
# on 0.11.0 and passes on the fix.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-rewrite.py"
RECORD="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-damage-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

mkdir -p "$T/.state/workstreams/maintain/fixture"
W="$T/.state/workstreams/maintain/fixture/workstream.md"
cat > "$W" <<'FIX'
---
name: fixture
type: maintain
status: active
---
## Purpose
A fixture carrying every record and Learning shape the 0.11.0
rewrites damaged.

## Backlog
### Build (BD)
- [x] #BD-1: *(2026-01-02 at abc1234: the completion note runs past four hundred characters, which is the threshold this rewrite fires on, and it mentions in passing that the figure it corrected was a pre-D26 one, the sort of aside that any real completion record carries somewhere in it. It also names 2026-01-09 as the date something else happened.)* **Write the thing against the spec**, generating wider than the budget and
      playtesting it down. The description continues onto a second line and a
      third, which is the part this repro is about.
- [x] #BD-2: *(2026-01-04: closed at def5678 -- reasoning in D1 (the first), and a
      note that wraps across several continuation lines the way a long one does,
      so the first line is short and a per-line trigger passed the record over;
      it mentions the other workstream's beta D4/D8/D9 and a pre-D2 figure in
      passing, and names 2026-01-20 as the day something else happened, long
      enough that the block clears four hundred.)* **Shape the widget** across a
      description that starts on the line the note closes on and continues here.
- [x] #BD-3: Write `kit-setup`, the core plugin's install skill, by D1 (the first): interviews the reader through the app's question control (who they are and how they work, a voice from the explainer's three, which of the five projects they want, or another), hands back the account block with the voice filled in, and for each chosen project gives the install steps; how much more it can do waits on the claim check. References generated at build time.
  DONE 2026-09-22 at e0c1afb in the plugin repository: `plugins/kit/skills/kit-setup/SKILL.md`, description 193 characters; four questions through the question control (who and how, voice, which projects, whether the reader is in the intended project); hands back the account block with the voice; per-project install steps naming only the plugin that exists. SUPERSEDED the same day by D2 (the second): the rounds moved to another skill.
- [x] #BD-4: A record whose description wraps onto a continuation that opens with neither a status word nor a date, and whose first line alone runs long enough to have tripped the old trigger, because it says a great deal about the shape of the thing before it stops, at more length than anyone needs,
  and so the record cannot be split into a description and a note without guessing which is which, and it is left alone rather than guessed at.
- [x] #BD-5: a short done task, DONE 2026-01-01
- [x] #BD-7: Resolve the count against the set-aside piece. The finale needs at least one
      undealt piece at every supported count, and four pieces break at four players.
      *Done 2026-08-07 (D1): six pieces at three to five players, drafted at 757d23f, with the
      master doc and the setup updated and the alternative recorded for the gate, which is
      the long part of the note that the condensation replaces with its evidence.*
- [ ] #BD-6: an open task
- [ ] #G-BD: USER CHECKPOINT -- the build gate

## Decisions
### D1 (2026-01-01): First
The first decision.

### D2 (2026-01-02): Second
The second decision.

### D4 (2026-01-04): Fourth
A Decision the other workstream's D4 must not be read as.

## Learnings
- L2 (2026-09-28): Carried from tag ws/old-explore. Agents briefed in
  internal vocabulary write it into published files; brief them in
  plain words -- integration target: a skill task.
  EXTENDED 2026-09-28: a hand-written ID pattern misses bare forms.
  APPLIED 2026-10-01: abc1234, `docs/CLAUDE.md` (Briefing agents).
- L3 (2026-09-28): An open insight with more to say. A second sentence
  about it that a condensation would drop.
  EXTENDED 2026-09-29: more evidence arrived, and nothing is applied yet.
- L4 (2026-09-28): An insight routed and then reopened. Its middle
  sentence explains why. ROUTED 2026-09-29 to #BD-6. EXTENDED
  2026-09-30: a later case the route does not carry.
- L5 (2026-01-01): An insight. *Integration target: written to `f.md`.*
  **APPLIED 2026-01-02** at abc1234.

## Deletion Criteria
- [ ] the fixture is read
FIX
cp "$W" "$T/original.md"
ln() { grep -F -- "$1" "$W"; }

echo "== records: the run"
rc=0; OUT=$(python3 "$SCRIPT" records "$W" --write --date 2026-05-05 2>"$T/err.txt") || rc=$?
printf '%s\n' "$OUT" > "$T/out.txt"
check "records exits 0 and writes" "[ \"\$rc\" -eq 0 ] && grep -q WRITTEN \"$T/out.txt\""

echo "== records: the leading-note shape"
check "#BD-1's description keeps its opening clause on the task line, after the re-closed note" \
  "ln '#BD-1: *(' | grep -qF ')* **Write the thing against the spec**, generating wider than the budget and'"
check "#BD-1's continuation lines are byte-identical" \
  "grep -qxF '      playtesting it down. The description continues onto a second line and a' \"$W\" && grep -qxF '      third, which is the part this repro is about.' \"$W\""
check "#BD-1's note keeps the record's own date (2026-01-02), not the aside's (2026-01-09)" \
  "ln '#BD-1: *(' | grep -q '2026-01-02' && ! ln '#BD-1: *(' | grep -q '2026-01-09'"
check "#BD-1 cites no Decision from the aside (pre-D26)" "! ln '#BD-1: *(' | grep -q 'D26'"
check "#BD-1 keeps its commit and carries the condensation marker inside the note" \
  "ln '#BD-1: *(' | grep -q 'commits abc1234' && ln '#BD-1: *(' | grep -q 'Condensed 2026-05-05 at extract'"

echo "== records: the under-fire"
check "#BD-2 (short first line, long block) is condensed, not passed over" "grep -qE '^#BD-2 [0-9]+->' \"$T/out.txt\""
check "#BD-2 cites D1 from its note and none of the description's D2, D4, D8, D9" \
  "ln '#BD-2: *(' | grep -q 'Condensed 2026-05-05' && ln '#BD-2: *(' | grep -q 'reasoning in D1' && ! ln '#BD-2: *(' | grep -qE 'D2|D4|D8|D9'"
check "#BD-2's date is its note's (2026-01-04), not the description's (2026-01-20)" \
  "ln '#BD-2: *(' | grep -q 'Condensed 2026-05-05' && ln '#BD-2: *(' | grep -q '2026-01-04' && ! ln '#BD-2: *(' | grep -q '2026-01-20'"
check "#BD-2's description survives: its opening on the task line after the re-closed note, its continuation byte-identical" \
  "ln '#BD-2: *(' | grep -qF ')* **Shape the widget** across a' && grep -qxF '      description that starts on the line the note closes on and continues here.' \"$W\""
check "#BD-2's wrapped note lines are gone (removed side)" "! grep -q 'the way a long one does' \"$W\""

echo "== records: a wrapped description with an italic note beneath"
check "#BD-7's two description lines are byte-identical" \
  "grep -qxF -- '- [x] #BD-7: Resolve the count against the set-aside piece. The finale needs at least one' \"$W\" && grep -qxF '      undealt piece at every supported count, and four pieces break at four players.' \"$W\""
check "#BD-7's note is one italic line with its date, Decision and commit" \
  "grep -qE '^      \\*DONE 2026-08-07; reasoning in D1; commits 757d23f\\. Condensed 2026-05-05 at extract; full record in git before that commit\\.\\*\$' \"$W\""

echo "== records: the note-below shape"
check "#BD-3's task line is byte-identical (the description is never cut)" \
  "grep -qxF -e \"\$(grep -F -- '- [x] #BD-3:' \"$T/original.md\")\" \"$W\""
check "#BD-3 carries no '...' and no 'n.d.'" "! grep -A1 -F -- '- [x] #BD-3:' \"$W\" | grep -qE '\\.\\.\\.|n\\.d\\.'"
check "#BD-3's note is replaced: DONE with the note's date and commit, the Decision it names, the marker" \
  "grep -A1 -F -- '- [x] #BD-3:' \"$W\" | tail -1 | grep -qE '^  DONE 2026-09-22; .*commits e0c1afb.*Condensed 2026-05-05 at extract' && grep -A1 -F -- '- [x] #BD-3:' \"$W\" | tail -1 | grep -q 'D2'"
check "#BD-3's long note is gone (removed side)" "! grep -q 'four questions through the question control' \"$W\""

echo "== records: an unrecognised multi-line record is left alone and named"
check "#BD-4 is byte-identical" \
  "grep -qxF -e \"\$(grep -F -- '- [x] #BD-4:' \"$T/original.md\")\" \"$W\" && grep -qF 'and so the record cannot be split' \"$W\""
check "the report names #BD-4 as skipped" "grep -q '^SKIPPED #BD-4' \"$T/out.txt\""
check "the report counts one skipped record" "grep -q 'skipped=1' \"$T/out.txt\""
check "the short record, the open task and the gate are untouched" \
  "grep -qxF -- '- [x] #BD-5: a short done task, DONE 2026-01-01' \"$W\" && grep -qxF -- '- [ ] #BD-6: an open task' \"$W\" && grep -qxF -- '- [ ] #G-BD: USER CHECKPOINT -- the build gate' \"$W\""

echo "== records: idempotence"
cp "$W" "$T/after-records.md"
OUT=$(python3 "$SCRIPT" records "$W" --write --date 2026-06-06)
check "a second records run changes nothing" "printf '%s' \"\$OUT\" | grep -q 'NO CHANGE' && cmp -s \"$W\" \"$T/after-records.md\""

echo "== learnings"
rc=0; OUT=$(python3 "$SCRIPT" learnings "$W" --write --date 2026-05-05 2>"$T/err2.txt") || rc=$?
check "learnings exits 0" "[ \"\$rc\" -eq 0 ]"
L2=$(awk '/^- L2 /,/^- L3 /' "$W" | grep -v '^- L3 ' | tr '\n' ' ' | tr -s ' ')
check "L2 keeps its insight, not only the provenance sentence" \
  "printf '%s' \"\$L2\" | grep -qF 'Agents briefed in internal vocabulary write it into published files; brief them in plain words'"
check "L2 keeps the provenance sentence too" "printf '%s' \"\$L2\" | grep -qF 'Carried from tag ws/old-explore.'"
check "L2 keeps the LATEST marker (APPLIED) and its sentence, and drops the EXTENDED one" \
  "printf '%s' \"\$L2\" | grep -qF 'APPLIED 2026-10-01: abc1234, \`docs/CLAUDE.md\` (Briefing agents).' && ! printf '%s' \"\$L2\" | grep -q EXTENDED"
check "L2 keeps its integration-target clause (a bare disposition may be the only other trace of where it went)" "printf '%s' \"\$L2\" | grep -qF 'brief them in plain words -- integration target: a skill task.'"
for n in 3 4 5; do
  m=$((n + 1))
  awk "/^- L$n /,/^(- L$m |## )/" "$W" | grep -vE "^(- L$m |## )" > "$T/a$n.txt"
  awk "/^- L$n /,/^(- L$m |## )/" "$T/original.md" | grep -vE "^(- L$m |## )" > "$T/b$n.txt"
done
check "L3 (EXTENDED only, still open) is byte-identical" "cmp -s \"$T/a3.txt\" \"$T/b3.txt\""
check "L4 (EXTENDED after its ROUTED) is byte-identical" "cmp -s \"$T/a4.txt\" \"$T/b4.txt\""

echo "== the content guard fires on the output 0.11.0 wrote"
LOSS=$(cd "$KIT_DIR/.claude/scripts" && python3 -c '
import importlib.util, sys; sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("rw", "workstream-rewrite.py")
rw = importlib.util.module_from_spec(spec); spec.loader.exec_module(rw)
before = ("- L2 (2026-09-28): Carried from tag ws/old-explore. Agents briefed in internal vocabulary write it "
          "into published files; brief them in plain words -- integration target: a skill task. "
          "EXTENDED 2026-09-28: a hand-written ID pattern misses bare forms. "
          "APPLIED 2026-10-01: abc1234, `docs/CLAUDE.md` (Briefing agents).")
old = "- L2 (2026-09-28): Carried from tag ws/old-explore. EXTENDED 2026-09-28: a hand-written ID pattern misses bare forms."
print("old", rw.learning_loss(before, old) is not None)
print("new", rw.learning_loss(before, rw.condense_learning(before)) is None)
')
check "the guard refuses the condensation 0.11.0 produced for the issue's fixture" "printf '%s\n' \"\$LOSS\" | grep -qx 'old True'"
check "the guard lets the fixed condensation through" "printf '%s\n' \"\$LOSS\" | grep -qx 'new True'"

echo "== the disposition rule"
DISP=$(cd "$KIT_DIR/.claude/scripts" && python3 -c '
import sys; sys.dont_write_bytecode = True
from workstream_state import disposition
cases = {
 "emph": "- L1 (2026-01-01): An insight. *Integration target: written to `f.md`.*\n  **APPLIED 2026-01-02** at abc1234.",
 "plain": "- L1 (2026-01-01): An insight. Integration target: written to `f.md`.\n  **APPLIED 2026-01-02** at abc1234.",
 "ext": "- L3 (2026-09-28): An open insight. EXTENDED 2026-09-29: more evidence.",
 "routed_ext": "- L4 (2026-09-28): An insight. ROUTED 2026-09-29 to #BD-6. EXTENDED 2026-09-30: a later case.",
 "mid": "- L6 (2026-01-01): the thing was **DONE** by then, on 2026-01-01, bold mid-sentence.",
}
for k, v in cases.items():
    print(k, disposition(v))
')
check "an emphasised marker after an emphasised sentence is terminal" "printf '%s\n' \"\$DISP\" | grep -qx 'emph terminal'"
check "the plain-sentence form still scores terminal" "printf '%s\n' \"\$DISP\" | grep -qx 'plain terminal'"
check "a Learning carrying only EXTENDED is not dispositioned" "printf '%s\n' \"\$DISP\" | grep -qx 'ext None'"
check "ROUTED then EXTENDED still scores terminal (the ROUTED marker)" "printf '%s\n' \"\$DISP\" | grep -qx 'routed_ext terminal'"
check "a bold marker mid-sentence is still a mention" "printf '%s\n' \"\$DISP\" | grep -qx 'mid None'"
check "the record scores L2, L4 and L5 terminal and L3 alone undispositioned" \
  "python3 \"$RECORD\" \"$T\" | jq -e '.workstreams[0].learnings | .terminal == 3 and (.undispositioned | length == 1 and (.[0] | startswith(\"- L3 \")))' >/dev/null"

echo
if [ "$RESULT" -eq 0 ]; then echo "DAMAGE ACCEPTANCE: ALL CHECKS PASS"; else echo "DAMAGE ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
