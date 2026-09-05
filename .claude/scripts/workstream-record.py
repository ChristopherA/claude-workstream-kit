#!/usr/bin/env python3
"""workstream-record.py -- the kit's measures, one sub-command each.

Every sub-command reads state files, git, or the environment and prints
what it found. None writes a file, and none scores the session or
infers a judgment the caller names and the user decides -- which
Decisions shipped, whether a criterion holds, whether a gate is ready.
The rewrites live in workstream-rewrite.py, so a read-only skill runs a
tool that cannot write. Standard library only.

Usage:
  workstream-record.py record <project-root>
  workstream-record.py <project-root>            (alias of record)
  workstream-record.py cites <project-root> <needle> [<needle>...]
                             [--repo] [--section <name>]
  workstream-record.py refs <project-root>

The bare form is kept because the status and extract skills, the record
suite and consumers' scripts call it. Every sub-command takes its path
explicitly, never a default of the current directory. Exit codes: 0
success, 1 a failed check (self-check), 2 usage or a root with no
.state/ directory. Prints JSON to stdout.

`record` derives the record (workstream-status SKILL.md, Move 2) for
every .state/workstreams/*/*/workstream.md under the root, plus the hold
lines and cross-workstream references in .state/ACTIVE.md, and a
per-field corpus-coverage count.

`cites` is the citation sweep four skills prescribe and none gave a
command for: every block under .state/ (the whole tree minus .git with
--repo) that carries a needle, folded so a multi-word needle straddling
a wrap still matches, each hit with its file, line, section, the
Backlog ID whose block it sits in, whether it is inside a strike, and
the hold verb preceding it in the sentence. A needle shaped like an ID
matches on word boundaries only, so #BD-1 does not match #BD-10.

`refs` is the cited-ID resolution the review skill specifies in prose:
every task, gate, D, L and OQ reference in LIVE content -- open backlog
blocks, the critical path, unresolved Open Questions, open and standing
criteria, ACTIVE.md -- classified as defined here, homed and resolved,
homed with the home missing, homed with the home lacking it, or
unhomed. A home is `in type/name` or `in ws/<tag>` beside the ID; a tag
home is read with `git show`. Placeholders with no digit (#XX-N) and
the literal #G-XX are skipped. Classes with their lines, never a count.
"""

import json
import os
import re
import sys

sys.dont_write_bytecode = True  # the scripts dir is a payload install.sh copies whole
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from workstream_state import (  # noqa: E402
    ANY_HEADING_RE, CHECKBOX_ID_RE, CHECKBOX_RE, CROSS_REF_TAG_RE, CROSS_REF_WS_RE,
    DECISION_HEADING_RE, DELETION_DONE_RE, DELETION_OPEN_RE, DONE_GATE_RE, DONE_LINE_RE,
    GATE_LINE_RE, HOLDS_RE, HOLD_RE, ID_RE, LEARNING_RE, LIST_ITEM_RE, PHASE_HEADING_RE,
    SATISFIED_MARK_RE, TASK_CODE_RE, TOP_HEADING_RE, TOTAL_OPEN_RE,
    blank_strikes, disposition, extract_section, find_workstreams, fold_blocks, in_strike,
    git, join_block, line_at, negated, read_lines, require_root, section_of, sentence_span,
    split_sentences, state_files, strip_frontmatter,
)

PROG = 'workstream-record.py'


def usage(msg=None):
    if msg:
        sys.stderr.write("%s: %s\n" % (PROG, msg))
    sys.stderr.write(__doc__)
    sys.exit(2)


# --- record: the per-workstream fields -----------------------------------

def purpose_fields(lines):
    section = extract_section(lines, r'^##\s+Purpose\s*$')
    joined = ' '.join(text.strip() for _, text in section if text.strip())
    sentences = split_sentences(joined)
    if not sentences:
        return {"first": "", "done": ""}
    first = sentences[0]
    done = next((s for s in sentences if 'Done means' in s), sentences[-1])
    return {"first": first, "done": done}


