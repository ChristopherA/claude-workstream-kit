"""workstream_state.py -- what the kit's two state scripts share.

The folder that turns a hard-wrapped state file into blocks, the patterns
the record derives its fields from, the disposition-marker rule, the
structure fingerprint a rewrite asserts before writing, and the small
git and path helpers. Imported by workstream-record.py (measures) and
workstream-rewrite.py (rewrites); standard library only.

The state-file format is two-shaped and everything here reads both
shapes: backlog lines and deletion criteria are one line each, so their
COUNTS anchor at line start; every prose section is hard-wrapped at
roughly 70 columns, so anything reading prose -- a hold, a marker, a
citation -- reads a folded BLOCK, a line plus its continuation lines,
never a single line. Reading a wrapped construct one line at a time
returns a false empty, which is what six consumers reported at once.
"""

import glob
import os
import re
import subprocess
import sys

# --- patterns -----------------------------------------------------------

TOTAL_OPEN_RE = re.compile(r'^ *- \[ \] #')
GATE_LINE_RE = re.compile(r'^ *- \[ \] #G-')
DONE_LINE_RE = re.compile(r'^ *- \[[xX]\] #')
DONE_GATE_RE = re.compile(r'^ *- \[[xX]\] #G-')
CHECKBOX_RE = re.compile(r'^ *- \[[ xX]\] ')
CHECKBOX_ID_RE = re.compile(r'^ *- \[([ xX])\] (#[A-Za-z]+-[0-9]+[a-z]?|#G-[A-Za-z0-9]+)')
DELETION_OPEN_RE = re.compile(r'^ *- \[ \]')
DELETION_DONE_RE = re.compile(r'^ *- \[[xX]\]')
LEARNING_RE = re.compile(r'^- (?:~~)?L([0-9]+)')
OQ_RE = re.compile(r'^- (?:~~)?OQ-([0-9]+)')
DECISION_HEADING_RE = re.compile(r'^### D([0-9]+)\b')
# A phase heading is `### <Name> (<XX>)` or `### <Name> (<XX> / <YY>)`;
# text after the code ("-- retired", "-- rollout residue") is tolerated,
# since real files carry it, and so is a multi-code heading.
PHASE_HEADING_RE = re.compile(
    r'^###\s+(.+?)\s*\(([A-Za-z0-9]+(?:\s*/\s*[A-Za-z0-9]+)*)\)'
)
TOP_HEADING_RE = re.compile(r'^##\s')
ANY_HEADING_RE = re.compile(r'^#{1,6}\s')
LIST_ITEM_RE = re.compile(r'^ *(?:[-*+]|[0-9]+\.) ')
TASK_CODE_RE = re.compile(r'#(?:G-)?([A-Z]+)-?')

DATE = r'[0-9]{4}-[0-9]{2}-[0-9]{2}'
DATE_RE = re.compile(r'\b' + DATE + r'\b')
# Gate markers are the DATED forms the rule names. A bare word is a
# mention -- a build note quoting "the SATISFIED sentence" -- and a date is
# what turns a mention into a marking.
SATISFIED_MARK_RE = re.compile(
    r'\b(?:SATISFIED|READY|criterion is met) ' + DATE
)
HOLDS_RE = re.compile(r'\bHOLDS (' + DATE + ')')

# Holds: a hold VERB WITH ITS OBJECT, since the bare verb is ordinary
# prose -- "the two retired checkpoints held", "conditions that hold" --
# and 29 of 34 hits on one project were that. Word boundaries also
# exclude a hyphen, since `-` is a word boundary to the engine and
# `Held-out validation` is not a hold. A match whose clause is negated
# (`Nothing in this file is held by ...`) is dropped: a critical-path
# paragraph is exactly where a workstream says it is NOT held. A
# struck-through span (`~~...~~`) is blanked before matching, so a hold
# already retired in place does not count.
HOLD_RE = re.compile(
    r'(?<![\w-])(?:held (?:by|behind|until|pending|for|on|back)|'
    r'holds? (?:for|until|behind|pending|back))\b|blocked (?:by|on)|unblocks when|'
    r'\bwait(?:s|ing)? (?:for|on)\b|not before|sequenced after',
    re.IGNORECASE,
)
STRIKE_RE = re.compile(r'~~.*?~~', re.S)
NEGATION_RE = re.compile(r'\b(?:no|not|nothing|never|nor|neither|without)\b', re.IGNORECASE)
CLAUSE_SPLIT_RE = re.compile(r'[.;:]')

