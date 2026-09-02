---
name: workstream-status
description: >-
  Reads every workstream in the project and states where the project is:
  a roster with each workstream's next task, the critical paths that run
  across workstreams, what is waiting on the user, and where the state
  files disagree with each other. Read-only and on demand: it writes
  nothing and resolves nothing.
  WHEN: the user says "/workstream-status", "project status", "where are
  we across workstreams", "what is on the critical path", or wants the
  whole project's state before choosing what to work.
  WHEN NOT: re-cohering one workstream (use /workstream-review); draining
  one (use /workstream-extract); session start, where the hook's roster
  already runs; capturing a session (use /workstream-capture); changing
  any state file, which this skill never does.
---

# Workstream Status

Every other skill in the kit takes one workstream, and the session-start hook prints one line per workstream. The only cross-workstream prose is ACTIVE.md's Now, written by hand by whoever last remembered to. This skill is the read that the roster is too narrow for and the hand-written paragraph too unreliable for: it reads every workstream and says what runs across them. It is read-only and on demand. It writes nothing — not ACTIVE.md, which `/workstream-capture` owns; not a backlog, which `/workstream-review` owns; and not a status file, which would be a durable artifact making present-tense claims about live state, true when written and silently false after. It resolves nothing: a disagreement between two state files is reported with both texts and the skill that owns the fix, and the fix is that skill's session. It asks the user nothing: the report is the answer, and what it cannot derive it names as a gap.

## Sources

This is the complete list. Anything not on it is not read, and the statement's last section says which of these could not be read.

- Every `.state/workstreams/*/*/workstream.md`, whatever its `status:` says. A paused workstream is the exposed case: nobody is reading it, and it is the one most likely to be cited from elsewhere.
- `.state/ACTIVE.md`.
- `.state/workstreams/ARCHIVE.md`, for resolving references to closed workstreams.
- `.state/handoffs/*.md`, the inbox.
- The roster, re-derived by running `.claude/hooks/session-start.sh` with `CLAUDE_PROJECT_DIR` set to the project root — never recalled from the transcript, which is a session old at best.
- Git, three reads and no more: the last-commit date of each state file (`git log -1 --format=%ci -- <file>`, the derivation the hook uses, since the `updated:` field drifts); commits ahead of the upstream (`git rev-list --count @{upstream}..HEAD`, or the named remote branch when no upstream is set); and uncommitted state (`git status --short -- .state/`).
- `.state/PROJECT.md`, the project's own list of what is unique to it: skills and context files. For each listed skill, the `description` in the frontmatter of `.claude/skills/<name>/SKILL.md` and nothing else of it; for each listed file, the file. The list exists because a scan cannot tell a skill unique to the project from one copied in from a shared source, and only the unique ones frame a status. Nothing outside `.state/` and git is read unless that file lists it — not `CLAUDE.md`, not `README.md`, not the rest of `.claude/`. When the file is absent or its sections are empty, the statement says so and names the file.

Other projects are out: a handoff this project SENT lives in another project's inbox, and a task that names another project is reported as the reference it is, unresolved.

## Move 1 — Roster and pointer

In main context: run the hook, read ACTIVE.md and PROJECT.md, take the three git reads. Note the workstream count, each status and flag, the inbox count and oldest age, and whether ACTIVE.md's pointer names a workstream and task that exist. This is cheap and bounded, and it is the frame every later move hangs on.

## Move 2 — The record, one command per field

In main context, derive the record below for every `workstream.md`, with the commands given and over all files at once. Each is line-anchored, so its output is small whatever the file's size — the largest file is never read whole, only grepped — and deterministic, which is what a record has to be before anything is built on it. The first run of this skill sent one scout per file for the same record: the scouts took a minute or more each, returned summaries where lines were asked for, dropped a gate and a task, and loosened the patterns, while two commands in main context derived every record exactly. Delegation moved to Move 5, where reading beats grep.

The record, per file:

