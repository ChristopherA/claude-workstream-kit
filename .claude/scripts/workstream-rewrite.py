#!/usr/bin/env python3
"""workstream-rewrite.py -- the kit's rewrites, one sub-command each.

Every sub-command changes one workstream.md to a form the rule already
prescribes. All dry-run by default and write only under --write; each
carries a dated marker or a fixed point so a second run is a no-op;
each asserts the structure fingerprint (heading multiset, checkbox ID
and state sequence) identical before writing and exits 1 otherwise;
each leaves the full text in git at the commit before the run. The
fingerprint cannot see prose lost INSIDE a block, and it passed a run
that cut nineteen records' descriptions; `records` and `learnings`
therefore check each condensed entry for what it must keep and refuse
otherwise, and `workstream-record.py fires` run AFTER a rewrite is what
surfaces a severed sentence either check missed. None
infers a judgment the caller names: which Decisions shipped is
--decisions, which blocks a rotation keeps is --keep. The measures
live in workstream-record.py. Standard library only.

Usage:
  workstream-rewrite.py records   <workstream.md> [--write] [--date YYYY-MM-DD] [--keep <#ID>]...
  workstream-rewrite.py decisions <workstream.md> --decisions D1,D4-D9 --release <tag>
                                  [--write] [--date YYYY-MM-DD] [--keep D<n>]...
  workstream-rewrite.py learnings <workstream.md> [--write] [--date YYYY-MM-DD] [--keep L<n>]...
  workstream-rewrite.py rotate    <workstream.md> --tag ws/<name>-<date> [--write]
                                  [--date YYYY-MM-DD] [--keep <phrase>]...
                                  [--allow-stale-claims]
  workstream-rewrite.py archive   <workstream.md> [--phases CODE[,CODE...]]
                                  [--headings <heading>]... [--write]

`records`: every `- [x]` record in the live Backlog, and under
## Archive when that section exists, whose BLOCK -- the task line, its
continuations, and its own indented note paragraphs after a blank
line -- runs past 400 bytes has its completion NOTE condensed to the
rule's form, read from the note alone: the last dated status word,
in any case where it opens a clause, with the date in its own
sentence (with no status word, the date opening its LAST dated
sentence) and the pointer a closing verb carries (`SUPERSEDED
2026-01-12 by #X (...)`, `MOVED ... to <home> as #Y`); its Decision
citations; the commits that lead its evidence; the clauses it must
keep verbatim; a dated marker. The description is never cut: a note
below the task line, or a leading `*(<note>)*`, is replaced in place
with the description lines byte-identical; a one-line record with no
delimiter keeps its description's first sentence whole; a note below
the description, in parts or in `*( )*`, condenses whole or not at all.
A Decision is cited only as its own token (not `pre-D26`, not
`D4/D8/D9`), only when this file defines it, and never when a run of
IDs carries another workstream's home -- a path, a tag, or another
workstream's name, after the run (`D2 and D4 in feature/x`) or before
it (`beta's D4`); the ones it does not cite are named on the entry's
report line. A record that LIVE content cites -- an open task, gate
line, the critical path, an open criterion or an unresolved Open
Question in this file, or another workstream file's live content
homed here -- is left whole whatever the citation's wording, and
reported `SKIPPED <ID>: cited by live content at <file>:<line>`. This
file's closed content (ticked criteria, Decisions, records), an Open
Question resolved in place (`RESOLVED <date> via #ID`) and ACTIVE.md
hold a record only when they cite it FOR ITS NOTE (`see #ID
completion note`, a note word near the ID), reported `cited as its
note by`; a hold that only a record this run condenses gave is
released, the record condensed in the same run and reported
`RELEASED <ID>`, so a second run is a no-op. `--keep <#ID>` leaves any record whole
(`KEPT`). A note already at the completion-note form -- one sentence,
opening with its status word or date, naming its commit and a
backticked command or a count -- is left whole and reported SKIPPED,
as is one whose kept clause opens an item of an enumerated list
(`(1)`, `(a)`, `2.`), whose lead-in and siblings would drop,
and with no commit leading a note, every lead clause carrying a
command or a count is kept, as an issue's is. A record dated before
its colon (`- [x] #ID (2026-01-02): ...`, any parenthetical) keeps the
parenthetical verbatim, its date dating a note that names none; any
other line the record script reads as done is reported `SKIPPED <ID>:
unrecognised record form`. A multi-line record in no recognised shape is left as it is
and reported `SKIPPED <ID>: <reason>`, never guessed at. Note
paragraphs an earlier run left under a condensed record are counted
as orphaned_note_lines and left in place.

`decisions`: each named Decision condenses to its heading, its first
paragraph and a line naming the release; the section is restored to
numeric order. A Decision already one paragraph long is byte-identical
after. --release must be a tag or a commit the repository holding the
file resolves, refused otherwise; the line reads `Shipped in` for a
tag and `Landed at` for a commit, since a project workstream's
Decisions land in commits rather than releases. A named Decision that
live content cites -- the same reading `records` gives a record -- is
left whole and reported `SKIPPED D<n>: cited by live content at
<file>:<line>`; `--keep D<n>` leaves any named Decision whole.

`learnings`: every Learning the record scores terminal (a disposition
marker at sentence start with a date in its sentence, or struck
through whole) condenses to its statement -- the first sentence, with
a leading provenance sentence kept beside it -- every sentence naming
its integration target, and the sentence of EVERY disposition marker
it carries, terminal or deferred, each in its place, re-wrapped; a sentence never ends inside a code span or
before a lower-case word; a deferred or undispositioned
entry is byte-identical after, and so is a terminal one already that
short or one with an EXTENDED written after its last terminal marker.
An entry is read whole, its indented follow-on paragraphs included.
A terminal entry is also left whole, and reported `SKIPPED L<n>`, when
a kept sentence after a dropped one opens on neither a disposition
marker nor an integration target, or points back (`that task`,
`there`, `it` as its subject, a count such as `all three`) at one the
condensation drops, when no kept sentence names a file or commit and
a dropped one does (the only record of where the finding lives), or
when some text cites it for its note; `--keep L<n>` leaves any entry
whole.

`rotate`: the extract skill's Move 3b -- keep only what is live (the
frontmatter and Purpose; open Backlog lines under their headings with
the critical-path paragraph; the Decisions a surviving task, gate,
criterion or critical path cites; deferred and undispositioned
Learnings; unresolved Open Questions; the Deletion Criteria; every
section the kit does not know, verbatim) and write ONE rotation
paragraph first under Purpose -- `Rotated <date>; the record before
it is at <tag>`, every earlier rotation's tag listed after it newest
first, rewritten in place at each rotation -- and, when Learnings
leave, the numbering note at the head of Learnings saying which L
range is at which tag and what the next Learning is. Three checks
the hand rotation of 2026-09-04 passed while losing content: before
writing, every leaving block's ID and lead phrase is searched for in
the surviving text and in the live content of every other state file,
and any hit refuses the run unless the hit's sentence names the tag
(the report's line numbers index the files on disk, never the rotated
output, and each names the block's first line beside the citing line);
in another file a bare-ID match is a hit only when its home is this
workstream, and the home-less ones are listed without refusing; a
lead-phrase match exactly where a task line's own description begins
is a sibling task opening with the same words and is not a hit;
after the rewrite, every count a surviving criterion, gate line or
critical-path sentence states about a section that was true before
and is false after is reported with both figures and refuses the run
unless --allow-stale-claims; and the open count, gate count, STANDING
count and open IDs are asserted identical. The tag must exist. A file
with wrapped open lines is refused as non-conforming. A Learning is
read whole, its indented follow-on paragraphs included, so it leaves
or stays as one.

`archive`: the extract skill's Move 3 relocation. Every `### ...
(<CODE>)` block whose heading declares a --phases code (a code
declared by several headings moves them all; a heading declaring
several codes moves when any is named), read between `## Backlog` and
the next `## ` heading, so a `### D3 (...)` heading past it is never a
phase, and running from its heading to the next `### ` or higher,
moves to the end of `## Archive` in file order, the section created at
the end of the file when absent. `--headings <heading>`, repeatable,
selects a block by its heading instead, for a code declared by several
headings of which only some are complete: the text after `### `
(given with or without the `### `), matched exactly against every
`### ` heading under `## Backlog`, coded or not. A text matching none
refuses the run and names it, unless an `## Archive` heading reads
the same, which reports `ALREADY ARCHIVED heading line <n>:
<heading>`; a text matching more than one refuses and names each
line. The two options combine, a block named by both moving once. A block holding any open checkbox
line, indented or not, refuses the run and names each line (its first
160 characters); a code no Backlog heading declares refuses the run
and names the code, unless an `## Archive` heading already declares
it, which reports `ALREADY ARCHIVED <code>`, so a second run prints NO
CHANGE. Before writing, the heading-line multiset (the new `##
Archive` heading excluded), the checkbox ID-and-state multiset and the
non-blank-line multiset are asserted identical; the sequence the
fingerprint reads is not, since a move reorders it. A moved checkbox
whose ID the task-ID grammar cannot parse (`#P8-V`) is reported
`UNPARSABLE <ID> line <n>` and still moves: the ID leaves the Backlog
and stops being flagged there, by `workstream-record.py`'s
unparsable_ids or anything else that reads only the Backlog, so the
report is where it stays visible. Each moved block is reported `MOVE
line <a>-<b> (<n> checkbox line(s)): <heading>`.

Exit 0 on success (a dry run included), 1 on a refusal or a failed
check, 2 on usage or an unreadable file. Prints a report, then WRITTEN
or NO CHANGE (a dry run with changes prints the report alone). The
report is one shape for records, decisions and learnings: a summary
line, then one line per condensed entry -- `<ID> <bytes before>-><bytes
after>: <the condensed line's first 160 characters>`, with what the
note named and did not keep in brackets after it -- so a dry run
shows what a write would leave. A condensed record lists as `commits`
only the hex words its note names (7 to 40 characters, at least one a
letter) that resolve as commits in the repository holding the file,
each once, as first written: those in its lead clause, and one named
later only when a verb of making stands directly before it (landed,
built, shipped, fixed, committed, merged, released or pushed, an `at`,
`in` or `as` allowed between; the noun `commit` is not one). Any other
commit, and any hex word that does not resolve -- a gist ID, a
digest, a commit in another repository -- keeps the clause it sits in
and is named in the report, and with no commit leading, an issue, PR
or URL in the lead keeps its clause too. The script never
derives a hash; outside a repository the words are listed unchecked
and the report says so.
"""

import datetime
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from workstream_state import (  # noqa: E402
    ANY_HEADING_RE, CHECKBOX_ID_RE, CHECKBOX_HASH_RE, CHECKBOX_RE, LIST_ITEM_RE, ADDENDUM_RE, DECISION_HEADING_RE, DELETION_OPEN_RE, DONE_LINE_RE,
    DEFERRED_RE, TERMINAL_MARKERS, DEFERRED_MARKERS, ADDENDUM_MARKERS,
    GATE_LINE_RE, LEARNING_RE, PHASE_HEADING_RE, TERMINAL_RE, TOTAL_OPEN_RE, STRIKE_RE,
    blank_strikes, disposition, extract_section, find_workstreams, fingerprint, fold_blocks,
    git, join_block, line_at, marker_counts, read_lines, section_bounds, sentence_span,
    split_sentences, strip_frontmatter, wrap, TASK_ID_FORM, GATE_ID_FORM,
    CROSS_REF_WS_RE, workstream_id, open_question, RESOLVED_MARK_RE,
    learning_tail, with_learning_tails,
)

PROG = 'workstream-rewrite.py'
GUARD_RE = re.compile(r"Condensed \S+ at extract")  # any earlier run, whatever its date


class Refusal(Exception):
    pass


def usage(msg=None):
    if msg:
        sys.stderr.write("%s: %s\n" % (PROG, msg))
    sys.stderr.write(__doc__)
    sys.exit(2)


def parse_options(args, flags=(), values=(), multi=()):
    """Split args into positionals and options; unknown options are usage."""
    opts = {f: False for f in flags}
    opts.update({v: None for v in values})
    opts.update({m: [] for m in multi})
    rest = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in flags:
            opts[a] = True
        elif a in values or a in multi:
            if i + 1 >= len(args):
                usage("%s needs a value" % a)
            if a in multi:
                opts[a].append(args[i + 1])
            else:
                opts[a] = args[i + 1]
            i += 1
        elif a.startswith('--'):
            usage("unknown option %s" % a)
        else:
            rest.append(a)
        i += 1
    return rest, opts


def load(path):
    try:
        with open(path, encoding='utf-8') as f:
            return f.read()
    except OSError as e:
        usage(str(e))


def finish(path, text, new, dry, report, extra_lines=()):
    """The shared tail: fingerprint, report, write or not."""
    old_lines = text.split('\n')
    new_lines = new.split('\n')
    if fingerprint(new_lines) != fingerprint(old_lines):
        sys.stderr.write("%s: structure changed (headings or checkbox IDs/states); refusing to write\n" % PROG)
        return 1
    print(" ".join(report))
    for l in extra_lines:
        print(l)
    if new == text:
        print("NO CHANGE")
    elif not dry:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new)
        print("WRITTEN")
    return 0


# --- records and decisions: the two shipped moves ------------------------

