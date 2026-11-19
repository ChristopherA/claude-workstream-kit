#!/bin/sh
# Offline acceptance test for the records and learnings condensers'
# second round of damage fixes, each shape one a consumer's drain or the
# steward's triage met at 0.11.2:
#
#   records, inbound citations: a record that live content cites as its
#     note -- a ticked criterion's `see #BD-1 completion note`, another
#     workstream's open task -- lost the measurements the citation
#     points at. It is now left whole and the citer named; `--keep <ID>`
#     leaves any record whole. An open task's `the readings are in the
#     #BD-21 record` named no note word and lost the readings: a
#     citation from live content now holds a record whatever its
#     wording, while closed content still needs a note word.
#   records, the evidence lead: a note whose evidence is an issue, with
#     no commit leading it, fell back to `evidence in the record at the
#     commit preceding` and lost its only handle, while a provenance
#     commit named later in prose was listed as the evidence. A commit
#     named as a time reference (`after the capture commit`) was listed
#     too. A commit past the lead is now listed only after a verb of
#     making (`landed at`); any other keeps its clause and is reported.
#   records, notes already at the form: `DONE <date> at <commit>:
#     <command> reports 14 patterns OK` condensed to its date and commit,
#     and a command result with no commit fell back to `evidence in the
#     record`. The first is left whole; the second keeps its result.
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
#     task`, `there`, `it does;`) left a routing to nothing; a sentence
#     was cut at an unquoted `%G? ` or an `e.g. `; only the latest
#     marker's sentence was kept, losing the earlier ones.
#   learnings, follow-on paragraphs: an entry's indented paragraphs
#     after a blank line stayed verbatim under the condensed line,
#     unreported, and a marker written only there went unread.
#   learnings, anaphora outside the word list: a kept sentence
#     opening on `And` or `Each`, or saying `all three`, after the
#     sentence it leaned on was dropped, condensed with skipped=0;
#     `this workstream` was read as pointing back.
#   decisions, live citations: every named Decision condensed, those
#     an open gate or open task still cited included.
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
- [x] #BD-21: Read the tokens.
      DONE 2026-01-04: each token's name, scope and expiry read from the account, READINGWORD three tokens with one expiring 2026-03-01. $P
- [x] #BD-22: Read the gauge.
      DONE 2026-01-04: GAUGEWORD the gauge read 71 on the left dial and 64 on the right. $P
- [x] #BD-23: Calibrate the dial.
      DONE 2026-01-04: CALIBWORD the dial was set against the reference and held. $P
- [x] #BD-24: Write the guide section.
      DONE 2026-01-06: the guide gains a section on the server. The restart is confirmed: this process started 2026-01-06 12:08:39, after the capture commit $PROV. $P
- [x] #BD-25: Build the probe.
      DONE 2026-01-06: the probe reads the gauge. The work landed at $PROV and was read back. $P
- [x] #BD-26: Build both halves.
      DONE 2026-01-07 at $SHORT: the first half. The second half landed at $PROV. $P