def hold_matches(start_no, raw):
    text, starts = join_block(raw, start_no)
    blanked = blank_strikes(text)
    out = []
    for m in HOLD_RE.finditer(blanked):
        if negated(blanked, m.start()):
            continue
        start = max(0, m.start() - 100)
        end = min(len(text), m.end() + 100)
        out.append({"line": line_at(starts, m.start()), "match": m.group(0), "context": text[start:end]})
    return out


def cross_ref_matches(start_no, raw):
    text, starts = join_block(raw, start_no)
    text = blank_strikes(text)
    found = []
    for m in CROSS_REF_WS_RE.finditer(text):
        found.append((m.start(), m.end(), "workstream", m.group(0)))
    for m in CROSS_REF_TAG_RE.finditer(text):
        found.append((m.start(), m.end(), "tag", m.group(0)))
    found.sort(key=lambda t: t[0])

    ids = list(ID_RE.finditer(text))

    out = []
    for start, _end, kind, target in found:
        preceding_id = None
        best_start = -1
        for idm in ids:
            if idm.end() <= start and idm.start() > best_start:
                best_start = idm.start()
                preceding_id = idm.group(0)
        out.append({
            "line": line_at(starts, start),
            "target": target,
            "kind": kind,
            "preceding_id": preceding_id,
        })
    return out


def critical_path_field(blocks):
    """The critical-path paragraph: the block beginning `**Critical path`,
    or the first paragraph under a heading naming the critical path.
    Returns (joined_text, start_line_no, raw_lines) or ("not found", None, [])."""
    for start, kind, text, raw in blocks:
        if kind != 'heading' and text.startswith('**Critical path'):
            return text, start, raw
    heading_re = re.compile(r'^#{2,6}\s+Critical path\b', re.IGNORECASE)
    for idx, (start, kind, text, _raw) in enumerate(blocks):
        if kind == 'heading' and heading_re.match(text):
            for nstart, nkind, ntext, nraw in blocks[idx + 1:]:
                if nkind == 'heading':
                    break
                return ntext, nstart, nraw
            break
    return "not found", None, []


def phase_records(lines):
    """Phases under ## Backlog, POSITION-KEYED: a task belongs to the
    heading it sits under, so the per-heading sum plus the outside count
    equals the total by construction and a negative is unrepresentable.
    A task whose code the heading does not declare is reported as a
    mismatch, provenance rather than arithmetic. Each phase carries its
    DONE counts beside the open ones, so a completed phase -- done above
    zero, nothing open -- is visible without a second scan."""
    backlog = extract_section(lines, r'^##\s+Backlog\s*$')
    phases = []
    current = None
    outside = 0
    mismatches = []
    declared_codes = set()
    task_codes = set()
    for line_no, text in backlog:
        m = PHASE_HEADING_RE.match(text)
        if m:
            codes = [c.strip() for c in m.group(2).split('/')]
            declared_codes.update(codes)
            current = {"name": m.group(1), "code": m.group(2),
                       "codes": codes, "open_tasks": 0, "open_gates": 0,
                       "done_tasks": 0, "done_gates": 0}
            phases.append(current)
            continue
        if DONE_LINE_RE.match(text):
            if current is not None:
                if DONE_GATE_RE.match(text):
                    current["done_gates"] += 1
                else:
                    current["done_tasks"] += 1
            continue
        if not TOTAL_OPEN_RE.match(text):
            continue
        is_gate = bool(GATE_LINE_RE.match(text))
        cm = TASK_CODE_RE.search(text)
        code = cm.group(1) if cm else None
        if code:
            task_codes.add(code)
        if current is None:
            outside += 1
            continue
        if is_gate:
            current["open_gates"] += 1
        else:
            current["open_tasks"] += 1
        if code and code not in current["codes"]:
            mismatches.append({"line": line_no, "code": code,
                               "heading": current["name"], "heading_code": current["code"]})
    records = [{"name": p["name"], "code": p["code"],
                "open_tasks": p["open_tasks"], "open_gates": p["open_gates"],
                "done_tasks": p["done_tasks"], "done_gates": p["done_gates"]}
               for p in phases]
    codes_without_heading = sorted(task_codes - declared_codes)
    return records, outside, mismatches, codes_without_heading