# A completed record: the ID, then an optional parenthetical before the
# colon -- `#XX-3 (2026-01-02):`, `#G-XX (CLEARED 2026-01-02):` -- which
# is carried verbatim as part of the separator and never condensed. Any
# other line the record script reads as done (DONE_LINE_RE) is reported
# SKIPPED as an unrecognised form rather than passed over in silence.
DONE_RE = re.compile(r"^( *- \[x\] )(#" + TASK_ID_FORM + "|#" + GATE_ID_FORM + r")((?: \([^()]*\))?: ?)(.*)$")
DATE_RE = re.compile(r"\b(20[0-9]{2}-[0-9]{2}-[0-9]{2})\b")
SHA_RE = re.compile(r"\b(?=[0-9]*[a-f])[0-9a-f]{7,40}\b")  # a hash the note names verbatim, any repo; never a bare number
STATUS_WORDS = ('DONE', 'DECIDED', 'RETIRED', 'SUPERSEDED', 'CLOSED', 'SHIPPED', 'ABSORBED',
                'RESOLVED', 'APPROVED', 'UNBLOCKED', 'MERGED', 'MOVED')
STATUS_RE = re.compile(r"\b(" + "|".join(STATUS_WORDS) + r")\b")
# The same words in any case where they OPEN a clause -- `closed
# 2026-01-12, superseded by #BD-12` -- which an upper-case-only match
# missed, writing DONE over a record closed unbuilt. Counted only when
# the word is used as a status: directly before a date, a pointer's
# preposition or another status word -- `closed issue 10` is an act,
# not a closing -- and, like any mark, only when its sentence carries a
# date, so a description's passing `done` never displaces a dated one.
CLAUSE_STATUS_RE = re.compile(
    r"(?:^|(?<=\*\()|(?<=\()|(?<=[.;:,]\s)|(?<=\s--\s))(" + "|".join(STATUS_WORDS) + r")\b", re.I)
CLAUSE_STATUS_FOLLOW_RE = re.compile(
    r"(?::?\s+(?:on\s+)?20[0-9]{2}-[0-9]{2}-[0-9]{2}\b|\s+(?:by|to|into|as)\s|,\s+(?:"
    + "|".join(STATUS_WORDS) + r")\b)", re.I)
# The pointer a closing verb carries -- `superseded by #BD-12 (the
# replacement)`, `moved 2026-01-13 to feature/x as #XY-1` -- which is
# the whole content of a record closed that way and was dropped.
POINTER_RE = re.compile(
    r"\b(superseded|absorbed|merged|moved)(?:\s+(?:on\s+)?20[0-9]{2}-[0-9]{2}-[0-9]{2}\b)?"
    r"\s+(?:by|to|into|as|in)\s+", re.I)
POINTER_MAX = 240  # characters; a pointer clause with no end in that span is not guessed at


def status_marks(body):
    """(start, end, WORD, upper) for every status word in body: upper
    case anywhere, or any case where it opens a clause."""
    seen = {}
    for m in STATUS_RE.finditer(body):
        seen[m.start(1)] = (m.start(1), m.end(1), m.group(1), True)
    for m in CLAUSE_STATUS_RE.finditer(body):
        if m.start(1) not in seen and CLAUSE_STATUS_FOLLOW_RE.match(body, m.end(1)):
            seen[m.start(1)] = (m.start(1), m.end(1), m.group(1).upper(), False)
    return [seen[k] for k in sorted(seen)]


def clause_end(text, start, limit=POINTER_MAX):
    """The offset where the clause running from start ends: a `;` or
    `,`, a full stop before whitespace, or a note's closing `)*`, at
    parenthesis depth 0 and outside a code span; None when no end
    falls within limit characters."""
    depth = 0
    code = False
    i = start
    while i < len(text) and i - start <= limit:
        c = text[i]
        if c == '`':
            code = not code
        elif not code:
            if c == '(':
                depth += 1
            elif c == ')':
                if depth == 0:
                    return i
                depth -= 1
            elif depth == 0 and c in ';,':
                return i
            elif depth == 0 and c in '.!?' and (i + 1 == len(text) or text[i + 1].isspace()):
                return i
        i += 1
    return len(text) if i == len(text) else None


def pointer_of(note):
    """(verb, phrase_after_verb_and_date, whole_phrase) for the LAST
    closing pointer in note, or None. Its verb must itself be a status
    mark -- upper case, or opening a clause -- so prose that says `the
    rounds moved to another skill` is not read as where the record
    went."""
    found = None
    starts = {m[0] for m in status_marks(note)}
    for m in POINTER_RE.finditer(note):
        if m.start(1) not in starts:
            continue
        end = clause_end(note, m.end())
        if end is not None and end > m.end():
            found = (m.group(1).upper(), note[m.end(1):end].strip(), note[m.start():end].strip())
    return found


def entry_line(ident, before, after, line):
    """The per-entry report line every rewrite prints."""
    return "%s %d->%d: %s" % (ident, before, after, line.strip()[:160])


def status_and_date(body, dates):
    """The record's LAST DATED status word and the date in that word's
    own sentence (the record script's marker rule): after the word
    first, else anywhere in the sentence. Never the block's last date,
    which can belong to another sentence -- a record that ran VERIFIED,
    DONE, CORRECTED condensed to the date of another project's commit
    mentioned last. A later status word whose sentence carries no date
    (`DONE 2026-09-22 at e0c1afb ... SUPERSEDED the same day by D12`)
    does not displace the dated one; with no dated status word at all
    the last upper-case one stands as n.d. With no status word, the
    note is dated by the LAST of its sentences that opens with a date
    (`2026-01-02 at abc1234: ...`) -- a note kept as several dated
    paragraphs was dated by its first, which is the work's start rather
    than its close -- and otherwise the block's last date stands, since
    nothing else ties a date to the status."""
    marks = status_marks(body)
    for start, end, word, _upper in reversed(marks):
        s, e = sentence_span(body, start)
        after = DATE_RE.search(body, end, e)
        if after:
            return word, after.group(1)
        within = DATE_RE.search(body, s, e)
        if within:
            return word, within.group(1)
    upper = [m for m in marks if m[3]]
    if upper:
        return upper[-1][2], "n.d."
    opened = [m.group(1) for m in (re.match(r"[\s*(]*(?:[Dd]one\s+)?(20[0-9]{2}-[0-9]{2}-[0-9]{2})\b", s)
                                   for s in split_sentences(body)) if m]
    if opened:
        return "DONE", opened[-1]
    return "DONE", (dates[-1] if dates else "n.d.")


# A Decision a record cites: the ID standing as its own token, never
# part of a longer one (`pre-D26`, `D4/D8/D9`), and never one whose home
# is another workstream. IDs written as a RUN -- `D2 and D4 in
# feature/alpha`, `beta's D4, D8`, a gloss allowed after each -- share
# the home written after the run's last ID or before its first: a
# lookahead on each ID alone read `D2` in `D2 and D4 in feature/alpha`
# as this file's, and a condensed record cited three local Decisions it
# never named. A home is a workstream path, a tag, or the name of
# another workstream in the project; this workstream's own is local.
DEC_TOKEN_RE = re.compile(r"(?<![\w/-])D([0-9]+)(?![\w/-])")
DEC_GLUE_RE = re.compile(r"^\s*(?:\([^()]*\))?\s*(?:,\s*(?:and\s+|or\s+)?|and\s+|or\s+|&\s*)$")
HOME_PATH = r"(?:(?:explore|feature|fix|project|maintain|docs)/[a-z0-9.-]*[a-z0-9]|ws/[\w.-]*\w)"


class Context(object):
    """What reading a note needs from outside it: the Decisions this
    file defines, this workstream's own home and name, the project's
    other workstream names, and the commit resolver."""

    def __init__(self, present=frozenset(), own=None, others=(), resolve=None):
        self.present = set(present)
        self.own = own
        self.own_name = own.split('/', 1)[1] if own and '/' in own else own
        self.others = sorted(set(others) - {self.own_name}, key=len, reverse=True)
        self.resolve = resolve
        names = "|".join(re.escape(n) for n in self.others)
        home = HOME_PATH + (("|(?:the\\s+)?(?:%s)(?:\\s+workstream)?" % names) if names else "")
        # No `^`: the pattern is matched at an offset, where `^` never holds.
        self.after_re = re.compile(r"\s*(?:\([^()]*\))?`?(?:'s)?\s+(?:in|at|of|from)\s+`?(" + home + r")(?![\w/-])")
        self.before_re = re.compile(r"(?<![\w/-])(" + home + r")`?(?:'s)?\s*(?:\(\s*)?$")


def home_is_foreign(home, ctx):
    h = re.sub(r"^the\s+|\s+workstream$", "", home.strip())
    return h not in (ctx.own, ctx.own_name)


def decisions_cited(note, ctx):
    """(local, absent, foreign): the Decision IDs a note cites that this
    file defines, numeric order; those it names that this file does not,
    reported rather than cited, since a citation to nothing is the
    pointer the rule calls a defect; and those whose home is another
    workstream, reported and never credited here."""
    toks = list(DEC_TOKEN_RE.finditer(note))
    runs = []
    for m in toks:
        if runs and DEC_GLUE_RE.match(note[runs[-1][-1].end():m.start()]):
            runs[-1].append(m)
        else:
            runs.append([m])
    local, foreign = set(), set()
    for run in runs:
        nums = [int(m.group(1)) for m in run]
        after = ctx.after_re.match(note, run[-1].end())
        before = ctx.before_re.search(note[:run[0].start()])
        home = (after.group(1) if after else None) or (before.group(1) if before else None)
        if home and home_is_foreign(home, ctx):
            foreign.update(nums)
        else:
            local.update(nums)
    local -= foreign
    return (["D%d" % n for n in sorted(local) if n in ctx.present],
            ["D%d" % n for n in sorted(local) if n not in ctx.present],
            ["D%d" % n for n in sorted(foreign)])


# Where a clause of a note ends, for keeping one verbatim: a `;`, a
# `: `, ` -- ` or a sentence end, at parenthesis depth 0 and outside a
# code span.
def segments(text):
    """[(start, end)] of the note's clauses."""
    out = []
    depth = 0
    code = False
    start = 0
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        cut = 0
        if c == '`':
            code = not code
        elif not code:
            if c == '(':
                depth += 1
            elif c == ')' and depth:
                depth -= 1
            elif depth == 0:
                if c == ';' or (c == ':' and i + 1 < n and text[i + 1] == ' '):
                    cut = 1
                elif c in '.!?' and (i + 1 == n or text[i + 1].isspace()):
                    cut = 1
                elif text.startswith(' -- ', i):
                    cut = 4
        if cut:
            out.append((start, i))
            start = i + cut
            i += cut
            continue
        i += 1
    if start < n:
        out.append((start, n))
    return [(s, e) for s, e in out if text[s:e].strip()]


# A kept clause's opener the condensed note already carries: a status
# word in any case with its date, a date alone, or an upper-case status
# word alone -- never a lower-case verb that is the clause's own (`closed
# issue 10 on the site`).
SEGMENT_OPENER_RE = re.compile(
    r"^[\s*(]*(?:(?:(?i:" + "|".join(STATUS_WORDS) + r")\s+)?(?:on\s+)?20[0-9]{2}-[0-9]{2}-[0-9]{2}\b[\s:]*"
    r"|(?:" + "|".join(STATUS_WORDS) + r"|Done)\b[\s:]*)")
# An identifier a note can rest on when no commit leads it.
IDENT_RE = re.compile(
    r"\b(?:issue|issues|PR|pull request)\s+#?[0-9]+\b|https?://\S+|\b[\w.-]+/[\w.-]+#[0-9]+\b|\b[\w.-]+#[0-9]+\b")
# A count a note's evidence states -- `reports 14 patterns`, `0 for this
# file` -- and never a date, a time, a version, an ID or a hash part:
# the digits stand alone, not after `-`, `.`, `:`, `/`, `#` or a letter.
COUNT_RE = re.compile(r"(?<![\w#.:/-])[0-9]+(?![\w:/-]|\.[0-9])")


def carries_evidence(text):
    """True when a clause states a result the note rests on: a
    backticked command or a count (hex words blanked first, so an
    all-digit hash is not read as one)."""
    return '`' in text or bool(COUNT_RE.search(SHA_RE.sub(' ', text)))


AT_THE_FORM = "a note already at the completion-note form (one sentence: its date, its commit, its command or count)"


def at_the_form(note):
    """True for a note already in the rule's completion-note form: ONE
    sentence, opening with its status word or date, that names its
    commit and the command or count whose result is the evidence. The
    condenser could only drop that result, for fewer bytes than its own
    marker: `DONE 2026-10-03 at 9b6933f in <kit>: \\`self-check\\` reports
    14 patterns OK` would have become `DONE 2026-10-03; at 9b6933f in
    <kit>` to save 15."""
    n = note.strip()
    return (len(prose_sentences(n)) == 1 and bool(NOTE_START_RE.match(n)) and bool(SHA_RE.search(n))
            and carries_evidence(n))


def segment_text(note, s, e):
    """A clause kept verbatim, its leading status word and date dropped
    since the condensed note opens with them."""
    seg = note[s:e].strip()
    trimmed = SEGMENT_OPENER_RE.sub("", seg, count=1).strip()
    return trimmed or seg


def batch_resolver(cwd):
    """A function token -> full commit hash or None, answering from one
    `git cat-file --batch-check` per run; None when cwd is not in a git
    repository, so the caller can say the hashes went unchecked."""
    rc, _ = git(['rev-parse', '--git-dir'], cwd)
    if rc != 0:
        return None
    cache = {}

    def resolve_all(tokens):
        todo = [t for t in dict.fromkeys(tokens) if t not in cache]
        if not todo:
            return
        try:
            p = subprocess.run(['git', 'cat-file', '--batch-check'], cwd=cwd, capture_output=True, text=True,
                               input=''.join(t + '^{commit}\n' for t in todo))
            answers = p.stdout.splitlines()
        except OSError:
            answers = []
        for t, a in zip(todo, answers + [''] * len(todo)):
            parts = a.split()
            cache[t] = parts[0] if len(parts) >= 2 and parts[1] == 'commit' else None

    def resolve(token):
        if token not in cache:
            resolve_all([token])
        return cache.get(token)

    resolve.prime = resolve_all
    return resolve