- [x] #BD-27: Check the patterns in the other kit. $P
      DONE 2026-01-08 at c0ffee1 in the-other-kit: \`fx-check self-test\` reports 14 patterns OK, the sender's case among them.
- [x] #BD-28: Check the cases here. $P
      DONE 2026-01-08 at $SHORT: \`fx-check\` reports 3 cases OK, each of the three planted cases read back from the log the way its sender described it.
- [x] #BD-29: Gloss the mentions.
      DONE 2026-01-09 at review: every mention glossed, and \`fx-ids .\` reports 0 for this file, 24 before the pass. The placement half was already done: $P
- [x] #BD-30: Write the guide.
      DONE 2026-01-09 at $SHORT: the guide gained a section on the server, its settings, the way it loads and the order its parts are read in at start. $P
- [x] #BD-31: Read the meter.
      DONE 2026-01-10: METERWORD the meter was read and logged. $P $P
- [x] #BD-32: Pick the meter.
      DONE 2026-01-10: PICKWORD the left meter was picked over the right. $P $P
- [x] #BD-33: Read the right meter.
      DONE 2026-01-10: RIGHTWORD the right meter read 9 at noon and 11 at dusk. $P
- [ ] #BD-20: the next audit re-reads the tokens; the 2026-01-04 readings are in the #BD-21 (read the tokens) record

## Decisions
### D2 (2026-01-01): two
A local D2 the foreign D2 must not be read as.

### D3 (2026-01-01): three
The local Decision. Work routes to #BD-8 (the site fix).

### D4 (2026-01-01): four
A local D4 the foreign D4 must not be read as.

## Learnings
- L1 (2026-01-01): Signing can return an empty signature with exit 0. The work goes to #BD-3 (the signing check). Integration target: that task. APPLIED 2026-01-10.
- L2 (2026-01-01): A condensed entry can point at nothing. A middle sentence that goes. HANDED OFF 2026-01-03 to docs-site as its handoff of that day. VERIFIED 2026-01-04: received there that day and triaged.
- L3 (2026-01-01): Confirm the log reads %G? as G before any push, since an empty signature exits 0. A middle sentence that goes. APPLIED 2026-01-10 to \`rules/sign.md\`.
- L4 (2026-01-01): Prefer a probe, e.g. the record script, over a hand count. A middle sentence that goes. APPLIED 2026-01-10 to \`f.md\`.
- L5 (2026-01-01): A plain insight. A middle sentence that goes. APPLIED 2026-01-10 to \`g.md\`.
- L6 (2026-01-01): A clear starts a session but not a process. A middle sentence of evidence that goes. Integration target: \`docs/tools.md\`, since anything that loads a plugin mid-session needs a relaunch first. QUEUED 2026-01-03: the #BD-4 task line now names it. APPLIED 2026-01-04: \`docs/tools.md\` corrected on the way: the remedy is not only a relaunch, because \`/reload\` activates pending changes in the running session. VERIFIED 2026-01-04: it does; the session served the new version after \`/reload\` with no relaunch.
- L7 (2026-01-01): A reload can stand in for a relaunch. The reload command activates pending changes. A middle sentence that goes. VERIFIED 2026-01-04: it does; the new version was served.
- L8 (2026-01-01): The probe misreads a stale cache. The cache notes belong with the probe's own notes. It goes in the probe's notes -- integration target: \`h.md\`. APPLIED 2026-01-10 to \`h.md\`.
- L9 (2026-01-01): The handoff reached its inbox. A sentence naming the docs-site inbox that goes. VERIFIED 2026-01-04: received there that day and triaged.

## Open Questions
- OQ-1: ~~Which meter is read?~~ RESOLVED 2026-01-10 via #BD-32 (pick the meter): the left one.
- OQ-2: Does the right meter drift? Compare against #BD-33 (read the right meter) first.

## Deletion Criteria
- [x] The tracked count is zero; see #BD-1 completion note for the measurement.
- [x] The dial is calibrated, per #BD-23 (calibrate the dial).
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
- [ ] #NX-2: Compare the dials against #BD-22 in maintain/fx (read the gauge) before the next reading.
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
Fixture. Done: #BD-31 (read the meter), confirmed by the reading.
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
check "#BD-21, cited by an open task as 'the readings are in the #BD-21 record' with no note word, is left whole (not condensed to its fallback)" \
  "grep -qF 'READINGWORD three tokens' \"$W\" && ! block '#BD-21' | grep -q 'Condensed 2026-05-05'"
check "the report names #BD-21 as skipped, cited by live content, and names the open task's line" \
  "grep -E '^SKIPPED #BD-21: cited by live content at ' \"$T/out.txt\" | grep -q 'readings are in the #BD-21'"
check "#BD-22, cited by another workstream's open task with no note word, is left whole and that file is named" \
  "grep -qF 'GAUGEWORD the gauge read 71' \"$W\" && grep -E '^SKIPPED #BD-22: cited by live content at ' \"$T/out.txt\" | grep -q 'feature/alpha'"
check "#BD-23, cited by a TICKED criterion with no note word, is still condensed: closed content needs a note word" \
  "block '#BD-23' | grep -q 'Condensed 2026-05-05' && ! grep -qF 'CALIBWORD' \"$W\""
check "#BD-33, cited by an unresolved Open Question with no note word, is left whole" \
  "grep -qF 'RIGHTWORD the right meter read 9' \"$W\" && grep -E '^SKIPPED #BD-33: cited by live content at ' \"$T/out.txt\" | grep -q 'Open Questions'"
check "#BD-32, cited only by an Open Question resolved in place, is still condensed" \
  "block '#BD-32' | grep -q 'Condensed 2026-05-05' && ! grep -qF 'PICKWORD' \"$W\""
check "#BD-31, cited only by ACTIVE.md's session narrative with no note word, is still condensed" \
  "block '#BD-31' | grep -q 'Condensed 2026-05-05' && ! grep -qF 'METERWORD' \"$W\""
check "#BD-8, cited by a closed Decision with no note word, is still condensed" \
  "block '#BD-8' | grep -q 'Condensed 2026-05-05'"

echo "== records: the evidence lead"
check "#BD-8 keeps its issue, its only handle, rather than the 'evidence in the record' fallback" \
  "block '#BD-8' | grep -q 'Condensed 2026-05-05' && block '#BD-8' | grep -q 'web-site issue 10' && ! block '#BD-8' | grep -q 'evidence in the record'"
check "#BD-8 does not list the provenance commit named later in its prose" \
  "block '#BD-8' | grep -q 'Condensed 2026-05-05' && ! block '#BD-8' | grep -q \"commits.*$PROV\""
check "#BD-8 keeps the provenance commit's clause verbatim, and the report names the commit it did not list" \
  "block '#BD-8' | grep -qF \"a provenance commit $PROV is where a deleted notes.md lived\" && grep -E '^#BD-8 ' \"$T/out.txt\" | grep -qF \"no verb of making before it, kept in its clause: $PROV]\""
check "#BD-26 lists its lead commit and the later one a verb of making names, in that order" \
  "block '#BD-26' | grep -q \"commits $SHORT, $PROV[;.]\""

echo "== records: notes already at the form"
check "#BD-27, one sentence with its date, an other-repository commit and a command result, is byte-identical (not cut to its date and commit)" \
  "[ \"\$(block '#BD-27')\" = \"\$(awk -v id='#BD-27' 'index(\$0, \"- [x] \" id \":\") == 1 {on=1; print; next} on && /^- / {exit} on {print}' \"$T/original.md\")\" ] && grep -qF 'reports 14 patterns OK' \"$W\""
check "the report names #BD-27 as skipped, a note already at the form" \
  "grep -E '^SKIPPED #BD-27: a note already at the completion-note form' \"$T/out.txt\" >/dev/null"
check "#BD-28, the same form with a commit that resolves here, is left whole too" \
  "grep -qF '\`fx-check\` reports 3 cases OK, each of the three planted cases' \"$W\" && ! block '#BD-28' | grep -q 'Condensed 2026-05-05'"
check "#BD-29, a command result with no commit leading, keeps that clause rather than the 'evidence in the record' fallback" \
  "block '#BD-29' | grep -q 'Condensed 2026-05-05' && block '#BD-29' | grep -qF '\`fx-ids .\` reports 0 for this file, 24 before the pass' && ! block '#BD-29' | grep -q 'evidence in the record'"
check "#BD-30, one sentence with a commit and no command or count, is not at the form and still condenses" \
  "block '#BD-30' | grep -q \"DONE 2026-01-09; commits $SHORT. Condensed 2026-05-05\""
check "#BD-24 does not list the capture commit it names only as a time reference" \
  "block '#BD-24' | grep -q 'Condensed 2026-05-05' && ! block '#BD-24' | grep -q \"commits $PROV\""
check "#BD-24 keeps that commit's clause verbatim, and the report names it" \
  "block '#BD-24' | grep -qF \"after the capture commit $PROV\" && grep -E '^#BD-24 ' \"$T/out.txt\" | grep -qF \"no verb of making before it, kept in its clause: $PROV]\""
check "#BD-25 lists the commit a verb of making names: 'landed at'" \
  "block '#BD-25' | grep -q \"commits $PROV[;.]\""

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
check "#BD-9's condensed note keeps its delimiters, *( ... )*, and its closing part's commit in its clause, since no commit leads the note" \
  "block '#BD-9' | grep -qE '^      \\*\\(DONE 2026-01-09; at $SHORT\\. Condensed 2026-05-05 at extract; full record in git before that commit\\.\\)\\*\$'"
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

echo "== records: dated record forms"
# On 0.11.5 a record dated between its ID and the colon -- `#XX-3
# (2026-01-02): ...` -- matched no record pattern, so records passed it
# over and reported clean while the record script read it as done. The
# parenthetical is carried verbatim, its date standing in for a note
# that names none; a body that is all description stays whole, since
# the parenthetical can be the whole note; and any other line the
# record script reads as done is reported, never passed over.
mkdir -p .state/workstreams/maintain/dt
DTW="$T/.state/workstreams/maintain/dt/workstream.md"
cat > "$DTW" <<FIX
---
name: dt
type: maintain
status: active
---
## Purpose
A fixture carrying the dated record forms.