# Cross references: the type must not be the tail of a longer path or
# name (`ml-explore/mlx` is a repository, not `explore/mlx`), and a name
# may carry dots (`project/omlx-0.4.x-finalize`).
CROSS_REF_WS_RE = re.compile(
    r'(?<![\w./-])(?:explore|feature|fix|project|maintain)/[a-z0-9-]+(?:\.[a-z0-9-]+)*'
)
CROSS_REF_TAG_RE = re.compile(r'(?<![\w./-])ws/[a-z0-9-]+(?:\.[a-z0-9-]+)*')

# Every ID form the rule mints. A task ID must carry a digit: `#XX-N`
# and `#G-XX` are the rule's own metavariables, not references.
ID_RE = re.compile(
    r'#[A-Z]+-[0-9]+[a-z]?|\bD[0-9]+\b|\bL[0-9]+\b|\bOQ-[0-9]+\b'
)
TASK_ID_RE = re.compile(r'#(?:[A-Z]+-[0-9]+[a-z]?|G-[A-Z]+[0-9]*)(?![\w-])')

# Every ID a gloss is owed for: tasks and gates (a gate has no digit, so
# ID_RE alone misses #G-OG), Decisions, Learnings, Open Questions. The
# rule's metavariables (#XX-N, #G-XX) carry no digit and no real phase
# code and are excluded by the pattern, not by a list.
GLOSSABLE_ID_RE = re.compile(
    r'#(?:[A-Z]{1,4}-[0-9]+[a-z]?|G-(?!XX\b)[A-Z]{1,4}[0-9]*)(?![\w-])'
    r'|\bD[0-9]+\b|\bL[0-9]+\b|\bOQ-[0-9]+\b'
)
# What may sit between an ID and its gloss: a closing code span, a
# possessive, a home (`in type/name`, `in ws/tag`, `at ws/tag`).
GLOSS_BRIDGE_RE = re.compile(
    r"`?(?:'s)?(?: (?:in|at) (?:(?:explore|feature|fix|project|maintain)/[a-z0-9.-]+|ws/[a-z0-9.-]+)`?(?:'s)?)?\s*"
)
# The gloss itself: a parenthetical or a double-quoted phrase that
# carries at least one letter, so `(#EX-3)` -- an ID glossing an ID --
# does not count.
GLOSS_RE = re.compile(r'(?:\([^()\n]*[A-Za-z][^()\n]*\)|["“][^"”\n]*[A-Za-z][^"”\n]*["”])')
CODE_SPAN_RE = re.compile(r'`[^`\n]*`')
FENCE_RE = re.compile(r'^\s*(?:```|~~~)')


def blank_code(text):
    """Code spans replaced by spaces of the same length, so offsets hold
    and an ID quoted as code (`#EX-3:` in a command, a backlog line
    quoted whole) is not read as a mention."""
    return CODE_SPAN_RE.sub(lambda m: ' ' * (m.end() - m.start()), text)


def blank_fences(lines):
    """The same lines with every fenced block (``` or ~~~) replaced by
    empty strings, fence lines included, so line numbers hold and a
    backlog line quoted inside a fence is not read as a mention. Fence
    state has to be tracked across paragraphs, since fold_blocks joins
    a fence line to the paragraph before it."""
    out = []
    fenced = False
    for raw in lines:
        if FENCE_RE.match(raw):
            fenced = not fenced
            out.append('')
            continue
        out.append('' if fenced else raw)
    return out


def purpose_paragraphs_for_gloss(lines):
    """(start_line_no, raw_lines) for each paragraph of the Purpose
    section, the one prose section the rule's adoption pass names beside
    the live blocks."""
    section = extract_section(lines, r'^## Purpose\b')
    if not section:
        return []
    start_no = section[0][0]
    raw = [t for _n, t in section]
    return [(s + start_no - 1, r) for s, kind, _t, r in fold_blocks(raw) if kind != 'heading']