1. **Purpose**: the first sentence under `## Purpose`, and the sentence containing "Done means" or, absent that, the last sentence of the section (`awk '/^## Purpose/{f=1;next} /^## /{f=0} f'`).
2. **Phases**: every `### <Name> (<XX>)` heading under `## Backlog`, each with `grep -cE '^ *- \[ \] #<XX>-'` and `grep -cE '^ *- \[ \] #G-<XX>'`. Their sum must equal `grep -cE '^ *- \[ \] #'` for the file; a shortfall is a task sitting outside any phase heading, reported as such.
3. **First open task**: `grep -nE '^ *- \[ \] #' | head -1`.
4. **Open gates**: `grep -nE '^ *- \[ \] #G-'`, and for each whether it contains the capitalised word `SATISFIED` or `READY`, or the phrase `criterion is met` — case-sensitive on the capitals, since lower-case "satisfied" occurs in ordinary prose about a gate.
5. **Hold lines**: open task lines, critical-path paragraphs and ACTIVE.md matching, case-insensitively and on word boundaries, `\bheld\b|\bhold\b|blocked (by|on)|unblocks when|\bwait(s|ing)? (for|on)\b|not before|sequenced after` — the boundaries matter, because `hold` sits inside `threshold` and `household` — with a hundred characters of context either side of the match. A grep asked for that much context can exceed its engine's complexity limit and print nothing; python's `re` does not.
6. **Cross-workstream references**: on the same lines, every `(explore|feature|fix|project|maintain)/[a-z0-9-]+` and every `ws/[a-z0-9-]+` tag, each with the identifier that precedes it on the line if any (`#[A-Z]+-[0-9]+[a-z]?`, `D[0-9]+`, `L[0-9]+`, `OQ-[0-9]+`). `docs` is left out of the type list because `docs/` also names a directory; add it back only for a project that has a docs-type workstream. A target that is neither a directory under `.state/workstreams/` nor a name in `ARCHIVE.md` belongs to another project and is reported as out of reach in Move 5.
7. **Critical path**: the paragraph beginning `**Critical path`, from that line to the next blank line since it may be hard-wrapped (`awk '/^\*\*Critical path/{p=1} p&&/^$/{exit} p'`), or `not found`.
8. **Latest Decision**: the highest-numbered `### D<n>` heading and the count — the numeric maximum, since the headings are not in file order.
9. **Learnings**: `grep -cE '^- L[0-9]+'`, and among those lines the ones carrying no disposition word (APPLIED, ROUTED, DROPPED, DISPOSITION), as raw lines.
10. **Deletion criteria**: the counts of `- [ ]` and of `- [x]` lines under `## Deletion Criteria`.
11. **Size**: `wc -c`.

Records are data, not verdicts: a line that reads like a hold but does not match the pattern is not a hold line, and what any occurrence means is decided in Move 3 with the line in view. Check a line number with `sed -n` before citing it.

## Move 3 — Cross-workstream synthesis

In main context, from the records:

- **Edges.** A hold line or cross-workstream reference in A that names a task, Decision, release, or tag in B is an edge from A to B. Read B's record for the named thing's state: open, checked, or absent. A hold naming a task in a workstream whose status is `paused` is a dependency without a date — the rule calls it a wish — and is reported as such rather than as a blocker.
- **Chains.** Each workstream's critical-path paragraph gives its own order; join those orders along the edges. Chains that share no edge are independent.
- **Awaiting the user.** Every open gate, from every workstream, paused ones included. Split out the gates whose line carries satisfied-text from field 4: a gate decided in the record and never presented is the case a roster cannot show, since the checkbox is open and truthful.
- **Priority is not derived.** The files carry dependency order and never priority among independent chains. Present the chains side by side, in no order, and say when ACTIVE.md's pointer sits on none of their heads. Do not infer priority from recency, size, or the pointer, and do not ask: the gap is itself a finding.

## Move 4 — Disagreements

A synthesis exists to surface the places where the files disagree, because no single-workstream skill can see them. Check each class below across every record, on open lines, critical-path paragraphs and ACTIVE.md — a completed line's references are frozen provenance and are not checked; report every hit with both sources quoted (file and line each) and the skill that owns the fix. Resolve none.