## Backlog
### Dated (DT)
- [x] #DT-1 (2026-01-07): Build the dated thing.
      DONE at $SHORT: the dated build landed and its check passed. $P
- [x] #DT-2 (2026-01-08): A one-line dated record. DONE 2026-01-08 at $SHORT: the one-line build landed. $P $P
- [x] #G-DT (2026-01-09): USER CHECKPOINT decided. APPROVED 2026-01-09 at $SHORT: the gate passed. $P $P
- [x] #DT-3 (done 2026-01-09, site $SHORT): A body that is all description and carries no marker. $P $P
- [x] #7: A legacy-numbered record the ID grammar does not take. $P $P
FIX
cp "$DTW" "$T/dt-original.md"
dtblock() { awk -v id="$1" 'index($0, "- [x] " id " (") == 1 || index($0, "- [x] " id ":") == 1 {on=1; print; next} on && /^- / {exit} on && /^#/ {exit} on {print}' "$DTW"; }
rc=0; python3 "$SCRIPT" records "$DTW" --write --date 2026-05-05 >"$T/dt.txt" 2>&1 || rc=$?
check "records exits 0 and writes the dated fixture" "[ \"\$rc\" -eq 0 ] && grep -q WRITTEN \"$T/dt.txt\""
check "#DT-1, dated before the colon with its note below, condenses, its parenthetical kept and its note dated from it" \
  "dtblock '#DT-1' | head -1 | grep -qxF -- '- [x] #DT-1 (2026-01-07): Build the dated thing.' && dtblock '#DT-1' | grep -q \"DONE 2026-01-07; commits $SHORT. Condensed 2026-05-05\""
