#!/bin/sh
# Offline acceptance test for the records and learnings condensers'
# second round of damage fixes, each shape one a consumer's drain or the
# steward's triage met at 0.11.2:
#
#   records, inbound citations: a record that live content cites as its
#     note -- a ticked criterion's `see #BD-1 completion note`, another
#     workstream's open task -- lost the measurements the citation
#     points at. It is now left whole and the citer named; `--keep <ID>`
#     leaves any record whole.
#   records, the evidence lead: a note whose evidence is an issue, with
#     no commit leading it, fell back to `evidence in the record at the
#     commit preceding` and lost its only handle, while a provenance
#     commit named later in prose was listed as the evidence.
#   records, foreign Decisions: `D2 and D4 in feature/alpha` credited D2
#     as this file's, since only the ID written directly before `in
#     <home>` was read as foreign.
#   records, hex words: a gist ID and a data digest were listed as
#     commits, and a commit named short and full was listed twice. Only
#     a token that resolves as a commit here is listed; any other keeps
#     the clause it sits in.
#   records, orphaned paragraphs: a note's paragraphs after a blank
#     line stayed verbatim under the condensed line, unreported.
#   records, notes in parts and closing verbs: a `STARTED ... PROGRESS
#     ... DONE` note below its description had only its last line
#     condensed and lost its `)*`; a note kept as dated paragraphs was
#     dated by its first; `closed, superseded by #X` became DONE with
#     the pointer gone.
#   learnings: a kept sentence pointing back at a dropped one (`that
#     task`, `there`) left a routing to nothing; a sentence was cut at
#     an unquoted `%G? ` or an `e.g. `.
#
# Each check names the old behaviour it rules out, so the suite fails
# on 0.11.2 and passes on the fix. REWRITE_SCRIPT overrides the script
# under test.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="${REWRITE_SCRIPT:-$KIT_DIR/.claude/scripts/workstream-rewrite.py}"
SKILL="$KIT_DIR/.claude/skills/workstream-extract/SKILL.md"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-condenser-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

cd "$T"
git init -q -b main
git config user.email tests@example.invalid
git config user.name 'kit tests'
git config commit.gpgsign false
# Fixed dates make the hashes the same on every run, so no check flakes
# on a short hash that happens to be all digits, which no hex word
# pattern takes for a hash.
GIT_AUTHOR_DATE='2026-01-01T00:00:00Z'; GIT_COMMITTER_DATE='2026-01-01T00:00:00Z'
export GIT_AUTHOR_DATE GIT_COMMITTER_DATE
echo one > a.txt; git add a.txt; git commit -qm one
FULL=$(git rev-parse HEAD)
SHORT=$(git rev-parse --short=7 HEAD)
echo two > a.txt; git commit -qam two
PROV=$(git rev-parse --short=7 HEAD)
for h in "$SHORT" "$PROV"; do
  case $h in *[a-f]*) ;; *) echo "FAIL: fixture hash $h carries no letter; change a commit message"; exit 1 ;; esac
done

P='This sentence pads the record so its block runs past the four hundred byte trigger the condenser fires at, and a little further besides, so that no record here is passed over for being short. A second padding sentence makes sure of it, since the trigger counts the whole block in bytes.'

mkdir -p .state/workstreams/maintain/fx .state/workstreams/feature/alpha .state/workstreams/feature/beta
W="$T/.state/workstreams/maintain/fx/workstream.md"
cat > "$W" <<FIX
---
name: fx
type: maintain
status: active
---
## Purpose
A fixture carrying the record and Learning shapes 0.11.2 damaged.

