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

Every other skill takes one workstream and the hook prints one line per workstream; the only cross-workstream prose is ACTIVE.md's Now, written by hand by whoever last remembered to. This skill is the read the roster is too narrow for and the hand-written paragraph too unreliable for: it reads every workstream and says what runs across them. It is read-only and on demand: it writes nothing, resolves nothing (a disagreement is reported with both texts and the skill that owns the fix), asks nothing (what it cannot derive it names as a gap), and takes no argument (the project is the unit). The reason behind each move is in `references/failures.md` under the move's heading; read it when a move is doubted.

## Sources

This is the complete list. Anything not on it is not read, and the statement's last section says which of these could not be read.

- Every `.state/workstreams/*/*/workstream.md`, whatever its `status:` says — a paused one is the exposed case, unread and the most likely to be cited from elsewhere.
- `.state/ACTIVE.md`.
- `.state/workstreams/ARCHIVE.md`, for resolving references to closed workstreams.
- `.state/handoffs/*.md`, the inbox.
- The roster, re-derived by running `.claude/hooks/session-start.sh` with `CLAUDE_PROJECT_DIR` set to the project root — never recalled from the transcript, which is a session old at best.
- Git, through `python3 .claude/scripts/workstream-record.py git <project root>` and no more: `files[]`, each with `path` and `last_commit`; `ahead`, the commits past the upstream (`compare` says which branch, `--remote <name>` when no upstream is set); and `uncommitted[]`, the `git status` lines under `.state/`.
- `.state/PROJECT.md`, the project's list of what is unique to it — skills and context files — because a scan cannot tell a project-unique skill from a copied one, and only the unique ones frame a status. For each listed skill only the `description` in its SKILL.md frontmatter; for each listed file, the file. Beyond the hook, the record script and those descriptions, nothing outside `.state/` and git is read unless that file lists it — not `CLAUDE.md`, `README.md` or the rest of `.claude/`. An absent file or empty sections is a first-class finding in Move 1, with the fill instructions inline (one skill directory name per line under Unique skills, one path per line under Context files); when the sections are EMPTY, Move 1 also offers a DRAFT for the user to confirm or edit, derived at read time from the project's authored `CLAUDE.md` — the one exception to the read list, taken only then. The seed's own comment says when empty is correct; then the draft is declined, not nagged.

Other projects are out: a handoff this project SENT lives in the receiver's inbox, and a task naming another project is reported as an unresolved reference.

## Move 1 — Roster and pointer

In main context: run the hook, read ACTIVE.md and PROJECT.md, take the git reads. Note the workstream count, each status and flag, the inbox count and oldest age, and whether ACTIVE.md's pointer names a workstream and task that exist. Cheap, bounded, and the frame every later move hangs on.

## Move 2 — The record, by script

In main context, run `python3 .claude/scripts/workstream-record.py record <project root>`: one JSON object carrying the record for every `workstream.md` plus ACTIVE.md's hold lines and cross-workstream references. The script is the contract: its docstring and its suite define every field, and the fields read the file's two shapes — counts anchored at line start, prose fields over folded blocks — so a wrapped construct is not a false empty. Its output is small and deterministic whatever the file's size, which a record has to be before anything is built on it. A scout sent to derive it returns summaries where lines were asked for; delegation belongs in Move 5.

Read the record in this order:

- **`coverage` first**: the number of files in which each field matched at least once. A field at zero across files that visibly carry the construct is a calibration failure of the instrument, not a finding about the project, and the statement says which it is.
- **The fields**: `purpose`, `phases` (position-keyed, with `codes_without_heading` NAMED and `code_heading_mismatches` listed), `first_open_task`, `open_gates` with `satisfied_text` (the DATED marker only — a bare mention does not mark), `hold_lines` (each hit is `line`, `match` — the hold verb — and `context`, the sentence around it: a hold verb WITH ITS OBJECT, struck spans blanked, negated clauses dropped), `cross_refs` (each hit is `line`, `target`, `kind` — workstream or tag — and `preceding_id`, the ID the target homes; a target that is neither a directory under `.state/workstreams/` nor a name in `ARCHIVE.md` belongs to another project and is reported as out of reach in Move 5), `critical_path`, `latest_decision` (the numeric maximum), `learnings` (terminal, deferred and undispositioned apart, by the dated sentence-start marker rule), `deletion_criteria` (STANDING lines apart, with their oldest HOLDS), `size_bytes`, `wrapped_lines` (the conformance detector: continuations under OPEN lines), `composition`.
- **What the record does NOT reach**: hold lines and cross references cover open task blocks, phase headings, the critical path and ACTIVE.md, never Decisions or completed-task notes — a dependency stated only there is invisible here, which Move 5 says.