check "#DT-2, a dated one-line record, condenses with its parenthetical and first sentence kept" \
  "dtblock '#DT-2' | grep -qF -- '- [x] #DT-2 (2026-01-08): A one-line dated record. DONE 2026-01-08' && dtblock '#DT-2' | grep -q 'Condensed 2026-05-05'"
check "#G-DT, a dated gate record, condenses the same way" \
  "dtblock '#G-DT' | grep -qF -- '- [x] #G-DT (2026-01-09): USER CHECKPOINT decided. APPROVED 2026-01-09' && dtblock '#G-DT' | grep -q 'Condensed 2026-05-05'"
check "#DT-3, whose note is its parenthetical and whose body carries no marker, is byte-identical and reported" \
  "grep -qF -- '- [x] #DT-3 (done 2026-01-09, site $SHORT): A body that is all description' \"$DTW\" && grep -q '^SKIPPED #DT-3: a one-line record with no status word or date' \"$T/dt.txt\""
check "#7, done to the record script but outside the ID grammar, is byte-identical and reported as an unrecognised record form" \
  "grep -qF -- '- [x] #7: A legacy-numbered record' \"$DTW\" && grep -qx 'SKIPPED #7: unrecognised record form' \"$T/dt.txt\""
check "the summary counts both skips, so the report does not read clean" "grep -q '^condensed=3 .* skipped=2 ' \"$T/dt.txt\""
cp "$DTW" "$T/dt-after.md"
rc=0; python3 "$SCRIPT" records "$DTW" --write --date 2026-06-06 >"$T/dt2.txt" 2>&1 || rc=$?
check "a second records run over the dated fixture is a no-op" \
  "[ \"\$rc\" -eq 0 ] && grep -qx 'NO CHANGE' \"$T/dt2.txt\" && cmp -s \"$DTW\" \"$T/dt-after.md\""
command rm -rf .state/workstreams/maintain/dt

echo "== learnings"
cp "$T/original.md" "$W"
rc=0; python3 "$SCRIPT" learnings "$W" --write >"$T/learn.txt" 2>&1 || rc=$?
check "learnings exits 0" "[ \"\$rc\" -eq 0 ]"
check "L1, whose kept target says 'that task', is left whole and reported" \
  "grep -qF 'The work goes to #BD-3 (the signing check).' \"$W\" && grep -q '^SKIPPED L1:' \"$T/learn.txt\""
entry() { awk -v id="$1" 'index($0, "- " id " ") == 1 {on=1; print; next} on && (/^- / || /^#/ || /^$/) {exit} on {print}' "$W" | tr '\n' ' ' | tr -s ' '; }
check "L2 keeps both marker sentences, so the HANDED OFF naming docs-site still stands before VERIFIED's 'received there'" \
  "entry L2 | grep -qF 'HANDED OFF 2026-01-03 to docs-site as its handoff of that day. VERIFIED 2026-01-04: received there' && ! entry L2 | grep -q 'middle sentence'"
check "L9, whose kept marker says 'received there' with the sentence naming the place dropped, is left whole and reported" \
  "entry L9 | grep -qF 'naming the docs-site inbox' && grep -q '^SKIPPED L9:' \"$T/learn.txt\""
check "L7, whose kept VERIFIED sentence opens 'it does;' after a dropped sentence, is left whole and reported" \
  "entry L7 | grep -qF 'The reload command activates pending changes.' && grep -E '^SKIPPED L7:' \"$T/learn.txt\" | grep -qF \"('it')\""
check "L8, whose kept target sentence opens 'It' after a dropped sentence, is left whole and reported" \
  "entry L8 | grep -qF 'The cache notes belong with' && grep -q '^SKIPPED L8:' \"$T/learn.txt\""
check "L6's 'it does;' follows a kept APPLIED sentence, so the entry still condenses (the control)" \
  "! grep -q '^SKIPPED L6:' \"$T/learn.txt\" && ! entry L6 | grep -q 'middle sentence'"
check "L6 keeps its QUEUED, APPLIED and VERIFIED sentences: the correction ('not only a relaunch') stays beside the target it corrected" \
  "entry L6 | grep -qF 'QUEUED 2026-01-03: the #BD-4 task line now names it.' && entry L6 | grep -qF 'the remedy is not only a relaunch' && entry L6 | grep -qF 'VERIFIED 2026-01-04: it does;' && ! entry L6 | grep -q 'middle sentence'"
