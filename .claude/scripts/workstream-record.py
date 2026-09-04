#!/usr/bin/env python3
"""workstream-record.py -- the record, one field per command, as JSON.

Derives the record (workstream-status SKILL.md, Move 2) for every
.state/workstreams/*/*/workstream.md under a project root, plus the hold
lines and cross-workstream references in .state/ACTIVE.md, and a per-field
corpus-coverage count. Standard library only. Prints one JSON object to
stdout; exits 2 with a message on stderr when the project root has no
.state/ directory.

The state-file format is two-shaped and this script reads both shapes:
backlog lines and deletion criteria are one line each, so their COUNTS
anchor at line start; every prose section is hard-wrapped at roughly 70
columns, so the prose-bearing fields (holds, cross references, gate
markers, Learning dispositions, the critical path) read a folded BLOCK --
a line plus its continuation lines -- never a single line. Reading a
wrapped construct one line at a time returns a false empty, which is
what six consumers reported at once.

Usage: workstream-record.py <project-root>
"""

import glob
import json
import os
import re
import sys

# --- patterns -----------------------------------------------------------

TOTAL_OPEN_RE = re.compile(r'^ *- \[ \] #')
GATE_LINE_RE = re.compile(r'^ *- \[ \] #G-')
CHECKBOX_RE = re.compile(r'^ *- \[[ xX]\] ')
DELETION_OPEN_RE = re.compile(r'^ *- \[ \]')
DELETION_DONE_RE = re.compile(r'^ *- \[[xX]\]')
LEARNING_RE = re.compile(r'^- L[0-9]+')
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

# Gate markers are the DATED forms the rule names. A bare word is a
# mention -- a build note quoting "the SATISFIED sentence" -- and a date is
# what turns a mention into a marking.
DATE = r'[0-9]{4}-[0-9]{2}-[0-9]{2}'
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

ID_RE = re.compile(
    r'#[A-Z]+-[0-9]+[a-z]?|\bD[0-9]+\b|\bL[0-9]+\b|\bOQ-[0-9]+\b'
)

# Disposition markers, as the rule publishes them (Learnings convention).
# TERMINAL: the insight has left the file. DEFERRED: it is tracked work
# that has not landed. Anything else is undispositioned.
TERMINAL_MARKERS = (
    'APPLIED', 'ROUTED', 'DROPPED', 'EXTRACTED', 'SENT', 'HANDED OFF',
    'RESOLVED', 'FULFILLED', 'VERIFIED', 'EXTENDED', 'SUPERSEDED',
    'DISPOSITIONED', 'DISPOSITION', 'DONE',
)
DEFERRED_MARKERS = ('QUEUED', 'DEFERRED', 'PENDING')
TERMINAL_RE = re.compile(r'\b(?:' + '|'.join(re.escape(m) for m in TERMINAL_MARKERS) + r')\b')
DEFERRED_RE = re.compile(r'\b(?:' + '|'.join(re.escape(m) for m in DEFERRED_MARKERS) + r')\b')


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


# --- sentence splitting for Purpose --------------------------------------

def split_sentences(text):
    text = text.strip()
    if not text:
        return []
    return [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if s.strip()]


def purpose_fields(lines):
    section = extract_section(lines, r'^##\s+Purpose\s*$')
    joined = ' '.join(text.strip() for _, text in section if text.strip())
    sentences = split_sentences(joined)
    if not sentences:
        return {"first": "", "done": ""}
    first = sentences[0]
    done = next((s for s in sentences if 'Done means' in s), sentences[-1])
    return {"first": first, "done": done}


# --- hold lines and cross refs (shared by workstream and ACTIVE.md) -----

def negated(text, start):
    """True when the clause the match sits in carries a negation word
    before it. The clause runs back to the previous `.`, `;` or `:`."""
    head = text[:start]
    parts = CLAUSE_SPLIT_RE.split(head)
    return bool(NEGATION_RE.search(parts[-1])) if parts else False


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


# --- per-workstream record ------------------------------------------------

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
    mismatch, provenance rather than arithmetic."""
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
                       "codes": codes, "open_tasks": 0, "open_gates": 0}
            phases.append(current)
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
                "open_tasks": p["open_tasks"], "open_gates": p["open_gates"]}
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


def build_workstream_record(path, rel_path):
    size_bytes = os.path.getsize(path)
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    lines = content.splitlines()
    blocks = fold_blocks(lines)

    purpose = purpose_fields(lines)

    phases, tasks_outside_phases, code_mismatches, codes_without_heading = phase_records(lines)
    total_open = sum(1 for line in lines if TOTAL_OPEN_RE.match(line))

    # First open task.
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

    # Critical path.
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

    # Latest Decision.
    decision_nums = [int(m.group(1)) for line in lines for m in [DECISION_HEADING_RE.match(line)] if m]
    latest_decision = {
        "max": max(decision_nums) if decision_nums else None,
        "count": len(decision_nums),
    }

    # Learnings, block-scoped: a disposition marker on a wrapped
    # continuation counts. Terminal and deferred are reported apart.
    terminal = 0
    deferred = []
    undispositioned = []
    learning_count = 0
    for start, kind, text, raw in blocks:
        if kind == 'item' and LEARNING_RE.match(raw[0]):
            learning_count += 1
            if TERMINAL_RE.search(text):
                terminal += 1
            elif DEFERRED_RE.search(text):
                deferred.append(text)
            else:
                undispositioned.append(text)
    learnings = {
        "count": learning_count,
        "terminal": terminal,
        "deferred": deferred,
        "undispositioned": undispositioned,
    }

    # Deletion criteria.
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


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: workstream-record.py <project-root>\n")
        sys.exit(2)

    root = os.path.abspath(sys.argv[1])
    state_dir = os.path.join(root, '.state')
    if not os.path.isdir(state_dir):
        sys.stderr.write("workstream-record.py: no .state/ directory under %s\n" % root)
        sys.exit(2)

    pattern = os.path.join(state_dir, 'workstreams', '*', '*', 'workstream.md')
    workstreams = []
    for path in glob.glob(pattern):
        rel_path = os.path.relpath(path, root)
        workstreams.append(build_workstream_record(path, rel_path))
    workstreams.sort(key=lambda r: r["path"])

    active_path = os.path.join(state_dir, 'ACTIVE.md')
    active = None
    if os.path.isfile(active_path):
        active = build_active_record(active_path, os.path.relpath(active_path, root))

    result = {
        "workstreams": workstreams,
        "active": active,
        "coverage": coverage(workstreams),
    }
    print(json.dumps(result, indent=2))
    sys.exit(0)


if __name__ == '__main__':
    main()
