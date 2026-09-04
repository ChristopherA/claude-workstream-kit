#!/usr/bin/env python3
"""condense-completed-records.py -- the extract skill's condensation moves.

Two moves over one workstream.md, both idempotent and both leaving the
full text in git at the commit before the run:

1. Completed task records (Move 3). Every `- [x]` record in the live
   `## Backlog` that runs longer than the rule's completion-note form
   condenses to that form: the ID, the description's first sentence
   (capped), the last status word and date the record carried, its
   Decision citations and its commit hashes, and a marker naming this
   condensation so a second run is a no-op.

2. Shipped Decisions (`--decisions`). A Decision whose approved changes
   have shipped in a tagged release, and whose task records are already
   condensed, condenses to its heading, its first paragraph (the
   reasoning) and a line naming the release; the whole `## Decisions`
   section is then restored to numeric order. Which Decisions are
   shipped is the caller's judgment, named explicitly -- the script
   never infers it from the text.

Structure is verified before writing: the multiset of headings and the
sequence of checkbox IDs and states must be identical before and after,
or the script refuses to write and exits 1. Callers still re-derive the
open and gate counts and run the script a second time expecting zero
changes -- the first live run was not idempotent until the marker guard
was added, and only the second run showed it.

Usage:
  condense-completed-records.py <workstream.md> [--write] [--date YYYY-MM-DD]
      [--decisions D1,D4-D9 --release <tag>] [--no-tasks]

Without --write it reports what it would change and writes nothing.
--no-tasks skips move 1 (a Decisions-only run). Exit 0 on success, 1 on
a structure mismatch or a named Decision that does not exist, 2 on
usage.
"""
import datetime
import re
import sys


def usage(msg=None):
    if msg:
        sys.stderr.write("condense-completed-records.py: %s\n" % msg)
    sys.stderr.write(__doc__)
    sys.exit(2)


argv = sys.argv[1:]
DATE = datetime.date.today().isoformat()
DECISIONS = None
RELEASE = None
if "--date" in argv:
    i = argv.index("--date")
    if i + 1 >= len(argv):
        usage("--date needs a value")
    DATE = argv[i + 1]
    del argv[i:i + 2]
if "--decisions" in argv:
    i = argv.index("--decisions")
    if i + 1 >= len(argv):
        usage("--decisions needs a value")
    DECISIONS = argv[i + 1]
    del argv[i:i + 2]
if "--release" in argv:
    i = argv.index("--release")
    if i + 1 >= len(argv):
        usage("--release needs a value")
    RELEASE = argv[i + 1]
    del argv[i:i + 2]
DRY = "--write" not in argv
DO_TASKS = "--no-tasks" not in argv
args = [a for a in argv if not a.startswith("--")]
unknown = [a for a in argv if a.startswith("--") and a not in ("--write", "--no-tasks")]
if unknown:
    usage("unknown option %s" % unknown[0])
if len(args) != 1:
    usage()
if (DECISIONS is None) != (RELEASE is None):
    usage("--decisions and --release go together")
W = args[0]
MARK = "Condensed %s at extract" % DATE
GUARD_RE = re.compile(r"Condensed \S+ at extract")  # any earlier run, whatever its date

try:
    with open(W, encoding="utf-8") as f:
        text = f.read()
except OSError as e:
    usage(str(e))
lines = text.split("\n")


def section_bounds(name):
    """(start, end): the index of `## <name>` and of the next `## ` line
    (or len(lines)). None when the section is absent."""
    try:
        start = lines.index("## " + name)
    except ValueError:
        return None
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    return start, end


HEADING_RE = re.compile(r"^#{1,6} ")
CHECKBOX_RE = re.compile(r"^ *- \[([ xX])\] (#[A-Za-z]+-[0-9]+[a-z]?|#G-[A-Za-z0-9]+)")


def fingerprint(ls):
    headings = sorted(l for l in ls if HEADING_RE.match(l))
    boxes = [(m.group(1).lower(), m.group(2)) for l in ls for m in [CHECKBOX_RE.match(l)] if m]
    return headings, boxes


before_fp = fingerprint(lines)
report = []