def bare_ids(paragraphs):
    """Bare ID mentions in prose. `paragraphs` is an iterable of
    (start_line_no, lines): each paragraph is folded to one text and
    checked on its own, so a gloss wrapped across two lines still
    counts, and within it an ID owes a gloss at its FIRST mention only
    -- a later mention in the same paragraph inherits. A mention is
    glossed when the canonical form follows it directly: `#EX-37 (the
    phase split question)` or `#EX-37 "the phase split question"`, with
    a home allowed in between (`#EX-30 in project/tier (the neutrality
    sort)`). Exempt: the ID a paragraph's first line DEFINES (a checkbox
    line opening with it, a `### D<n>` heading, a `- L<n>` or `- OQ-<n>`
    item), text inside a code span, and struck spans; fenced blocks are
    blanked by the caller (blank_fences), since fence state crosses
    paragraphs. Returns a list of {"line", "id", "context"} with
    1-indexed line numbers."""
    out = []
    for start_no, lines in paragraphs:
        if not lines:
            continue
        head = lines[0]
        defined = None
        m = CHECKBOX_ID_RE.match(head)
        if m:
            defined = m.group(2)
        else:
            m = DECISION_HEADING_RE.match(head)
            if m:
                defined = 'D' + m.group(1)
            m = LEARNING_RE.match(head)
            if m:
                defined = 'L' + m.group(1)
            m = OQ_RE.match(head)
            if m:
                defined = 'OQ-' + m.group(1)
        # Fold to one text, keeping a table of where each line starts.
        starts = []
        parts = []
        pos = 0
        for raw in lines:
            piece = raw.strip()
            starts.append(pos)
            parts.append(piece)
            pos += len(piece) + 1
        text = ' '.join(parts)
        clean = blank_code(text)
        clean = STRIKE_RE.sub(lambda mm: ' ' * (mm.end() - mm.start()), clean)
        seen = set()
        for m in GLOSSABLE_ID_RE.finditer(clean):
            ident = m.group(0)
            if ident in seen:
                continue
            seen.add(ident)
            if ident == defined:
                continue
            bridge = GLOSS_BRIDGE_RE.match(clean, m.end())
            after = bridge.end() if bridge else m.end()
            if GLOSS_RE.match(clean, after):
                continue
            line_idx = max(k for k, st in enumerate(starts) if st <= m.start())
            a = max(0, m.start() - 40)
            b = min(len(text), m.end() + 60)
            out.append({"line": start_no + line_idx, "id": ident, "context": text[a:b].strip()})
    return out


# Disposition markers, as the rule publishes them (Learnings convention).
# TERMINAL: the insight has left the file. DEFERRED: it is tracked work
# that has not landed. Anything else is undispositioned.
TERMINAL_MARKERS = (
    'APPLIED', 'ROUTED', 'DROPPED', 'EXTRACTED', 'SENT', 'HANDED OFF',
    'RESOLVED', 'FULFILLED', 'VERIFIED', 'EXTENDED', 'SUPERSEDED',
    'DISPOSITIONED', 'DISPOSITION', 'DONE', 'SPENT',
)
DEFERRED_MARKERS = ('QUEUED', 'DEFERRED', 'PENDING')
TERMINAL_RE = re.compile(r'\b(?:' + '|'.join(re.escape(m) for m in TERMINAL_MARKERS) + r')\b')
DEFERRED_RE = re.compile(r'\b(?:' + '|'.join(re.escape(m) for m in DEFERRED_MARKERS) + r')\b')
SENTENCE_END_RE = re.compile(r'(?<=[.!?])\s+')

# The size line the session-start hook prints, and the threshold `fires`
# reads. The hook is sh with no python dependency, so the constant lives
# in both files; the fires suite asserts the two agree.
SIZE_BYTES = 65536



# --- blocks: the paragraph-aware read ------------------------------------

def fold_blocks(lines):
    """Group lines into blocks: a heading is its own block; a list item or
    a paragraph absorbs the non-blank lines that follow it until a blank
    line, a heading, or a new list item. Returns (start_line_no, kind,
    joined_text, raw_lines) with 1-indexed line numbers. Continuations at
    column 0 and indented continuations join alike -- the reflow wraps
    prose flush left, and a completion note is an indented block."""
    blocks = []
    current = None
    for i, line in enumerate(lines):
        no = i + 1
        if line.strip() == '':
            if current:
                blocks.append(current)
                current = None
            continue
        if ANY_HEADING_RE.match(line):
            if current:
                blocks.append(current)
            blocks.append((no, 'heading', line.strip(), [line]))
            current = None
            continue
        if LIST_ITEM_RE.match(line):
            if current:
                blocks.append(current)
            current = (no, 'item', line.strip(), [line])
            continue
        if current:
            start, kind, text, raw = current
            current = (start, kind, text + ' ' + line.strip(), raw + [line])
        else:
            current = (no, 'para', line.strip(), [line])
    if current:
        blocks.append(current)
    return blocks