# A verb of making directly before a hash, an `at`, `in` or `as`
# allowed between: what says a commit IS the work rather than a point
# the note measures from. The bare noun `commit` is not one -- `after the
# capture commit 9910d4c` was listed as a record's evidence.
MAKING_BEFORE_RE = re.compile(
    r"\b(?:landed|built|shipped|fixed|committed|merged|released|pushed)(?:\s+(?:at|in|as))?\s+`?$", re.I)


def note_evidence(note, ctx):
    """(listed_commits, kept_clauses, unresolved, unmade): what a
    condensed note keeps as its evidence.

    Commits are hex words (`SHA_RE`) that resolve as commits in the
    repository holding the file; one commit named short and full is
    listed once, as first written. A hex word that does not resolve --
    a gist ID, a data digest, a commit in another repository -- is
    never listed as a commit: the clause it sits in is kept verbatim
    instead, since a resolve-and-drop filter would lose the cross-
    repository commits notes cite and the sentence saying what a digest
    was. With no repository the words are listed as written, the
    report saying so.

    Commits that LEAD the note -- named in its first clause run, up to
    the first `;` -- are listed. A commit named later is listed only
    when a verb of making stands directly before it (`landed at`,
    `committed as`, `fixed in`); any other keeps its clause verbatim
    and is reported as unmade, since a provenance commit (`where a
    deleted notes.md lived`) or a time reference (`started after the
    capture commit X`) is not the work's own commit. With no commit
    leading, an issue, PR or URL in that lead is the record's handle
    and its clause is kept, and so is every lead clause carrying a
    backticked command or a count: a note whose evidence was
    `\\`bare-ids\\` reports 0 for this file` fell back to `evidence in the
    record at the commit preceding` and lost the result."""
    toks = list(dict.fromkeys(SHA_RE.findall(note)))
    if ctx.resolve is None:
        return toks, [], [], []
    ctx.resolve.prime(toks)
    first = split_sentences(note)[:1]
    lead = (first[0].split(';', 1)[0] if first else '')
    seen_commit = {}
    lead_commits, other_commits, unresolved = [], [], []
    for t in toks:
        full = ctx.resolve(t)
        if full is None:
            unresolved.append(t)
            continue
        if full in seen_commit:
            continue
        seen_commit[full] = t
        (lead_commits if re.search(r"(?<![0-9a-f])" + t + r"(?![0-9a-f])", lead) else other_commits).append(t)
    kept = []
    segs = segments(note)

    def keep_clause(at):
        for s, e in segs:
            if s <= at < e:
                txt = segment_text(note, s, e)
                if txt not in kept:
                    kept.append(txt)
                return

    for t in unresolved:
        at = re.search(r"(?<![0-9a-f])" + t + r"(?![0-9a-f])", note)
        if at:
            keep_clause(at.start())
    made, unmade = [], []
    for t in other_commits:
        hits = list(re.finditer(r"(?<![0-9a-f])" + t + r"(?![0-9a-f])", note))
        if any(MAKING_BEFORE_RE.search(note[:h.start()]) for h in hits):
            made.append(t)
        else:
            unmade.append(t)
            if hits:
                keep_clause(hits[0].start())
    if lead_commits:
        return lead_commits + made, kept, unresolved, unmade
    handles = []
    ident = IDENT_RE.search(lead)
    if ident:
        for s, e in segs:
            if s <= ident.start() < e:
                handles.append(segment_text(note, s, e))
                break
    # A command or count is the evidence only when the lead IS the note
    # -- opening with its status word or date -- and not a one-line
    # record's description quoting a command.
    off = note.find(lead) if lead.strip() else -1
    if off >= 0 and NOTE_START_RE.match(lead.strip()):
        for s, e in segs:
            if off <= s < off + len(lead) and carries_evidence(note[s:e]):
                txt = segment_text(note, s, e)
                if txt not in handles:
                    handles.append(txt)
    return made, handles + [k for k in kept if k not in handles], unresolved, unmade


# A kept clause that is one item of an enumerated list -- `(1) ...`,
# `(a) ...`, `2. ...`: kept alone, it reads as a list of one with its
# lead-in and siblings gone (`FLAGGED for the as-built check: (1) ...;
# (2) ...` condensed to `...; (1) ...`), so the record is left whole.
ENUM_ITEM_RE = re.compile(r"^(?:\((?:[0-9]+|[a-z])\)|[0-9]+\.)\s")


class SplitList(Exception):
    """A record whose condensation would keep one item of a list."""


def condensed_note(note, ctx, mark, fallback_date=None):
    """(text, notes) -- the completion-note form for one note's text:
    the status word and date of its own sentence, with the pointer its
    closing verb carries; its Decision citations; the commits that lead
    its evidence and the clauses kept verbatim; the dated marker; and
    the report annotations for what it named and did not list.
    Everything is read from the NOTE alone -- never from the
    description beside it, whose asides and dates are not the record's
    evidence. A dated record's `(<date>)` before the colon is its
    fallback_date, used only when the note itself carries none."""
    dates = DATE_RE.findall(note)
    decs, absent, foreign = decisions_cited(note, ctx)
    shas, kept, unresolved, unmade = note_evidence(note, ctx)
    for k in kept:
        m = ENUM_ITEM_RE.match(k)
        if m:
            raise SplitList("a kept clause is one item of an enumerated list (`%s`), whose lead-in and "
                            "siblings the condensation would drop -- condense by hand or leave it" % m.group(0).strip())
    mark_word, date = status_and_date(note, dates)
    if date == "n.d." and fallback_date:
        date = fallback_date
    head = "%s %s" % (mark_word, date)
    ptr = pointer_of(note)
    if ptr:
        verb, after_verb, whole = ptr
        if verb == mark_word:
            # The record's own verb carries the pointer: `SUPERSEDED
            # 2026-01-12 by #BD-12 (...)`, the date not repeated.
            head += " " + re.sub(r"^(?:on\s+)?20[0-9]{2}-[0-9]{2}-[0-9]{2}\b\s*", "", after_verb)
        else:
            head += ", " + whole
    ev = []
    if decs:
        ev.append("reasoning in " + ", ".join(decs))
    if shas:
        ev.append("commits " + ", ".join(shas[:8]) + (" ..." if len(shas) > 8 else ""))
    ev.extend(kept)
    if ev:
        text = "%s; %s. %s; full record in git before that commit." % (head, "; ".join(ev), mark)
    elif ptr:
        text = "%s. %s; full record in git before that commit." % (head, mark)
    else:
        text = "%s; evidence in the record at the commit preceding this condensation. %s; full record in git before that commit." % (head, mark)
    notes = []
    if absent:
        notes.append("not cited, no such Decision here: %s" % ", ".join(absent))
    if foreign:
        notes.append("not cited, another workstream's: %s" % ", ".join(foreign))
    if unresolved:
        notes.append("not listed, no such commit here, kept in its clause: %s" % ", ".join(unresolved))
    if unmade:
        notes.append("not listed, no verb of making before it, kept in its clause: %s" % ", ".join(unmade))
    if ctx.resolve is None and shas:
        notes.append("hashes listed unchecked: not a git repository")
    return text, notes


# --- inbound citations: what live content cites a record's NOTE for ---------

# A citation reads a record's note when a note word stands near the ID --
# `see #X completion note for the measurement`, `#Y in
# maintain/x (...); its completion note has the number` -- or `see`
# directly before it. A citation of the task itself (a Decision routing
# work to it) survives condensation, since the ID and description stay.
NOTE_WORD_RE = re.compile(r"\b(?:completion\s+)?notes?\b|\bevidence\b|\bmeasurements?\b", re.I)
SEE_BEFORE_RE = re.compile(r"\bsee\s+(?:the\s+)?$", re.I)
NOTE_WINDOW = (40, 80)  # characters before and after the ID


def live_blocks(lines, whole):
    """(start, raw) for the blocks of a state file that are LIVE: the
    whole text when whole, else open Backlog lines and the critical
    path, unresolved Open Questions and open Deletion Criteria."""
    blocks = fold_blocks(lines)
    if whole:
        return [(s, r) for s, k, t, r in blocks if k != 'heading']
    out = []
    cur = None
    for s, k, t, r in blocks:
        if k == 'heading':
            if t.startswith('## '):
                cur = t
            continue
        if cur == '## Backlog' and (TOTAL_OPEN_RE.match(r[0]) or t.startswith('**Critical path')):
            out.append((s, r))
        elif cur == '## Open Questions' and open_question(r):
            out.append((s, r))
        elif cur == '## Deletion Criteria' and DELETION_OPEN_RE.match(r[0]):
            out.append((s, r))
    return out


def block_owner(raw):
    """The ID a block defines: a checkbox's task ID or a Learning's L<n>."""
    m = CHECKBOX_ID_RE.match(raw[0])
    if m:
        return m.group(2)
    m = LEARNING_RE.match(raw[0])
    return ("L" + m.group(1)) if m else None


def resolved_question(raw):
    """True for an Open Question resolved in place -- `- OQ-1:
    ~~question~~ RESOLVED <date> via #X: answer`, or the struck-ID
    form carrying RESOLVED. live_blocks now drops both through
    open_question; the condenser's own filter stays as a guard."""
    if not re.match(r"^- (?:~~)?OQ-[0-9]+", raw[0]):
        return False
    return bool(marker_counts(blank_strikes(join_block(raw, 0)[0]), RESOLVED_MARK_RE))


def note_citations(root, path, lines, ids, live=False):
    """{id: (where, sentence, kind)} for each of ids that some text
    cites FOR ITS NOTE: anywhere in this file but the record's own
    block, ticked criteria and closed Decisions included, since a ticked
    criterion's `see #X completion note` lost its measurements to a run
    that never looked; and the live content of every other state file,
    where a bare ID counts only when its home is this workstream, IDs
    being per-workstream (ACTIVE.md is read whole, and its home-less
    mentions belong to the workstream it points at). kind is 'note'
    for a citation the note words found.

    With live, a citation from LIVE content -- this file's open tasks,
    gate lines, critical path, open criteria and unresolved Open
    Questions, or another workstream file's live content homed here --
    is found whatever its wording, kind 'live': an open task reading
    `the readings are in the #X record` named no note word, and the
    record condensed to its fallback and lost readings that existed
    nowhere else. Note words still decide for closed content, for an
    Open Question resolved in place (`~~question~~ RESOLVED <date> via
    #X`), which names where it was settled rather than pointing at a
    note, and for ACTIVE.md, whose session narrative (`Done: #X (...)`)
    is rewritten every session."""
    if not ids:
        return {}
    alt = "|".join(re.escape(i) for i in sorted(ids, key=len, reverse=True))
    rx = re.compile(r"(?<![\w/-])(" + alt + r")(?![\w-])")
    wid = workstream_id(path)
    found = {}
    targets = [(os.path.basename(path) if root is None else os.path.relpath(path, root), lines, True, False)]
    active_ws = None
    if root is not None:
        for p, rel in find_workstreams(root):
            if os.path.abspath(p) != os.path.abspath(path):
                targets.append((rel, read_lines(p), False, False))
        active = os.path.join(root, '.state', 'ACTIVE.md')
        if os.path.isfile(active):
            alines = read_lines(active)
            for l in alines[:10]:
                if l.startswith('workstream:'):
                    active_ws = l.split(':', 1)[1].strip().strip('"')
                    break
            kept = {n for n, _t in strip_frontmatter(alines)}
            targets.append(('.state/ACTIVE.md', [t if n in kept else '' for n, t in enumerate(alines, start=1)],
                            False, True))
    for rel, flines, own, is_active in targets:
        if own:
            kept = {n for n, _t in strip_frontmatter(flines)}
            flines = [t if n in kept else '' for n, t in enumerate(flines, start=1)]
            heads = {}
            cur = None
            for n, l in enumerate(flines, start=1):
                if l.startswith('## '):
                    cur = l[3:].strip()
                heads[n] = cur
            blocks = live_blocks(flines, True)
            live_starts = {s for s, r in live_blocks(flines, False) if not resolved_question(r)} if live else set()
        else:
            blocks = live_blocks(flines, is_active)
            live_starts = ({s for s, r in blocks if not resolved_question(r)}
                           if live and not is_active else set())
        for start, raw in blocks:
            owner = block_owner(raw)
            text, starts = join_block(raw, start)
            blanked = blank_strikes(text)
            for m in rx.finditer(blanked):
                ident = m.group(1)
                if ident in found or (own and ident == owner):
                    continue
                if not own:
                    home = ID_HOME_RE.match(blanked, m.end())
                    s, e = sentence_span(blanked, m.start())
                    homes = [home.group(1)] if home else sorted(set(CROSS_REF_WS_RE.findall(blanked[s:e])))
                    if homes:
                        if homes != [wid]:
                            continue
                    elif not (is_active and active_ws == wid):
                        continue
                lo = max(0, m.start() - NOTE_WINDOW[0])
                hi = min(len(blanked), m.end() + NOTE_WINDOW[1])
                s, e = sentence_span(blanked, m.start())
                window = blanked[max(lo, s):min(hi, e)]
                if start in live_starts:
                    kind = 'live'
                elif NOTE_WORD_RE.search(window) or SEE_BEFORE_RE.search(blanked[s:m.start()]):
                    kind = 'note'
                else:
                    continue
                line = line_at(starts, m.start())
                where = "%s:%s" % (rel, line)
                if own and heads.get(line):
                    where += " (%s)" % heads[line]
                found[ident] = (where, blanked[s:e].strip()[:120], kind)
    return found


