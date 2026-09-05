#!/usr/bin/env python3
"""workstream-rewrite.py -- the kit's rewrites, one sub-command each.

Every sub-command changes one workstream.md to a form the rule already
prescribes. All dry-run by default and write only under --write; each
carries a dated marker or a fixed point so a second run is a no-op;
each asserts the structure fingerprint (heading multiset, checkbox ID
and state sequence) identical before writing and exits 1 otherwise;
each leaves the full text in git at the commit before the run. None
infers a judgment the caller names: which Decisions shipped is
--decisions. The measures
live in workstream-record.py. Standard library only.

Usage:
  workstream-rewrite.py records   <workstream.md> [--write] [--date YYYY-MM-DD]
  workstream-rewrite.py decisions <workstream.md> --decisions D1,D4-D9 --release <tag>
                                  [--write] [--date YYYY-MM-DD]
`records`: every `- [x]` record in the live Backlog longer than the
rule's completion-note form condenses to that form (the ID, the
description's first sentence, the last status word and date, its
Decision citations and commit hashes, a dated marker).

`decisions`: each named Decision condenses to its heading, its first
paragraph and a line naming the release; the section is restored to
numeric order.

Exit 0 on success (a dry run included), 1 on a refusal or a failed
check, 2 on usage or an unreadable file. Prints a report, then WRITTEN
or NO CHANGE (a dry run with changes prints the report alone).
"""

import datetime
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from workstream_state import (  # noqa: E402
    DECISION_HEADING_RE, fingerprint, section_bounds,
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
SHA_RE = re.compile(r"\b[0-9a-f]{7}\b")
STATUS_RE = re.compile(r"\b(DONE|DECIDED|RETIRED|SUPERSEDED|CLOSED|SHIPPED|ABSORBED|RESOLVED|APPROVED|UNBLOCKED|MERGED)\b")


def condense_records(lines, mark):
    bounds = section_bounds(lines, "Backlog")
    if bounds is None:
        raise Refusal("no ## Backlog section")
    start, end = bounds
    out = []
    condensed = 0
    saved = 0
    samples = []
    for i in range(start, end):
        ln = lines[i]
        m = DONE_RE.match(ln)
        if not m or len(ln) <= 400 or GUARD_RE.search(ln):
            out.append(ln)
            continue
        prefix, tid, _sep, body = m.groups()
        head = re.split(r"(?<=[.!?])\s+(?=[A-Z`(#])", body, maxsplit=1)[0]
        if len(head) > 220:
            head = head[:217].rsplit(" ", 1)[0] + "..."
        dates = DATE_RE.findall(body)
        decs = sorted(set(DEC_RE.findall(body)), key=lambda d: int(d[1:]))
        shas = list(dict.fromkeys(SHA_RE.findall(body)))
        marks = list(dict.fromkeys(STATUS_RE.findall(body)))
        mark_word = marks[-1] if marks else "DONE"
        date = dates[-1] if dates else "n.d."
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
        if len(samples) < 3:
            samples.append((tid, len(ln), len(note), note[:300]))
    report = "condensed=%d bytes_saved=%d backlog_lines %d->%d" % (condensed, saved, end - start, len(out))
    return lines[:start] + out + lines[end:], report, samples


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


def condense_decisions(lines, wanted, release, mark):
    start, end, preamble, blocks = decision_blocks(lines)
    present = {n for n, _ in blocks}
    missing = sorted(wanted - present)
    if missing:
        raise Refusal("no Decision heading for %s" % ", ".join("D%d" % n for n in missing))
    condensed = 0
    saved = 0
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
            tail = "Shipped in %s. %s; full text in git before that commit." % (release, mark)
            cond = [head] + para + [tail]
            saved += sum(len(l) + 1 for l in bl) - sum(len(l) + 1 for l in cond)
            condensed += 1
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
    return lines[:start + 1] + rebuilt + lines[end:], report


def run_condense(path, do_tasks, decisions, release, date, dry):
    """The shipped script's whole run, kept for the forwarding shim:
    records unless --no-tasks, then the named Decisions, one report."""
    text = load(path)
    lines = text.split("\n")
    mark = "Condensed %s at extract" % date
    report = []
    samples = []
    try:
        if do_tasks:
            lines, r, samples = condense_records(lines, mark)
            report.append(r)
        if decisions is not None:
            lines, r = condense_decisions(lines, parse_decisions(decisions), release, mark)
            report.append(r)
    except Refusal as e:
        sys.stderr.write("%s: %s in %s\n" % (PROG, e, path))
        return 1
    return finish(path, text, "\n".join(lines), dry, report, [str(s) for s in samples])


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


# --- dispatch ---------------------------------------------------------------

COMMANDS = {
    'records': cmd_records,
    'decisions': cmd_decisions,
}


def main():
    argv = sys.argv[1:]
    if not argv or argv[0] not in COMMANDS:
        usage("sub-command required: %s" % ", ".join(COMMANDS))
    sys.exit(COMMANDS[argv[0]](argv[1:]))


if __name__ == '__main__':
    main()