check "L3's statement survives whole past an unquoted %G? (not cut at the question mark)" \
  "grep -A2 '^- L3 ' \"$W\" | tr '\\n' ' ' | tr -s ' ' | grep -qF 'since an empty signature exits 0.' && ! grep -A2 '^- L3 ' \"$W\" | grep -q 'middle sentence'"
check "L4's statement survives whole past 'e.g.'" \
  "grep -A2 '^- L4 ' \"$W\" | tr '\\n' ' ' | tr -s ' ' | grep -qF 'e.g. the record script, over a hand count.' && ! grep -A2 '^- L4 ' \"$W\" | grep -q 'middle sentence'"
check "L5, the control, still condenses" "! grep -A2 '^- L5 ' \"$W\" | grep -q 'middle sentence'"

echo "== learnings: the last marker decides"
# A terminal marker followed by QUEUED reopened the entry; the condenser
# offered it anyway and dropped the sentence saying why it reopened.
mkdir -p "$T/last/.state/workstreams/maintain/q"
LW="$T/last/.state/workstreams/maintain/q/workstream.md"
printf -- '---\nname: q\ntype: maintain\nstatus: active\ncreated: 2026-01-01\n---\n## Purpose\nA fixture.\n\n## Backlog\n### Work (BD)\n- [ ] #BD-1: a task\n- [ ] #BD-2: another\n\n## Learnings\n- L1 (2026-01-01): The first statement of the insight. A middle sentence the condenser would drop. APPLIED 2026-01-02 to #BD-1 and #BD-2. QUEUED 2026-01-03 on #BD-2, since the second half reopened when its build found a gap.\n- L2 (2026-01-01): The second insight. A middle sentence the condenser would drop. APPLIED 2026-01-02 to docs/x.md. EXTENDED 2026-01-03: a further case, still owed to a file.\n- L3 (2026-01-01): The control insight. A middle sentence the condenser would drop. APPLIED 2026-01-02 to docs/x.md.\n' > "$LW"
rc=0; python3 "$SCRIPT" learnings "$LW" >"$T/last.txt" 2>&1 || rc=$?
check "fixture: L1 runs APPLIED then QUEUED, L2 APPLIED then EXTENDED, L3 APPLIED alone" \
  "grep -q 'APPLIED 2026-01-02 to #BD-1 and #BD-2. QUEUED 2026-01-03' \"\$LW\" && grep -q 'APPLIED 2026-01-02 to docs/x.md. EXTENDED' \"\$LW\""
check "L1 (terminal, then QUEUED) and L2 (terminal, then EXTENDED) are not offered; L3, the control, is" \
  "[ \"\$rc\" -eq 0 ] && grep -q '^learnings_condensed=1 ' \"\$T/last.txt\" && grep -q '^L3 ' \"\$T/last.txt\" && ! grep -qE '^L[12] ' \"\$T/last.txt\""

echo "== learnings: follow-on paragraphs"
# A Learning written as several indented paragraphs had its first
# paragraph condensed and the rest left verbatim under it, the report
# saying nothing. The whole entry is now read: its follow-on paragraphs
# condense with it, or it is left whole and reported.
mkdir -p "$T/tail/.state/workstreams/maintain/q"
TW="$T/tail/.state/workstreams/maintain/q/workstream.md"
cat > "$TW" <<'FIX'
---
name: q
type: maintain
status: active
created: 2026-01-01
---
## Purpose
A fixture.

## Backlog
### Work (BD)
- [ ] #BD-1: a task

## Learnings
- L1 (2026-01-01): The first insight, stated once. A middle sentence
  the condenser would drop. APPLIED 2026-01-02 to docs/x.md.

  A spent follow-on paragraph that the disposition makes unnecessary,
  kept under the entry by an earlier condensation.
- L2 (2026-01-01): The second insight, whose marker sits below. A
  middle sentence the condenser would drop.

  APPLIED 2026-01-02 to docs/y.md, in the follow-on paragraph.
- L3 (2026-01-01): The third insight. A middle sentence the condenser
  would drop. APPLIED 2026-01-02 to docs/z.md.

  EXTENDED 2026-01-03: a further case in a follow-on paragraph, still
  owed to a file.
- L4 (2026-01-01): The fourth insight. A middle sentence the condenser
  would drop. APPLIED 2026-01-02 to docs/w.md.

  ```
  a fenced block a re-wrap would break
  ```
- L5 (2026-01-01): The control insight. A middle sentence the condenser
  would drop. APPLIED 2026-01-02 to docs/v.md.