def condense_context(path, lines, keep=()):
    """The Context a records or learnings run reads notes with."""
    p = os.path.abspath(path)
    wsdir = os.path.dirname(p)
    up = os.path.dirname(os.path.dirname(wsdir))
    root = os.path.dirname(os.path.dirname(up)) if (os.path.basename(up) == 'workstreams'
                                                     and os.path.basename(os.path.dirname(up)) == '.state') else None
    present = set()
    if section_bounds(lines, "Decisions"):
        present = {n for n, _ in decision_blocks(lines)[3]}
    own = workstream_id(p) if root else None
    others = [os.path.basename(os.path.dirname(a)) for a, _r in find_workstreams(root)] if root else []
    ctx = Context(present, own, others, batch_resolver(wsdir))
    ctx.root = root
    ctx.path = p
    ctx.keep = set(keep)
    ctx.held = {}
    return ctx


def condense_records(lines, mark, ctx=None):
    """Records under ## Backlog and, when the section exists, under
    ## Archive: the extract skill's Move 3 condenses a record whether
    or not its phase has moved, and four records moved before this
    script existed sat verbatim under Archive at 14,000 bytes."""
    bounds = section_bounds(lines, "Backlog")
    if bounds is None:
        raise Refusal("no ## Backlog section")
    if ctx is None:
        _s, _e, _pre, dblocks = decision_blocks(lines) if section_bounds(lines, "Decisions") else (0, 0, [], [])
        ctx = Context({n for n, _ in dblocks})
        ctx.keep, ctx.held = set(), {}
    condensed = 0
    saved = 0
    entries = []
    report = []
    skipped = 0
    kept = 0
    orphaned = 0
    archive = section_bounds(lines, "Archive")
    ranges = [("backlog", bounds)] + ([("archive", archive)] if archive else [])
    # Rebuild from the end so earlier offsets stay valid.
    for name, (start, end) in sorted(ranges, key=lambda r: -r[1][0]):
        out, c, s, ents, k, o, kp = condense_range(lines, start, end, mark, ctx)
        condensed += c
        saved += s
        skipped += k
        orphaned += o
        kept += kp
        entries = ents + entries
        report.insert(0, "%s_lines %d->%d" % (name, end - start, len(out)))
        lines = lines[:start] + out + lines[end:]
    report.insert(0, "condensed=%d bytes_saved=%d" % (condensed, saved))
    report.append("skipped=%d" % skipped)
    report.append("kept=%d" % kept)
    report.append("orphaned_note_lines=%d" % orphaned)
    return lines, " ".join(report), entries


RECORD_MIN = 400  # bytes of the whole BLOCK, never of its first line
DATE_PAT = r"20[0-9]{2}-[0-9]{2}-[0-9]{2}\b"
# Where a completion note begins: a status word or a date, after an
# opening `*(`, `**` or `*` -- `DONE 2026-01-02 at abc1234: ...`,
# `*Done 2026-08-07 (D4): ...*` -- or any upper-case word, or a status
# word in any case, written directly before a date: a note kept in
# parts (`*(STARTED 2026-01-02: ...`, `PROGRESS 2026-01-03: ...`,
# `DONE ...)*`) opened at its first DONE, so its earlier parts were read
# as description and its `*(` was left with no `)*`.
NOTE_START_RE = re.compile(
    r"^(?:\*\(|\*\*|\*)?(?:" + STATUS_RE.pattern + r"|Done\b|" + DATE_PAT
    + r"|[A-Z]{4,}:?\s+(?:on\s+)?" + DATE_PAT
    + r"|(?i:" + "|".join(STATUS_WORDS) + r"):?\s+(?:on\s+)?" + DATE_PAT + ")")


def first_sentence(body):
    """The description's first sentence, found on a copy with code spans
    blanked inside their backticks: a description quoting a sentence
    (`Done. Commit the new files ...`) was cut at the quoted full stop,
    leaving a head that ended `-- \\`Done.`. Never cut mid-sentence: a
    head cut at a byte budget with `...` lost the description it was
    meant to keep."""
    spans = re.sub(r"`[^`]*`", lambda mm: "`" + " " * (len(mm.group(0)) - 2) + "`", body)
    split = re.search(r"(?<=[.!?])\s+(?=[A-Z`(#])", spans)
    return body[:split.start()] if split else body


def condense_record(raw, mark, ctx, tail=""):
    """(new_raw, changed_line, absent_decisions) for one completed
    record's block, or (None, None, reason) when the block is left as it
    is. A record is a BLOCK -- the task line plus its continuations --
    and only its NOTE is condensed; the description is never touched.
    Three shapes:

      leading note   `- [x] #ID: *(<note>)* <description>`, the note
                     free to wrap until its `)*` and the description to
                     run on after it: the note condenses onto the task
                     line, its `)*` re-emitted, and whatever followed
                     the `)*` stays as it was.
      note below     the description (one line, as the rule keeps it,
                     or wrapped) with the completion note on the
                     indented lines beneath it, its first line opening
                     with a status word or a date (`  DONE 2026-01-02
                     at abc1234: ...`, `*Done 2026-08-07 (D4): ...*`):
                     the description lines stay byte-identical and the
                     note lines become one, keeping an enclosing `*`.
      one line       note and description on one line with no
                     delimiter between them: the description's first
                     sentence is kept whole and the rest condenses.

    A multi-line block in none of these shapes cannot be split into a
    description and a note without guessing, and is skipped with a
    reason the report prints. A one-line record carrying neither a
    status word nor a date has no note to condense and is skipped the
    same way.

    tail is the text of the record's own note paragraphs that follow it
    after a blank line; it is read as part of the note and leaves with
    it, since a run that condensed the first paragraph alone left the
    rest verbatim under the condensed line, attributed to nothing."""
    m = DONE_RE.match(raw[0])
    prefix, tid, sep, body = m.groups()
    sep_date = (DATE_RE.findall(sep) or [None])[-1]
    cont = raw[1:]
    more = (" " + tail) if tail else ""
    if body.startswith("*("):
        segs = [body[2:]] + cont
        close = next(((k, sg.find(")*")) for k, sg in enumerate(segs) if ")*" in sg), None)
        if close is None:
            return None, None, "a leading note that never closes"
        k, at = close
        note = " ".join([sg.strip() for sg in segs[:k]] + [segs[k][:at].strip()]).strip()
        rest = segs[k][at + 2:]
        if k > 0:
            rest = rest.lstrip()
            rest = (" " + rest) if rest else ""
        if not more and at_the_form(note):
            return None, None, AT_THE_FORM
        note_text, absent = condensed_note(note + more, ctx, mark, sep_date)
        first = "%s%s%s*(%s)*%s" % (prefix, tid, sep, note_text, rest)
        new = [first] + cont[k:]
        if rest.strip() not in first or cont[k:] != new[1:]:
            raise Refusal("%s: the description would not survive the condensation" % tid)
        return new, first, absent
    if cont:
        k = next((k for k, c in enumerate(cont) if c[:1].isspace() and NOTE_START_RE.match(c.strip())), None)
        if k is None:
            return None, None, "continuation lines that are neither a note nor recognisably the description"
        desc, note_lines = raw[:k + 1], cont[k:]
        if any("*(" in d for d in desc[1:]):
            return None, None, "a note that opens in what reads as the description"
        note = " ".join(c.strip() for c in note_lines)
        wrap_open, wrap_close = "", ""
        if note.startswith("*("):
            # A whole note in `*( ... )*` below the description: condensed
            # inside its delimiters, or not at all.
            close = note.rfind(")*")
            if close < 0 or note[close + 2:].strip():
                return None, None, "a note below the description whose `*(` does not close at its end"
            note = note[2:close]
            wrap_open, wrap_close = "*(", ")*"
        elif note.startswith("*") and not note.startswith("**") and note.endswith("*"):
            note = note[1:-1]
            wrap_open, wrap_close = "*", "*"
        indent = note_lines[0][:len(note_lines[0]) - len(note_lines[0].lstrip())]
        if not more and at_the_form(note):
            return None, None, AT_THE_FORM
        note_text, absent = condensed_note(note + more, ctx, mark, sep_date)
        line = indent + wrap_open + note_text + wrap_close
        return desc + [line], line, absent
    if not (STATUS_RE.search(body) or DATE_RE.search(body)):
        # Read in the body alone: a dated record's parenthetical can be
        # its whole note (`(done <date>, site <hash>)`), and a date there
        # would license cutting a body that is all description.
        return None, None, "a one-line record with no status word or date to condense"
    head = first_sentence(body)
    note_text, absent = condensed_note(body + more, ctx, mark, sep_date)
    # The separator is carried verbatim: a dated record's `(<date>)` is
    # part of it, and a rebuilt `: ` dropped the date.
    line = "%s%s%s %s %s" % (prefix, tid, sep.rstrip(), head, note_text)
    if head not in line:
        raise Refusal("%s: the description's first sentence would not survive the condensation" % tid)
    return [line], line, absent


def condense_range(lines, start, end, mark, ctx):
    """Fold the range into blocks and condense each completed record
    whose BLOCK runs past RECORD_MIN bytes. A per-line loop once fired
    only on first lines over 400 characters: a record whose note and
    description shared that line lost its description's opening clause
    with its continuations left orphaned mid-sentence, and a long
    record with a short first line was passed over entirely.

    A record is also every INDENTED paragraph after it that only blank
    lines separate from it, up to the next checkbox, heading or
    flush-left line: `fold_blocks` ends a block at a blank line, and a
    run that condensed the first paragraph alone left 159 note lines
    verbatim under 19 condensed records with nothing in the report.
    Such paragraphs under a record an EARLIER run condensed are counted
    as orphaned_note_lines and left for the operator, since a second
    run must stay a no-op."""
    region = lines[start:end]
    out = []
    condensed = 0
    saved = 0
    skipped = 0
    kept = 0
    orphaned = 0
    entries = []
    consumed = 0
    blocks = fold_blocks(region)
    i = 0
    while i < len(blocks):
        bstart, kind, text, raw = blocks[i]
        i += 1
        idx = bstart - 1
        if idx < consumed:
            continue  # absorbed into the record before it
        out.extend(region[consumed:idx])
        consumed = idx + len(raw)
        if kind != 'item' or not DONE_RE.match(raw[0]):
            if kind == 'item' and DONE_LINE_RE.match(raw[0]):
                # Done to the record script, unreadable here: a report
                # that skipped it in silence read clean.
                m = re.match(r"^ *- \[[xX]\] (#[^\s:(]+)", raw[0])
                entries.append("SKIPPED %s: unrecognised record form" % (m.group(1) if m else raw[0].strip()[:40]))
                skipped += 1
            out.extend(raw)
            continue
        # The record's blank-separated tail.
        tail_blocks = []
        stop = consumed
        j = i
        while j < len(blocks):
            nb = blocks[j]
            gap = region[stop:nb[0] - 1]
            if (not gap or any(g.strip() for g in gap) or nb[1] == 'heading'
                    or not nb[3][0][:1].isspace() or CHECKBOX_RE.match(nb[3][0])):
                break
            tail_blocks.append(nb)
            stop = nb[0] - 1 + len(nb[3])
            j += 1
        whole = region[idx:stop]
        tid = DONE_RE.match(raw[0]).group(2)
        if GUARD_RE.search(text):
            orphaned += sum(1 for l in region[consumed:stop] if l.strip())
            out.extend(whole)
            consumed = stop
            i = j
            continue
        size = len('\n'.join(whole))
        if size <= RECORD_MIN:
            out.extend(whole)
            consumed = stop
            i = j
            continue
        nxt = region[consumed] if consumed < len(region) else ''
        if tid in ctx.keep:
            entries.append("KEPT %s: --keep" % tid)
            kept += 1
            out.extend(whole)
            consumed = stop
            i = j
            continue
        if tid in ctx.held:
            where, sentence, how = ctx.held[tid]
            new, changed, why = None, None, ("%s %s: %s -- re-point that citation, or condense by hand keeping "
                                             "what it cites" % ("cited by live content at" if how == 'live'
                                                                else "cited as its note by", where, sentence))
        elif len(raw) == 1 and nxt[:1].isspace() and LIST_ITEM_RE.match(nxt) and not CHECKBOX_RE.match(nxt):
            # A note written as an indented bullet folds as its own item,
            # which would leave the task line looking like a one-line
            # record and condense its description.
            new, changed, why = None, None, "a completion note written as an indented list item"
        elif any(b[1] == 'item' for b in tail_blocks):
            new, changed, why = None, None, "a note with indented list items after a blank line"
        else:
            try:
                new, changed, why = condense_record(raw, mark, ctx, " ".join(b[2] for b in tail_blocks))
            except SplitList as e:
                new, changed, why = None, None, str(e)
        consumed = stop
        i = j
        if new is None:
            entries.append("SKIPPED %s: %s" % (tid, why))
            skipped += 1
            out.extend(whole)
            continue
        after = len('\n'.join(new))
        if after >= size:
            out.extend(whole)  # already at or under the condensed form
            continue
        out.extend(new)
        condensed += 1
        saved += size - after
        entry = entry_line(tid, size, after, changed)
        if tail_blocks:
            entry += " [with %d note line(s) after a blank line]" % sum(len(b[3]) for b in tail_blocks)
        for w in why or ():
            entry += " [%s]" % w
        entries.append(entry)
    out.extend(region[consumed:])
    return out, condensed, saved, entries, skipped, orphaned, kept


def parse_decisions(spec):
    wanted = set()
    for part in spec.split(","):
        part = part.strip()
        m = re.fullmatch(r"D?([0-9]+)(?:-D?([0-9]+))?", part)
        if not m:
            usage("--decisions entry %r is not D<n> or D<n>-D<m>" % part)
        lo = int(m.group(1))
        hi = int(m.group(2)) if m.group(2) else lo
        wanted.update(range(lo, hi + 1))
    return wanted