def continuation_counts(lines):
    """The conformance detector: continuation lines belonging to checkbox
    lines, open and done counted apart. The rule keeps backlog lines and
    deletion criteria on one line, so a continuation under an OPEN item
    is a wrap the line-anchored counts cannot see; under a done item it is
    usually a completion-note block. Column-0 and indented continuations
    both count -- the reflow wraps flush left."""
    open_cont = 0
    done_cont = 0
    state = None
    for line in lines:
        if line.strip() == '' or ANY_HEADING_RE.match(line) or LIST_ITEM_RE.match(line):
            if CHECKBOX_RE.match(line):
                state = 'open' if DELETION_OPEN_RE.match(line) else 'done'
            else:
                state = None
            continue
        if state == 'open':
            open_cont += 1
        elif state == 'done':
            done_cont += 1
    return open_cont, done_cont


def composition(lines):
    """Bytes per `## ` section, and bytes inside checkbox BLOCKS split
    done/open -- the extract skill's composition report, which decides
    whether an oversized file is a condensation backlog (mostly finished
    work) or live scope (mostly open work). A checkbox block runs from
    its line to the next blank line or heading, so a completion note
    scores as done. Byte counts include each line's newline. Hand-rolled
    three times in one day this came out three different ways, in the
    direction that decides what to do."""
    sections = {}
    current = '(before the first ## heading)'
    done = 0
    open_ = 0
    state = None
    for line in lines:
        n = len(line.encode('utf-8')) + 1
        if TOP_HEADING_RE.match(line):
            current = line.strip()
        sections[current] = sections.get(current, 0) + n
        if line.strip() == '' or ANY_HEADING_RE.match(line):
            state = None
        elif CHECKBOX_RE.match(line):
            state = 'open' if DELETION_OPEN_RE.match(line) else 'done'
        if state == 'done':
            done += n
        elif state == 'open':
            open_ += n
    ordered = sorted(sections.items(), key=lambda kv: -kv[1])
    return {
        "sections": [{"heading": h, "bytes": b} for h, b in ordered],
        "checkbox_bytes": {
            "done": done,
            "open": open_,
            "done_open_ratio": round(done / open_, 2) if open_ else None,
        },
    }


def learnings_field(lines, blocks):
    """Learnings, block-scoped and bounded to ## Learnings: a disposition
    marker on a wrapped continuation counts, and a list item beginning
    `- L` inside a Decision does not -- one scored as a 65th Learning in
    a section holding 64. A marker is told from a MENTION by the rule in
    workstream_state.disposition: sentence-start position plus a date in
    the sentence. Terminal and deferred are reported apart."""
    learnings_lines = {no for no, _t in extract_section(lines, r'^##\s+Learnings\s*$')}
    terminal = 0
    deferred = []
    undispositioned = []
    count = 0
    for start, kind, text, raw in blocks:
        if kind == 'item' and LEARNING_RE.match(raw[0]) and start in learnings_lines:
            count += 1
            d = disposition(text)
            if d == 'terminal':
                terminal += 1
            elif d == 'deferred':
                deferred.append(text)
            else:
                undispositioned.append(text)
    return {"count": count, "terminal": terminal, "deferred": deferred,
            "undispositioned": undispositioned}


