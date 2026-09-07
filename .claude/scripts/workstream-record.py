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
  workstream-record.py paths <project-root>
  workstream-record.py decay <project-root>
  workstream-record.py git <project-root> [--remote <name|name/branch>] [--tags]
  workstream-record.py fires <project-root> [<type/name>] [--json]
                             [--interval-days <n>]
  workstream-record.py bare-ids <project-root> [--text]
  workstream-record.py bare-ids --stdin [--text]
  workstream-record.py self-check

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
home is read with `git show`. A home is named once per block: a bare
mention AFTER a homed one in the same block inherits its class and
home (`homed_by_line` says which). Placeholders with no digit (#XX-N)
and the literal #G-XX are skipped. Classes with their lines, never a
count.

`paths` is the review skill's cheapest staleness probe: every
path-like token in Decisions and open task blocks -- a token with a `/`
or a known extension, code spans included, URLs and workstream or tag
references excluded -- with whether it exists relative to the root, else
relative to the kit checkout (WORKSTREAM_KIT_DIR in the environment or in
the project's settings.json env, where install.sh records it), or, for a
`~` path, the home directory, and whether it sits in a strike. Each entry
says where it resolved (`resolved_in`: project, kit, absolute or null); a
path found only in the kit is also listed under `kit`, since a task in a
kit-using project routinely names the kit's own files. A BARE name
(`CLAUDE.md`, `rules/`: one segment, unanchored) could sit anywhere and
is listed apart under `bare`, never as missing, with `exists` null
rather than false; `missing` holds the anchored, unstruck tokens that
resolve nowhere and is the verdict to read -- a row's `exists` alone is
not.

`decay` is the status skill's critical-path decay compare: for each
workstream, its open task count and, where a critical-path paragraph
exists, the newest commit timestamp among the paragraph's lines (git
blame) against each open task's mint timestamp (the first commit whose
diff adds its `#XX-N:`), reporting every task minted after the
paragraph. Timestamps, never dates, so a task minted the same day but
hours after the paragraph is reported. A paragraph naming no task ID
(gates aside) is `shape: queue`: it states order, a task minted after
it is what it predicts, and only the count (`minted_since`) is
reported, with no task list to review. A workstream.md with
uncommitted changes is unmeasurable, not current.

