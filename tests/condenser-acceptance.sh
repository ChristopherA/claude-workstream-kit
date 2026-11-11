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
- L6 (2026-01-01): A clear starts a session but not a process. A middle sentence of evidence that goes. Anything that loads a plugin mid-session needs a relaunch first -- integration target: \`docs/tools.md\`. QUEUED 2026-01-03: the #BD-4 task line now names it. APPLIED 2026-01-04: \`docs/tools.md\` corrected on the way: the remedy is not only a relaunch, because \`/reload\` activates pending changes in the running session. VERIFIED 2026-01-04: it does; the session served the new version after \`/reload\` with no relaunch.
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

echo "== the extract skill"
check "Move 3 names the cites step and --keep beside the records command" \
  "awk '/^## Move 3 /{on=1;next} /^## /{on=0} on' \"$SKILL\" | grep -q 'cites' && awk '/^## Move 3 /{on=1;next} /^## /{on=0} on' \"$SKILL\" | grep -q -- '--keep'"

exit $RESULT