def build_workstream_record(path, rel_path):
    size_bytes = os.path.getsize(path)
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    lines = content.splitlines()
    blocks = fold_blocks(lines)

    purpose = purpose_fields(lines)

    phases, tasks_outside_phases, code_mismatches, codes_without_heading = phase_records(lines)
    total_open = sum(1 for line in lines if TOTAL_OPEN_RE.match(line))

    first_open_task = None
    for i, line in enumerate(lines):
        if TOTAL_OPEN_RE.match(line):
            first_open_task = {"line": i + 1, "text": line}
            break

    # Open gates: the whole gate BLOCK is read for the dated marker, so a
    # marker on a wrapped continuation is seen and a bare mention is not.
    open_gates_list = []
    for start, kind, text, raw in blocks:
        if kind == 'item' and GATE_LINE_RE.match(raw[0]):
            open_gates_list.append({
                "line": start,
                "text": raw[0],
                "satisfied_text": bool(SATISFIED_MARK_RE.search(text)),
            })

    critical_path, cp_line, cp_raw = critical_path_field(blocks)

    # Hold lines / cross refs. Sources: every open task block and gate
    # block (folded), every phase heading under ## Backlog, and the
    # critical-path paragraph -- each searched as one string.
    sources = []
    for start, kind, text, raw in blocks:
        if kind == 'item' and TOTAL_OPEN_RE.match(raw[0]):
            sources.append((start, raw))
    for line_no, text in extract_section(lines, r'^##\s+Backlog\s*$'):
        if PHASE_HEADING_RE.match(text):
            sources.append((line_no, [text]))
    if critical_path != "not found":
        sources.append((cp_line, cp_raw))
    sources.sort(key=lambda s: s[0])

    hold_lines = []
    cross_refs = []
    for start_no, raw in sources:
        hold_lines.extend(hold_matches(start_no, raw))
        cross_refs.extend(cross_ref_matches(start_no, raw))

    # Latest Decision, bounded to ## Decisions: a `### D<n>` heading
    # elsewhere is a mention, not a decision.
    decision_nums = [int(m.group(1)) for _no, line in extract_section(lines, r'^##\s+Decisions\s*$')
                     for m in [DECISION_HEADING_RE.match(line)] if m]
    latest_decision = {
        "max": max(decision_nums) if decision_nums else None,
        "count": len(decision_nums),
    }

    learnings = learnings_field(lines, blocks)

    deletion_section = extract_section(lines, r'^##\s+Deletion Criteria\s*$')
    deletion_open = sum(1 for _n, text in deletion_section
                        if DELETION_OPEN_RE.match(text) and 'STANDING' not in text)
    deletion_done = sum(1 for _n, text in deletion_section if DELETION_DONE_RE.match(text))
    # STANDING criteria are health conditions, never unmet; the last HOLDS
    # date on each line is its latest re-check, and the oldest of those
    # is what a reader needs.
    standing_lines = [text for _n, text in deletion_section
                      if DELETION_OPEN_RE.match(text) and 'STANDING' in text]
    holds_dates = []
    never = 0
    for text in standing_lines:
        found = HOLDS_RE.findall(text)
        if found:
            holds_dates.append(found[-1])
        else:
            never += 1

    open_cont, done_cont = continuation_counts(lines)

    return {
        "path": rel_path,
        "purpose": purpose,
        "phases": phases,
        "open_total": total_open,
        "tasks_outside_phases": tasks_outside_phases,
        "codes_without_heading": codes_without_heading,
        "code_heading_mismatches": code_mismatches,
        "first_open_task": first_open_task,
        "open_gates": open_gates_list,
        "hold_lines": hold_lines,
        "cross_refs": cross_refs,
        "critical_path": critical_path,
        "latest_decision": latest_decision,
        "learnings": learnings,
        "deletion_criteria": {
            "open": deletion_open, "done": deletion_done,
            "standing": len(standing_lines),
            "standing_oldest_holds": min(holds_dates) if holds_dates else None,
            "standing_never_rechecked": never,
        },
        "wrapped_lines": {"open_items": open_cont, "done_items": done_cont},
        "size_bytes": size_bytes,
        "composition": composition(lines),
    }