## Backlog
### Build (BD)
- [x] #BD-1: Measure the tracked count.
      DONE 2026-01-05 at $SHORT: \`git ls-files\` returned 0 for the path, and a render was byte-identical to two baselines over 4106 frames. $P
- [x] #BD-15: Measure the other figure.
      DONE 2026-01-05 at $SHORT: the figure was 2430 changed pixels under a one-pixel control. $P
- [x] #BD-16: A record the operator keeps.
      DONE 2026-01-05 at $SHORT: an ordinary note the operator chooses to keep whole. $P
- [x] #BD-8: Ship the site fix.
      DONE 2026-01-11: closed web-site issue 10 with the fix described there; a provenance commit $PROV is where a deleted notes.md lived. $P
- [x] #BD-2: Credit the decisions.
      DONE 2026-01-06 at $SHORT, reasoning in D3 (the local one), and in D2 and D4 in feature/alpha, which are that workstream's. $P
- [x] #BD-18: Credit by name.
      DONE 2026-01-06 at $SHORT, by D3 (the local one) and beta's D4 (the beta call). $P
- [x] #BD-3: Retire the gist.
      DONE 2026-01-07 at $SHORT (also written $FULL): gist db9f830078f061de06a8aa30ab6f0e3b deleted with \`gh gist delete\`, API 404; the data digest a5d7df2d matched the baseline. $P
- [x] #BD-4: Two paragraphs.
      DONE 2026-01-08 at $SHORT: the first paragraph of the note. $P

      ORPHANWORD a second paragraph of the same note, after a blank line. $P
- [x] #BD-17: Condensed by an earlier run.
      DONE 2026-01-01; commits $SHORT. Condensed 2026-02-02 at extract; full record in git before that commit.

      LEFTOVERWORD a paragraph an earlier run left behind.
- [x] #BD-9: A note kept in parts.
      *(STARTED 2026-01-02: began the work. $P
      PROGRESS 2026-01-03: half done.
      DONE 2026-01-09 at $SHORT. $P)*
- [x] #BD-10: Dated paragraphs.
      2026-01-02: started at $SHORT with the first half. $P 2026-01-15: finished with the second half. $P
- [x] #BD-11: Build the unbuilt thing. Closed 2026-01-12, superseded by #BD-12 (the replacement), never built. $P $P
- [x] #BD-14: *(2026-01-12: closed, superseded by #BD-12 (the replacement). $P $P)* Build another.
- [x] #BD-13: Moved away.
      Moved 2026-01-13 to feature/alpha as #XY-1 (the moved build). $P $P
- [ ] #BD-20: an open task naming #BD-11 (the unbuilt thing)

## Decisions
### D2 (2026-01-01): two
A local D2 the foreign D2 must not be read as.

### D3 (2026-01-01): three
The local Decision. Work routes to #BD-8 (the site fix).

### D4 (2026-01-01): four
A local D4 the foreign D4 must not be read as.

## Learnings
- L1 (2026-01-01): Signing can return an empty signature with exit 0. The work goes to #BD-3 (the signing check). Integration target: that task. APPLIED 2026-01-10.
- L2 (2026-01-01): A condensed entry can point at nothing. HANDED OFF 2026-01-03 to docs-site as its handoff of that day. VERIFIED 2026-01-04: received there that day and triaged.
- L3 (2026-01-01): Confirm the log reads %G? as G before any push, since an empty signature exits 0. A middle sentence that goes. APPLIED 2026-01-10 to \`rules/sign.md\`.
- L4 (2026-01-01): Prefer a probe, e.g. the record script, over a hand count. A middle sentence that goes. APPLIED 2026-01-10 to \`f.md\`.
- L5 (2026-01-01): A plain insight. A middle sentence that goes. APPLIED 2026-01-10 to \`g.md\`.

## Deletion Criteria
- [x] The tracked count is zero; see #BD-1 completion note for the measurement.
FIX
cat > .state/workstreams/feature/alpha/workstream.md <<'FIX'
---
name: alpha
type: feature
status: active
---
## Purpose
Another workstream.

## Backlog
### Next (NX)
- [ ] #NX-1: Re-use the figure from #BD-15 in maintain/fx (the other figure); its completion note has the number.
FIX
cat > .state/workstreams/feature/beta/workstream.md <<'FIX'
---
name: beta
type: feature
status: active
---
## Purpose
A third workstream, named only to be cited by name.
FIX
cat > .state/ACTIVE.md <<'FIX'
---
workstream: maintain/fx
task: none
---
## Now
Fixture.
FIX
git add -A; git commit -qm fixture
cp "$W" "$T/original.md"
ln() { grep -F -- "$1" "$W"; }
orig() { grep -F -- "$1" "$T/original.md"; }
block() { awk -v id="$1" 'index($0, "- [x] " id ":") == 1 {on=1; print; next} on && /^- / {exit} on && /^#/ {exit} on {print}' "$W"; }

echo "== records: the run"
rc=0; python3 "$SCRIPT" records "$W" --write --date 2026-05-05 >"$T/out.txt" 2>"$T/err.txt" || rc=$?
check "records exits 0 and writes" "[ \"\$rc\" -eq 0 ] && grep -q WRITTEN \"$T/out.txt\""

echo "== records: inbound citations"
check "#BD-1, cited by a ticked criterion as its completion note, is byte-identical (not condensed to its commit alone)" \
  "grep -qF '4106 frames' \"$W\" && ! block '#BD-1' | grep -q 'Condensed 2026-05-05'"
check "the report names #BD-1 as skipped and names the citing criterion" \
  "grep -E '^SKIPPED #BD-1:' \"$T/out.txt\" | grep -q 'Deletion Criteria'"
check "#BD-15, cited as its note from another workstream's open task, is left whole and that file is named" \
  "grep -qF '2430 changed pixels' \"$W\" && grep -E '^SKIPPED #BD-15:' \"$T/out.txt\" | grep -q 'feature/alpha'"
check "#BD-11, cited by an open task without naming its note, is still condensed" \
  "ln '#BD-11:' | grep -q 'Condensed 2026-05-05'"

echo "== records: the evidence lead"
check "#BD-8 keeps its issue, its only handle, rather than the 'evidence in the record' fallback" \
  "block '#BD-8' | grep -q 'Condensed 2026-05-05' && block '#BD-8' | grep -q 'web-site issue 10' && ! block '#BD-8' | grep -q 'evidence in the record'"
check "#BD-8 does not list the provenance commit named later in its prose" \
  "block '#BD-8' | grep -q 'Condensed 2026-05-05' && ! block '#BD-8' | grep -q \"commits.*$PROV\""
check "the report names the commit #BD-8 did not list" \
  "grep -E '^#BD-8 ' \"$T/out.txt\" | grep -qF \"named in prose after the lead: $PROV]\""

echo "== records: foreign Decisions"
check "#BD-2 cites its one local Decision, D3" "block '#BD-2' | grep -q 'reasoning in D3'"
check "#BD-2 credits neither D2 nor D4, which its note gives to feature/alpha" \
  "block '#BD-2' | grep -q 'Condensed 2026-05-05' && ! block '#BD-2' | grep -qE 'D2|D4'"
check "the report names D2 and D4 as another workstream's" \
  "grep -E '^#BD-2 ' \"$T/out.txt\" | grep -q \"another workstream's: D2, D4\""
check "#BD-18 credits D3 and not D4, which its note gives to beta by name" \
  "block '#BD-18' | grep -q 'reasoning in D3;' && ! block '#BD-18' | grep -q 'D4'"

echo "== records: hex words"
check "#BD-3 lists its commit once, not short and full both" \
  "block '#BD-3' | grep -qE \"commits $SHORT[;.]\" && ! block '#BD-3' | grep -q \"$FULL\""
check "#BD-3 lists neither the 32-hex gist ID nor the data digest as a commit" \
  "block '#BD-3' | grep -q 'Condensed 2026-05-05' && ! block '#BD-3' | grep -qE 'commits[^.;]*(db9f8300|a5d7df2d)'"
check "#BD-3 keeps the gist's and the digest's clauses, the evidence a resolve-only filter drops" \
  "block '#BD-3' | grep -qF 'gist db9f830078f061de06a8aa30ab6f0e3b deleted with \`gh gist delete\`, API 404' && block '#BD-3' | grep -qF 'the data digest a5d7df2d matched the baseline'"

echo "== records: orphaned paragraphs"
check "#BD-4's second paragraph leaves with its record" \
  "block '#BD-4' | grep -q 'Condensed 2026-05-05' && ! grep -q 'ORPHANWORD' \"$W\""
check "#BD-4's condensed record is one task line and one note line" "[ \"\$(block '#BD-4' | grep -c .)\" -eq 2 ]"
check "the report counts #BD-17's leftover paragraph as orphaned_note_lines=1 and leaves it" \
  "grep -q 'orphaned_note_lines=1' \"$T/out.txt\" && grep -q 'LEFTOVERWORD' \"$W\""

echo "== records: notes in parts and closing verbs"
check "#BD-9's note in parts condenses whole: no STARTED or PROGRESS line left" \
  "block '#BD-9' | grep -q 'Condensed 2026-05-05' && ! block '#BD-9' | grep -qE 'STARTED|PROGRESS'"
check "#BD-9's condensed note keeps its delimiters, *( ... )*" \
  "block '#BD-9' | grep -qE '^      \\*\\(DONE 2026-01-09; commits $SHORT\\. Condensed 2026-05-05 at extract; full record in git before that commit\\.\\)\\*\$'"
check "#BD-10 is dated by its closing paragraph (2026-01-15), not its first (2026-01-02)" \
  "block '#BD-10' | grep -q 'DONE 2026-01-15' && ! block '#BD-10' | grep -q '2026-01-02'"
check "#BD-11 keeps its own verb and pointer: SUPERSEDED 2026-01-12 by #BD-12 (the replacement), no DONE" \
  "ln '#BD-11:' | grep -qF 'SUPERSEDED 2026-01-12 by #BD-12 (the replacement)' && ! ln '#BD-11:' | grep -q 'DONE'"
check "#BD-14's leading note keeps the same verb and pointer, no DONE" \
  "ln '#BD-14:' | grep -qF '*(SUPERSEDED 2026-01-12 by #BD-12 (the replacement).' && ! ln '#BD-14:' | grep -q 'DONE'"
check "#BD-13 keeps where it moved: MOVED 2026-01-13 to feature/alpha as #XY-1 (the moved build)" \
  "block '#BD-13' | grep -qF 'MOVED 2026-01-13 to feature/alpha as #XY-1 (the moved build)'"

echo "== records: --keep and idempotence"
cp "$T/original.md" "$W"
rc=0; python3 "$SCRIPT" records "$W" --keep '#BD-16' --date 2026-05-05 >"$T/keep.txt" 2>&1 || rc=$?
check "--keep #BD-16 runs and reports the record kept" "[ \"\$rc\" -eq 0 ] && grep -q '^KEPT #BD-16' \"$T/keep.txt\""
rc=0; python3 "$SCRIPT" records "$W" --keep '#BD-16' --write --date 2026-05-05 >"$T/keep-write.txt" 2>&1 || rc=$?
check "#BD-16 is byte-identical under a --keep run that wrote" \
  "[ \"\$rc\" -eq 0 ] && grep -q '^WRITTEN' \"$T/keep-write.txt\" && grep -qF 'an ordinary note the operator chooses to keep whole' \"$W\""
cp "$W" "$T/after-records.md"
rc=0; python3 "$SCRIPT" records "$W" --keep '#BD-16' --write --date 2026-06-06 >"$T/out2.txt" 2>&1 || rc=$?
check "a second records run is a no-op: exit 0, NO CHANGE, byte-identical" \
  "[ \"\$rc\" -eq 0 ] && grep -qx 'NO CHANGE' \"$T/out2.txt\" && cmp -s \"$W\" \"$T/after-records.md\""

echo "== learnings"
cp "$T/original.md" "$W"
rc=0; python3 "$SCRIPT" learnings "$W" --write >"$T/learn.txt" 2>&1 || rc=$?
check "learnings exits 0" "[ \"\$rc\" -eq 0 ]"
check "L1, whose kept target says 'that task', is left whole and reported" \
  "grep -qF 'The work goes to #BD-3 (the signing check).' \"$W\" && grep -q '^SKIPPED L1:' \"$T/learn.txt\""
check "L2, whose kept marker says 'received there', is left whole and reported" \
  "grep -qF 'HANDED OFF 2026-01-03 to docs-site' \"$W\" && grep -q '^SKIPPED L2:' \"$T/learn.txt\""
check "L3's statement survives whole past an unquoted %G? (not cut at the question mark)" \
  "grep -A2 '^- L3 ' \"$W\" | tr '\\n' ' ' | tr -s ' ' | grep -qF 'since an empty signature exits 0.' && ! grep -A2 '^- L3 ' \"$W\" | grep -q 'middle sentence'"
check "L4's statement survives whole past 'e.g.'" \
  "grep -A2 '^- L4 ' \"$W\" | tr '\\n' ' ' | tr -s ' ' | grep -qF 'e.g. the record script, over a hand count.' && ! grep -A2 '^- L4 ' \"$W\" | grep -q 'middle sentence'"
check "L5, the control, still condenses" "! grep -A2 '^- L5 ' \"$W\" | grep -q 'middle sentence'"

echo "== the extract skill"
check "Move 3 names the cites step and --keep beside the records command" \
  "awk '/^## Move 3 /{on=1;next} /^## /{on=0} on' \"$SKILL\" | grep -q 'cites' && awk '/^## Move 3 /{on=1;next} /^## /{on=0} on' \"$SKILL\" | grep -q -- '--keep'"

exit $RESULT
