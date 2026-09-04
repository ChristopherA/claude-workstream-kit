---
name: handoff
description: >-
  Cross-project handoffs via .state/handoffs/ files. Create: write a
  self-contained item file into another project's inbox. Receive: triage
  this project's inbox and delete processed files.
  WHEN: the user says "/handoff", "send this to <project>", "hand off",
  "process handoffs", or the session-start hook reports pending handoffs.
  WHEN NOT: same-project work (use the workstream backlog); team-scale
  tracking with notifications and ownership (use GitHub Issues instead).
---

# Handoff

Format: `.state/handoffs/from-<source>-<YYYYMMDD-HHMMSS>.md` in the RECEIVER's project.

```markdown
---
from: <source-project>
date: YYYY-MM-DD
blocking: no            # yes only if the receiver's work cannot proceed without acting
items: 2
about: <artifact>       # the file, skill or mechanism the items concern
class: <failure class>  # what kind of finding, so a duplicate is a grep of the inbox
---
> Cross-project handoff. Process: act on each item, route it into a
> workstream backlog, or decline with rationale; then delete this file.

## Item 1: <title>
Self-contained context and the requested action.
```

The two halves are split across two actors who cannot see each other's session, so each half carries a pre-flight that assumes nothing about the other: the sender cannot know what the receiver already holds, and the receiver cannot know whether the sender's steps ran.

## Create

Pre-flight, before writing into another project:

1. **Read what the receiver already tracks.** Any step that proposes to write into another party's tracker reads that tracker first: the receiver's `.state/workstreams/` including paused ones, its `ACTIVE.md`, and its inbox — where the `about:` and `class:` keys make the duplicate check a grep rather than a read of every file. "The receiver needs this" is a claim about the receiver and stays a claim about the sender's intent until the receiver's state is read. The grep is seconds and a duplicate is permanent, because a handoff is committed into the receiver's history and a later correction does not remove the original. Run this pre-flight ESPECIALLY when the user has named the destination and the action: that is the state in which a sender treats the research as done, and running it anyway is what has caught same-day convergence with other projects.
2. **Self-containment, per item.** Could someone act on it with NO access to this conversation or this repo? Its canonical failure is the bare task ID: `#ID-4` sends the receiver to grep your repo, which is the one thing the test forbids, and it slips through deep in a document whose earlier references were all named correctly — partial adoption reads as adoption. Include file contents, decisions, and rationale inline as needed. An ID sent with the WRONG home is worse than one sent with no home: an unhomed ID reads as ambiguous and gets queried, a wrongly-homed one reads as resolvable and gets answered into a permanent record — so a citation is checked when written, not only for staleness. An item asking the receiver to adopt a boundary, constraint, or ownership split carries one instruction before the writing: grep the target for the clause that currently contradicts it. A boundary appended while the broader permission it narrows stays in place leaves two passages equally authoritative, and the broader one wins in practice.
3. **Confirm the destination with the user, and its visibility.** Writing into another project is a cross-project action and gets its own confirmation. If the destination repository is public, say so before writing: handoffs routinely name the private projects they come from, and a file committed into a public repository's inbox is one authorized push from permanent public history. The sender is the party least placed to notice, because by the time anyone asks, the file is already committed there. A finding about the kit itself goes as a handoff to whichever project stewards your kit installation, or to an issue on the kit's repository if you maintain the kit yourself — not to the public repository by default, because a handoff routinely names private projects, task IDs and `.state/` paths, and the sender is the party least able to sweep it.

Then:

4. **Write the file** (`mkdir -p <dest>/.state/handoffs/` first), and re-derive every figure in it as the LAST edit before sending: a document arguing for a change is where that change lands first, and a handoff is the case where author and invalidator are guaranteed to be the same session. One file per destination; bundle multiple items. If the destination project does not exist yet, do NOT create a holding pen — record the items in the sender's own workstream.md (backlog or open question) until it does.
5. **Commit it in the receiver's repo as a FILING**, scoped to the one path (`git -C <dest> add` the file, then commit only it; if the receiver's repo has staged work, do not sweep it up) — UNLESS the receiver's session is live, since a commit into a repo another session is working lands on a tree that session did not pre-flight. Then the file is filed uncommitted and the frontmatter says so (`committed: no`), a stated outcome rather than a silent fallback; the receiver commits it on arrival, which is Receive's first step. Title the commit as what its diff proves — "File a handoff: <title>" — and never as a receive: a commit that adds a handoff and deletes none is a filing by the sender, however accurately its message describes the item, and titled "Receive ..." it tells the log the work was done while the file still sits untriaged in the inbox. `git show --stat <sha>` reporting insertions only is conclusive.
6. **Say which guarantee you delivered.** The commit buys durability — survival against `git clean`, a place in history; only a push buys reach, the receiver's other machines. Committed and unpushed, the handoff arrives only for a receiver session on this machine. Surface the push decision to the user with what it would publish (every other commit on that branch), and never push on this skill's say-so: a push is shared-visible and needs its own approval.
7. **Correcting an item still in flight is an edit in place**, not an appended correction. While the file sits untriaged, rewrite the item: the reader cannot see your conversation, so they cannot tell which of two contradicting passages was written later, and triage is exactly the moment they have least context to adjudicate. The window closes at triage; after that, a correction is a new item.

## Receive

Pre-flight, before triage:

1. **Commit each file in `.state/handoffs/` that arrived uncommitted, before anything else**: `git ls-files <path>` says which. A file that arrived uncommitted leaves no record once deleted — the deletion shows in `git status` as nothing, because git never had it — and the one that matters most is the one that refutes something this project already committed. Commit it first, as a filing; never reconstruct a missing one from memory, since a hand-retyped file presented as the received original is worse than an honest pointer.
2. **List `.state/workstreams/`, including paused ones**, before proposing any routing destination. Conversational salience never surfaces a paused workstream, and that is the class that gets duplicated; the creation skill's duplicate check catches only the route that passes through it.
3. **Verify a claim before it becomes a task description.** Not every sentence — the claims you are about to write down: a mechanism or environment claim, a count, a list of paths and line numbers. Check them against this tree by content, never by line number, because the receiver's own edits shift lines in the gap between sending and receiving and a careful sender's "measured, not estimated" does not survive it. An item framed as a correction to the receiver's own file carries borrowed authority — it arrives with evidence, it is about your mistake, and agreeing feels cooperative — and gets probed the same way.

Then:

4. **Triage per item**, with the user when interactive: **do now** (small, in scope), **route** to a workstream backlog as `- [ ] #XX-N: <task> (from <source>, <date>)`, or **decline** with rationale — if the sender needs to know, reply with a handoff back.
5. **Delete each fully processed file** — items routed into a backlog count as processed — and commit as a RECEIVE: the diff deletes the file, and the title says what was triaged. A receive commit that deletes nothing is a filing wearing the wrong name.
6. **An aging inbox** (the hook reports oldest age) is state to reconcile, not background noise — triage before new task work.