Records are data, not verdicts: a line that reads like a hold but does not match the pattern is not a hold line, and what any occurrence means is decided in Move 3 with the line in view. Check a line number with `sed -n` before citing it.

## Move 3 — Cross-workstream synthesis

In main context, from the records:

- **Edges.** A hold line or cross-workstream reference in A that names a task, Decision, release, or tag in B is an edge from A to B. Read B's record for the named thing's state: open, checked, or absent. A hold naming a task in a workstream whose status is `paused` is a dependency without a date — the rule calls it a wish — and is reported as such rather than as a blocker.
- **Chains.** Each workstream's critical-path paragraph gives its own order; join those orders along the edges. Chains that share no edge are independent.
- **Awaiting the user.** Every open gate, from every workstream, paused ones included. Split out the gates whose `satisfied_text` is true — a gate decided in the record and never presented is the case a roster cannot show, since the checkbox is open and truthful.
- **What each chain is FOR.** For every chain, name the goal it serves and where it is recorded — a Purpose, a Decision, a document PROJECT.md lists — and report `not found` when no listed source records one, which is itself the finding — a chain once dissolved at one question about purpose.
- **Priority is not derived.** The files carry dependency order and never priority among independent chains. Present the chains side by side, in no order, and say when ACTIVE.md's pointer sits on none of their heads. Do not infer priority from recency, size, or the pointer, and do not ask: the gap is itself a finding.
- **A premise the statement repeats is marked where it appears** — `asserted by <file>, unverified here`, inline, never disclaimed twenty lines later. The skill does not verify it; that would make a read-only skill a verifying one.

## Move 4 — Disagreements

No single-workstream skill can see where the files disagree; this move can. Check each class below across every record — open lines, critical-path paragraphs and ACTIVE.md; a completed line's references are frozen provenance and are not checked — and report every hit with both sources quoted (file and line each) and the skill that owns the fix. Label each MECHANICAL (no judgment in it) or DECISION (wants a choice), and for a mechanical hit whose evidence is line-scoped and cited, carry the EXACT EDIT — file, line, old text, new text — so the owning session applies it without re-deriving. Labelling is not resolving and carrying an edit is not applying it. Resolve none.

1. ACTIVE.md's `workstream:` names a directory the roster lacks, or its `task:` names an ID with no open line in that workstream (checked, or absent). Owner: `/workstream-capture`.
2. A hold line names a task in a workstream whose `status:` is `paused`. Owner: `/workstream-review` in the holding workstream.
3. An open gate line carries satisfied-text. Owner: the next session in that workstream presents the gate; `/workstream-review` if the backlog accreted behind it.
4. A cross-workstream reference names a home that exists and does not contain the ID, or names a closed workstream by name rather than by its archive tag: `workstream-record.py refs <project root>` lists the first as `homed_home_lacks`; the second arrives as `homed_home_missing`, and which of those are closed workstreams is read against `ARCHIVE.md` by hand, since the script does not read the ledger. Owner: `/workstream-review` in the referring workstream.
5. Every deletion criterion is checked, or the done condition reads as met, while `status:` is `active`. Owner: `/workstream-close`.
6. ACTIVE.md's Blockers names a workstream with nothing there matching the named thing — no open task, and no standing obligation of a never-closing workstream such as its drain or review. Owner: `/workstream-capture`.
7. Two workstreams claim the same next release, version, or artifact. Owner: `/workstream-review` in each.
8. `.state/PROJECT.md` lists a skill with no `.claude/skills/<name>/SKILL.md`, or a file that does not exist. Owner: the user, by editing that list.
9. A hold line or a critical-path paragraph names, as next or as the thing it waits on, a task or gate that is already checked — the paragraph reads as current because nothing marks the moment it stopped being. Owner: `/workstream-review` in that workstream.
10. A workstream's record names a code with no heading (`codes_without_heading`) or an open line whose code its heading does not declare (`code_heading_mismatches`) — usually a task moved in with its ID kept and no heading added for it. Owner: `/workstream-review` in that workstream, which adds the heading.
11. A workstream's critical-path paragraph is OLDER than a task minted in that workstream: `workstream-record.py decay <project root>` compares the paragraph's newest commit timestamp against each open task's mint timestamp and lists every task minted after it — timestamps, not dates, since a path re-derived at a morning gate was false by evening; class 9 sees only a path naming a CHECKED task. A path that names no task (`shape: queue` — "queue -> gate -> build -> release", order by design) is reported with only the COUNT minted since, as what the paragraph predicts rather than drift: state the count and name no owner, since a review cannot act on it. Owner otherwise: `/workstream-review` in that workstream.
12. A workstream with open tasks and no critical-path paragraph (`critical_path` is `not found`): Move 3 has nothing to chain for it, and the roster cannot say so. Owner: `/workstream-review` in that workstream, whose Move 5 writes the order-only note.

