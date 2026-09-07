#!/usr/bin/env python3
"""workstream-rewrite.py -- the kit's rewrites, one sub-command each.

Every sub-command changes one workstream.md to a form the rule already
prescribes. All dry-run by default and write only under --write; each
carries a dated marker or a fixed point so a second run is a no-op;
each asserts the structure fingerprint (heading multiset, checkbox ID
and state sequence) identical before writing and exits 1 otherwise;
each leaves the full text in git at the commit before the run. None
infers a judgment the caller names: which Decisions shipped is
--decisions, which blocks a rotation keeps is --keep. The measures
live in workstream-record.py. Standard library only.

Usage:
  workstream-rewrite.py records   <workstream.md> [--write] [--date YYYY-MM-DD]
  workstream-rewrite.py decisions <workstream.md> --decisions D1,D4-D9 --release <tag>
                                  [--write] [--date YYYY-MM-DD]
  workstream-rewrite.py learnings <workstream.md> [--write] [--date YYYY-MM-DD]
  workstream-rewrite.py rotate    <workstream.md> --tag ws/<name>-<date> [--write]
                                  [--date YYYY-MM-DD] [--keep <phrase>]...
                                  [--allow-stale-claims]

`records`: every `- [x]` record in the live Backlog, and under
## Archive when that section exists, longer than the rule's
completion-note form condenses to that form (the ID, the description's
first sentence, the last status word and the date in its own sentence,
its Decision citations and commit hashes, a dated marker).

`decisions`: each named Decision condenses to its heading, its first
paragraph and a line naming the release; the section is restored to
numeric order. A Decision already one paragraph long is byte-identical
after. --release must be a tag or a commit the repository holding the
file resolves, refused otherwise; the line reads `Shipped in` for a
tag and `Landed at` for a commit, since a project workstream's
Decisions land in commits rather than releases.

`learnings`: every Learning the record scores terminal (a disposition
marker at sentence start with a date in its sentence, or struck
through whole) condenses to its first sentence and its disposition
sentence, re-wrapped; a deferred or undispositioned entry is
byte-identical after, and so is a terminal one already that short.

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
after the rewrite, every count a surviving criterion, gate line or
critical-path sentence states about a section that was true before
and is false after is reported with both figures and refuses the run
unless --allow-stale-claims; and the open count, gate count, STANDING
count and open IDs are asserted identical. The tag must exist. A file
with wrapped open lines is refused as non-conforming.

Exit 0 on success (a dry run included), 1 on a refusal or a failed
check, 2 on usage or an unreadable file. Prints a report, then WRITTEN
or NO CHANGE (a dry run with changes prints the report alone). The
report is one shape for records, decisions and learnings: a summary
line, then one line per condensed entry -- `<ID> <bytes before>-><bytes
after>: <the condensed line's first 160 characters>` -- so a dry run
shows what a write would leave. The commit hashes a condensed record
keeps are those its note names VERBATIM, 7 to 40 hex characters with
at least one letter, in any repository, kept as written; the script
never derives one, and a note naming none says so.
"""