# --- move 1: completed task records ------------------------------------
tasks_condensed = 0
tasks_saved = 0
samples = []
if DO_TASKS:
    bounds = section_bounds("Backlog")
    if bounds is None:
        usage("no ## Backlog section in %s" % W)
    start, end = bounds
    DONE_RE = re.compile(r"^( *- \[x\] )(#[A-Z]+-[0-9]+[a-z]?|#G-[A-Z]+)(: ?)(.*)$")
    DATE_RE = re.compile(r"\b(20[0-9]{2}-[0-9]{2}-[0-9]{2})\b")
    DEC_RE = re.compile(r"\bD[0-9]+\b")
    SHA_RE = re.compile(r"\b[0-9a-f]{7}\b")
    STATUS_RE = re.compile(r"\b(DONE|DECIDED|RETIRED|SUPERSEDED|CLOSED|SHIPPED|ABSORBED|RESOLVED|APPROVED|UNBLOCKED|MERGED)\b")
    out = []
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
        mark = marks[-1] if marks else "DONE"
        date = dates[-1] if dates else "n.d."
        ev = []
        if decs:
            ev.append("reasoning in " + ", ".join(decs))
        if shas:
            ev.append("commits " + ", ".join(shas[:8]) + (" ..." if len(shas) > 8 else ""))
        note = "%s%s: %s %s %s; %s. %s; full record in git before that commit." % (
            prefix, tid, head, mark, date,
            "; ".join(ev) if ev else "evidence in the record at the commit preceding this condensation",
            MARK)
        out.append(note)
        tasks_condensed += 1
        tasks_saved += len(ln) - len(note)
        if len(samples) < 3:
            samples.append((tid, len(ln), len(note), note[:300]))
    report.append("condensed=%d bytes_saved=%d backlog_lines %d->%d" % (tasks_condensed, tasks_saved, end - start, len(out)))
    lines = lines[:start] + out + lines[end:]

# --- move 2: shipped Decisions ------------------------------------------
decisions_condensed = 0
decisions_saved = 0
reordered = False
if DECISIONS is not None:
    wanted = set()
    for part in DECISIONS.split(","):
        part = part.strip()
        m = re.fullmatch(r"D?([0-9]+)(?:-D?([0-9]+))?", part)
        if not m:
            usage("--decisions entry %r is not D<n> or D<n>-D<m>" % part)
        lo = int(m.group(1))
        hi = int(m.group(2)) if m.group(2) else lo
        wanted.update(range(lo, hi + 1))
    bounds = section_bounds("Decisions")
    if bounds is None:
        usage("no ## Decisions section in %s" % W)
    start, end = bounds
    DEC_HEAD_RE = re.compile(r"^### D([0-9]+)\b")
    # Split the section into a preamble and one block per Decision heading.
    body = lines[start + 1:end]
    preamble = []
    blocks = []  # (number, [lines])
    current = None
    for ln in body:
        m = DEC_HEAD_RE.match(ln)
        if m:
            current = (int(m.group(1)), [ln])
            blocks.append(current)
        elif current is None:
            preamble.append(ln)
        else:
            current[1].append(ln)
    present = {n for n, _ in blocks}
    missing = sorted(wanted - present)
    if missing:
        sys.stderr.write("condense-completed-records.py: no Decision heading for %s in %s\n"
                         % (", ".join("D%d" % n for n in missing), W))
        sys.exit(1)

    def strip_blank(ls):
        while ls and ls[-1].strip() == "":
            ls = ls[:-1]
        return ls

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
            tail = "Shipped in %s. %s; full text in git before that commit." % (RELEASE, MARK)
            condensed = [head] + para + [tail]
            decisions_saved += sum(len(l) + 1 for l in bl) - sum(len(l) + 1 for l in condensed)
            decisions_condensed += 1
            bl = condensed
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
    lines = lines[:start + 1] + rebuilt + lines[end:]
    report.append("decisions_condensed=%d bytes_saved=%d reordered=%s"
                  % (decisions_condensed, decisions_saved, "yes" if reordered else "no"))

new = "\n".join(lines)
after_fp = fingerprint(lines)
if after_fp != before_fp:
    sys.stderr.write("condense-completed-records.py: structure changed (headings or checkbox IDs/states); refusing to write\n")
    sys.exit(1)

print(" ".join(report))
for s in samples:
    print(s)
if new == text:
    print("NO CHANGE")
elif not DRY:
    with open(W, "w", encoding="utf-8") as f:
        f.write(new)
    print("WRITTEN")