Cross-project findings — a reference into another project, a handoff whose sender has moved on — are named as out of reach; `/handoff` is the route when they need action.

## Move 5 — The statement

Chat, in this shape and this order, and nothing written anywhere:

1. **One paragraph.** What this project is, from PROJECT.md's list and the count of workstreams; what is moving (the workstreams whose git date falls in the last week); what is waiting (gates and holds, by count). Where PROJECT.md is empty the paragraph says so instead of inventing a description.
2. **Roster.** One row per workstream: name, status, open tasks and gates, the first open task trimmed to a clause, and any flag (SIZE, STALE, ahead of remote, uncommitted). Every workstream appears here once and reappears below only in a chain, a gate, or a disagreement.
3. **Critical paths across workstreams.** Each chain as an ordered list of tasks with their workstream, and for each join the edge that makes it (file and line). Independent chains side by side. The sentence about the pointer.
4. **Awaiting the user.** Satisfied-but-unpresented gates first, then the rest, each with its workstream and the decision it asks for in words rather than codes.
5. **Disagreements.** Each with both texts and the owner.
6. **What this could not see.** Sources on the list that were absent or unreadable, a cited line the verifier could not open, references into other projects, and the standing gap: priority among independent chains. Say what the record did NOT scan, so the frame's edge does not pass as a verdict — a project once reported zero holds across files carrying 150 occurrences of the vocabulary, every dependency that mattered living in a Decision. Where `coverage` shows a field at zero across files that visibly carry its construct, say that the instrument, not the project, is what the zero describes.

Before delivery, two checks are MANDATORY in main context: re-derive every roster count by running the hook and `record` and comparing, and validate the instrument — `workstream-record.py self-check` fires every pattern the record uses at a known-positive and a known-negative, and `coverage` is read — before trusting any zero you are about to report — "no holds in this project" was once about to ship over six. Then hand the statement and the records to one fresh-context `scout` with this packet verbatim, scoped to the citations whose text CARRIES A CLAIM (a citation that merely locates a task the roster already counted is verified by the count): "Here is a status statement and the records it was built from. For every file and line the statement cites, open that line and report MATCH or the line's actual text; then report what SURROUNDS it that the citation does not mention — a continuation of the same task line, a later dated paragraph in the same section — since a true line can carry a false inference when the extraction that fed it stopped early. Report any occurrence you notice outside the citation list as output, named, not as noise. Report occurrences only, never a verdict on the statement." A citation that comes back as anything but MATCH is corrected or dropped before delivery; reading a cited line against a claim is the check a grep cannot make.

Bound the length by leaving things out, not by compressing: detail beyond a workstream's next task and gates belongs in its file. Task IDs are pointers, not names — every ID in the statement carries its gloss in the rule's canonical form, `#EX-37 (the phase split question)`, and the check is a command, not a re-read: pipe the finished statement through `python3 .claude/scripts/workstream-record.py bare-ids --stdin --text` before the scout pass and gloss every mention it lists; the statement is delivered only when that prints nothing. A gloss is written for the reader of the statement, not copied from the task line.

## Boundaries

This skill changes no file: the only tool it runs, `workstream-record.py`, has no write path, so `git status --short` reads the same before and after by construction; no commit, no clipboard. The statement is not durable state and is not made into any; a status wanted somewhere is pasted there by the user, who dates it by pasting. Findings that want action name the owning skill and stop — starting it is the user's call, in a session that has read the workstream it will change.
