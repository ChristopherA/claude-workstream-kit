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
- Git, three reads and no more: the last-commit date of each state file (`git log -1 --format=%ci -- <file>`; the hook's STALE flag uses the narrower last-checkbox-or-Decision commit, and there is no `updated:` field to read); commits ahead of the upstream (`git rev-list --count @{upstream}..HEAD`, or the named remote branch when no upstream is set); and uncommitted state (`git status --short -- .state/`).
- `.state/PROJECT.md`, the project's own list of what is unique to it: skills and context files. For each listed skill, the `description` in the frontmatter of `.claude/skills/<name>/SKILL.md` and nothing else of it; for each listed file, the file. The list exists because a scan cannot tell a skill unique to the project from one copied in from a shared source, and only the unique ones frame a status. Beyond the hook script, the record script and the listed skills' descriptions, nothing outside `.state/` and git is read unless that file lists it — not `CLAUDE.md`, not `README.md`, not the rest of `.claude/`. When the file is absent or its sections are empty, that is a first-class finding in Move 1, with the fill instructions inline: one skill directory name per line under Unique skills, one path per line under Context files. When the sections are empty, Move 1 also OFFERS A DRAFT for the user to confirm or edit, derived at read time from the project's authored `CLAUDE.md` — its Skills table or equivalent, which can tell a project-unique skill from a copied one where a scan of `.claude/skills/` cannot — and that read of `CLAUDE.md` is the one exception to the list above, taken only when the file is empty. The seed's own comment says when empty is correct: every skill present is the kit's, and nothing frames the project beyond `CLAUDE.md`; the draft is then declined, not nagged.

Other projects are out: a handoff this project SENT lives in another project's inbox, and a task that names another project is reported as the reference it is, unresolved.

## Move 1 — Roster and pointer

In main context: run the hook, read ACTIVE.md and PROJECT.md, take the three git reads. Note the workstream count, each status and flag, the inbox count and oldest age, and whether ACTIVE.md's pointer names a workstream and task that exist. This is cheap and bounded, and it is the frame every later move hangs on.

## Move 2 — The record, by script

In main context, run `.claude/scripts/workstream-record.py <project root>`: it prints the record below for every `workstream.md`, plus ACTIVE.md's hold lines and cross-workstream references with its frontmatter skipped, as one JSON object, and needs only python3. The field definitions that follow are the contract the script implements. The format is two-shaped and the script reads both shapes: counts anchor at line start, because backlog lines and deletion criteria are one line each; every prose-bearing field reads a folded BLOCK — a line plus the continuation lines under it — because prose is hard-wrapped, and a field that read one line at a time returned false empties across six consumers at once. The output is small whatever the file's size — the largest file is never read whole — and deterministic, which is what a record has to be before anything is built on it. A scout sent to derive it returns summaries where lines were asked for; delegation belongs in Move 5, where reading beats grep.

The record, per file:

1. **Purpose**: the first sentence under `## Purpose`, and the sentence containing "Done means" or, absent that, the last sentence of the section (`awk '/^## Purpose/{f=1;next} /^## /{f=0} f'`).
2. **Phases**: every `### <Name> (<XX>)` heading under `## Backlog` — text after the code, such as a retirement note, is tolerated, since real files carry it, and so is a multi-code heading such as `(SK / HW)` — each with the open tasks and open gates that SIT UNDER IT, attributed by position and not by code. The per-heading sum plus `tasks_outside_phases` (open lines above the first heading) equals `grep -cE '^ *- \[ \] #'` for the file by construction, so a negative is unrepresentable; two headings carrying one code are two rows. Beside the rows: `codes_without_heading`, the task codes no heading declares, NAMED rather than counted; and `code_heading_mismatches`, each open line whose code the heading above it does not declare — provenance, usually a task moved in with its ID kept, and reported as its own class in Move 4.
3. **First open task**: `grep -nE '^ *- \[ \] #' | head -1`.
4. **Open gates**: `grep -nE '^ *- \[ \] #G-'`, and for each whether its BLOCK — the line and every continuation under it, since a gate accretes agenda and wraps — carries a DATED marker: `SATISFIED <date>`, `READY <date>` or `criterion is met <date>`, the forms the rule names. The date is what separates a marking from a mention: a build note quoting "the SATISFIED sentence" fired the flag on this kit's own gate, and lower-case "satisfied" occurs in ordinary prose about a gate.
5. **Hold lines**: every open task or gate BLOCK (folded), every phase heading under `## Backlog`, the critical-path paragraph and ACTIVE.md's body, matching case-insensitively `held|hold|blocked (by|on)|unblocks when|wait(s|ing)? (for|on)|not before|sequenced after` on boundaries that exclude a hyphen as well as a letter — `hold` sits inside `threshold`, and `Held-out validation` is not a hold — and dropping a match whose clause carries a negation (`Nothing in this file is held by`), since a critical-path paragraph is exactly where a workstream says it is NOT held; with a hundred characters of context either side. A grep asked for that much context can exceed its engine's complexity limit and print nothing; python's `re` does not. This field reaches task bodies, headings and the critical path, and NOT Decisions or completed-task notes: a dependency stated only there is invisible here, which Move 5 says.
6. **Cross-workstream references**: on the same sources, every `(explore|feature|fix|project|maintain)/<name>` and every `ws/<name>` tag — the type not preceded by a letter, digit, dot, slash or hyphen, so the repository `ml-explore/mlx` does not manufacture `explore/mlx`, and the name allowing dots, so `project/omlx-0.4.x-finalize` is captured whole — each with the identifier that precedes it in the block if any (`#[A-Z]+-[0-9]+[a-z]?`, `D[0-9]+`, `L[0-9]+`, `OQ-[0-9]+`). `docs` is left out of the type list because `docs/` also names a directory; add it back only for a project that has a docs-type workstream. A target that is neither a directory under `.state/workstreams/` nor a name in `ARCHIVE.md` belongs to another project and is reported as out of reach in Move 5.
7. **Critical path**: the paragraph beginning `**Critical path`, or the first paragraph under a heading naming the critical path, from that line to the next blank line since it is hard-wrapped, or `not found`. Both forms occur across consumers, and a miss here cascades: the paragraph is also a source for fields 5 and 6.
8. **Latest Decision**: the highest-numbered `### D<n>` heading and the count — the numeric maximum, since the headings are not in file order.
9. **Learnings**: `grep -cE '^- L[0-9]+'`, and each Learning's BLOCK sorted by the marker set the rule publishes beside its Learnings convention: `terminal` counts the ones that have left the file (APPLIED, ROUTED, DROPPED, EXTRACTED, SENT, HANDED OFF, RESOLVED, FULFILLED, VERIFIED, EXTENDED, SUPERSEDED, DISPOSITIONED, DISPOSITION, DONE); `deferred` lists the ones marked as tracked work not yet landed (QUEUED, DEFERRED, PENDING); `undispositioned` lists the rest, as folded text. A deferred Learning is work and an undispositioned one is a gap; they were one total once, and QUEUED scored as nothing.
10. **Deletion criteria**: the counts of `- [ ]` and of `- [x]` lines under `## Deletion Criteria`.
11. **Size**: `wc -c`.
12. **Wrapped lines**: `wrapped_lines.open_items`, the continuation lines sitting under OPEN checkbox lines, at column 0 or indented alike — the conformance detector for the one-line convention, since a wrapped backlog line leaves every line-anchored count correct and every prose-bearing field degraded, which is the violation no count shows; `done_items` counts the same under done lines, where a completion-note block is expected.

And once, for the corpus: **coverage**, the number of files in which each field matched at least once (`phases`, `open_gates`, `gates_satisfied`, `hold_lines`, `cross_refs`, `critical_path`, `learnings`, `learnings_dispositioned`) beside `files`. Read it BEFORE the fields: a field at zero across files that visibly carry the construct is a calibration failure of the instrument, not a finding about the project, and the statement says which it is.

Records are data, not verdicts: a line that reads like a hold but does not match the pattern is not a hold line, and what any occurrence means is decided in Move 3 with the line in view. Check a line number with `sed -n` before citing it.

## Move 3 — Cross-workstream synthesis

In main context, from the records:

- **Edges.** A hold line or cross-workstream reference in A that names a task, Decision, release, or tag in B is an edge from A to B. Read B's record for the named thing's state: open, checked, or absent. A hold naming a task in a workstream whose status is `paused` is a dependency without a date — the rule calls it a wish — and is reported as such rather than as a blocker.
- **Chains.** Each workstream's critical-path paragraph gives its own order; join those orders along the edges. Chains that share no edge are independent.
- **Awaiting the user.** Every open gate, from every workstream, paused ones included. Split out the gates whose line carries satisfied-text from field 4: a gate decided in the record and never presented is the case a roster cannot show, since the checkbox is open and truthful.
- **What each chain is FOR.** For every chain, name the goal it serves and where that goal is recorded — a Purpose paragraph, a Decision, a document PROJECT.md lists — and report `not found` when no source on the list records one, which is itself the finding. A run that recommended a chain on leverage and word-count grounds was dissolved by one question about purpose: the governing direction was a user statement in a file outside the read set, and the number the recommendation optimised had been retired by nobody.
- **Priority is not derived.** The files carry dependency order and never priority among independent chains. Present the chains side by side, in no order, and say when ACTIVE.md's pointer sits on none of their heads. Do not infer priority from recency, size, or the pointer, and do not ask: the gap is itself a finding.
- **A premise the statement repeats is marked where it appears.** A claim about the world that a state file asserts — "two skills declare the same name", "introduced in <sha>" — is repeated with its source beside it, inline (`asserted by <file>, unverified here`), never disclaimed twenty lines later in the closing section, which does not reach a reader who skimmed to the roster. The skill does not verify it: that would make a read-only skill a verifying one.

## Move 4 — Disagreements

A synthesis exists to surface the places where the files disagree, because no single-workstream skill can see them. Check each class below across every record, on open lines, critical-path paragraphs and ACTIVE.md — a completed line's references are frozen provenance and are not checked; report every hit with both sources quoted (file and line each) and the skill that owns the fix. Label each hit MECHANICAL (a rotted pointer, a stale status, a count that re-derives differently — no judgment in it) or DECISION (wants a choice), and for a mechanical one whose evidence is line-scoped and already cited, carry the EXACT EDIT — file, line, old text, new text — so the owning session applies it without re-deriving anything. Labelling is not resolving and carrying an edit is not applying it: the boundary stays absolute. Resolve none.

1. ACTIVE.md's `workstream:` names a directory the roster lacks, or its `task:` names an ID with no open line in that workstream (checked, or absent). Owner: `/workstream-capture`.
2. A hold line names a task in a workstream whose `status:` is `paused`. Owner: `/workstream-review` in the holding workstream.
3. An open gate line carries satisfied-text. Owner: the next session in that workstream presents the gate; `/workstream-review` if the backlog accreted behind it.
4. A cross-workstream reference names a home that exists and does not contain the ID, or names a closed workstream by name rather than by its archive tag. Owner: `/workstream-review` in the referring workstream.
5. Every deletion criterion is checked, or the done condition reads as met, while `status:` is `active`. Owner: `/workstream-close`.
6. ACTIVE.md's Blockers names a workstream with nothing there matching the named thing — no open task, and no standing obligation of a never-closing workstream such as its drain or review. Owner: `/workstream-capture`.
7. Two workstreams claim the same next release, version, or artifact. Owner: `/workstream-review` in each.
8. `.state/PROJECT.md` lists a skill with no `.claude/skills/<name>/SKILL.md`, or a file that does not exist. Owner: the user, by editing that list.
9. A hold line or a critical-path paragraph names, as next or as the thing it waits on, a task or gate that is already checked. The paragraph reads as current because nothing marks the moment it stopped being. Owner: `/workstream-review` in that workstream.
10. A workstream's record names a code with no heading (`codes_without_heading`) or an open line whose code its heading does not declare (`code_heading_mismatches`) — usually a task moved in with its ID kept and no heading added for it. Provenance is unreadable there, not the arithmetic. Owner: `/workstream-review` in that workstream, which adds the heading.
11. A workstream's critical-path paragraph is OLDER than a task minted in that workstream: compare the paragraph's last-modified date (`git blame --date=short -L <first>,<last> -- <file>`, newest line) against each open task's mint date (`git log --reverse --format=%cs -S'#XX-N:' -- <file> | head -1`). A path decays against tasks written after it — a scope claim made at 14:15 was falsified by three tasks minted that afternoon, one carrying the workstream's only hard date — and class 9 sees only a path naming a CHECKED task. The date comparison needs no view on what the paragraph means. Owner: `/workstream-review` in that workstream.

Cross-project findings — a reference into another project, a handoff whose sender has moved on — are named as out of reach; `/handoff` is the route when they need action.

## Move 5 — The statement

Chat, in this shape and this order, and nothing written anywhere:

1. **One paragraph.** What this project is, from PROJECT.md's list and the count of workstreams; what is moving (the workstreams whose git date falls in the last week); what is waiting (gates and holds, by count). Where PROJECT.md is empty the paragraph says so instead of inventing a description.
2. **Roster.** One row per workstream: name, status, open tasks and gates, the first open task trimmed to a clause, and any flag (SIZE, STALE, ahead of remote, uncommitted). Every workstream appears here once and reappears below only in a chain, a gate, or a disagreement.
3. **Critical paths across workstreams.** Each chain as an ordered list of tasks with their workstream, and for each join the edge that makes it (file and line). Independent chains side by side. The sentence about the pointer.
4. **Awaiting the user.** Satisfied-but-unpresented gates first, then the rest, each with its workstream and the decision it asks for in words rather than codes.
5. **Disagreements.** Each with both texts and the owner.
6. **What this could not see.** Sources on the list that were absent or unreadable, a cited line the verifier could not open, references into other projects, and the standing gap: priority among independent chains. Say what the record did NOT scan, so the frame's edge does not pass as a verdict: hold lines and cross references reach open task blocks, phase headings, the critical path and ACTIVE.md, and never Decisions or completed-task notes — a project reported zero holds across ten files carrying 150 occurrences of the vocabulary, every dependency that mattered living in a Decision. Where `coverage` shows a field at zero across files that visibly carry its construct, say that the instrument, not the project, is what the zero describes.

Before the statement is delivered, two checks are MANDATORY in main context: re-derive every roster count by command, and validate the instrument — fire the hold pattern at one line known to carry a hold and one known not to, and read `coverage` — before trusting any zero you are about to report, since "no holds in this project" was once about to ship over six. Then hand the statement and the records to one fresh-context `scout` with this packet verbatim, scoped to the citations whose text CARRIES A CLAIM (a citation that merely locates a task the roster already counted is verified by the count): "Here is a status statement and the records it was built from. For every file and line the statement cites, open that line and report MATCH or the line's actual text; then report what SURROUNDS it that the citation does not mention — a continuation of the same task line, a later dated paragraph in the same section — since a true line can carry a false inference when the extraction that fed it stopped early. Report any occurrence you notice outside the citation list as output, named, not as noise. Report occurrences only, never a verdict on the statement." A citation that comes back as anything but MATCH is corrected or dropped before delivery. This is where a sub-agent earns its place: reading a cited line against a claim is the check a grep cannot make.

Bound the length by leaving things out, not by compressing: a workstream's detail beyond its next task and its gates does not belong here, and a reader who wants it opens the file. Task IDs are pointers, not names — every ID in the statement carries a few words saying what it is.

## Boundaries

This skill changes no file: `git status --short` reads the same before and after a run, and the run makes no commit and touches no clipboard. The statement is not durable state and is not made into any: a status that is wanted somewhere is pasted there by the user, who dates it by pasting. Findings that want action name the owning skill and stop — starting that skill is the user's call, in a session that has read the workstream it will change.