A flush-left paragraph that belongs to the section, not to L5.
FIX
cp "$TW" "$T/tail-original.md"
rc=0; python3 "$SCRIPT" learnings "$TW" --write >"$T/tail.txt" 2>&1 || rc=$?
tentry() { awk -v id="$1" 'index($0, "- " id " ") == 1 {on=1; print; next} on && (/^- / || /^#/) {exit} on {print}' "$TW" | tr '\n' ' ' | tr -s ' '; }
check "the run exits 0 and reports follow_on_paragraphs=2 (L1's and L2's)" \
  "[ \"\$rc\" -eq 0 ] && grep -q '^learnings_condensed=3 .*follow_on_paragraphs=2\$' \"\$T/tail.txt\""
check "L1's spent follow-on paragraph leaves with the condensation (it stayed verbatim under the condensed line)" \
  "! grep -q 'spent follow-on paragraph' \"\$TW\" && tentry L1 | grep -qF 'The first insight, stated once. APPLIED 2026-01-02 to docs/x.md.'"
check "L2's marker, written only in the follow-on paragraph, is read and kept (the entry scored as undispositioned)" \
  "tentry L2 | grep -qF 'The second insight, whose marker sits below. APPLIED 2026-01-02 to docs/y.md' && ! tentry L2 | grep -q 'middle sentence'"
check "L3, EXTENDED in a follow-on paragraph after its terminal marker, is left whole" \
  "tentry L3 | grep -q 'middle sentence' && tentry L3 | grep -qF 'EXTENDED 2026-01-03'"
check "L4, whose follow-on paragraph holds a fenced block, is left whole and reported" \
  "tentry L4 | grep -q 'middle sentence' && grep -q 'a fenced block a re-wrap would break' \"\$TW\" && grep -q '^SKIPPED L4: a follow-on paragraph holds a code block' \"\$T/tail.txt\""
check "L5 condenses and the flush-left paragraph after it stays (the control)" \
  "! tentry L5 | grep -q 'middle sentence' && grep -qx 'A flush-left paragraph that belongs to the section, not to L5.' \"\$TW\""
cp "$TW" "$T/tail-after1.md"
rc=0; python3 "$SCRIPT" learnings "$TW" --write >"$T/tail2.txt" 2>&1 || rc=$?
check "a second run is a no-op: NO CHANGE, byte-identical" \
  "[ \"\$rc\" -eq 0 ] && grep -qx 'NO CHANGE' \"\$T/tail2.txt\" && cmp -s \"\$TW\" \"\$T/tail-after1.md\""

echo "== learnings: anaphora outside the word list"
# Three shapes condensed with skipped=0 while a kept sentence leaned on
# a dropped one: a count (`all three`), a connective (`And`), a
# distributive subject (`Each`). A kept sentence after a dropped one now
# stands only when it opens on a disposition marker or an integration
# target, and a count that refers back holds the entry anywhere.
mkdir -p "$T/ana/.state/workstreams/maintain/q"
AW="$T/ana/.state/workstreams/maintain/q/workstream.md"
cat > "$AW" <<'FIX'
---
name: q
type: maintain
status: active
created: 2026-01-01
---
## Purpose
A fixture.

## Backlog
### Work (BD)
- [ ] #BD-1: a task

## Learnings
- L1 (2026-01-01): The checker misreads names in three shapes. The
  first two are a bare name and a quoted one. APPLIED 2026-01-02 to
  docs/x.md with all three shapes.
- L2 (2026-01-01): The rewrite loses meaning in two ways. A middle
  sentence names the first way. And the second keeps every hash --
  integration target: docs/y.md. APPLIED 2026-01-02 to docs/y.md.
- L3 (2026-01-01): Two instruments misread the build. The middle
  sentence names the request log and the cache. Each was caught by a
  second reading -- integration target: docs/z.md. APPLIED 2026-01-02
  to docs/z.md.
- L4 (2026-01-01): The control insight. A middle sentence the
  condenser would drop. APPLIED 2026-01-02 to docs/v.md.
- L5 (2026-01-01): The dashed-target insight. A middle sentence the
  condenser would drop. -- integration target: docs/u.md. APPLIED
  2026-01-02 there in full.
- L6 (2026-01-01): The self-referring insight. A middle sentence the
  condenser would drop. Integration target: this workstream, at #BD-1,
  whose line now carries the check. APPLIED 2026-01-02.
- L7 (2026-01-01): The standalone-target insight. A middle sentence
  the condenser would drop. Anything that loads a plugin mid-session
  needs a relaunch -- integration target: docs/t.md. APPLIED
  2026-01-02 to docs/t.md.
FIX
rc=0; python3 "$SCRIPT" learnings "$AW" --write >"$T/ana.txt" 2>&1 || rc=$?
aentry() { awk -v id="$1" 'index($0, "- " id " ") == 1 {on=1; print; next} on && (/^- / || /^#/ || /^$/) {exit} on {print}' "$AW" | tr '\n' ' ' | tr -s ' '; }
check "L1, whose kept marker sentence says 'all three' after the sentence naming two is dropped, is left whole and reported" \
  "[ \"\$rc\" -eq 0 ] && aentry L1 | grep -qF 'The first two are' && grep -E '^SKIPPED L1:' \"\$T/ana.txt\" | grep -qF \"('all three')\""