def extract_section(lines, header_regex):
    """Lines (1-indexed via enumerate) between a heading matching
    header_regex and the next top-level '## ' heading (exclusive of both),
    or to EOF. Returns a list of (line_no, text) tuples, blanks included."""
    header_re = re.compile(header_regex)
    start = None
    for i, line in enumerate(lines):
        if header_re.match(line):
            start = i
            break
    if start is None:
        return []
    section = []
    for i in range(start + 1, len(lines)):
        line = lines[i]
        if TOP_HEADING_RE.match(line):
            break
        section.append((i + 1, line))
    return section


def section_bounds(lines, name):
    """(start, end) indexes (0-based) of the `## <name>` line and of the
    next `## ` line or len(lines); None when the section is absent."""
    try:
        start = lines.index('## ' + name)
    except ValueError:
        return None
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith('## ')), len(lines))
    return start, end


def section_of(lines):
    """For each line index, the `## ` heading text it sits under (or
    None before the first)."""
    out = []
    current = None
    for line in lines:
        if TOP_HEADING_RE.match(line):
            current = line.strip()
        out.append(current)
    return out


def strip_frontmatter(lines):
    """Drop a leading '---' ... '---' flat-frontmatter block if present.
    Returns the remaining lines as (line_no, text) tuples, numbered against
    the ORIGINAL file (so line numbers stay citable)."""
    if not lines or lines[0].strip() != '---':
        return list(enumerate(lines, start=1))
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            end = i
            break
    if end is None:
        return list(enumerate(lines, start=1))
    return [(i + 1, lines[i]) for i in range(end + 1, len(lines))]


def split_sentences(text):
    text = text.strip()
    if not text:
        return []
    return [s.strip() for s in SENTENCE_END_RE.split(text) if s.strip()]


def join_block(raw, start_no):
    """The block's lines joined by single spaces (the same text fold_blocks
    builds), with the offset at which each line starts, so a match can
    cite the LINE holding it rather than the block's first line -- a
    scout sent to verify 'line 30' found the phrase on line 41."""
    text = ''
    starts = []
    for i, line in enumerate(raw):
        if text:
            text += ' '
        starts.append((len(text), start_no + i))
        text += line.strip()
    return text, starts


def line_at(starts, offset):
    line_no = starts[0][1] if starts else None
    for off, no in starts:
        if off <= offset:
            line_no = no
        else:
            break
    return line_no


def blank_strikes(text):
    return STRIKE_RE.sub(lambda m: ' ' * len(m.group(0)), text)


def in_strike(text, offset):
    return any(m.start() <= offset < m.end() for m in STRIKE_RE.finditer(text))


def negated(text, start):
    """True when the clause the match sits in carries a negation word
    before it. The clause runs back to the previous `.`, `;` or `:`."""
    head = text[:start]
    parts = CLAUSE_SPLIT_RE.split(head)
    return bool(NEGATION_RE.search(parts[-1])) if parts else False


# --- the disposition-marker rule -----------------------------------------

def sentence_span(text, offset):
    """(start, end) of the sentence holding offset."""
    start = 0
    for m in SENTENCE_END_RE.finditer(text):
        if m.end() <= offset:
            start = m.end()
        else:
            return start, m.start()
    return start, len(text)


def marker_counts(text, marker_re):
    """Matches of marker_re that are MARKERS rather than mentions: the
    word stands at the start of a sentence or clause -- block start, or
    after `. `, `-- ` or `: ` -- AND a date lies in the same sentence,
    either side. Measured over one project's six live workstreams: 30
    occurrences, 29 real markers and one mention ("was this already
    DONE"), which sits mid-sentence in a sentence that carries a date,
    so the position half is what rejects it. Requiring the date AFTER
    the word, the gate-ready precedent, would have scored eleven real
    dispositions (`DISPOSITION 2026-01-01: ROUTED ...`) as mentions.
    Inline emphasis around the word (`**APPLIED 2026-01-01**`) is not
    position: a consumer that bolds its markers as a house habit scored
    142 undispositioned where 0.10.3 scored 89, one drained workstream
    re-scoring as 7 of 7. The emphasis characters are stripped from the
    head before the test, so a bold marker mid-sentence is still a
    mention. Asterisk emphasis only: an underscore is a word character
    to the marker regex's boundary, so `__DONE__` never matches at all."""
    out = []
    for m in marker_re.finditer(text):
        head = text[:m.start()].rstrip()
        head = head.rstrip('*_').rstrip()
        at_start = (head == '' or head.endswith(('.', '!', '?', '--', ':')))
        if not at_start:
            continue
        s, e = sentence_span(text, m.start())
        if DATE_RE.search(text[s:e]):
            out.append(m)
    return out


