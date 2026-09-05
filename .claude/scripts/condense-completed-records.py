#!/usr/bin/env python3
"""condense-completed-records.py -- a one-release forwarding shim.

The extract skill's two condensation moves now live in
workstream-rewrite.py as its `records` and `decisions` sub-commands.
This name stays for one release so a consumer mid-upgrade, whose skill
text still names it, is not broken: the old options are accepted and
the old output shape is printed, by calling the same code.

Usage (unchanged):
  condense-completed-records.py <workstream.md> [--write] [--date YYYY-MM-DD]
      [--decisions D1,D4-D9 --release <tag>] [--no-tasks]
"""
import datetime
import importlib.util
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('workstream_rewrite', os.path.join(HERE, 'workstream-rewrite.py'))
rewrite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rewrite)


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
sys.exit(rewrite.run_condense(args[0], DO_TASKS, DECISIONS, RELEASE, DATE, DRY))