check "L2, whose kept marker sentence opens on 'And' after a dropped one, is left whole and reported" \
  "aentry L2 | grep -qF 'A middle sentence names the first way.' && grep -E '^SKIPPED L2:' \"\$T/ana.txt\" | grep -qF 'opens on neither'"
check "L3, whose kept marker sentence opens on 'Each' after a dropped one, is left whole and reported" \
  "aentry L3 | grep -qF 'the request log and the cache' && grep -q '^SKIPPED L3:' \"\$T/ana.txt\""
check "L4, a marker sentence after a dropped one, still condenses (the control)" \
  "! aentry L4 | grep -q 'middle sentence' && grep -q '^L4 ' \"\$T/ana.txt\""
check "L5, an integration target opened by a dash after a dropped one, still condenses" \
  "! aentry L5 | grep -q 'middle sentence' && aentry L5 | grep -qF -- '-- integration target: docs/u.md.'"
check "L6, whose target names 'this workstream', its own home, condenses (it was read as pointing back)" \
  "! aentry L6 | grep -q 'middle sentence' && aentry L6 | grep -qF 'Integration target: this workstream, at #BD-1'"
check "L7, a target sentence that opens on its own subject after a dropped one, is held too: the inverted rule's cost, a whole entry rather than a lost antecedent" \
  "aentry L7 | grep -q 'middle sentence' && grep -q '^SKIPPED L7:' \"\$T/ana.txt\""

echo "== learnings: the sentence that names where the finding lives"
# On 0.11.5 an entry whose kept sentences named no file or commit lost
# the one dropped sentence that did, with skipped=0: `... recorded as V8
# in reference/validation-report.md` was the only record of where the
# finding went. Such an entry is left whole and reported. An entry
# whose kept sentences already name a file still condenses, and so
# does one whose dropped sentence names only a branch or a workstream.
mkdir -p "$T/loc/.state/workstreams/maintain/q"
LW="$T/loc/.state/workstreams/maintain/q/workstream.md"
cat > "$LW" <<'FIX'
---
name: q
type: maintain
status: active
created: 2026-01-01
---
## Purpose
A fixture.

## Backlog
### Work (BD)
- [ ] #BD-1: a task

## Learnings
- L1 (2026-01-01): Some register may hide inside the tutorial
  concepts. RESOLVED 2026-01-02 at #BD-1 (the corpus check): no
  register is hiding. The concepts read as neutral documentation,
  recorded as V8 in `reference/validation-report.md`.
- L2 (2026-01-01): The same shape with its target named. A middle
  sentence naming `notes/old.md`. APPLIED 2026-01-02 to `docs/a.md`.
- L3 (2026-01-01): A finding about branches. A middle sentence on
  origin/main and maintain/other. RESOLVED 2026-01-02 at #BD-1:
  nothing more to do.
- L4 (2026-01-01): A finding kept by commit. The fix landed at
  abc1234 in the other repository. RESOLVED 2026-01-02 at #BD-1: done.
FIX
rc=0; python3 "$SCRIPT" learnings "$LW" --write >"$T/loc.txt" 2>&1 || rc=$?
lentry() { awk -v id="$1" 'index($0, "- " id " ") == 1 {on=1; print; next} on && (/^- / || /^#/ || /^$/) {exit} on {print}' "$LW" | tr '\n' ' ' | tr -s ' '; }
check "L1, whose dropped sentence alone names the file the finding is in, is left whole and reported" \
  "[ \"\$rc\" -eq 0 ] && lentry L1 | grep -qF 'reference/validation-report.md' && grep -E '^SKIPPED L1:' \"\$T/loc.txt\" | grep -qF 'names where the finding lives (reference/validation-report.md)'"
check "L4, whose dropped sentence alone names a commit, is left whole and reported" \
  "lentry L4 | grep -qF 'abc1234' && grep -E '^SKIPPED L4:' \"\$T/loc.txt\" | grep -qF '(abc1234)'"
check "L2, whose kept marker names its own file, still condenses (the control)" \
  "! lentry L2 | grep -q 'middle sentence' && grep -q '^L2 ' \"\$T/loc.txt\""
check "L3, whose dropped sentence names only a branch and a workstream, still condenses" \
  "! lentry L3 | grep -q 'middle sentence' && grep -q '^L3 ' \"\$T/loc.txt\""