`git` is the status skill's three git reads -- last-commit date per
state file, commits ahead of the upstream or the named remote branch,
uncommitted state under .state/ -- and, with --tags, the closure reads:
for every ws/* tag whether its commit is contained in a remote branch,
how many commits the tag would carry that the remote branch lacks, and
whether the tag ref is on the remote. The remote listing is the one
network call, taken only under --tags.

`fires` is the extract skill's firing symptoms as one verdict per
workstream, each symptom named: undispositioned Learnings, a completed
phase, an open task line outside ## Backlog (appended after the
section ended, which the roster counts and no phase count sees), a
sentence severed inside a wrapped block (a continuation opening
lowercase under a line ending in a full stop -- an insertion landed
mid-sentence, and every count still passes), size past the hook's
threshold, a notes.md beside the file, a file in the directory the kit
does not know, a STANDING criterion never re-checked or last
re-checked longer ago than the interval (30 days unless
--interval-days says otherwise). A paused workstream is
still measured: the exposed case is the one nobody reads. Prints one
text line per workstream for the session-start hook, JSON with --json.
It says what fires, never who should run the drain.

`bare-ids` is the rule's gloss convention as a check: every task, gate,
Decision, Learning or Open Question ID mentioned in live prose owes a
few words saying what it is, in the canonical form `#EX-37 (the phase
split question)` or `#EX-37 "the phase split question"`, a home allowed
between (`#EX-30 in project/tier (the neutrality sort)`), at the ID's
first mention in each paragraph. Over a project root it reads
ACTIVE.md's body and, for every workstream, the Purpose, the critical
path, open task blocks, unresolved Open Questions and open or STANDING
criteria -- the live content the rule's adoption pass names; completed
notes and Decisions are frozen provenance and are not read. With
--stdin it reads a draft (a status statement, a message) instead, so a
skill can check its own text before delivery. Exempt everywhere: the
line that defines the ID, code spans and fenced blocks, struck spans.
Lists every bare mention with file, line and context; --text prints one
summary line per file that has any, nothing when none has.

`self-check` fires every pattern the record uses at built-in
known-positive and known-negative strings and exits 1 on any miss,
naming the pattern and the string. The status skill runs it before
trusting any zero it is about to report.
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
    split_sentences, state_files, strip_frontmatter, workstream_id, SIZE_BYTES,
    CROSS_REF_WS_RE as _WS_RE, TASK_ID_RE,
    bare_ids, blank_fences, purpose_paragraphs_for_gloss,
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


def open_outside_backlog_field(lines):
    """Every open checkbox line (task or gate) whose section is not
    ## Backlog, with its line and ID -- a task the counts cannot see.
    The Deletion Criteria section is exempt: a criterion is a checkbox
    outside the Backlog by design, and one that OPENS with a task ID
    (`- [ ] #EX-30 in project/x names ...`) is a criterion about that
    task, not the task -- a fresh workstream's criteria fired this
    symptom within the hour of the check shipping."""
    sections = section_of(lines)
    out = []
    for i, line in enumerate(lines):
        if not TOTAL_OPEN_RE.match(line):
            continue
        if sections[i] in ('## Backlog', '## Deletion Criteria'):
            continue
        m = CHECKBOX_ID_RE.match(line)
        out.append({"line": i + 1, "id": m.group(2) if m else None,
                    "section": sections[i]})
    return out


def build_workstream_record(path, rel_path):
    size_bytes = os.path.getsize(path)
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    lines = content.splitlines()
    blocks = fold_blocks(lines)

    purpose = purpose_fields(lines)

    phases, tasks_outside_phases, code_mismatches, codes_without_heading = phase_records(lines)
    total_open = sum(1 for line in lines if TOTAL_OPEN_RE.match(line))
    # An open task line OUTSIDE ## Backlog -- appended after the section
    # ended, under Decisions or below -- is counted by the hook's roster
    # (which anchors on the line) and by nothing position-keyed: the
    # phases sum fell one short of the roster with no field naming why.
    open_outside_backlog = open_outside_backlog_field(lines)

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
    # Criteria are read as BLOCKS, the rule's discipline for anything that
    # reads a marker or a hold: the rule keeps each criterion on one line,
    # but a file that breaks the exemption must mis-score nothing -- a
    # consumer's two STANDING criteria with five HOLDS cycles each on
    # continuation lines read as `standing: 0, open: 2` for months, a
    # quiet wrong answer. `wrapped` counts the continuation lines so the
    # breach is visible beside the fields it would have degraded.
    crit_blocks = [(text, raw) for _s, kind, text, raw
                   in fold_blocks([t for _n, t in deletion_section]) if kind == 'item']
    deletion_open = sum(1 for text, _r in crit_blocks
                        if DELETION_OPEN_RE.match(text) and 'STANDING' not in text)
    deletion_done = sum(1 for text, _r in crit_blocks if DELETION_DONE_RE.match(text))
    wrapped_criteria = sum(len(raw) - 1 for text, raw in crit_blocks
                           if DELETION_OPEN_RE.match(text) or DELETION_DONE_RE.match(text))
    # STANDING criteria are health conditions, never unmet; the last HOLDS
    # date in each block is its latest re-check, and the oldest of those
    # is what a reader needs.
    standing_lines = [text for text, _r in crit_blocks
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
        "open_outside_backlog": open_outside_backlog,
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
            "wrapped": wrapped_criteria,
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


def _possessive(text, end):
    """True when the name ending at `end` is followed by 's (a closing
    backtick in between is allowed: `project/x`'s)."""
    rest = text[end:end + 3]
    if rest.startswith('`'):
        rest = rest[1:]
    return rest.startswith("'s")


def homes_near(text, start, end):
    """Every workstream or tag named in the ID's sentence, nearest first:
    those after the ID by distance, then those before. This project's
    corpus writes the home after the ID far more often than before, and
    a sentence naming two homes ("#EX-3 lives in project/a ... read as
    #SW-5 in project/b") homes each ID at the wrong one if only the
    nearest is tried, so the caller resolves against each in turn."""
    s, e = sentence_span(text, start)
    # A name followed by an apostrophe-s ("project/x's row") is a
    # possessive, not a home: a bare second mention of an ID whose
    # sentence named only such a possessive was reported home-lacking
    # at the possessive while the block's first mention had resolved.
    homes = [(m.start(), m.group(0), 'workstream') for m in CROSS_REF_WS_RE.finditer(text, s, e)
             if not _possessive(text, m.end())]
    homes += [(m.start(), m.group(0), 'tag') for m in CROSS_REF_TAG_RE.finditer(text, s, e)
              if not _possessive(text, m.end())]
    after = sorted((h for h in homes if h[0] >= end), key=lambda h: h[0])
    before = sorted((h for h in homes if h[0] < start), key=lambda h: -h[0])
    out = []
    for _pos, name, kind in after + before:
        if (name, kind) not in out:
            out.append((name, kind))
    return out


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
            # The rule names a home once per readable unit, and a block
            # is the unit: a homed mention covers every LATER bare
            # mention of the same ID in the block, which inherits its
            # class and home (an earlier bare mention stays unhomed).
            homed_in_block = {}
            for m in REF_RE.finditer(blanked):
                ref = m.group(0)
                if ref == PLACEHOLDER_GATE:
                    continue
                entry = {"file": rel, "line": line_at(starts, m.start()), "id": ref,
                         "home": None, "context": text[max(0, m.start() - 60):m.end() + 60]}
                if own_lines is not None and defines(own_lines, ref):
                    classes["defined_here"].append(entry)
                    continue
                candidates = homes_near(blanked, m.start(), m.end())
                if not candidates:
                    if ref in homed_in_block:
                        cls, home, at = homed_in_block[ref]
                        entry["home"] = home
                        entry["homed_by_line"] = at
                        classes[cls].append(entry)
                    else:
                        classes["unhomed"].append(entry)
                    continue
                # Resolve against each home the sentence names, nearest
                # first; the one that defines the ID wins. When none does,
                # the nearest is reported as before, and every candidate
                # is listed so the reader sees what was tried.
                verdict = None
                for home, kind in candidates:
                    if kind == 'workstream':
                        hpath = os.path.join(root, '.state', 'workstreams', home, 'workstream.md')
                        hlines = lines_of(hpath)
                    else:
                        hlines = tags.lines_at(home)
                        if hlines == 'missing':
                            hlines = None
                        elif hlines is None:
                            hlines = []
                    if hlines is not None and defines(hlines, ref):
                        verdict = ("homed_resolved", home)
                        break
                    if verdict is None:
                        verdict = ("homed_home_missing" if hlines is None else "homed_home_lacks", home)
                cls, home = verdict
                entry["home"] = home
                if len(candidates) > 1:
                    entry["candidates"] = [h for h, _k in candidates]
                classes[cls].append(entry)
                if ref not in homed_in_block:
                    homed_in_block[ref] = (cls, home, entry["line"])
    return {"classes": classes}


def cmd_refs(args):
    if len(args) != 1:
        usage("refs takes exactly one project root")
    root = require_root(args[0], PROG)
    print(json.dumps(refs(root), indent=2))
    return 0


# --- paths: do the paths a Decision or open task names still exist ----------

PATH_TOKEN_RE = re.compile(r'`[^`]+`|[^\s`()\[\],;"\'<>]+')
KNOWN_EXT = ('.md', '.py', '.sh', '.json', '.txt', '.yaml', '.yml', '.toml',
             '.c', '.h', '.js', '.ts', '.html', '.css', '.csv', '.gitignore')
URL_RE = re.compile(r'^[a-z]+://|^[\w.-]+@[\w.-]+:')
# A word pair like and/or, read/write or D1/D2: neither side a path
# segment (no dot, dash, underscore or digit) or both sides IDs.
WORD_PAIR_RE = re.compile(r'^[A-Za-z]+(?:/[A-Za-z]+)+$|^[0-9./]+$')
ID_PAIR_RE = re.compile(r'^(?:#?[A-Z]+-?[0-9]+[a-z]?|D[0-9]+|L[0-9]+)(?:/(?:#?[A-Z]+-?[0-9]+[a-z]?|D[0-9]+|L[0-9]+))+$')


def path_tokens(text):
    """(offset, token) for every path-like token in text."""
    out = []
    for m in PATH_TOKEN_RE.finditer(text):
        raw = m.group(0)
        # A code span holding whitespace is a command; its words are
        # tokens in their own right (`git show ws/x:docs/a.md`).
        for tok in raw.strip('`').split():
            tok = tok.rstrip('.,;:')
            if tok.endswith('~~'):
                tok = tok[:-2]
            if tok.startswith('~~'):
                tok = tok[2:]
            if not tok or URL_RE.match(tok):
                continue
            # A `rev:path` token (a tag, a commit) names the path after
            # the colon; a `file:line` citation keeps its file.
            if ':' in tok and not re.search(r':[0-9]+(?:-[0-9]+)?$', tok):
                tok = tok.split(':', 1)[1]
            if _path_token(tok):
                out.append((m.start(), tok))
    return out


def _path_token(tok):
    if True:
        if CROSS_REF_WS_RE.fullmatch(tok) or CROSS_REF_TAG_RE.fullmatch(tok):
            return False
        looks = '/' in tok or tok.endswith(KNOWN_EXT)
        if not looks:
            return False
        if WORD_PAIR_RE.match(tok) or ID_PAIR_RE.match(tok):
            return False
        if tok.startswith('#') or tok.startswith('--') or any(c in tok for c in '*<>{}$'):
            return False  # a glob, a metavariable, an expansion
        if re.match(r'^/[A-Za-z-]+$', tok):  # a slash command, /workstream-status
            return False
        return True


def anchored(tok):
    """A token that names a place: absolute, home-relative, dot-relative,
    or two or more segments. A bare `CLAUDE.md` or `rules/` names a
    file that could sit anywhere."""
    if tok.startswith(('/', '~', '.')):
        return True
    parts = [p for p in tok.split('/') if p]
    return len(parts) >= 2


def kit_dir(root):
    """The kit checkout a project installed from: WORKSTREAM_KIT_DIR in
    the environment, else the same key in the project's settings.json
    env, which install.sh writes. None when neither names a directory."""
    cand = os.environ.get('WORKSTREAM_KIT_DIR')
    if not cand:
        try:
            with open(os.path.join(root, '.claude', 'settings.json')) as fh:
                cand = (json.load(fh).get('env') or {}).get('WORKSTREAM_KIT_DIR')
        except (OSError, ValueError, AttributeError):
            cand = None
    if cand and os.path.isdir(cand):
        return cand
    return None


def path_resolves(root, tok, kit):
    """Where the token resolves: 'absolute' for a `/` or `~` path that
    exists, 'project' under the root, 'kit' under the kit checkout when
    the root lacks it, None when nowhere. A relative path in a task that
    names a kit file (`tests/x.sh`, `install.sh`) was reported missing
    from the project while it existed in the checkout the project
    installed from -- ten of eleven rows on one review."""
    tok = re.sub(r':[0-9]+(?:-[0-9]+)?$', '', tok)  # a `file:line` citation
    if tok.startswith('~'):
        return 'absolute' if os.path.exists(os.path.expanduser(tok)) else None
    if tok.startswith('/'):
        return 'absolute' if os.path.exists(tok) else None
    if os.path.exists(os.path.join(root, tok)):
        return 'project'
    if kit and os.path.exists(os.path.join(kit, tok)):
        return 'kit'
    return None


def paths(root):
    entries = []
    kit = kit_dir(root)
    for path, rel in find_workstreams(root):
        lines = read_lines(path)
        sections = section_of(lines)
        for start, kind, _text, raw in fold_blocks(lines):
            sec = sections[start - 1]
            if kind == 'heading':
                continue
            live = (sec == '## Decisions') or (sec == '## Backlog' and kind == 'item'
                                                and TOTAL_OPEN_RE.match(raw[0]))
            if not live:
                continue
            text, starts = join_block(raw, start)
            owner = None
            m = CHECKBOX_ID_RE.match(raw[0])
            if m:
                owner = m.group(2)
            for off, tok in path_tokens(text):
                where = path_resolves(root, tok, kit)
                is_anchored = anchored(tok)
                # A bare name resolves nowhere by construction; `false`
                # on its row read as rot beside anchored rows that
                # resolved (14 of 39 rows on one review), so it is null.
                exists = (where is not None) if (is_anchored or where is not None) else None
                entries.append({
                    "file": rel, "line": line_at(starts, off), "section": sec,
                    "owning_id": owner, "path": tok, "anchored": is_anchored,
                    "exists": exists, "resolved_in": where,
                    "struck": in_strike(text, off),
                })
    return {"paths": entries,
            "missing": [e for e in entries if e["anchored"] and not e["exists"] and not e["struck"]],
            "kit": [e for e in entries if e["resolved_in"] == 'kit'],
            "bare": [e for e in entries if not e["anchored"]]}


def cmd_paths(args):
    if len(args) != 1:
        usage("paths takes exactly one project root")
    root = require_root(args[0], PROG)
    print(json.dumps(paths(root), indent=2))
    return 0


# --- decay: is the critical path older than the tasks it should order -------

def blame_newest(root, rel, start, count):
    """The newest committer timestamp among lines start..start+count-1
    of rel at HEAD, by git blame in porcelain form; None when the file
    is not tracked."""
    rc, out = git(['blame', '-p', '-L', '%d,%d' % (start, start + count - 1), 'HEAD', '--', rel], root)
    if rc != 0:
        return None
    newest = None
    for line in out.splitlines():
        if line.startswith('committer-time '):
            t = int(line.split()[1])
            newest = t if newest is None or t > newest else newest
    return newest


def mint_time(root, rel, task_id):
    """The first commit whose diff adds `#XX-N:`; rewording the line
    later does not move it, since -S counts occurrences."""
    rc, out = git(['log', '--reverse', '--format=%ct', '-S', task_id + ':', '--', rel], root)
    if rc != 0:
        return None
    first = out.split()
    return int(first[0]) if first else None


def decay(root):
    result = []
    for path, rel in find_workstreams(root):
        lines = read_lines(path)
        blocks = fold_blocks(lines)
        cp_text, cp_line, cp_raw = critical_path_field(blocks)
        entry = {"path": rel, "critical_path": None, "unmeasurable": None,
                 "shape": None, "minted_since": 0, "minted_after": [], "open_tasks": 0}
        # The open count is a fact about the file, reported whether or
        # not a paragraph exists to compare against: a file with seven
        # open tasks and no paragraph once read as open_tasks 0.
        open_ids = []
        for line in lines:
            if not TOTAL_OPEN_RE.match(line) or GATE_LINE_RE.match(line):
                continue
            m = CHECKBOX_ID_RE.match(line)
            if m:
                open_ids.append(m.group(2))
        entry["open_tasks"] = len(open_ids)
        if cp_line is None:
            entry["critical_path"] = "not found"
            result.append(entry)
            continue
        rc, status = git(['status', '--porcelain', '--', rel], root)
        if rc != 0:
            entry["unmeasurable"] = "not a git repository"
            result.append(entry)
            continue
        if status.strip():
            entry["unmeasurable"] = "uncommitted changes in %s" % rel
            result.append(entry)
            continue
        newest = blame_newest(root, rel, cp_line, len(cp_raw))
        if newest is None:
            entry["unmeasurable"] = "%s is not tracked" % rel
            result.append(entry)
            continue
        entry["critical_path"] = {"line": cp_line, "lines": len(cp_raw), "newest_commit_time": newest}
        # A paragraph naming no task (gates aside) states ORDER, not a
        # plan -- "queue -> gate -> build -> release" -- and a task minted
        # after it is what it predicts, not drift. Such a path is
        # reported queue-shaped with the count minted since and no
        # task list, so the reader has nothing to route to a review.
        named = [m.group(0) for m in TASK_ID_RE.finditer(blank_strikes(cp_text))
                 if not m.group(0).startswith('#G-')]
        entry["shape"] = "named" if named else "queue"
        for oid in open_ids:
            minted = mint_time(root, rel, oid)
            if minted is not None and minted > newest:
                entry["minted_since"] += 1
                if named:
                    entry["minted_after"].append({"id": oid, "mint_time": minted,
                                                  "after_by_seconds": minted - newest})
        result.append(entry)
    return {"workstreams": result}


def cmd_decay(args):
    if len(args) != 1:
        usage("decay takes exactly one project root")
    root = require_root(args[0], PROG)
    print(json.dumps(decay(root), indent=2))
    return 0


# --- git: the status and closure reads ---------------------------------------

def git_reads(root, remote=None, tags=False):
    rc, top = git(['rev-parse', '--show-toplevel'], root)
    if rc != 0:
        return {"error": "not a git repository", "files": [], "ahead": None,
                "uncommitted": [], "tags": None}
    files = []
    for path, rel in find_workstreams(root):
        rc, out = git(['log', '-1', '--format=%ci', '--', rel], root)
        files.append({"path": rel, "last_commit": out.strip() or None})
    active = os.path.join(root, '.state', 'ACTIVE.md')
    if os.path.isfile(active):
        rel = os.path.relpath(active, root)
        rc, out = git(['log', '-1', '--format=%ci', '--', rel], root)
        files.append({"path": rel, "last_commit": out.strip() or None})

    rc, branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], root)
    branch = branch.strip() or None
    # The comparison ref: the upstream, else the named remote branch.
    rc, up = git(['rev-parse', '--abbrev-ref', '@{upstream}'], root)
    upstream = up.strip() if rc == 0 else None
    compare = upstream
    remote_name = None
    if remote:
        remote_name = remote.split('/', 1)[0]
        compare = remote if '/' in remote else (remote + '/' + branch if branch else None)
    elif upstream:
        remote_name = upstream.split('/', 1)[0]
    ahead = None
    if compare:
        rc, out = git(['rev-list', '--count', compare + '..HEAD'], root)
        ahead = int(out.strip()) if rc == 0 and out.strip() else None
    rc, out = git(['status', '--short', '--', '.state/'], root)
    uncommitted = [l for l in out.splitlines() if l.strip()]

    result = {"branch": branch, "upstream": upstream, "compare": compare,
              "ahead": ahead, "files": files, "uncommitted": uncommitted, "tags": None}
    if not tags:
        return result

    rc, remotes = git(['remote'], root)
    remotes = remotes.split()
    if remote_name is None and remotes:
        remote_name = remotes[0]
    rc, local_tags = git(['tag', '-l', 'ws/*'], root)
    local_tags = local_tags.split()
    if not remotes or remote_name not in remotes:
        result["tags"] = {"remote": None, "note": "no remote configured",
                          "entries": [{"tag": t} for t in local_tags]}
        return result
    # One network call. An annotated tag lists twice, once dereferenced
    # as `^{}`, so the filter is load-bearing: unfiltered, the remote
    # reads roughly double and looks complete when closure tags have
    # never left this machine.
    rc, out = git(['ls-remote', '--tags', remote_name, 'refs/tags/ws/*'], root)
    on_remote = set()
    if rc == 0:
        for line in out.splitlines():
            parts = line.split()
            if len(parts) == 2 and not parts[1].endswith('^{}'):
                on_remote.add(parts[1][len('refs/tags/'):])
    entries = []
    for t in local_tags:
        rc, commit = git(['rev-list', '-n1', t], root)
        commit = commit.strip()
        rc, contained = git(['branch', '-r', '--contains', commit], root)
        contained_in = [b.strip().lstrip('* ') for b in contained.splitlines() if b.strip()]
        unpushed = None
        if compare:
            rc, out = git(['rev-list', '--count', compare + '..' + t], root)
            unpushed = int(out.strip()) if rc == 0 and out.strip() else None
        rc, kind = git(['cat-file', '-t', t], root)
        entries.append({"tag": t, "commit": commit, "annotated": kind.strip() == 'tag',
                        "commit_on_remote": bool(contained_in), "contained_in": contained_in,
                        "unpushed_commits": unpushed, "tag_on_remote": t in on_remote})
    result["tags"] = {"remote": remote_name, "entries": entries,
                      "ref_only": [e["tag"] for e in entries if e["commit_on_remote"] and not e["tag_on_remote"]],
                      "carrying_unpushed": [e["tag"] for e in entries if not e["commit_on_remote"]]}
    return result


def cmd_git(args):
    remote = None
    tags = False
    rest = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--tags':
            tags = True
        elif a == '--remote':
            if i + 1 >= len(args):
                usage("--remote needs a value")
            remote = args[i + 1]
            i += 1
        elif a.startswith('--'):
            usage("unknown option %s" % a)
        else:
            rest.append(a)
        i += 1
    if len(rest) != 1:
        usage("git takes exactly one project root")
    root = require_root(rest[0], PROG)
    print(json.dumps(git_reads(root, remote=remote, tags=tags), indent=2))
    return 0


# --- fires: the drain's symptoms, one verdict per workstream ------------------

KNOWN_FILES = ('workstream.md', 'notes.md')


SEVERED_LOWER_RE = re.compile(r'^[a-z]')
SEVERED_ENUM_RE = re.compile(r'^[a-z]+\)')


def severed_sentences(lines):
    """Lines where a wrapped block's sentence was cut by an insertion:
    a continuation (two-space indent) opening with a lowercase word
    under a line that ends in a full stop. Ordinary wrapping never
    ends a line at a period mid-paragraph, so the shape is almost
    always a severed sentence; a lowercase proper noun is the false
    positive to expect. Code fences are skipped. From a consumer whose
    gate line ended mid-clause for five days while every count passed."""
    out = []
    fenced = False
    for i in range(1, len(lines)):
        cur = lines[i]
        if cur.lstrip().startswith('```'):
            fenced = not fenced
            continue
        if fenced or not cur.startswith('  '):
            continue
        body = cur.strip()
        prev = lines[i - 1].rstrip()
        if not body or not prev.endswith('.'):
            continue
        if SEVERED_LOWER_RE.match(body) and not SEVERED_ENUM_RE.match(body):
            out.append(i + 1)
    return out


def fires(root, only=None, interval_days=30):
    import datetime
    today = datetime.date.today()
    out = []
    for path, rel in find_workstreams(root):
        wid = workstream_id(path)
        if only and wid != only:
            continue
        rec = build_workstream_record(path, rel)
        symptoms = []
        n = len(rec["learnings"]["undispositioned"])
        if n:
            symptoms.append({"symptom": "undispositioned Learnings", "detail": str(n)})
        for ph in rec["phases"]:
            if (ph["done_tasks"] + ph["done_gates"]) > 0 and ph["open_tasks"] + ph["open_gates"] == 0:
                symptoms.append({"symptom": "completed phase", "detail": "%s (%s)" % (ph["name"], ph["code"])})
        severed = severed_sentences(read_lines(path))
        if severed:
            symptoms.append({"symptom": "severed sentence",
                             "detail": ", ".join("line %d" % n for n in severed)})
        if rec["open_outside_backlog"]:
            symptoms.append({"symptom": "open task outside Backlog",
                             "detail": ", ".join("line %d (%s)" % (e["line"], e["id"] or "no ID")
                                                 for e in rec["open_outside_backlog"])})
        if rec["size_bytes"] > SIZE_BYTES:
            symptoms.append({"symptom": "size", "detail": "%dKB past %dKB" % (rec["size_bytes"] // 1024, SIZE_BYTES // 1024)})
        d = os.path.dirname(path)
        names = sorted(os.listdir(d))
        if 'notes.md' in names:
            symptoms.append({"symptom": "notes.md beside the file", "detail": "notes.md"})
        for name in names:
            if name not in KNOWN_FILES and not name.startswith('.'):
                symptoms.append({"symptom": "unknown file in the directory", "detail": name})
        dc = rec["deletion_criteria"]
        if dc["standing_never_rechecked"]:
            symptoms.append({"symptom": "STANDING criteria never re-checked", "detail": str(dc["standing_never_rechecked"])})
        if dc["standing_oldest_holds"]:
            try:
                oldest = datetime.date.fromisoformat(dc["standing_oldest_holds"])
                age = (today - oldest).days
                if age > interval_days:
                    symptoms.append({"symptom": "STANDING re-check older than the interval",
                                     "detail": "oldest HOLDS %s, %d days" % (dc["standing_oldest_holds"], age)})
            except ValueError:
                pass
        out.append({"workstream": wid, "path": rel, "symptoms": symptoms})
    return {"threshold_bytes": SIZE_BYTES, "interval_days": interval_days, "workstreams": out}


def fires_text(result):
    lines = []
    for w in result["workstreams"]:
        if not w["symptoms"]:
            lines.append("%s: quiet" % w["workstream"])
        else:
            parts = ["%s %s" % (s["symptom"], s["detail"]) for s in w["symptoms"]]
            lines.append("%s: fires -- %s" % (w["workstream"], "; ".join(parts)))
    return "\n".join(lines)


def cmd_fires(args):
    as_json = False
    interval = 30
    rest = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--json':
            as_json = True
        elif a == '--interval-days':
            if i + 1 >= len(args) or not args[i + 1].isdigit():
                usage("--interval-days needs a number")
            interval = int(args[i + 1])
            i += 1
        elif a.startswith('--'):
            usage("unknown option %s" % a)
        else:
            rest.append(a)
        i += 1
    if len(rest) not in (1, 2):
        usage("fires takes a project root and an optional type/name")
    root = require_root(rest[0], PROG)
    only = rest[1] if len(rest) == 2 else None
    if only and not os.path.isfile(os.path.join(root, '.state', 'workstreams', only, 'workstream.md')):
        usage("no workstream %s under %s" % (only, root))
    result = fires(root, only=only, interval_days=interval)
    if as_json:
        print(json.dumps(result, indent=2))
    else:
        text = fires_text(result)
        if text:
            print(text)
    return 0


# --- bare-ids: the gloss convention as a check ------------------------------

def bare_ids_paragraphs(lines):
    """The live paragraphs of a workstream.md for the gloss check: the
    Purpose section's paragraphs and every live block (open tasks, the
    critical path, unresolved Open Questions, open and STANDING
    criteria), as (start_line_no, raw_lines)."""
    out = []
    for no, text in purpose_paragraphs_for_gloss(lines):
        out.append((no, text))
    have = {no for no, _r in out}
    for start, raw in live_blocks(lines):
        if start not in have:
            out.append((start, raw))
    out.sort(key=lambda b: b[0])
    return out


def bare_ids_for_file(path, rel, whole_body=False):
    lines = blank_fences(read_lines(path))
    if whole_body:
        body = strip_frontmatter(lines)
        body_lines = [t for _n, t in body]
        offset = body[0][0] - 1 if body else 0
        paras = [(start + offset, raw) for start, _k, _t, raw in fold_blocks(body_lines)]
    else:
        paras = bare_ids_paragraphs(lines)
    hits = bare_ids(paras)
    return {"path": rel, "bare": hits, "count": len(hits)}


def bare_ids_project(root):
    files = []
    active = os.path.join(root, '.state', 'ACTIVE.md')
    if os.path.isfile(active):
        files.append(bare_ids_for_file(active, os.path.relpath(active, root), whole_body=True))
    for path, rel in find_workstreams(root):
        files.append(bare_ids_for_file(path, rel))
    return {"files": files, "total": sum(f["count"] for f in files)}


def bare_ids_stdin(text):
    lines = blank_fences(text.splitlines())
    paras = [(start, raw) for start, _k, _t, raw in fold_blocks(lines)]
    hits = bare_ids(paras)
    return {"files": [{"path": "<stdin>", "bare": hits, "count": len(hits)}], "total": len(hits)}


def bare_ids_text(result):
    lines = []
    for f in result["files"]:
        if f["count"]:
            ids = []
            for h in f["bare"]:
                if h["id"] not in ids:
                    ids.append(h["id"])
            lines.append("%s: %d bare id mention(s): %s" % (f["path"], f["count"], ", ".join(ids)))
    return "\n".join(lines)


def cmd_bare_ids(args):
    as_text = False
    from_stdin = False
    rest = []
    for a in args:
        if a == '--text':
            as_text = True
        elif a == '--stdin':
            from_stdin = True
        elif a.startswith('--'):
            usage("unknown option %s" % a)
        else:
            rest.append(a)
    if from_stdin:
        if rest:
            usage("bare-ids --stdin takes no project root")
        result = bare_ids_stdin(sys.stdin.read())
    else:
        if len(rest) != 1:
            usage("bare-ids takes exactly one project root, or --stdin")
        root = require_root(rest[0], PROG)
        result = bare_ids_project(root)
    if as_text:
        text = bare_ids_text(result)
        if text:
            print(text)
    else:
        print(json.dumps(result, indent=2))
    return 0


# --- self-check: the instrument fired at what it must catch and must let through

def _holds(text):
    return bool(hold_matches(1, [text]))


def _refs(text):
    return [r["target"] for r in cross_ref_matches(1, [text])]


SELF_CHECKS = [
    # (name, predicate, positives, negatives): the predicate must be true
    # of every positive and false of every negative.
    ("HOLD_RE", _holds,
     ["blocked on feature/beta for the schema", "waits for the upstream fix", "held by #PX-1 until the split",
      "sequenced after the extract"],
     ["evaluate the Held-out validation set", "the two retired checkpoints held, so conditions that hold here",
      "raise the alert threshold before shipping"]),
    ("negated hold", _holds,
     ["the order is blocked on #PX-2"],
     ["Nothing in this file is held by another workstream; the order runs PX-1"]),
    ("SATISFIED_MARK_RE", lambda t: bool(SATISFIED_MARK_RE.search(t)),
     ["the exit criterion is SATISFIED 2026-03-03 with evidence", "READY 2026-02-02, decided", "criterion is met 2026-01-01"],
     ["the build note reads the SATISFIED sentence quoted", "READY when the user says so"]),
    ("disposition", lambda t: disposition(t) == 'terminal',
     ["- L1 (2026-01-01): An insight. HANDED OFF 2026-01-02 to feature/beta.",
      "- L5 (2026-01-01): DISPOSITION 2026-01-03: ROUTED to #PX-1.",
      "- L4 (2026-01-01): An insight that is spent. SPENT 2026-01-02 -- routed to docs/design.md.",
      "- ~~L9 (2026-01-01): struck through whole.~~",
      "- L5 (2026-01-01): An insight. **APPLIED 2026-09-05** at abc123.",
      "- L5 (2026-01-01): An insight. *HANDED OFF* to feature/beta, 2026-09-05."],
     ["- L7 (2026-09-04): The record quotes the two-word `HANDED OFF` marker mid-sentence, a mention.",
      "- L6 (2026-01-01): the thing was **DONE** by then, on 2026-01-01, bold mid-sentence.",
      "- L8 (2026-01-01): An insight. APPLIED to docs/design.md, the author forgetting the date.",
      "- L3 (2026-01-01): An insight with no disposition at all."]),
    ("deferred disposition", lambda t: disposition(t) == 'deferred',
     ["- L2 (2026-01-01): Tracked work. QUEUED 2026-01-02 for #PX-2.",
      "- L2 (2026-01-01): Tracked work. **QUEUED** on #GV-1 -- verified 2026-09-05."],
     ["- L2 (2026-01-01): Tracked work, queued informally.",
      "- L2 (2026-01-01): Tracked work. QUEUED on #GV-1 with no date anywhere in the sentence."]),
    ("CROSS_REF_WS_RE", lambda t: bool(_refs(t)),
     ["blocked on feature/beta", "then finalize in project/omlx-0.4.x-finalize"],
     ["waits for the upstream fix in ml-explore/mlx#3856 to land", "a plain sentence"]),
    ("dotted name captured whole", lambda t: 'project/omlx-0.4.x-finalize' in _refs(t),
     ["then finalize in project/omlx-0.4.x-finalize"], ["then finalize in project/omlx"]),
    ("PHASE_HEADING_RE", lambda t: bool(PHASE_HEADING_RE.match(t)),
     ["### Build (BD) -- the heading carries a suffix", "### Split (SK / HW)"],
     ["### D3 (2026-01-01): Third decision", "## Backlog"]),
    ("TOTAL_OPEN_RE", lambda t: bool(TOTAL_OPEN_RE.match(t)),
     ["- [ ] #BD-1: a task", "  - [ ] #BD-1a: an indented sub-task"],
     ["- [ ] Criterion one not yet met", "- [x] #BD-2: done"]),
    ("HOLDS_RE", lambda t: bool(HOLDS_RE.search(t)),
     ["-- HOLDS 2026-01-01, HOLDS 2026-02-02"], ["HOLDS today", "the criterion holds for now"]),
    ("CHECKBOX_ID_RE", lambda t: bool(CHECKBOX_ID_RE.match(t)),
     ["- [x] #OL-3 (DONE 2026-01-01, the no-colon form)", "- [ ] #G-BD: USER CHECKPOINT"],
     ["- [x] a plain criterion", "- L1 (2026-01-01): a Learning"]),
    ("needle_regex word boundaries", lambda t: bool(needle_regex('#BD-1').search(t)),
     ["cites #BD-1 and", "(#BD-1)"], ["cites #BD-10 and", "cites #BD-1a and"]),
    ("TASK_ID_RE", lambda t: bool(TASK_ID_RE.search(t)),
     ["routed to #OG-188 there", "decided at #G-OG"], ["a plain sentence", "the #hashtag"]),
    ("bare_ids glossed", lambda t: not bare_ids([(1, [t])]),
     ["#EX-37 (the phase split question) is open", '#G-OG "the kit change approval gate" stands',
      "#EX-30 in project/tier (the neutrality sort) waits", "D96 (the release decision) and D96 again",
      "- [ ] #EX-37: a backlog line naming #EX-3 (the heuristic)", "run `rg '#EX-3'` here",
      "#XX-N and #G-XX are metavariables"],
     ["#EX-37 is open", "#G-OG stands", "D96 and D96 again", "the (#EX-3) form glosses nothing",
      "#EX-37's split question", "- [ ] #EX-37: a backlog line naming #EX-3 bare"]),
]


def cmd_self_check(args):
    if args:
        usage("self-check takes no arguments")
    misses = 0
    for name, pred, positives, negatives in SELF_CHECKS:
        bad = []
        for t in positives:
            if not pred(t):
                bad.append(("must match", t))
        for t in negatives:
            if pred(t):
                bad.append(("must not match", t))
        if bad:
            misses += len(bad)
            for why, t in bad:
                print("MISS %s: %s: %r" % (name, why, t))
        else:
            print("ok %s: matches %s; lets through %s" % (
                name, " | ".join(positives), " | ".join(negatives)))
    if misses:
        print("SELF-CHECK FAILED: %d miss(es)" % misses)
        return 1
    print("SELF-CHECK OK: %d patterns" % len(SELF_CHECKS))
    return 0


# --- dispatch --------------------------------------------------------------

COMMANDS = {
    'record': cmd_record,
    'cites': cmd_cites,
    'refs': cmd_refs,
    'paths': cmd_paths,
    'decay': cmd_decay,
    'git': cmd_git,
    'fires': cmd_fires,
    'bare-ids': cmd_bare_ids,
    'self-check': cmd_self_check,
}


def main():
    argv = sys.argv[1:]
    if not argv:
        usage()
    if argv[0] in ('-h', '--help'):
        sys.stdout.write(__doc__)
        sys.exit(0)
    if argv[0] in COMMANDS:
        sys.exit(COMMANDS[argv[0]](argv[1:]))
    if argv[0].startswith('-'):
        usage("unknown option %s" % argv[0])
    if len(argv) == 1:
        sys.exit(cmd_record(argv))
    usage("unknown sub-command %s" % argv[0])


if __name__ == '__main__':
    main()