1. ACTIVE.md's `workstream:` names a directory the roster lacks, or its `task:` names an ID with no open line in that workstream (checked, or absent). Owner: `/workstream-capture`.
2. A hold line names a task in a workstream whose `status:` is `paused`. Owner: `/workstream-review` in the holding workstream.
3. An open gate line carries satisfied-text. Owner: the next session in that workstream presents the gate; `/workstream-review` if the backlog accreted behind it.
4. A cross-workstream reference names a home that exists and does not contain the ID, or names a closed workstream by name rather than by its archive tag. Owner: `/workstream-review` in the referring workstream.
5. Every deletion criterion is checked, or the done condition reads as met, while `status:` is `active`. Owner: `/workstream-close`.
6. ACTIVE.md's Blockers names a workstream with nothing there matching the named thing — no open task, and no standing obligation of a never-closing workstream such as its drain or review. Owner: `/workstream-capture`.
7. Two workstreams claim the same next release, version, or artifact. Owner: `/workstream-review` in each.
8. `.state/PROJECT.md` lists a skill with no `.claude/skills/<name>/SKILL.md`, or a file that does not exist. Owner: the user, by editing that list.
9. A hold line or a critical-path paragraph names, as next or as the thing it waits on, a task or gate that is already checked. The paragraph reads as current because nothing marks the moment it stopped being; in the first run two of five critical paths did this, one of them re-derived that same day. Owner: `/workstream-review` in that workstream.

Cross-project findings — a reference into another project, a handoff whose sender has moved on — are named as out of reach; `/handoff` is the route when they need action.

## Move 5 — The statement

Chat, in this shape and this order, and nothing written anywhere:

1. **One paragraph.** What this project is, from PROJECT.md's list and the count of workstreams; what is moving (the workstreams whose git date falls in the last week); what is waiting (gates and holds, by count). Where PROJECT.md is empty the paragraph says so instead of inventing a description.
2. **Roster.** One row per workstream: name, status, open tasks and gates, the first open task trimmed to a clause, and any flag (SIZE, STALE, ahead of remote, uncommitted). Every workstream appears here once and reappears below only in a chain, a gate, or a disagreement.
3. **Critical paths across workstreams.** Each chain as an ordered list of tasks with their workstream, and for each join the edge that makes it (file and line). Independent chains side by side. The sentence about the pointer.
4. **Awaiting the user.** Satisfied-but-unpresented gates first, then the rest, each with its workstream and the decision it asks for in words rather than codes.
5. **Disagreements.** Each with both texts and the owner.
6. **What this could not see.** Sources on the list that were absent or unreadable, a cited line the verifier could not open, references into other projects, and the standing gap: priority among independent chains.

Before the statement is delivered, hand it and the records to one fresh-context `scout` with this packet verbatim: "Here is a status statement and the records it was built from. For every file and line the statement cites, open that line and report MATCH or the line's actual text. For every row of the roster, run `grep -cE '^ *- \[ \] #'` and `grep -nE '^ *- \[ \] #G-'` on that workstream's file now and report whether the row's counts agree. Report occurrences only, never a verdict on the statement." A citation that comes back as anything but MATCH is corrected or dropped before delivery. This is where a sub-agent earns its place — reading a cited line against a claim is the check a grep cannot make — and the first run showed the reverse assignment fails: scouts sent to derive the record summarized and dropped lines, while the derivation in main context was exact.

Bound the length by leaving things out, not by compressing: a workstream's detail beyond its next task and its gates does not belong here, and a reader who wants it opens the file. Task IDs are pointers, not names — every ID in the statement carries a few words saying what it is.

## Boundaries

This skill changes no file: `git status --short` reads the same before and after a run, and the run makes no commit and touches no clipboard. The statement is not durable state and is not made into any: a status that is wanted somewhere is pasted there by the user, who dates it by pasting. Findings that want action name the owning skill and stop — starting that skill is the user's call, in a session that has read the workstream it will change.