echo "== decisions: live citations"
# `decisions` condensed every Decision named with no citation check: a
# drain named 31 shipped Decisions and 12 were still cited by open work,
# some by open gates. A Decision live content cites is now left whole
# and reported, as `records` leaves a record; `--keep D<n>` holds any.
mkdir -p "$T/dec/.state/workstreams/maintain/q" "$T/dec/.state/workstreams/feature/other"
DW="$T/dec/.state/workstreams/maintain/q/workstream.md"
cat > "$DW" <<'FIX'
---
name: q
type: maintain
status: active
created: 2026-01-01
---
## Purpose
A fixture.

## Backlog
### Work (BD)
- [ ] #BD-1: an open task
- [ ] #G-BD: USER CHECKPOINT -- approve the batch D1 (the batch plan) scoped

## Decisions
### D1 (2026-01-01): The batch plan
First paragraph of the plan.

A second paragraph of detail the open gate still reads.

### D2 (2026-01-01): The shared format
First paragraph of the format.

A second paragraph of detail another workstream's open task reads.

### D3 (2026-01-01): A spent choice
First paragraph of the spent choice.

A second paragraph only a closed Decision mentions.

### D4 (2026-01-01): Another spent choice
First paragraph, and D3 is named here with no note word.

A second paragraph nobody cites.

### D5 (2026-01-01): An open question's subject
First paragraph.

A second paragraph the open question reads.

## Open Questions
- OQ-1: Does D5 (the open question's subject) still hold? (resolve at #BD-1)

## Deletion Criteria
- [ ] the batch ships
FIX
printf -- '---\nname: other\ntype: feature\nstatus: active\ncreated: 2026-01-01\n---\n## Purpose\nAnother.\n\n## Backlog\n### Build (BT)\n- [ ] #BT-1: build to D2 in maintain/q (the shared format)\n' > "$T/dec/.state/workstreams/feature/other/workstream.md"
( cd "$T/dec" && git init -q -b main && git config user.email t@example.invalid && git config user.name T \
  && git config commit.gpgsign false && git config tag.gpgsign false && git add -A && git commit -q -m fixture && git tag v0.1.0 )
cp "$DW" "$T/dec-original.md"
rc=0; python3 "$SCRIPT" decisions "$DW" --decisions D1-D5 --release v0.1.0 >"$T/dec.txt" 2>&1 || rc=$?
check "the dry run exits 0 and reports decisions_condensed=2 skipped=3" \
  "[ \"\$rc\" -eq 0 ] && grep -q '^decisions_condensed=2 .*skipped=3 kept=0' \"\$T/dec.txt\" && cmp -s \"\$DW\" \"\$T/dec-original.md\""
check "D1, cited by an open gate, is SKIPPED as cited by live content at its line" \
  "grep -E '^SKIPPED D1: cited by live content at [^ ]*workstream.md:[0-9]+' \"\$T/dec.txt\" | grep -q 'G-BD'"
check "D2, cited by another workstream's open task homed here, is SKIPPED with that file named" \
  "grep -q '^SKIPPED D2: cited by live content at .state/workstreams/feature/other/workstream.md:' \"\$T/dec.txt\""
check "D5, cited by an unresolved Open Question, is SKIPPED" "grep -q '^SKIPPED D5: cited by live content' \"\$T/dec.txt\""
check "D3, named only by a closed Decision with no note word, and D4, cited by nothing, condense" \
  "grep -q '^D3 ' \"\$T/dec.txt\" && grep -q '^D4 ' \"\$T/dec.txt\""
rc=0; python3 "$SCRIPT" decisions "$DW" --decisions D1-D5 --release v0.1.0 --keep D4 --keep D9 --write >"$T/dec2.txt" 2>&1 || rc=$?
check "--keep D4 leaves D4 whole and reports KEPT; --keep D9, not named, is reported and holds nothing" \
  "[ \"\$rc\" -eq 0 ] && grep -qx 'KEPT D4: --keep' \"\$T/dec2.txt\" && grep -q '^KEPT D9: not among --decisions' \"\$T/dec2.txt\" && grep -qF 'A second paragraph nobody cites.' \"\$DW\""
check "after the write, the cited Decisions keep their detail and D3 lost its second paragraph" \
  "grep -qF 'the open gate still reads' \"\$DW\" && grep -qF \"another workstream's open task reads\" \"\$DW\" && grep -qF 'the open question reads' \"\$DW\" && ! grep -qF 'only a closed Decision mentions' \"\$DW\""
rc=0; python3 "$SCRIPT" decisions "$DW" --decisions D1 --release v0.1.0 --keep '#BD-1' >/dev/null 2>&1 || rc=$?
check "--keep with a task ID is refused: exit 2" '[ "$rc" -eq 2 ]'

echo "== the extract skill"
check "Move 3 names the cites step and --keep beside the records command" \
  "awk '/^## Move 3 /{on=1;next} /^## /{on=0} on' \"$SKILL\" | grep -q 'cites' && awk '/^## Move 3 /{on=1;next} /^## /{on=0} on' \"$SKILL\" | grep -q -- '--keep'"

exit $RESULT