def disposition(text):
    """'terminal', 'deferred' or None for a Learning block's joined text.
    The leading `- ` is tolerated. A block struck through whole is
    terminal: the entry has been retired in place."""
    body = text[2:] if text.startswith('- ') else text
    body = body.strip()
    if body.startswith('~~') and body.endswith('~~') and body.count('~~') == 2:
        return 'terminal'
    body = blank_strikes(body)
    if marker_counts(body, TERMINAL_RE):
        return 'terminal'
    if marker_counts(body, DEFERRED_RE):
        return 'deferred'
    return None


# --- structure fingerprint (asserted by every rewrite) --------------------

def fingerprint(lines):
    """The heading multiset and the checkbox (state, ID) sequence -- what a
    rewrite must leave identical or refuse to write."""
    headings = sorted(l for l in lines if ANY_HEADING_RE.match(l))
    boxes = [(m.group(1).lower(), m.group(2)) for l in lines for m in [CHECKBOX_ID_RE.match(l)] if m]
    return headings, boxes


# --- wrapping ------------------------------------------------------------

def wrap(text, width=70, indent='  ', first_indent=''):
    """Hard-wrap prose at roughly width columns, never splitting a token.
    Continuations take indent; the first line takes first_indent."""
    words = text.split()
    lines = []
    current = first_indent
    for w in words:
        if current.strip() == '':
            current = current + w
        elif len(current) + 1 + len(w) > width:
            lines.append(current)
            current = indent + w
        else:
            current = current + ' ' + w
    if current.strip():
        lines.append(current)
    return lines


# --- files and git -------------------------------------------------------

def find_workstreams(root):
    """[(abs_path, rel_path)] for every workstream.md under .state/."""
    pattern = os.path.join(root, '.state', 'workstreams', '*', '*', 'workstream.md')
    out = []
    for path in sorted(glob.glob(pattern)):
        out.append((path, os.path.relpath(path, root)))
    return out


def workstream_id(path):
    """type/name for a workstream.md path."""
    d = os.path.dirname(os.path.abspath(path))
    return os.path.basename(os.path.dirname(d)) + '/' + os.path.basename(d)


def read_lines(path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        return f.read().splitlines()


def state_files(root, repo=False):
    """Every .md file under .state/ (or, with repo, under the whole tree
    minus .git), walked by python, which follows no ignore file and skips
    no dot-directory -- the default of rg did, and returned a falsely
    clean sweep against a kit payload under .claude/."""
    base = root if repo else os.path.join(root, '.state')
    out = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(d for d in dirnames if d != '.git')
        for name in sorted(filenames):
            if name.endswith('.md'):
                out.append(os.path.join(dirpath, name))
    return out


def git(args, cwd, check=False):
    """(exit code, stdout) of a git command run in cwd; never raises on a
    non-zero exit unless check is set. stderr is discarded: the callers
    read the status and the output, since a helper's complaint on stderr
    beside a successful exit is a routine shape on macOS."""
    try:
        p = subprocess.run(['git'] + list(args), cwd=cwd, capture_output=True, text=True)
    except OSError as e:
        if check:
            raise
        return 127, str(e)
    if check and p.returncode != 0:
        raise RuntimeError('git %s failed: %s' % (' '.join(args), p.stderr.strip()))
    return p.returncode, p.stdout


def require_root(root, prog):
    """Resolve a project root and exit 2 when it has no .state/."""
    root = os.path.abspath(root)
    if not os.path.isdir(os.path.join(root, '.state')):
        sys.stderr.write("%s: no .state/ directory under %s\n" % (prog, root))
        sys.exit(2)
    return root