def decision_blocks(lines):
    """(start, end, preamble, [(number, block_lines)]) for ## Decisions."""
    bounds = section_bounds(lines, "Decisions")
    if bounds is None:
        raise Refusal("no ## Decisions section")
    start, end = bounds
    body = lines[start + 1:end]
    preamble = []
    blocks = []
    current = None
    for ln in body:
        m = DECISION_HEADING_RE.match(ln)
        if m:
            current = (int(m.group(1)), [ln])
            blocks.append(current)
        elif current is None:
            preamble.append(ln)
        else:
            current[1].append(ln)
    return start, end, preamble, blocks


def strip_blank(ls):
    while ls and ls[-1].strip() == "":
        ls = ls[:-1]
    return ls


def resolve_release(path, value):
    """('tag' | 'commit', value) for a --release the repository holding
    path resolves; a Refusal otherwise. A tag that did not exist once
    passed unchecked into a line reading `Shipped in`, and a project
    workstream's Decisions land in commits rather than releases, so
    the line is worded by kind: `Shipped in <tag>`, `Landed at <sha>`."""
    cwd = os.path.dirname(os.path.abspath(path))
    rc, out = git(['tag', '-l', '--', value], cwd)
    if rc != 0:
        raise Refusal("--release %s cannot be checked: not a git repository" % value)
    if out.strip() == value:
        return 'tag', value
    rc, out = git(['rev-parse', '--verify', '--quiet', value + '^{commit}'], cwd)
    if rc == 0 and out.strip():
        return 'commit', value
    raise Refusal("--release %s is neither a tag nor a commit this repository resolves" % value)


def condense_decisions(lines, wanted, release, mark, kind='tag', held=None, keep=()):
    """Condense each wanted Decision. One that LIVE content cites -- an
    open task, gate line, the critical path, an open criterion or an
    unresolved Open Question in this file, or another workstream file's
    live content homed here -- is left whole and reported, as `records`
    leaves a record: a drain named 31 Decisions shipped by its build
    tag, and 12 of them were still cited by open work, some by open
    gates, whose reader would have had to fetch the tag for the detail.
    `--keep D<n>` leaves any Decision whole."""
    start, end, preamble, blocks = decision_blocks(lines)
    held = held or {}
    present = {n for n, _ in blocks}
    missing = sorted(wanted - present)
    if missing:
        raise Refusal("no Decision heading for %s" % ", ".join("D%d" % n for n in missing))
    condensed = 0
    saved = 0
    skipped = 0
    kept = 0
    entries = []
    new_blocks = []
    for n, bl in blocks:
        bl = strip_blank(bl)
        did = "D%d" % n
        if n in wanted and did in keep:
            entries.append("KEPT %s: --keep" % did)
            kept += 1
        elif n in wanted and did in held and not any(GUARD_RE.search(l) for l in bl):
            where, sentence, _how = held[did]
            entries.append("SKIPPED %s: cited by live content at %s: %s -- re-point that citation, or "
                           "--keep it" % (did, where, sentence))
            skipped += 1
        elif n in wanted and not any(GUARD_RE.search(l) for l in bl):
            head = bl[0]
            rest = bl[1:]
            while rest and rest[0].strip() == "":
                rest = rest[1:]
            para = []
            for l in rest:
                if l.strip() == "":
                    break
                para.append(l)
            if not any(l.strip() for l in rest[len(para):]):
                # One paragraph only: already at or under the condensed
                # form. Adding the release line would GROW it (four
                # such Decisions gained 114 bytes each on a dry run).
                new_blocks.append((n, bl))
                continue
            verb = "Shipped in" if kind == 'tag' else "Landed at"
            tail = "%s %s. %s; full text in git before that commit." % (verb, release, mark)
            cond = [head] + para + [tail]
            before_b = sum(len(l) + 1 for l in bl)
            after_b = sum(len(l) + 1 for l in cond)
            saved += before_b - after_b
            condensed += 1
            entries.append(entry_line("D%d" % n, before_b, after_b, head))
            bl = cond
        new_blocks.append((n, bl))
    order_before = [n for n, _ in new_blocks]
    new_blocks.sort(key=lambda t: t[0])
    reordered = order_before != [n for n, _ in new_blocks]
    rebuilt = strip_blank(preamble)
    for _n, bl in new_blocks:
        if rebuilt:
            rebuilt.append("")
        rebuilt.extend(bl)
    rebuilt.append("")
    report = "decisions_condensed=%d bytes_saved=%d reordered=%s skipped=%d kept=%d" % (
        condensed, saved, "yes" if reordered else "no", skipped, kept)
    return lines[:start + 1] + rebuilt + lines[end:], report, entries


def run_condense(path, do_tasks, decisions, release, date, dry, keep=()):
    """The shipped script's whole run, kept for the forwarding shim:
    records unless --no-tasks, then the named Decisions, one report."""
    text = load(path)
    lines = text.split("\n")
    mark = "Condensed %s at extract" % date
    report = []
    entries = []
    try:
        if do_tasks:
            ctx = condense_context(path, lines, keep)
            done = {m.group(2) for m in (DONE_RE.match(l) for l in lines) if m}
            ctx.held = note_citations(ctx.root, ctx.path, lines, done - ctx.keep, live=True)
            for k in sorted(ctx.keep - done):
                entries.append("KEPT %s: no completed record with this ID, nothing to keep" % k)
            # A record held only by another record's note loses its hold
            # when this run condenses that note, so a second run used to
            # condense what the first held, and a reviewer of the first
            # dry run approved less than the drain wrote. Narrow the held
            # set to what the condensed output still cites, and condense
            # the input again, until it stops changing: the first run
            # writes what a second would.
            first = dict(ctx.held)
            for _round in range(10):
                out, r, ents = condense_records(lines, mark, ctx)
                still = note_citations(ctx.root, ctx.path, out, set(ctx.held), live=True)
                narrowed = {k: v for k, v in ctx.held.items() if k in still}
                if len(narrowed) == len(ctx.held):
                    break
                ctx.held = narrowed
            for k in sorted(set(first) - set(ctx.held)):
                where, sentence, _how = first[k]
                entries.append("RELEASED %s: held only by %s, a note this run condenses: %s" % (k, where, sentence[:120]))
            lines = out
            report.append(r)
            entries.extend(ents)
        if decisions is not None:
            kind, release = resolve_release(path, release)
            wanted = parse_decisions(decisions)
            dkeep = {k for k in keep if re.fullmatch(r"D[0-9]+", k)}
            dctx = condense_context(path, lines)
            cited = note_citations(dctx.root, dctx.path, lines, {"D%d" % n for n in wanted} - dkeep, live=True)
            held = {k: v for k, v in cited.items() if v[2] == 'live'}
            for k in sorted(dkeep - {"D%d" % n for n in wanted}):
                entries.append("KEPT %s: not among --decisions, nothing to keep" % k)
            lines, r, ents = condense_decisions(lines, wanted, release, mark, kind, held, dkeep)
            report.append(r)
            entries.extend(ents)
    except Refusal as e:
        sys.stderr.write("%s: %s in %s\n" % (PROG, e, path))
        return 1
    return finish(path, text, "\n".join(lines), dry, report, entries)


def cmd_records(args):
    rest, o = parse_options(args, flags=('--write',), values=('--date',), multi=('--keep',))
    if len(rest) != 1:
        usage("records takes exactly one workstream.md")
    for k in o['--keep']:
        if not re.fullmatch(r"#(?:" + TASK_ID_FORM + "|" + GATE_ID_FORM + ")", k):
            usage("--keep %r is not a task ID (#XX-N)" % k)
    return run_condense(rest[0], True, None, None, o['--date'] or datetime.date.today().isoformat(),
                        not o['--write'], o['--keep'])


def cmd_decisions(args):
    rest, o = parse_options(args, flags=('--write',), values=('--date', '--decisions', '--release'),
                            multi=('--keep',))
    if len(rest) != 1:
        usage("decisions takes exactly one workstream.md")
    if o['--decisions'] is None or o['--release'] is None:
        usage("decisions needs --decisions and --release")
    for k in o['--keep']:
        if not re.fullmatch(r"D[0-9]+", k):
            usage("--keep %r is not a Decision ID (D<n>)" % k)
    return run_condense(rest[0], False, o['--decisions'], o['--release'],
                        o['--date'] or datetime.date.today().isoformat(), not o['--write'], o['--keep'])


# --- learnings: terminal entries condense to statement plus disposition -----

LEARNING_PREFIX_RE = re.compile(r'^- (L[0-9]+ \([^)]*\):)\s*(.*)$', re.S)


# A leading sentence that says where the entry came from rather than
# what it found: `Carried from tag ws/<name>.` Taken as the statement,
# it condensed an entry to its provenance and dropped the insight.
TARGET_RE = re.compile(r'integration target', re.I)
PROVENANCE_RE = re.compile(
    r'^(?:Carried|Moved|Lifted|Copied|Received|Imported|Ported|Brought)\b.*\b(?:from|at|in)\b', re.I)


def prose_spans(text):
    """[(start, end)] of text's sentences. A sentence ends at `.`, `!`
    or `?` before whitespace -- never inside a code span, and never when
    the next word starts lower case: the shared splitter cut a kept
    sentence at an unquoted `%G? ` and at `e.g. `, and a condensed
    Learning ended mid-sentence."""
    spans = []
    code = False
    start = 0
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '`':
            code = not code
        elif not code and c in '.!?' and i + 1 < n and text[i + 1].isspace():
            j = i + 1
            while j < n and text[j].isspace():
                j += 1
            if j < n and not text[j].islower():
                spans.append((start, i + 1))
                start = j
                i = j
                continue
        i += 1
    if start < n:
        spans.append((start, n))
    return [(s, e) for s, e in spans if text[s:e].strip()]


def prose_sentences(text):
    text = text.strip()
    return [text[s:e].strip() for s, e in prose_spans(text)]


def prose_span(text, offset):
    for s, e in prose_spans(text):
        if s <= offset < e:
            return s, e
    return 0, len(text)


# A kept sentence that points BACK -- `Integration target: that task.`,
# `received there` -- names nothing once the sentence before it is
# dropped, and still reads as a routing.
BACKREF_RE = re.compile(
    r"\b(?:that|this|the same|the above)\s+(?:task|item|file|commit|workstream|project|handoff|entry|"
    r"decision|gate|issue|rule|skill|one|place|destination|target|repository|repo)\b"
    r"|\bthere\b(?!\s+(?:is|are|was|were|will|would|has|have|had|being|be)\b)|\babove\b", re.I)
# `it` points back only as a kept sentence's SUBJECT -- opening it, or
# right after its marker and date (`VERIFIED 2026-01-04: it does;`) --
# whose antecedent sat in the sentence before; `it` as an object (`the
# task line now names it`) refers inside its own sentence.
IT_SUBJECT_RE = re.compile(
    r"^[*_]*(?:(?:" + "|".join(re.escape(m) for m in TERMINAL_MARKERS + DEFERRED_MARKERS + ADDENDUM_MARKERS)
    + r")[*_]*(?:\s+(?:on\s+)?20[0-9]{2}-[0-9]{2}-[0-9]{2}\b)?[*_]*[:,]?\s+)?(it(?:'s)?)\b", re.I)
# A kept sentence whose predecessor is dropped stands alone only when it
# opens on what it is kept FOR -- a disposition marker or an integration
# target. A word list of anaphors kept missing the next one: a count
# (`all three`), a connective (`And`), a distributive subject (`Each
# was caught`) each condensed with `skipped=0`, so the test is inverted.
KEPT_OPENER_RE = re.compile(
    r"^[-*_ (]*(?:(?:" + "|".join(re.escape(m) for m in TERMINAL_MARKERS + DEFERRED_MARKERS + ADDENDUM_MARKERS)
    + r")\b|(?:integration\s+)?targets?\b)", re.I)
# A count that refers back names its members only in the dropped text,
# even inside a sentence the opener test lets stand.
COUNT_BACKREF_RE = re.compile(
    r"\b(?:all (?:two|three|four|five|six|seven|eight|nine|ten)|both|the (?:two|three|four|five)"
    r"|each of (?:them|these|those)|either|neither|the former|the latter|the rest|the others?)\b", re.I)
# Where a finding lives: a file -- a name with an extension, or a
# backticked directory ending in `/` -- a commit-shaped hash (a digit
# and a letter), a URL. When the kept sentences name none and a dropped
# one does, that sentence was the only record of where the insight
# went: `... recorded as V8 in `reference/x.md`.` condensed away with
# skipped=0. A branch, a workstream name or a slash command is not one.
LOCATION_RE = re.compile(
    r"`[^`\s]+/`"
    r"|(?<![\w/.-])[\w./~-]*[\w-]\.(?:md|py|sh|json|txt|ya?ml|toml|html|js|ts|css|csv)\b"
    r"|\b(?=[0-9a-f]*[0-9])(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b|https?://\S+")
# `this workstream` and `this project` name the file's own home, not a
# sentence before: an integration target reading `this workstream, at
# #G-XX` routes somewhere real.
SELF_REF_RE = re.compile(r"\bthis\s+(?:workstream|project|repository|repo)\b", re.I)


def condense_learning(text):
    """The condensed joined text of one Learning block, or None; the
    reading is condense_learning_why's."""
    return condense_learning_why(text)[0]


def sentence_index(spans, offset):
    """The index of the span holding offset, or None."""
    for i, (s, e) in enumerate(spans):
        if s <= offset < e:
            return i
    return None


def marker_sentences(body, spans):
    """The indices of the sentences carrying a disposition marker,
    terminal or deferred, in order."""
    blanked = blank_strikes(body)
    found = {sentence_index(spans, m.start())
             for m in marker_counts(blanked, TERMINAL_RE) + marker_counts(blanked, DEFERRED_RE)}
    return sorted(i for i in found if i is not None)


