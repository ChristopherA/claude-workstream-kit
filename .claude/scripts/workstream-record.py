#!/usr/bin/env python3
"""workstream-record.py -- the record, one field per command, as JSON.

Derives the eleven-field record (workstream-status SKILL.md, Move 2) for
every .state/workstreams/*/*/workstream.md under a project root, plus the
hold lines and cross-workstream references in .state/ACTIVE.md. Standard
library only. Prints one JSON object to stdout; exits 2 with a message on
stderr when the project root has no .state/ directory.

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
DELETION_OPEN_RE = re.compile(r'^ *- \[ \]')
DELETION_DONE_RE = re.compile(r'^ *- \[[xX]\]')
LEARNING_RE = re.compile(r'^- L[0-9]+')
DECISION_HEADING_RE = re.compile(r'^### D([0-9]+)\b')
# A phase heading is `### <Name> (<XX>)`; text after the code ("-- retired",
# "-- rollout residue") is tolerated, since real files carry it.
PHASE_HEADING_RE = re.compile(r'^###\s+(.+?)\s*\(([A-Za-z0-9]+)\)')
TOP_HEADING_RE = re.compile(r'^##\s')

SATISFIED_WORD_RE = re.compile(r'\bSATISFIED\b')
READY_WORD_RE = re.compile(r'\bREADY\b')

HOLD_RE = re.compile(
    r'\bheld\b|\bhold\b|blocked (by|on)|unblocks when|'
    r'\bwait(s|ing)? (for|on)\b|not before|sequenced after',
    re.IGNORECASE,
)

CROSS_REF_WS_RE = re.compile(r'\b(?:explore|feature|fix|project|maintain)/[a-z0-9-]+')
CROSS_REF_TAG_RE = re.compile(r'\bws/[a-z0-9-]+')

ID_RE = re.compile(
    r'#[A-Z]+-[0-9]+[a-z]?|\bD[0-9]+\b|\bL[0-9]+\b|\bOQ-[0-9]+\b'
)

DISPOSITION_WORDS = ('APPLIED', 'ROUTED', 'DROPPED', 'DISPOSITION')


# --- section extraction --------------------------------------------------

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

def hold_matches(line_no, text):
    out = []
    for m in HOLD_RE.finditer(text):
        start = max(0, m.start() - 100)
        end = min(len(text), m.end() + 100)
        out.append({"line": line_no, "match": m.group(0), "context": text[start:end]})
    return out


def cross_ref_matches(line_no, text):
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
            "line": line_no,
            "target": target,
            "kind": kind,
            "preceding_id": preceding_id,
        })
    return out


# --- per-workstream record ------------------------------------------------

def critical_path_field(lines):
    start = None
    for i, line in enumerate(lines):
        if line.startswith('**Critical path'):
            start = i
            break
    if start is None:
        return "not found", None
    para = []
    for i in range(start, len(lines)):
        line = lines[i]
        if line.strip() == '' and i != start:
            break
        para.append(line)
    joined = ' '.join(p.strip() for p in para if p.strip())
    return joined, start + 1


def build_workstream_record(path, rel_path):
    size_bytes = os.path.getsize(path)
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    lines = content.splitlines()

    purpose = purpose_fields(lines)

    # Phases: headings under ## Backlog only.
    backlog_section = extract_section(lines, r'^##\s+Backlog\s*$')
    phases = []
    for _line_no, text in backlog_section:
        m = PHASE_HEADING_RE.match(text)
        if m:
            phases.append({"name": m.group(1), "code": m.group(2)})

    total_open = sum(1 for line in lines if TOTAL_OPEN_RE.match(line))

    phase_records = []
    phase_sum = 0
    for phase in phases:
        code = phase["code"]
        task_re = re.compile(r'^ *- \[ \] #' + re.escape(code) + r'-')
        gate_re = re.compile(r'^ *- \[ \] #G-' + re.escape(code))
        open_tasks = sum(1 for line in lines if task_re.match(line))
        open_gates = sum(1 for line in lines if gate_re.match(line))
        phase_sum += open_tasks + open_gates
        phase_records.append({
            "name": phase["name"],
            "code": code,
            "open_tasks": open_tasks,
            "open_gates": open_gates,
        })

    tasks_outside_phases = total_open - phase_sum

    # First open task.
    first_open_task = None
    for i, line in enumerate(lines):
        if TOTAL_OPEN_RE.match(line):
            first_open_task = {"line": i + 1, "text": line}
            break

    # Open gates.
    open_gates_list = []
    for i, line in enumerate(lines):
        if GATE_LINE_RE.match(line):
            satisfied = bool(
                SATISFIED_WORD_RE.search(line)
                or READY_WORD_RE.search(line)
                or 'criterion is met' in line
            )
            open_gates_list.append({"line": i + 1, "text": line, "satisfied_text": satisfied})

    # Critical path.
    critical_path, cp_line = critical_path_field(lines)

    # Hold lines / cross refs: open task lines plus the critical-path
    # paragraph (joined), searched as one string each.
    sources = [(i + 1, line) for i, line in enumerate(lines) if TOTAL_OPEN_RE.match(line)]
    if critical_path != "not found":
        sources.append((cp_line, critical_path))

    hold_lines = []
    cross_refs = []
    for line_no, text in sources:
        hold_lines.extend(hold_matches(line_no, text))
        cross_refs.extend(cross_ref_matches(line_no, text))

    # Latest Decision.
    decision_nums = [int(m.group(1)) for line in lines for m in [DECISION_HEADING_RE.match(line)] if m]
    latest_decision = {
        "max": max(decision_nums) if decision_nums else None,
        "count": len(decision_nums),
    }

    # Learnings.
    learning_lines = [line for line in lines if LEARNING_RE.match(line)]
    undispositioned = [
        line for line in learning_lines
        if not any(word in line for word in DISPOSITION_WORDS)
    ]
    learnings = {"count": len(learning_lines), "undispositioned": undispositioned}

    # Deletion criteria.
    deletion_section = extract_section(lines, r'^##\s+Deletion Criteria\s*$')
    deletion_open = sum(1 for _n, text in deletion_section if DELETION_OPEN_RE.match(text))
    deletion_done = sum(1 for _n, text in deletion_section if DELETION_DONE_RE.match(text))

    return {
        "path": rel_path,
        "purpose": purpose,
        "phases": phase_records,
        "open_total": total_open,
        "tasks_outside_phases": tasks_outside_phases,
        "first_open_task": first_open_task,
        "open_gates": open_gates_list,
        "hold_lines": hold_lines,
        "cross_refs": cross_refs,
        "critical_path": critical_path,
        "latest_decision": latest_decision,
        "learnings": learnings,
        "deletion_criteria": {"open": deletion_open, "done": deletion_done},
        "size_bytes": size_bytes,
    }


def build_active_record(path, rel_path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    lines = content.splitlines()
    body = strip_frontmatter(lines)

    hold_lines = []
    cross_refs = []
    for line_no, text in body:
        hold_lines.extend(hold_matches(line_no, text))
        cross_refs.extend(cross_ref_matches(line_no, text))

    return {
        "path": rel_path,
        "hold_lines": hold_lines,
        "cross_refs": cross_refs,
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

    result = {"workstreams": workstreams, "active": active}
    print(json.dumps(result, indent=2))
    sys.exit(0)


if __name__ == '__main__':
    main()
