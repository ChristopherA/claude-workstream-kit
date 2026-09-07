#!/usr/bin/env python3
"""Stop hook: hand back a turn whose final message mentions a task,
gate, Decision, Learning or Open Question ID with no gloss.

The workstreams rule says an ID is a pointer, not a name, and that
every mention outside its own backlog line carries a few words saying
what it is, in the canonical form `#EX-37 (the phase split question)`.
Prose asked for that for months and kept slipping; this hook is the
check that fails. It reads the turn's assistant text from the
transcript, runs the same detector the record script's `bare-ids`
sub-command runs over state files, and when bare mentions remain
returns a block decision naming them, so the turn ends only once they
are glossed. It fires once per turn: when Claude Code reports the hook
already blocked this turn (`stop_hook_active`), it lets the stop
through, so a message that cannot be fixed cannot loop.

Registered by install.sh under Stop with no matcher. Reads stdin JSON
(session_id, transcript_path, stop_hook_active); writes JSON to stdout
only when blocking. Exits 0 always: a hook error must never hold a
session. Standard library only; the detector is imported from the
scripts directory beside this hook.
"""

import json
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'scripts'))

try:
    from workstream_state import bare_ids, blank_fences, fold_blocks  # noqa: E402
except Exception:  # the payload is incomplete: never hold the session for it
    sys.exit(0)


def turn_text(transcript_path):
    """The assistant text of the turn that is ending: every text block
    of the assistant records after the last human message, in order.
    A `user` record whose content is only tool results is the harness
    talking, not the user, and does not end the walk."""
    try:
        with open(transcript_path, 'r', encoding='utf-8', errors='replace') as f:
            records = [json.loads(l) for l in f if l.strip()]
    except Exception:
        return ''
    texts = []
    for rec in reversed(records):
        kind = rec.get('type')
        msg = rec.get('message') or {}
        content = msg.get('content')
        if kind == 'user':
            if isinstance(content, str):
                break
            if isinstance(content, list) and any(b.get('type') != 'tool_result' for b in content if isinstance(b, dict)):
                break
            continue
        if kind != 'assistant' or not isinstance(content, list):
            continue
        for b in content:
            if isinstance(b, dict) and b.get('type') == 'text' and b.get('text'):
                texts.append(b['text'])
    texts.reverse()
    return '\n\n'.join(texts)


def main():
    try:
        payload = json.loads(sys.stdin.read() or '{}')
    except Exception:
        return 0
    if payload.get('stop_hook_active'):
        return 0
    path = payload.get('transcript_path')
    if not path or not os.path.isfile(path):
        return 0
    text = turn_text(path)
    if not text.strip():
        return 0
    lines = blank_fences(text.splitlines())
    hits = bare_ids([(start, raw) for start, _k, _t, raw in fold_blocks(lines)])
    if not hits:
        return 0
    ids = []
    for h in hits:
        if h['id'] not in ids:
            ids.append(h['id'])
    reason = (
        "Your last message mentions %d id(s) with no gloss: %s. The workstreams rule "
        "makes every id outside its own backlog line carry a few words saying what it is, "
        "in the form `#EX-37 (the phase split question)`, at its first mention in each "
        "paragraph. Send the message again with each of these glossed; nothing else "
        "needs to change." % (len(ids), ", ".join(ids))
    )
    out = {"decision": "block", "reason": reason,
           "hookSpecificOutput": {"hookEventName": "Stop", "decision": "block", "reason": reason}}
    print(json.dumps(out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