def condense_learning_why(text):
    """(condensed, None) for one Learning block; (None, reason) when it
    must stay whole and the report says why; (None, None) when the
    entry is not terminal, is struck, or is already that short. The
    statement is the first sentence, or the first two when the first is
    provenance; the disposition is the sentence of EVERY disposition
    marker the entry carries, terminal or deferred, in its place -- an
    entry that ran QUEUED, APPLIED, VERIFIED once condensed to its
    VERIFIED sentence alone, and kept a target sentence the dropped
    APPLIED sentence had corrected. An EXTENDED written after the last
    terminal marker is new matter the disposition does not carry, and
    the entry is left whole. Every sentence naming an integration
    target is kept too, in its place: a real entry's disposition read
    `APPLIED 2026-09-22.` alone, and the target sentence -- which in
    another entry was also the insight itself -- was the only record of
    where it went. A kept sentence after a dropped one must open on a
    disposition marker or an integration target, and one that points
    back (`that task`, `there`, `all three`) at a sentence the condensation would drop
    leaves the entry whole: a target reading `Integration target: that
    task.` routed to nothing."""
    if disposition(text) != 'terminal':
        return None, None
    m = LEARNING_PREFIX_RE.match(text)
    if not m:
        return None, None
    prefix, body = m.group(1), m.group(2).strip()
    spans = prose_spans(body)
    sentences = [body[s:e].strip() for s, e in spans]
    if len(sentences) <= 1:
        return None, None
    blanked = blank_strikes(body)
    marks = marker_counts(blanked, TERMINAL_RE)
    if not marks:
        return None, None
    last = marks[-1]
    if any(a.start() > last.start() for a in marker_counts(blanked, ADDENDUM_RE)):
        return None, None
    markers = set(marker_sentences(body, spans))
    lead = set(range(2 if PROVENANCE_RE.match(sentences[0]) else 1))
    keep = set(lead)
    keep.update(i for i, x in enumerate(sentences) if TARGET_RE.search(x) and not ADDENDUM_RE.match(x))
    keep |= markers
    for i in sorted(keep):
        if i in lead or i == 0 or (i - 1) in keep:
            continue
        x = sentences[i]
        ref = (BACKREF_RE.search(SELF_REF_RE.sub('', x)) or IT_SUBJECT_RE.match(x)
               or COUNT_BACKREF_RE.search(x))
        if ref:
            word = ref.group(ref.lastindex or 0)
            return None, ("a kept sentence points back (%r) at one the condensation drops: %s"
                          % (word, x[:80]))
        if not KEPT_OPENER_RE.match(x):
            return None, ("a kept sentence after a dropped one opens on neither a disposition marker"
                          " nor an integration target: %s" % x[:80])
    condensed = ' '.join(sentences[i] for i in sorted(keep))
    if condensed == body or len(condensed) >= len(body):
        return None, None
    if not LOCATION_RE.search(condensed):
        for i, x in enumerate(sentences):
            loc = None if i in keep else LOCATION_RE.search(x)
            if loc:
                return None, ("a dropped sentence names where the finding lives (%s) and no kept one"
                              " names a file or commit: %s" % (loc.group(0)[:60], x[:80]))
    return '- ' + prefix + ' ' + condensed, None


def learning_loss(before, after):
    """What a condensed Learning lost that it must keep, or None: its
    statement (the first sentence that is not provenance, whole), every
    sentence naming its integration target, and the whole sentence of
    every disposition marker it carries. The structure fingerprint sees
    headings and checkboxes only, so a condensation that kept the wrong
    sentences passed it."""
    m = LEARNING_PREFIX_RE.match(before)
    body = m.group(2).strip() if m else before
    spans = prose_spans(body)
    sentences = [body[s:e].strip() for s, e in spans]
    stmt = next((x for x in sentences if not PROVENANCE_RE.match(x)), None)
    if stmt and not ADDENDUM_RE.match(stmt):
        if stmt not in after:
            return "its statement (%s ...)" % ' '.join(stmt.split()[:6])
    for x in sentences:
        if TARGET_RE.search(x) and not ADDENDUM_RE.match(x) and x not in after:
            return "its integration target (%s ...)" % ' '.join(x.split()[:6])
    for i in marker_sentences(body, spans):
        if sentences[i] not in after:
            return "its disposition (%s)" % sentences[i][:60]
    return None


FENCE_RE = re.compile(r'^\s*(?:```|~~~|\|)')


def condense_learnings(lines, keep=(), held=None):
    bounds = section_bounds(lines, "Learnings")
    if bounds is None:
        raise Refusal("no ## Learnings section")
    held = held or {}
    start, end = bounds
    section = lines[start + 1:end]
    out = []
    condensed = 0
    saved = 0
    skipped = 0
    kept = 0
    follow_on = 0
    entries = []
    blocks = fold_blocks(section)
    consumed = 0
    i = 0
    while i < len(blocks):
        bstart, kind, text, raw = blocks[i]
        i += 1
        idx = bstart - 1
        out.extend(section[consumed:idx])
        consumed = idx + len(raw)
        if kind == 'item' and LEARNING_RE.match(raw[0]):
            lid = "L" + LEARNING_RE.match(raw[0]).group(1)
            tail, stop, i = learning_tail(section, blocks, i, consumed)
            if tail:
                raw = section[idx:stop]
                consumed = stop
                text = ' '.join([text] + [t[2] for t in tail])
            if tail and any(FENCE_RE.match(l) for t in tail for l in t[3]):
                new, why = None, None
                if disposition(text) == 'terminal':
                    why = "a follow-on paragraph holds a code block or table, which a re-wrap would break"
            else:
                new, why = condense_learning_why(text)
            if new is not None and lid in keep:
                entries.append("KEPT %s: --keep" % lid)
                kept += 1
                new = None
            elif new is not None and lid in held:
                why = "cited as its note by %s: %s" % held[lid][:2]
                new = None
            if why:
                entries.append("SKIPPED %s: %s" % (lid, why))
                skipped += 1
            if new is not None:
                lost = learning_loss(text, new)
                if lost:
                    raise Refusal("L%s: the condensation would lose %s" % (LEARNING_RE.match(raw[0]).group(1), lost))
                wrapped = wrap(new, 70, indent='  ')
                before_b = sum(len(l) + 1 for l in raw)
                after_b = sum(len(l) + 1 for l in wrapped)
                saved += before_b - after_b
                condensed += 1
                follow_on += len(tail)
                lm = LEARNING_RE.match(raw[0])
                entries.append(entry_line("L" + lm.group(1), before_b, after_b, wrapped[0]))
                out.extend(wrapped)
                continue
        out.extend(raw)
    out.extend(section[consumed:])
    before = sum(1 for l in section if LEARNING_RE.match(l))
    after = sum(1 for l in out if LEARNING_RE.match(l))
    if before != after:
        raise Refusal("Learnings count changed %d->%d" % (before, after))
    report = "learnings_condensed=%d bytes_saved=%d learnings=%d skipped=%d kept=%d follow_on_paragraphs=%d" % (
        condensed, saved, after, skipped, kept, follow_on)
    return lines[:start + 1] + out + lines[end:], report, entries


def cmd_learnings(args):
    rest, o = parse_options(args, flags=('--write',), values=('--date',), multi=('--keep',))
    if len(rest) != 1:
        usage("learnings takes exactly one workstream.md")
    for k in o['--keep']:
        if not re.fullmatch(r"L[0-9]+", k):
            usage("--keep %r is not a Learning ID (L<n>)" % k)
    path = rest[0]
    text = load(path)
    try:
        lines = text.split("\n")
        ctx = condense_context(path, lines, o['--keep'])
        lids = {"L" + m.group(1) for m in (LEARNING_RE.match(l) for l in lines) if m}
        held = note_citations(ctx.root, ctx.path, lines, lids - ctx.keep)
        lines, report, entries = condense_learnings(lines, ctx.keep, held)
    except Refusal as e:
        sys.stderr.write("%s: %s in %s\n" % (PROG, e, path))
        return 1
    return finish(path, text, "\n".join(lines), not o['--write'], [report], entries)


# --- rotate: Move 3b with the removed-side checks -----------------------------

# A tag name may carry dots (ws/omlx-0.4.x) but never ends in one: a
# pattern admitting a trailing dot read the sentence's full stop as part
# of the tag and saw every rotation as a new one.
TAG = r'ws/[\w-]+(?:\.[\w-]+)*'
ROTATED_RE = re.compile(r'^Rotated [0-9]{4}-[0-9]{2}-[0-9]{2}; the record before it is at (' + TAG + ')')
TAG_RE = re.compile(TAG)
NUMBERING_RE = re.compile(r'^Numbering continues from the rotation tag')
RANGE_RE = re.compile(r'\bL([0-9]+)(?: to L([0-9]+))?\b(?: are| is)? at (' + TAG + ')')


def rotation_paragraph(date, tags):
    """ONE paragraph naming every rotation tag newest first, rewritten
    in place at each rotation: a second rotation once prepended its own
    line above the first, and the reader merged the two by hand."""
    text = 'Rotated %s; the record before it is at %s' % (date, tags[0])
    if len(tags) > 1:
        earlier = tags[1:]
        listed = earlier[0] if len(earlier) == 1 else ', '.join(earlier[:-1]) + ' and ' + earlier[-1]
        text += ', and the records before that at %s, newest first' % listed
    return wrap(text + '.', 70, indent='')


def numbering_note(ranges, next_no):
    """The Learnings numbering note: which L range sits at which tag,
    and the next number to mint, one sentence so that the citation
    sweep sees the current tag beside every leaving ID it names."""
    parts = []
    for lo, hi, tag in sorted(ranges):
        parts.append(('L%d at %s' % (lo, tag)) if lo == hi else ('L%d to L%d at %s' % (lo, hi, tag)))
    listed = parts[0] if len(parts) == 1 else ', '.join(parts[:-1]) + ' and ' + parts[-1]
    text = ('Numbering continues from the rotation tags: %s; the next Learning is L%d, '
            'and a citation to any L resolves to exactly one entry across the tags.' % (listed, next_no))
    return wrap(text, 70, indent='')
KNOWN_SECTIONS = ('## Purpose', '## Backlog', '## Decisions', '## Learnings',
                  '## Open Questions', '## Deletion Criteria', '## Archive')
COUNT_NOUNS = {
    'learnings': re.compile(r'\bLearnings?\b'),
    'learnings_terminal': re.compile(r'\bLearnings?\b'),
    'decisions': re.compile(r'\bDecisions?\b'),
    'open_questions': re.compile(r'\bOpen Questions?\b'),
    'open_tasks': re.compile(r'\bopen (?:tasks?|items?)\b', re.I),
    'open_gates': re.compile(r'\bopen gates?\b|\bgates?\b', re.I),
}


def lead_phrase(text):
    """A distinctive phrase of a block's first sentence: its bold lead
    when it has one, else its first five words after any ID prefix."""
    m = re.match(r'^\*\*(.+?)\.?\*\*', text.strip())
    if m:
        return m.group(1).strip()
    body = re.sub(r'^(?:- )?(?:\[[ xX]\] )?#?[A-Z][A-Z0-9]*-?[0-9]*[a-z]?\s*(?:\([^)]*\))?:?\s*', '', text.strip())
    body = re.sub(r'^\*\*|^~~', '', body)
    words = body.split()
    return ' '.join(words[:5])


def section_counts(lines):
    """The counts a claim can be about, derived from lines."""
    learn_lines = {no for no, _t in extract_section(lines, r'^##\s+Learnings\s*$')}
    learn = 0
    terminal = 0
    for s, k, t, r in with_learning_tails(lines, fold_blocks(lines)):
        if k == 'item' and LEARNING_RE.match(r[0]) and s in learn_lines:
            learn += 1
            if disposition(t) == 'terminal':
                terminal += 1
    decs = sum(1 for _n, t in extract_section(lines, r'^##\s+Decisions\s*$') if DECISION_HEADING_RE.match(t))
    oqs = sum(1 for _n, t in extract_section(lines, r'^##\s+Open Questions\s*$') if re.match(r'^- (?:~~)?OQ-', t))
    open_tasks = sum(1 for t in lines if TOTAL_OPEN_RE.match(t) and not GATE_LINE_RE.match(t))
    gates = sum(1 for t in lines if GATE_LINE_RE.match(t))
    return {'learnings': learn, 'learnings_terminal': terminal, 'decisions': decs,
            'open_questions': oqs, 'open_tasks': open_tasks, 'open_gates': gates}


def structure(lines):
    crit = extract_section(lines, r'^##\s+Deletion Criteria\s*$')
    standing = sum(1 for _n, t in crit if DELETION_OPEN_RE.match(t) and 'STANDING' in t)
    ids = sorted(m.group(2) for t in lines for m in [CHECKBOX_ID_RE.match(t)] if m and m.group(1) == ' ')
    return {'open': sum(1 for t in lines if TOTAL_OPEN_RE.match(t)),
            'gates': sum(1 for t in lines if GATE_LINE_RE.match(t)),
            'standing': standing, 'open_ids': ids}