def build_active_record(path, rel_path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    lines = content.splitlines()
    body = strip_frontmatter(lines)
    body_lines = [text for _no, text in body]
    offset = body[0][0] - 1 if body else 0

    hold_lines = []
    cross_refs = []
    for start, _kind, _text, raw in fold_blocks(body_lines):
        line_no = start + offset
        hold_lines.extend(hold_matches(line_no, raw))
        cross_refs.extend(cross_ref_matches(line_no, raw))

    return {
        "path": rel_path,
        "hold_lines": hold_lines,
        "cross_refs": cross_refs,
    }


def coverage(workstreams):
    """Files in which each field matched at least once. A field at zero
    across a corpus whose files visibly carry the construct is a
    calibration failure of the instrument, not a fact about the project;
    the consuming skill reads a zero here before reading the field."""
    def count(pred):
        return sum(1 for r in workstreams if pred(r))
    return {
        "files": len(workstreams),
        "phases": count(lambda r: bool(r["phases"])),
        "open_gates": count(lambda r: bool(r["open_gates"])),
        "gates_satisfied": count(lambda r: any(g["satisfied_text"] for g in r["open_gates"])),
        "hold_lines": count(lambda r: bool(r["hold_lines"])),
        "cross_refs": count(lambda r: bool(r["cross_refs"])),
        "critical_path": count(lambda r: r["critical_path"] != "not found"),
        "learnings": count(lambda r: r["learnings"]["count"] > 0),
        "learnings_dispositioned": count(
            lambda r: r["learnings"]["terminal"] > 0 or bool(r["learnings"]["deferred"])
        ),
    }


def build_record(root):
    workstreams = [build_workstream_record(p, rel) for p, rel in find_workstreams(root)]
    active_path = os.path.join(root, '.state', 'ACTIVE.md')
    active = None
    if os.path.isfile(active_path):
        active = build_active_record(active_path, os.path.relpath(active_path, root))
    return {"workstreams": workstreams, "active": active, "coverage": coverage(workstreams)}


def cmd_record(args):
    if len(args) != 1:
        usage("record takes exactly one project root")
    root = require_root(args[0], PROG)
    print(json.dumps(build_record(root), indent=2))
    return 0


# --- cites: the citation sweep ----------------------------------------------

def needle_regex(needle):
    """An ID-shaped needle matches on word boundaries only, so `#BD-1`
    does not hit `#BD-10` or `#BD-1a`; a prose needle matches across any
    whitespace, which is what a 70-column wrap turns a space into."""
    if re.fullmatch(r'#[A-Za-z]+-[0-9]+[a-z]?|#G-[A-Za-z0-9]+|D[0-9]+|L[0-9]+|OQ-[0-9]+', needle):
        return re.compile(r'(?<![\w-])' + re.escape(needle) + r'(?![\w-])')
    return re.compile(r'\s+'.join(re.escape(w) for w in needle.split()))


def hold_before(text, offset):
    """The last hold verb (with its object) in the sentence before
    offset, or None -- the direction hint close's inward sweep reads by
    hand: a block naming this ID as a BLOCKER loses its referent when the
    directory goes, one naming it as a source does not."""
    s, _e = sentence_span(text, offset)
    last = None
    for m in HOLD_RE.finditer(blank_strikes(text), s, offset):
        last = m.group(0)
    return last


def cites(root, needles, repo=False, section=None):
    regexes = [(n, needle_regex(n)) for n in needles]
    hits = []
    files = state_files(root, repo=repo)
    for path in files:
        lines = read_lines(path)
        sections = section_of(lines)
        rel = os.path.relpath(path, root)
        for start, kind, _text, raw in fold_blocks(lines):
            sec = sections[start - 1]
            if section is not None and (sec is None or sec[3:].strip() != section):
                continue
            text, starts = join_block(raw, start)
            owner = None
            m = CHECKBOX_ID_RE.match(raw[0])
            if m and sec == '## Backlog':
                owner = m.group(2)
            for needle, rx in regexes:
                for hm in rx.finditer(text):
                    hits.append({
                        "needle": needle,
                        "file": rel,
                        "line": line_at(starts, hm.start()),
                        "section": sec,
                        "owning_id": owner,
                        "struck": in_strike(text, hm.start()),
                        "hold_before": hold_before(text, hm.start()),
                        "context": text[max(0, hm.start() - 80):hm.end() + 80],
                    })
    return {"needles": needles, "files_scanned": len(files), "repo": repo,
            "section": section, "hits": hits}


def cmd_cites(args):
    repo = False
    section = None
    rest = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--repo':
            repo = True
        elif a == '--section':
            if i + 1 >= len(args):
                usage("--section needs a value")
            section = args[i + 1]
            i += 1
        elif a.startswith('--'):
            usage("unknown option %s" % a)
        else:
            rest.append(a)
        i += 1
    if len(rest) < 2:
        usage("cites takes a project root and at least one needle")
    root = require_root(rest[0], PROG)
    print(json.dumps(cites(root, rest[1:], repo=repo, section=section), indent=2))
    return 0


# --- refs: do cited IDs resolve where they say they live -------------------

REF_RE = re.compile(
    r'#[A-Z]+-[0-9]+[a-z]?(?![\w-])|#G-[A-Z]+[0-9]*(?![\w-])|'
    r'(?<![\w/-])D[0-9]+\b|(?<![\w/-])L[0-9]+\b|(?<![\w/-])OQ-[0-9]+\b'
)
PLACEHOLDER_GATE = '#G-XX'


def defines(lines, ref):
    """True when a line in lines DEFINES ref: a checkbox line carrying
    the ID with any word boundary after it (a completed task written
    `- [x] #XX-N (dated note)` is conforming, and a matcher demanding
    the colon scores every one of them undefined), a `### D<n>` heading,
    a `- L<n>` or `- OQ-n` item, struck or not."""
    esc = re.escape(ref)
    if ref.startswith('#'):
        rx = re.compile(r'^ *- \[[ xX]\] (?:~~)?' + esc + r'(?![\w-])')
    elif ref.startswith('D'):
        rx = re.compile(r'^### ' + esc + r'\b')
    else:
        rx = re.compile(r'^- (?:~~)?' + esc + r'\b')
    return any(rx.match(l) for l in lines)


def home_near(text, start, end):
    """The workstream or tag named beside the ID in the same sentence:
    the nearest one after it, else the nearest before it. This project's
    corpus writes the home after the ID far more often than before."""
    s, e = sentence_span(text, start)
    homes = [(m.start(), m.group(0), 'workstream') for m in CROSS_REF_WS_RE.finditer(text, s, e)]
    homes += [(m.start(), m.group(0), 'tag') for m in CROSS_REF_TAG_RE.finditer(text, s, e)]
    after = sorted((h for h in homes if h[0] >= end), key=lambda h: h[0])
    if after:
        return after[0][1], after[0][2]
    before = sorted((h for h in homes if h[0] < start), key=lambda h: -h[0])
    if before:
        return before[0][1], before[0][2]
    return None, None


def live_blocks(lines):
    """(start_no, raw) for every live block: open checkbox blocks in
    the Backlog, the critical-path paragraph, unresolved Open Questions,
    open and STANDING criteria. A completed task's note is out of scope:
    its bare IDs are frozen provenance."""
    blocks = fold_blocks(lines)
    sections = section_of(lines)
    out = []
    cp_text, cp_line, cp_raw = critical_path_field(blocks)
    for start, kind, text, raw in blocks:
        sec = sections[start - 1]
        if kind != 'item':
            continue
        if sec == '## Backlog' and TOTAL_OPEN_RE.match(raw[0]):
            out.append((start, raw))
        elif sec == '## Open Questions' and re.match(r'^- OQ-[0-9]+', raw[0]):
            out.append((start, raw))
        elif sec == '## Deletion Criteria' and DELETION_OPEN_RE.match(raw[0]):
            out.append((start, raw))
    if cp_line is not None:
        out.append((cp_line, cp_raw))
    out.sort(key=lambda b: b[0])
    return out


class TagReader:
    """Reads a workstream.md at an archive or rotation tag, both git
    reads, caching per tag."""

    def __init__(self, root):
        self.root = root
        self.cache = {}

    def lines_at(self, tag):
        if tag in self.cache:
            return self.cache[tag]
        rc, out = git(['tag', '-l', tag], self.root)
        if rc != 0 or out.strip() != tag:
            self.cache[tag] = 'missing'
            return 'missing'
        name = tag[len('ws/'):]
        name = re.sub(r'-[0-9]{4}-[0-9]{2}-[0-9]{2}$', '', name)
        rc, out = git(['ls-tree', '-r', '--name-only', tag, '--', '.state/workstreams'], self.root)
        path = None
        for p in out.splitlines():
            if p.endswith('/' + name + '/workstream.md'):
                path = p
                break
        if path is None:
            self.cache[tag] = None
            return None
        rc, out = git(['show', '%s:%s' % (tag, path)], self.root)
        self.cache[tag] = out.splitlines() if rc == 0 else None
        return self.cache[tag]


def refs(root):
    classes = {"defined_here": [], "homed_resolved": [], "homed_home_missing": [],
               "homed_home_lacks": [], "unhomed": []}
    tags = TagReader(root)
    file_lines = {}

    def lines_of(path):
        if path not in file_lines:
            file_lines[path] = read_lines(path) if os.path.isfile(path) else None
        return file_lines[path]

    sources = []
    for path, rel in find_workstreams(root):
        lines = lines_of(path)
        sources.append((path, rel, lines, live_blocks(lines)))
    active = os.path.join(root, '.state', 'ACTIVE.md')
    if os.path.isfile(active):
        body = strip_frontmatter(lines_of(active))
        body_lines = [t for _n, t in body]
        offset = body[0][0] - 1 if body else 0
        blocks = [(start + offset, raw) for start, _k, _t, raw in fold_blocks(body_lines)]
        sources.append((active, os.path.relpath(active, root), None, blocks))

    for path, rel, own_lines, blocks in sources:
        for start, raw in blocks:
            text, starts = join_block(raw, start)
            blanked = blank_strikes(text)
            for m in REF_RE.finditer(blanked):
                ref = m.group(0)
                if ref == PLACEHOLDER_GATE:
                    continue
                entry = {"file": rel, "line": line_at(starts, m.start()), "id": ref,
                         "home": None, "context": text[max(0, m.start() - 60):m.end() + 60]}
                if own_lines is not None and defines(own_lines, ref):
                    classes["defined_here"].append(entry)
                    continue
                home, kind = home_near(blanked, m.start(), m.end())
                if home is None:
                    classes["unhomed"].append(entry)
                    continue
                entry["home"] = home
                if kind == 'workstream':
                    hpath = os.path.join(root, '.state', 'workstreams', home, 'workstream.md')
                    hlines = lines_of(hpath)
                else:
                    hlines = tags.lines_at(home)
                    if hlines == 'missing':
                        hlines = None
                    elif hlines is None:
                        hlines = []
                if hlines is None:
                    classes["homed_home_missing"].append(entry)
                elif defines(hlines, ref):
                    classes["homed_resolved"].append(entry)
                else:
                    classes["homed_home_lacks"].append(entry)
    return {"classes": classes}


def cmd_refs(args):
    if len(args) != 1:
        usage("refs takes exactly one project root")
    root = require_root(args[0], PROG)
    print(json.dumps(refs(root), indent=2))
    return 0


# --- dispatch --------------------------------------------------------------

COMMANDS = {
    'record': cmd_record,
    'cites': cmd_cites,
    'refs': cmd_refs,
}


def main():
    argv = sys.argv[1:]
    if not argv:
        usage()
    if argv[0] in COMMANDS:
        sys.exit(COMMANDS[argv[0]](argv[1:]))
    if argv[0].startswith('-'):
        usage("unknown option %s" % argv[0])
    if len(argv) == 1:
        sys.exit(cmd_record(argv))
    usage("unknown sub-command %s" % argv[0])


if __name__ == '__main__':
    main()