import datetime
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from workstream_state import (  # noqa: E402
    ANY_HEADING_RE, CHECKBOX_ID_RE, DECISION_HEADING_RE, DELETION_OPEN_RE, DONE_LINE_RE,
    GATE_LINE_RE, LEARNING_RE, PHASE_HEADING_RE, TERMINAL_RE, TOTAL_OPEN_RE, STRIKE_RE,
    blank_strikes, disposition, extract_section, find_workstreams, fingerprint, fold_blocks,
    git, join_block, line_at, marker_counts, read_lines, section_bounds, sentence_span,
    split_sentences, strip_frontmatter, wrap,
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

DONE_RE = re.compile(r"^( *- \[x\] )(#[A-Z]+-[0-9]+[a-z]?|#G-[A-Z]+)(: ?)(.*)$")
DATE_RE = re.compile(r"\b(20[0-9]{2}-[0-9]{2}-[0-9]{2})\b")
DEC_RE = re.compile(r"\bD[0-9]+\b")
SHA_RE = re.compile(r"\b(?=[0-9]*[a-f])[0-9a-f]{7,40}\b")  # a hash the note names verbatim, any repo; never a bare number
STATUS_RE = re.compile(r"\b(DONE|DECIDED|RETIRED|SUPERSEDED|CLOSED|SHIPPED|ABSORBED|RESOLVED|APPROVED|UNBLOCKED|MERGED)\b")


def entry_line(ident, before, after, line):
    """The per-entry report line every rewrite prints."""
    return "%s %d->%d: %s" % (ident, before, after, line.strip()[:160])


def status_and_date(body, dates):
    """The record's LAST status word and the date in that word's own
    sentence (the record script's marker rule): after the word first,
    else anywhere in the sentence, else n.d. Never the block's last
    date, which can belong to another sentence -- a record that ran
    VERIFIED, DONE, CORRECTED condensed to the date of another
    project's commit mentioned last. With no status word the block's
    last date stands, since nothing else ties a date to the status."""
    marks = list(STATUS_RE.finditer(body))
    if not marks:
        return "DONE", (dates[-1] if dates else "n.d.")
    m = marks[-1]
    s, e = sentence_span(body, m.start())
    after = DATE_RE.search(body, m.end(), e)
    if after:
        return m.group(1), after.group(1)
    within = DATE_RE.search(body, s, e)
    return m.group(1), (within.group(1) if within else "n.d.")


def condense_records(lines, mark):
    """Records under ## Backlog and, when the section exists, under
    ## Archive: the extract skill's Move 3 condenses a record whether
    or not its phase has moved, and four records moved before this
    script existed sat verbatim under Archive at 14,000 bytes."""
    bounds = section_bounds(lines, "Backlog")
    if bounds is None:
        raise Refusal("no ## Backlog section")
    condensed = 0
    saved = 0
    entries = []
    report = []
    archive = section_bounds(lines, "Archive")
    ranges = [("backlog", bounds)] + ([("archive", archive)] if archive else [])
    # Rebuild from the end so earlier offsets stay valid.
    for name, (start, end) in sorted(ranges, key=lambda r: -r[1][0]):
        out, c, s, ents = condense_range(lines, start, end, mark)
        condensed += c
        saved += s
        entries = ents + entries
        report.insert(0, "%s_lines %d->%d" % (name, end - start, len(out)))
        lines = lines[:start] + out + lines[end:]
    report.insert(0, "condensed=%d bytes_saved=%d" % (condensed, saved))
    return lines, " ".join(report), entries


def condense_range(lines, start, end, mark):
    out = []
    condensed = 0
    saved = 0
    entries = []
    for i in range(start, end):
        ln = lines[i]
        m = DONE_RE.match(ln)
        if not m or len(ln) <= 400 or GUARD_RE.search(ln):
            out.append(ln)
            continue
        prefix, tid, _sep, body = m.groups()
        # The first sentence is found on a copy with code spans blanked
        # inside their backticks: a description quoting a sentence
        # (`Done. Commit the new files ...`) was cut at the quoted full
        # stop, leaving a head that ended `-- \`Done.`
        spans = re.sub(r"`[^`]*`", lambda mm: "`" + " " * (len(mm.group(0)) - 2) + "`", body)
        split = re.search(r"(?<=[.!?])\s+(?=[A-Z`(#])", spans)
        head = body[:split.start()] if split else body
        if len(head) > 220:
            head = head[:217].rsplit(" ", 1)[0] + "..."
        dates = DATE_RE.findall(body)
        decs = sorted(set(DEC_RE.findall(body)), key=lambda d: int(d[1:]))
        shas = list(dict.fromkeys(SHA_RE.findall(body)))
        mark_word, date = status_and_date(body, dates)
        ev = []
        if decs:
            ev.append("reasoning in " + ", ".join(decs))
        if shas:
            ev.append("commits " + ", ".join(shas[:8]) + (" ..." if len(shas) > 8 else ""))
        note = "%s%s: %s %s %s; %s. %s; full record in git before that commit." % (
            prefix, tid, head, mark_word, date,
            "; ".join(ev) if ev else "evidence in the record at the commit preceding this condensation",
            mark)
        out.append(note)
        condensed += 1
        saved += len(ln) - len(note)
        entries.append(entry_line(tid, len(ln), len(note), note))
    return out, condensed, saved, entries


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


def condense_decisions(lines, wanted, release, mark, kind='tag'):
    start, end, preamble, blocks = decision_blocks(lines)
    present = {n for n, _ in blocks}
    missing = sorted(wanted - present)
    if missing:
        raise Refusal("no Decision heading for %s" % ", ".join("D%d" % n for n in missing))
    condensed = 0
    saved = 0
    entries = []
    new_blocks = []
    for n, bl in blocks:
        bl = strip_blank(bl)
        if n in wanted and not any(GUARD_RE.search(l) for l in bl):
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
    report = "decisions_condensed=%d bytes_saved=%d reordered=%s" % (condensed, saved, "yes" if reordered else "no")
    return lines[:start + 1] + rebuilt + lines[end:], report, entries


def run_condense(path, do_tasks, decisions, release, date, dry):
    """The shipped script's whole run, kept for the forwarding shim:
    records unless --no-tasks, then the named Decisions, one report."""
    text = load(path)
    lines = text.split("\n")
    mark = "Condensed %s at extract" % date
    report = []
    entries = []
    try:
        if do_tasks:
            lines, r, ents = condense_records(lines, mark)
            report.append(r)
            entries.extend(ents)
        if decisions is not None:
            kind, release = resolve_release(path, release)
            lines, r, ents = condense_decisions(lines, parse_decisions(decisions), release, mark, kind)
            report.append(r)
            entries.extend(ents)
    except Refusal as e:
        sys.stderr.write("%s: %s in %s\n" % (PROG, e, path))
        return 1
    return finish(path, text, "\n".join(lines), dry, report, entries)


def cmd_records(args):
    rest, o = parse_options(args, flags=('--write',), values=('--date',))
    if len(rest) != 1:
        usage("records takes exactly one workstream.md")
    return run_condense(rest[0], True, None, None, o['--date'] or datetime.date.today().isoformat(), not o['--write'])


def cmd_decisions(args):
    rest, o = parse_options(args, flags=('--write',), values=('--date', '--decisions', '--release'))
    if len(rest) != 1:
        usage("decisions takes exactly one workstream.md")
    if o['--decisions'] is None or o['--release'] is None:
        usage("decisions needs --decisions and --release")
    return run_condense(rest[0], False, o['--decisions'], o['--release'],
                        o['--date'] or datetime.date.today().isoformat(), not o['--write'])


# --- learnings: terminal entries condense to statement plus disposition -----

LEARNING_PREFIX_RE = re.compile(r'^- (L[0-9]+ \([^)]*\):)\s*(.*)$', re.S)


def condense_learning(text):
    """The condensed joined text of one Learning block, or None when the
    entry is not terminal, is struck, or is already that short."""
    if disposition(text) != 'terminal':
        return None
    m = LEARNING_PREFIX_RE.match(text)
    if not m:
        return None
    prefix, body = m.group(1), m.group(2).strip()
    sentences = split_sentences(body)
    if len(sentences) <= 1:
        return None
    blanked = blank_strikes(body)
    marks = marker_counts(blanked, TERMINAL_RE)
    if not marks:
        return None
    s, e = sentence_span(body, marks[0].start())
    disp = body[s:e].strip()
    first = sentences[0]
    condensed = first if disp == first else first + ' ' + disp
    if condensed == body:
        return None
    return '- ' + prefix + ' ' + condensed


def condense_learnings(lines):
    bounds = section_bounds(lines, "Learnings")
    if bounds is None:
        raise Refusal("no ## Learnings section")
    start, end = bounds
    section = lines[start + 1:end]
    out = []
    condensed = 0
    saved = 0
    entries = []
    blocks = fold_blocks(section)
    consumed = 0
    for bstart, kind, text, raw in blocks:
        idx = bstart - 1
        out.extend(section[consumed:idx])
        consumed = idx + len(raw)
        if kind == 'item' and LEARNING_RE.match(raw[0]):
            new = condense_learning(text)
            if new is not None:
                wrapped = wrap(new, 70, indent='  ')
                before_b = sum(len(l) + 1 for l in raw)
                after_b = sum(len(l) + 1 for l in wrapped)
                saved += before_b - after_b
                condensed += 1
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
    report = "learnings_condensed=%d bytes_saved=%d learnings=%d" % (condensed, saved, after)
    return lines[:start + 1] + out + lines[end:], report, entries


def cmd_learnings(args):
    rest, o = parse_options(args, flags=('--write',), values=('--date',))
    if len(rest) != 1:
        usage("learnings takes exactly one workstream.md")
    path = rest[0]
    text = load(path)
    try:
        lines, report, entries = condense_learnings(text.split("\n"))
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
    body = re.sub(r'^(?:- )?(?:\[[ xX]\] )?#?[A-Z]+-?[0-9]*[a-z]?\s*(?:\([^)]*\))?:?\s*', '', text.strip())
    body = re.sub(r'^\*\*|^~~', '', body)
    words = body.split()
    return ' '.join(words[:5])


def section_counts(lines):
    """The counts a claim can be about, derived from lines."""
    learn_lines = {no for no, _t in extract_section(lines, r'^##\s+Learnings\s*$')}
    learn = 0
    terminal = 0
    for s, k, t, r in fold_blocks(lines):
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
                if kind == 'item' and re.match(r'^- OQ-', raw[0]) or keep_by_phrase(text) or kind == 'heading':
                    new.extend(gap)
                    new.extend(raw)
                else:
                    m = re.match(r'^- (?:~~)?(OQ-[0-9]+)', raw[0])
                    leaving.append(('open question', m.group(1) if m else None, lead_phrase(text), raw[0]))
            rebuilt[heading] = strip_blank(new) + ['']
            live_text.extend(rebuilt[heading])
        elif heading == '## Learnings':
            new = []
            blocks = fold_blocks(body)
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


def sweep_removed(root, path, new_lines, leaving, tag, old_lines=None):
    """Hits in the surviving text and in the live content of every other
    state file for each leaving block's ID and lead phrase. A hit whose
    sentence names the tag is a re-pointed reference and is not a hit.
    Line numbers index the file ON DISK: a surviving block is looked up
    in old_lines, since the rotated output's numbering (the Rotated
    paragraph alone shifts everything after it) sent an operator's
    `sed -n` to the wrong line for every hit of the first rotation.
    A block the rotation wrote has no source line and is cited as
    written."""
    hits = []
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
        body = strip_frontmatter(read_lines(active))
        targets.append((os.path.relpath(active, root), [t for _n, t in body], 'live content'))

    # The record's live blocks for the other files; the whole text for
    # the surviving file, which is live by construction.
    def live_blocks_of(lines, whole):
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
            elif cur == '## Open Questions' and re.match(r'^- OQ-', r[0]):
                out.append((s, r))
            elif cur == '## Deletion Criteria' and DELETION_OPEN_RE.match(r[0]):
                out.append((s, r))
            elif cur is None:
                out.append((s, r))  # ACTIVE.md's body
        return out

    needles = []
    for kind, ident, phrase, first in leaving:
        if ident:
            needles.append((kind, ident, re.compile(r'(?<![\w/-])' + re.escape(ident) + r'(?![\w-])'), first))
        if phrase and len(phrase.split()) >= 2:
            needles.append((kind, phrase, re.compile(re.escape(phrase).replace(r'\ ', r'\s+'), re.I), first))
    for rel, lines, scope in targets:
        whole = scope == 'surviving text'
        for start, raw in live_blocks_of(lines, whole):
            if whole and source_start:
                start = source_start.get(tuple(raw), start)
            text, starts = join_block(raw, start)
            blanked = blank_strikes(text)
            for kind, needle, rx, first in needles:
                for m in rx.finditer(blanked):
                    if whole and raw[0] == first:
                        continue  # the block's own definition is not a reference
                    s, e = sentence_span(blanked, m.start())
                    sentence = blanked[s:e]
                    if tag in sentence or re.search(r'\b(?:rotation|archive) tag\b|\bat (?:its|the) tag\b', sentence):
                        continue
                    hits.append({"file": rel, "line": line_at(starts, m.start()), "block": start,
                                 "scope": scope, "leaving": kind, "needle": needle,
                                 "sentence": sentence[:160]})
    return hits


NOT_A_COUNT_RE = re.compile(
    r'\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b'          # a date: 2026-09-04 read as a claim of 4
    r'|ws/[\w.-]+'                             # a rotation or archive tag, dated
    r'|\b(?:L|D|OQ-)[0-9]+\b'                  # an ID: (L67 to L70) is a span, not a count
    r'|#[A-Z]+-[0-9]+[a-z]?'                   # a task ID
)
NOUN_WINDOW = 45  # characters either side of the number, a few words


def stale_claims(old_lines, new_lines):
    """Numbers in surviving criteria, gate lines and critical-path
    sentences that equal a section's OLD count and not its NEW one, in a
    sentence naming that section WITHIN A FEW WORDS of the number.
    Dates, tags and IDs are blanked first: the first live rotation read
    `learnings 4 claimed, now 0` twice, once from the `-04` of a tag's
    date in a sentence counting criteria and once from the span `(L67
    to L70)`, and refused until --allow-stale-claims after both had
    been checked by hand."""
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
            for key, rx in COUNT_NOUNS.items():
                if not rx.search(scan):
                    continue
                for nm in re.finditer(r'\b([0-9]+)\b', scan):
                    v = int(nm.group(1))
                    near = scan[max(0, nm.start() - NOUN_WINDOW):nm.end() + NOUN_WINDOW]
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
    hits = sweep_removed(root, path, new_lines, leaving, tag, old_lines)
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


# --- dispatch ---------------------------------------------------------------

COMMANDS = {
    'records': cmd_records,
    'decisions': cmd_decisions,
    'learnings': cmd_learnings,
    'rotate': cmd_rotate,
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