def rotate(path, lines, tag, date, keeps):
    """(new_lines, leaving, report) -- leaving is [(kind, id_or_None,
    phrase, first_line)] for every block that does not survive."""
    leaving = []
    kept_counts = {}
    out = []
    i = 0
    n = len(lines)

    def keep_by_phrase(text):
        return any(k in text for k in keeps)

    # Frontmatter and anything before the first ## heading.
    while i < n and not lines[i].startswith('## '):
        out.append(lines[i])
        i += 1
    # Sections.
    sections = []
    while i < n:
        start = i
        i += 1
        while i < n and not lines[i].startswith('## '):
            i += 1
        sections.append((lines[start], lines[start + 1:i]))

    # First pass: what survives in the Backlog, to know which Decisions
    # are cited by live text.
    live_text = []
    rebuilt = {}
    for heading, body in sections:
        if heading == '## Purpose':
            # Every rotation paragraph already there (one per earlier
            # rotation when they were stacked) is folded into one.
            tags = []
            drop = set()
            for bstart, kind, text, raw in fold_blocks(body):
                if kind == 'para' and ROTATED_RE.match(text):
                    for t in TAG_RE.findall(text):
                        if t not in tags:
                            tags.append(t)
                    drop.update(range(bstart - 1, bstart - 1 + len(raw)))
            already = bool(tags) and tags[0] == tag
            new = list(body)
            if not already:
                j = 0
                while j < len(new) and new[j].strip() == '':
                    j += 1
                rest = [l for i, l in enumerate(new) if i >= j and i not in drop]
                while rest and rest[0].strip() == '':
                    rest.pop(0)
                new = new[:j] + rotation_paragraph(date, [tag] + tags) + [''] + rest
            rebuilt[heading] = new
            live_text.extend(new)
        elif heading == '## Backlog':
            new = []
            blocks = fold_blocks(body)
            consumed = 0
            pending_heading = None
            for bstart, kind, text, raw in blocks:
                idx = bstart - 1
                gap = body[consumed:idx]
                consumed = idx + len(raw)
                if kind == 'heading':
                    pending_heading = (raw, gap)
                    continue
                keep = False
                if kind == 'item' and TOTAL_OPEN_RE.match(raw[0]):
                    keep = True
                elif kind == 'item' and DONE_LINE_RE.match(raw[0]):
                    keep = keep_by_phrase(text)
                    if not keep:
                        m = CHECKBOX_ID_RE.match(raw[0])
                        leaving.append(('task', m.group(2) if m else None, lead_phrase(text), raw[0]))
                else:
                    keep = text.startswith('**Critical path') or keep_by_phrase(text)
                    if not keep:
                        leaving.append(('paragraph', None, lead_phrase(text), raw[0]))
                if keep:
                    if pending_heading is not None:
                        new.extend(pending_heading[1])
                        new.extend(pending_heading[0])
                        pending_heading = None
                    new.extend(gap)
                    new.extend(raw)
            if pending_heading is not None and keeps and any(k in pending_heading[0][0] for k in keeps):
                new.extend(pending_heading[1])
                new.extend(pending_heading[0])
            new = strip_blank(new) + ['']
            rebuilt[heading] = new
            live_text.extend(new)
        elif heading == '## Deletion Criteria':
            rebuilt[heading] = list(body)
            live_text.extend(body)
        elif heading == '## Open Questions':
            new = []
            blocks = fold_blocks(body)
            consumed = 0
            for bstart, kind, text, raw in blocks:
                idx = bstart - 1
                gap = body[consumed:idx]
                consumed = idx + len(raw)
                if kind == 'item' and open_question(raw) or keep_by_phrase(text) or kind == 'heading':
                    new.extend(gap)
                    new.extend(raw)
                else:
                    m = re.match(r'^- (?:~~)?(OQ-[0-9]+)', raw[0])
                    leaving.append(('open question', m.group(1) if m else None, lead_phrase(text), raw[0]))
            rebuilt[heading] = strip_blank(new) + ['']
            live_text.extend(rebuilt[heading])
        elif heading == '## Learnings':
            new = []
            blocks = with_learning_tails(body, fold_blocks(body))
            consumed = 0
            leaving_nos = []
            all_nos = []
            ranges = []
            note = None
            for bstart, kind, text, raw in blocks:
                idx = bstart - 1
                gap = body[consumed:idx]
                consumed = idx + len(raw)
                if kind == 'item' and LEARNING_RE.match(raw[0]):
                    all_nos.append(int(LEARNING_RE.match(raw[0]).group(1)))
                if kind == 'para' and NUMBERING_RE.match(text):
                    note = (gap, raw)
                    for lo, hi, t in RANGE_RE.findall(text):
                        ranges.append((int(lo), int(hi or lo), t))
                    continue
                if kind == 'item' and LEARNING_RE.match(raw[0]) and disposition(text) == 'terminal' and not keep_by_phrase(text):
                    m = LEARNING_RE.match(raw[0])
                    leaving.append(('learning', 'L' + m.group(1), lead_phrase(text), raw[0]))
                    leaving_nos.append(int(m.group(1)))
                else:
                    new.extend(gap)
                    new.extend(raw)
            if leaving_nos:
                # The numbering note is carried forward with this tag's
                # range, at the head of the section; a note that was
                # there is rewritten rather than left naming one tag.
                ranges = [r for r in ranges if r[2] != tag]
                ranges.append((min(leaving_nos), max(leaving_nos), tag))
                head = numbering_note(ranges, max(all_nos) + 1)
                while new and new[0].strip() == '':
                    new.pop(0)
                new = head + [''] + new
            elif note is not None:
                new = note[0] + note[1] + new
            rebuilt[heading] = strip_blank(new) + ['']
        elif heading == '## Archive':
            for bstart, kind, text, raw in fold_blocks(body):
                if kind == 'item':
                    m = CHECKBOX_ID_RE.match(raw[0])
                    leaving.append(('archived task', m.group(2) if m else None, lead_phrase(text), raw[0]))
            rebuilt[heading] = None
        elif heading == '## Decisions':
            pass  # decided after the live text is known
        else:
            rebuilt[heading] = list(body)  # a section the kit does not know is carried verbatim
            live_text.extend(body)

    live_joined = blank_strikes('\n'.join(live_text))
    cited = set(int(x) for x in re.findall(r'(?<![\w/-])D([0-9]+)\b', live_joined))
    for heading, body in sections:
        if heading != '## Decisions':
            continue
        _s, _e, preamble, blocks = decision_blocks(['## Decisions'] + body)
        new = strip_blank(list(preamble))
        for num, bl in blocks:
            text = ' '.join(l.strip() for l in bl if l.strip())
            if num in cited or keep_by_phrase(text):
                if new:
                    new.append('')
                new.extend(strip_blank(bl))
            else:
                leaving.append(('decision', 'D%d' % num, lead_phrase(bl[0][4:]), bl[0]))
        rebuilt[heading] = new + ['']

    for heading, body in sections:
        new = rebuilt.get(heading)
        if new is None:
            continue
        out.append(heading)
        out.extend(new)
    # Normalise the tail: one trailing newline.
    out = strip_blank(out) + ['']
    kinds = {}
    for k, _i, _p, _l in leaving:
        kinds[k] = kinds.get(k, 0) + 1
    report = "rotate: dropped " + (", ".join("%s=%d" % (k, v) for k, v in sorted(kinds.items())) or "nothing")
    return out, leaving, report


# The home written directly after an ID: `D2 in maintain/kit`,
# `#MG-2 at ws/kit-2026-01-01`, a closing code span allowed between.
ID_HOME_RE = re.compile(
    r"`?(?:'s)?\s+(?:in|at|of)\s+`?((?:explore|feature|fix|project|maintain|docs)/[a-z0-9.-]*[a-z0-9]|ws/[\w.-]*\w)")


# A task line up to its description: `- [ ] #XX-1: ` (a gate's ID too).
OWN_DESCRIPTION_RE = re.compile(r'^ *- \[[ xX]\] #[A-Za-z][A-Za-z0-9]*-[A-Za-z0-9]+:\s*')


def sweep_removed(root, path, new_lines, leaving, tag, old_lines=None):
    """Hits in the surviving text and in the live content of every other
    state file for each leaving block's ID and lead phrase. A hit whose
    sentence names the tag is a re-pointed reference and is not a hit.
    Line numbers index the file ON DISK: a surviving block is looked up
    in old_lines, since the rotated output's numbering (the Rotated
    paragraph alone shifts everything after it) sent an operator's
    `sed -n` to the wrong line for every hit of the first rotation.
    A block the rotation wrote has no source line and is cited as
    written.

    IDs are per-workstream, so in ANOTHER file a bare-ID match is a
    reference to this workstream only when its home says so: the home
    written right after the ID (`D2 in maintain/kit`), else the one home
    its sentence names. ACTIVE.md's home-less mentions belong to the
    workstream it points at. Every other home-less match is returned in
    `bare`, reported and never refusing: the first rotation of a
    workstream with low-numbered IDs was refused on some forty of other
    workstreams' own D1s and L2s, four of them real. A lead-phrase match
    that is exactly where a task line's own description begins is a
    sibling task opening with the same words, and is not a hit."""
    hits = []
    bare = []
    wid = workstream_id(path)
    active_ws = None
    targets = [(os.path.relpath(path, root), new_lines, 'surviving text')]
    source_start = {}
    if old_lines is not None:
        for s, _k, _t, r in fold_blocks(old_lines):
            source_start.setdefault(tuple(r), s)
    for p, rel in find_workstreams(root):
        if os.path.abspath(p) == os.path.abspath(path):
            continue
        targets.append((rel, read_lines(p), 'live content'))
    active = os.path.join(root, '.state', 'ACTIVE.md')
    if os.path.isfile(active):
        alines = read_lines(active)
        for l in alines[:10]:
            if l.startswith('workstream:'):
                active_ws = l.split(':', 1)[1].strip().strip('"')
                break
        # The frontmatter is blanked, not dropped, so a hit's line number
        # is ACTIVE.md's own on disk.
        kept = {n for n, _t in strip_frontmatter(alines)}
        targets.append((os.path.relpath(active, root),
                        [t if n in kept else '' for n, t in enumerate(alines, start=1)], 'live content'))

    # The record's live blocks for the other files; the whole text for
    # the surviving file, which is live by construction.
    live_blocks_of = live_blocks

    needles = []
    for kind, ident, phrase, first in leaving:
        if ident:
            needles.append((kind, ident, re.compile(r'(?<![\w/-])' + re.escape(ident) + r'(?![\w-])'), first, True))
        if phrase and len(phrase.split()) >= 2:
            needles.append((kind, phrase, re.compile(re.escape(phrase).replace(r'\ ', r'\s+'), re.I), first, False))
    for rel, lines, scope in targets:
        whole = scope == 'surviving text'
        is_active = rel == os.path.relpath(active, root)
        # ACTIVE.md is live as a whole: its body opens with `## Now`, so
        # the per-section filter kept none of it and it was never read.
        for start, raw in live_blocks_of(lines, whole or is_active):
            if whole and source_start:
                start = source_start.get(tuple(raw), start)
            text, starts = join_block(raw, start)
            blanked = blank_strikes(text)
            # Where a task line's own description begins: a lead phrase
            # matched exactly there is a sibling task opening with the same
            # words, not a citation of the leaving block.
            own = OWN_DESCRIPTION_RE.match(blanked)
            for kind, needle, rx, first, is_id in needles:
                for m in rx.finditer(blanked):
                    if whole and raw[0] == first:
                        continue  # the block's own definition is not a reference
                    if not is_id and own and m.start() == own.end():
                        continue  # another task whose description opens the same way
                    s, e = sentence_span(blanked, m.start())
                    sentence = blanked[s:e]
                    if tag in sentence or re.search(r'\b(?:rotation|archive) tag\b|\bat (?:its|the) tag\b', sentence):
                        continue
                    if is_id and not whole:
                        home = ID_HOME_RE.match(blanked, m.end())
                        if home:
                            homes = [home.group(1)]
                        else:
                            homes = sorted(set(CROSS_REF_WS_RE.findall(sentence)))
                        if homes:
                            if homes != [wid]:
                                continue  # another workstream's own ID, or a tag
                        elif not (is_active and active_ws == wid):
                            bare.append({"file": rel, "line": line_at(starts, m.start()),
                                         "needle": needle, "sentence": sentence[:160]})
                            continue
                    hits.append({"file": rel, "line": line_at(starts, m.start()), "block": start,
                                 "scope": scope, "leaving": kind, "needle": needle,
                                 "sentence": sentence[:160]})
    return hits, bare


NOT_A_COUNT_RE = re.compile(
    r'\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b'          # a date: 2026-09-04 read as a claim of 4
    r'|ws/[\w.-]+'                             # a rotation or archive tag, dated
    r'|\b(?:L|D|OQ-)[0-9]+\b'                  # an ID: (L67 to L70) is a span, not a count
    r'|#' + TASK_ID_FORM +                     # a task ID, `#W3-1` included
    r'|#' + GATE_ID_FORM                       # a gate, `#G-W3a` included
)
NOUN_WINDOW = 45  # characters either side of the number, a few words
# What may be READ as a count is a bare integer in the same CLAUSE as the
# counted noun, not merely near it: `Criterion 2 HOLDS: no Learning is
# orphaned.` was read as a Learnings count of 2 and refused the rotation,
# with nothing to amend. A number that LABELS something (`Criterion 2`,
# `Phase 3`) is an ordinal and is blanked before any count is read, and a
# clause ends at a semicolon, an em dash or ` -- `. A colon is not a
# break: `Learnings: 2 remain` is a count in the house style.
CLAUSE_BREAK_RE = re.compile(r'[;\u2014]| -- ')
ORDINAL_LABEL_RE = re.compile(
    r'\b(?:criteri(?:on|a)|item|step|phase|section|move|class|part|round|pass|'
    r'line|field|question|option|stage|tier|level|version|rule|case|gate|note|point)'
    r'\s+[0-9]+\b', re.I)


def stale_claims(old_lines, new_lines):
    """Numbers in surviving criteria, gate lines and critical-path
    sentences that equal a section's OLD count and not its NEW one, in a
    sentence naming that section WITHIN A FEW WORDS of the number.
    Dates, tags and IDs are blanked first: the first live rotation read
    `learnings 4 claimed, now 0` twice, once from the `-04` of a tag's
    date in a sentence counting criteria and once from the span `(L67
    to L70)`, and refused until --allow-stale-claims after both had
    been checked by hand. The noun must share the number's CLAUSE, and
    an ordinal label is never a count (CLAUSE_BREAK_RE, ORDINAL_LABEL_RE)."""
    old = section_counts(old_lines)
    new = section_counts(new_lines)
    claims = []
    seen = set()
    blocks = fold_blocks(new_lines)
    cur = None
    for s, k, t, r in blocks:
        if k == 'heading':
            if t.startswith('## '):
                cur = t
            continue
        live = ((cur == '## Deletion Criteria') or
                (cur == '## Backlog' and (GATE_LINE_RE.match(r[0]) or t.startswith('**Critical path'))))
        if not live:
            continue
        text, starts = join_block(r, s)
        for sent in split_sentences(text):
            scan = NOT_A_COUNT_RE.sub(lambda m: ' ' * len(m.group(0)), sent)
            scan = ORDINAL_LABEL_RE.sub(lambda m: ' ' * len(m.group(0)), scan)
            breaks = [m.start() for m in CLAUSE_BREAK_RE.finditer(scan)]
            for key, rx in COUNT_NOUNS.items():
                if not rx.search(scan):
                    continue
                for nm in re.finditer(r'\b([0-9]+)\b', scan):
                    v = int(nm.group(1))
                    lo = max([b + 1 for b in breaks if b < nm.start()] + [0])
                    hi = min([b for b in breaks if b >= nm.end()] + [len(scan)])
                    near = scan[max(lo, nm.start() - NOUN_WINDOW):min(hi, nm.end() + NOUN_WINDOW)]
                    if not rx.search(near):
                        continue
                    if v == old[key] and v != new[key] and v > 0 and (s, key, v) not in seen:
                        seen.add((s, key, v))  # "2 of 2" is one claim, not two
                        claims.append({"section": key, "claimed": v, "now": new[key],
                                       "line": s, "sentence": sent[:160]})
    return claims


def cmd_rotate(args):
    rest, o = parse_options(args, flags=('--write', '--allow-stale-claims'),
                            values=('--date', '--tag'), multi=('--keep',))
    if len(rest) != 1:
        usage("rotate takes exactly one workstream.md")
    if not o['--tag']:
        usage("rotate needs --tag ws/<name>-<date>")
    path = os.path.abspath(rest[0])
    tag = o['--tag']
    date = o['--date'] or datetime.date.today().isoformat()
    text = load(path)
    old_lines = text.split('\n')
    wsdir = os.path.dirname(path)
    root = os.path.abspath(os.path.join(wsdir, '..', '..', '..', '..'))
    rc, out = git(['tag', '-l', tag], wsdir)
    if rc != 0 or out.strip() != tag:
        sys.stderr.write("%s: tag %s does not exist; tag the current commit first\n" % (PROG, tag))
        return 1
    # Non-conforming open lines cannot be carried line by line.
    wrapped = 0
    state = None
    for l in old_lines:
        if l.strip() == '' or ANY_HEADING_RE.match(l) or re.match(r'^ *(?:[-*+]|[0-9]+\.) ', l):
            state = 'open' if TOTAL_OPEN_RE.match(l) else None
            continue
        if state == 'open':
            wrapped += 1
    if wrapped:
        sys.stderr.write("%s: %d continuation line(s) under open items; the file is non-conforming, refusing\n" % (PROG, wrapped))
        return 1
    try:
        new_lines, leaving, report = rotate(path, old_lines, tag, date, o['--keep'])
    except Refusal as e:
        sys.stderr.write("%s: %s in %s\n" % (PROG, e, path))
        return 1
    hits, bare = sweep_removed(root, path, new_lines, leaving, tag, old_lines)
    if bare:
        sys.stderr.write("%s: %d home-less mention(s) of a leaving ID in other files, not counted "
                         "(IDs are per-workstream; give a citation its home if it means this one)\n"
                         % (PROG, len(bare)))
        for b in bare:
            sys.stderr.write("  %s:%s bare %r: %s\n" % (b["file"], b["line"], b["needle"], b["sentence"]))
    if hits:
        sys.stderr.write("%s: %d reference(s) to a leaving block; refusing to write "
                         "(line numbers index the files on disk; block = the block's first line)\n"
                         % (PROG, len(hits)))
        for h in hits:
            sys.stderr.write("  %s:%s (block %s, %s) cites leaving %s %r: %s\n" % (
                h["file"], h["line"], h["block"], h["scope"], h["leaving"], h["needle"], h["sentence"]))
        return 1
    claims = stale_claims(old_lines, new_lines)
    if claims:
        for c in claims:
            print("STALE CLAIM line %d: %s %d claimed, now %d: %s" % (
                c["line"], c["section"], c["claimed"], c["now"], c["sentence"]))
        if not o['--allow-stale-claims']:
            sys.stderr.write("%s: %d claim(s) the rotation makes false; refusing without --allow-stale-claims\n" % (PROG, len(claims)))
            return 1
    before, after = structure(old_lines), structure(new_lines)
    if before != after:
        sys.stderr.write("%s: structure not carried: %s -> %s; refusing\n" % (PROG, before, after))
        return 1
    new = '\n'.join(new_lines)
    report += " open=%d gates=%d standing=%d bytes %d->%d" % (
        after['open'], after['gates'], after['standing'], len(text.encode('utf-8')), len(new.encode('utf-8')))
    # The fingerprint is not identical by design here (headings and done
    # boxes leave), so the shared tail is not used.
    print(report)
    if new == text:
        print("NO CHANGE")
    elif o['--write']:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new)
        print("WRITTEN")
    return 0


# --- archive: Move 3's relocation of completed phases ------------------------

PHASE_CODE_RE = re.compile(r'[A-Za-z0-9]+')
BLOCK_END_RE = re.compile(r'^#{1,3}\s')


def heading_blocks(lines, bounds):
    """[(start, end, heading, codes)] for every `### ` block inside
    bounds, the 0-based (start, end) of a `## ` section, coded or not
    (codes is [] for a heading declaring none). A block runs from its
    heading to the next heading of level 3 or above, or to the section's
    end, so a `### D3 (...)` past the next `## ` is never read."""
    start, end = bounds
    heads = [i for i in range(start + 1, end) if BLOCK_END_RE.match(lines[i])]
    out = []
    for n, h in enumerate(heads):
        if not lines[h].startswith('### '):
            continue
        m = PHASE_HEADING_RE.match(lines[h])
        stop = heads[n + 1] if n + 1 < len(heads) else end
        out.append((h, stop, lines[h], [c.strip() for c in m.group(2).split('/')] if m else []))
    return out


def phase_blocks(lines, bounds):
    """The heading_blocks whose heading declares a phase code."""
    return [b for b in heading_blocks(lines, bounds) if b[3]]


def heading_text(h):
    """A --headings value or a heading line, as the text after `### `."""
    return h[4:].strip() if h.startswith('### ') else h.strip()


def multiset(items):
    counts = {}
    for k in items:
        counts[k] = counts.get(k, 0) + 1
    return counts


def archive(lines, codes, headings=()):
    """(new_lines, report, entries, created): the blocks of the named
    phases and of the named headings moved from the Backlog to the end
    of ## Archive, in file order, each once."""
    backlog = section_bounds(lines, 'Backlog')
    if backlog is None:
        raise Refusal("no ## Backlog section")
    if sum(1 for l in lines if l == '## Archive') > 1:
        raise Refusal("more than one ## Archive section")
    arch = section_bounds(lines, 'Archive')
    live = phase_blocks(lines, backlog)
    done = phase_blocks(lines, arch) if arch else []
    moving = [b for b in live if any(c in codes for c in b[3])]
    unmoved = [c for c in codes if not any(c in b[3] for b in live)]
    archived = [c for c in unmoved if any(c in b[3] for b in done)]
    missing = [c for c in unmoved if c not in archived]
    if missing:
        raise Refusal("no phase heading under ## Backlog declares %s" % ", ".join(missing))
    live_all = heading_blocks(lines, backlog)
    done_all = heading_blocks(lines, arch) if arch else []
    archived_heads = []
    for want in headings:
        t = heading_text(want)
        hits = [b for b in live_all if heading_text(b[2]) == t]
        if len(hits) > 1:
            raise Refusal("\"%s\" matches %d headings under ## Backlog; name one heading exactly\n%s" % (
                t, len(hits), "\n".join("  line %d: %s" % (b[0] + 1, b[2][:160]) for b in hits)))
        if hits:
            if hits[0] not in moving:
                moving.append(hits[0])
            continue
        prior = [b for b in done_all if heading_text(b[2]) == t]
        if not prior:
            raise Refusal("no ### heading under ## Backlog reads \"%s\"" % t)
        archived_heads.append(prior[0])
    moving.sort(key=lambda b: b[0])
    open_lines = [(i, lines[i]) for s, e, _h, _c in moving for i in range(s, e)
                  if DELETION_OPEN_RE.match(lines[i])]
    if open_lines:
        raise Refusal("%d open line(s) in a phase to archive, and a partly-archived phase hides work\n%s" % (
            len(open_lines), "\n".join("  line %d: %s" % (i + 1, t[:160]) for i, t in open_lines)))
    entries = []
    unparsable = 0
    for s, e, h, _c in moving:
        boxes = sum(1 for i in range(s, e) if CHECKBOX_RE.match(lines[i]))
        last = e
        while last > s + 1 and not lines[last - 1].strip():
            last -= 1
        entries.append("MOVE line %d-%d (%d checkbox line(s)): %s" % (s + 1, last, boxes, h))
        for i in range(s, e):
            m = None if CHECKBOX_ID_RE.match(lines[i]) else CHECKBOX_HASH_RE.match(lines[i])
            if m:
                unparsable += 1
                entries.append("UNPARSABLE %s line %d: leaves the Backlog, where it stops being flagged" % (
                    m.group(1), i + 1))
    for c in archived:
        b = next(b for b in done if c in b[3])
        entries.append("ALREADY ARCHIVED %s line %d: %s" % (c, b[0] + 1, b[2]))
    for b in archived_heads:
        entries.append("ALREADY ARCHIVED heading line %d: %s" % (b[0] + 1, b[2]))
    archived = archived + archived_heads
    if not moving:
        return lines, "archive: 0 phase block(s) to move, %d already archived" % len(archived), entries, False
    taken = set()
    payload = []
    for s, e, _h, _c in moving:
        taken.update(range(s, e))
        chunk = lines[s:e]
        while chunk and chunk[-1].strip() == '':
            chunk.pop()
        payload += [''] + chunk
    rest = [l for i, l in enumerate(lines) if i not in taken]
    arch = section_bounds(rest, 'Archive')
    created = arch is None
    if created:
        k = len(rest)
        while k > 0 and rest[k - 1].strip() == '':
            k -= 1
        new = rest[:k] + ['', '## Archive'] + payload + rest[k:]
    else:
        k = arch[1]
        while k > arch[0] + 1 and rest[k - 1].strip() == '':
            k -= 1
        tail = rest[k:]
        new = rest[:k] + payload + ([''] if tail and tail[0].strip() else []) + tail
    report = "archive: %d phase block(s) to ## Archive (%s), %d already archived, %d unparsable ID(s)" % (
        len(moving), 'created' if created else 'appended', len(archived), unparsable)
    return new, report, entries, created


def cmd_archive(args):
    rest, o = parse_options(args, flags=('--write',), values=('--phases',), multi=('--headings',))
    if len(rest) != 1:
        usage("archive takes exactly one workstream.md")
    if not o['--phases'] and not o['--headings']:
        usage("archive needs --phases CODE[,CODE...] or --headings <heading>")
    headings = []
    for h in o['--headings']:
        if not heading_text(h):
            usage("--headings needs a heading's text")
        if heading_text(h) not in headings:
            headings.append(heading_text(h))
    codes = []
    for c in o['--phases'].split(',') if o['--phases'] else []:
        c = c.strip()
        if not PHASE_CODE_RE.fullmatch(c):
            usage("--phases %r is not a comma-separated list of phase codes" % o['--phases'])
        if c not in codes:
            codes.append(c)
    path = rest[0]
    text = load(path)
    old_lines = text.split('\n')
    try:
        new_lines, report, entries, created = archive(old_lines, codes, headings)
    except Refusal as e:
        head, _sep, lines = str(e).partition('\n')
        sys.stderr.write("%s: %s in %s\n" % (PROG, head, path))
        if lines:
            sys.stderr.write(lines + "\n")
        return 1
    # A move reorders the checkboxes, so the MULTISET form is asserted
    # rather than the sequence `fingerprint` reads. The new heading is the
    # one line a move adds and is taken out before comparing.
    after = list(new_lines)
    if created:
        after.remove('## Archive')
    for name, pick in (
            ('heading', lambda ls: [l for l in ls if ANY_HEADING_RE.match(l)]),
            ('checkbox ID-and-state', lambda ls: [(m.group(1).lower(), m.group(2))
                                                  for l in ls for m in [CHECKBOX_ID_RE.match(l)] if m]),
            ('non-blank line', lambda ls: [l for l in ls if l.strip()])):
        if multiset(pick(old_lines)) != multiset(pick(after)):
            sys.stderr.write("%s: %s multiset changed; refusing to write\n" % (PROG, name))
            return 1
    new = '\n'.join(new_lines)
    print("%s; bytes %d->%d" % (report, len(text.encode('utf-8')), len(new.encode('utf-8'))))
    for l in entries:
        print(l)
    if new == text:
        print("NO CHANGE")
    elif o['--write']:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new)
        print("WRITTEN")
    return 0


# --- dispatch ---------------------------------------------------------------

COMMANDS = {
    'records': cmd_records,
    'decisions': cmd_decisions,
    'learnings': cmd_learnings,
    'rotate': cmd_rotate,
    'archive': cmd_archive,
}


def main():
    argv = sys.argv[1:]
    if argv and argv[0] in ('-h', '--help'):
        sys.stdout.write(__doc__)
        sys.exit(0)
    if not argv or argv[0] not in COMMANDS:
        usage("sub-command required: %s" % ", ".join(COMMANDS))
    sys.exit(COMMANDS[argv[0]](argv[1:]))


if __name__ == '__main__':
    main()
