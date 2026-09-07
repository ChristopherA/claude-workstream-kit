---
name: workstream-extract
description: >-
  Drains an accreting workstream: extracts durable content to permanent homes,
  condenses what is spent, moves completed phases to an in-file archive, and
  re-checks standing-health criteria. The periodic half of closure, for
  workstreams that are not closing.
  WHEN: a workstream.md has accreted — resolved Learnings with no disposition,
  a completed phase, an undispositioned notes.md, durable artifacts still under
  `.state/`, or the session-start hook's SIZE line; also called by
  /workstream-review and /workstream-close.
  WHEN NOT: the workstream is actually closing (use /workstream-close, which
  calls this); the backlog no longer matches what has been decided (that is
  drift — use /workstream-review); capturing one session at a boundary
  (/workstream-capture).
---

# Workstream Extract

A workstream accumulates faster than anyone drains it. Closure drains a workstream once, at the end; the workstreams that need draining most are the ones that never reach it. This is that drain, run on symptoms instead of on an ending: durable content out to permanent homes, spent reasoning condensed, finished phases moved out of the live reader's way, standing criteria re-checked against current evidence. The reason behind each move is in `references/failures.md` under the move's heading; read it when a move is doubted.

Takes an optional `type/name`; bare means the active workstream. Review asks whether the PLAN is right. Extract asks whether the RECORD has been drained. Both are periodic and they fire on different symptoms, so run whichever the symptoms name — neither implies the other.

## When it fires

Not a schedule. `python3 .claude/scripts/workstream-record.py fires <project root> [<type/name>]` names, per workstream, each symptom that holds: a Learning with no disposition marker (resolved or not — the script cannot tell, so read the entry), a completed phase, size past the hook's threshold, a `notes.md` beside the file, a file the kit does not know in the directory, a STANDING criterion unchecked past the interval. The session-start hook prints the same lines. Two symptoms the script cannot see: a durable artifact — a doc, reference material, a spec another project needs — still living under `.state/`, and a file that feels heavy while measuring light. If none holds, say so and stop — a drain that moves nothing means the symptoms were absent, not that the workstream is clean.

## Move 1 — Extract

Every resolved Learning and settled Open Question ends in exactly one of: **applied** to a named file outside `.state/` (cite it; make the edit now if it is missing), **handed off** via `/handoff` (in this run, not "later", and through that skill's own gate, which this skill names and does not pass), or **dropped** with stated rationale, in place. Mark the disposition on the entry itself — a marker at sentence start with a date in its sentence, the form the record script scores — so the next pass can see it. An entry still live stays: dispositioning it early hides open work.

Verify each recorded disposition rather than trusting it, by what it cites:

- A commit: spot-check it; it usually holds.
- A task: aspirational until that task ran.
- A task DESCRIPTION: inside `.state/` however landed it reads, and Move 2 removes exactly that text — a completion note is the only part of a record safe to cite.
- An Open Question: never lands, since an OQ resolves into a decision rather than an artifact — treat it as unrouted and write the substance to a file.
- A file this project does not GOVERN — an installed copy, a generated file, a vendored template: provisional until the change reaches whatever governs the file; verify it there.

Sweep every entry instead of reconstructing where the last pass stopped — an already-applied item simply reads present, so a full pass is self-correcting. Where a named target sits under a dot-directory, `workstream-record.py cites <project root> <needle> --repo` reaches it; a default `rg` sweep skips `.claude/` and returns falsely clean.

Then sweep outward. Findings belonging to OTHER workstreams or projects go to that workstream's Backlog with provenance, or out as a handoff. For anything recorded as absorbed or covered downstream, run `cites` on the DESTINATION: if the receiving task or its criteria do not name it, it is not routed — edit them so they do.

Finally, move durable artifacts out of `.state/` to their permanent homes, and disposition every `notes.md` section — summarized into workstream.md, routed to a named home, or dropped by declaration.

## Move 2 — Condense

Only after Move 1, and the order is load-bearing: trimming before extracting destroys the insight you were about to route, and the trim looks successful either way.

The criterion is whether the content still does work, not its age or completion. A shipped proposal is **spent** — its wording lives where it shipped and its reasoning in its Decision — and condenses to a line naming the proposal, the Decision, and the release. A protocol is **reusable** — it governs the next instance — and survives verbatim. The test is whether a future session would consult it; git holds what the record drops.

- Before condensing any block, run `workstream-record.py cites <project root> <its ID> "<a distinctive phrase of it>"` over the WHOLE state tree — a load-bearing block is CITED BY something still running, a direction invisible from inside the record, and a within-file grep found zero where six citations sat in another workstream's file.
- A Learning carrying a terminal disposition condenses to its statement and its marker: `workstream-rewrite.py learnings <workstream.md>` (dry-run by default, `--write` to apply) does exactly that and leaves every other entry byte-identical — disposition answers whether an entry still owes something, condensation whether it still needs to be read.
- The spent test reaches OPEN lines too: a gate line or long-lived open task accretes status entries of which one is current; condense it by hand to its current agenda and queue, the history living in the Decisions the entries cite — nothing else drains an open line.
- A condensation of GUIDANCE text — a rule, a skill, a template — is verified by a fresh-context read of each instruction and its reason against the original, never by size — the author's own re-read found none of thirteen dropped reasons.
- Mark a superseded Decision in place rather than deleting it — a stale Decision that reads as current is worse than a long file.
- A SHIPPED Decision — its changes in a tagged release, its task records already condensed — condenses to its heading, its reasoning paragraph and a line naming the release, the section restored to numeric order: `workstream-rewrite.py decisions <workstream.md> --decisions D1,D4-D9 --release <tag>`. Which Decisions have shipped is your judgment, named explicitly; the script never infers it. Run `cites` first as above — a condensed Decision keeps its heading, so a citation to it still resolves, and a citation to a paragraph it dropped now resolves to the tag.

Every rewrite the kit ships dry-runs by default, refuses to write when a heading or a checkbox would change, and leaves the full text in git at the commit before; the probes you write yourself read blocks by their leading marker, anchor ID matches to line start, and run one known-positive case through any classification count — `workstream-record.py self-check` fires the record's own patterns.

## Move 3 — Archive completed phases in place

A completed record longer than the rule's completion note condenses to that note — the date, the commit or command that is the evidence, and `reasoning in D<n>` where a Decision holds the why — whether or not its phase is ready to move: `workstream-rewrite.py records <workstream.md>` (dry-run by default, `--write` to apply), which carries a dated marker so a second run is a no-op. Deleting a record loses it and an archive tag hides it, so neither is the instrument. Beyond that, move: add an `## Archive` section at the end of workstream.md and relocate each fully-completed phase's backlog block under it, heading intact, checkboxes and condensed notes in place — the phase stops competing with live work and stays resolvable at its original IDs. Moving text within a file changes no bytes, so this move cannot answer a size signal; condensation can, and the composition report under Record says which one a file needs.

Move a phase only when every task in it is checked — the record's per-phase `done_tasks` and `open_tasks` say which phases qualify — since a partly-archived phase hides work. Bound every scan of the Backlog between `## Backlog` and the next `## ` heading — phase headings and Decision headings are both `### `.

## Move 3b — Rotate a never-closing workstream

When the SIZE line persists after a full drain, the file has outgrown draining, and a never-closing workstream rotates it the way a log rotates rather than splitting the workstream. Tag the current commit `ws/<name>-<YYYY-MM-DD>` (annotated, pushed with the next push the way a closure tag is), then `workstream-rewrite.py rotate <workstream.md> --tag ws/<name>-<date>` (dry-run by default, `--write` to apply) keeps only what is live — the frontmatter and Purpose, open Backlog lines under their headings with the critical-path paragraph, the Decisions a live task, gate, criterion or critical path still cites, deferred and undispositioned Learnings, unresolved Open Questions, the Deletion Criteria with their STANDING marks, every section the kit does not know — and writes one rotation paragraph first under Purpose — `Rotated <date>; the record before it is at ws/<name>-<date>`, with every earlier rotation's tag listed after it newest first, rewritten in place at each rotation rather than stacked — and, when Learnings leave, the numbering note at the head of Learnings saying which L range sits at which tag and what the next Learning is. Nothing leaves history and every ID stays resolvable at the tag. Three checks are the script's, learned from a hand rotation that passed every count while losing content: it refuses when any surviving text or another state file's live content still cites a leaving block — re-point the citing sentence at the tag, or `--keep <phrase>` to carry a block that must stay — a kept block's OWN citations of leaving blocks count too and the report lists them, so expect a second round of re-pointing after a `--keep` rather than reading it as the script contradicting itself — and sweep the frozen provenance outside live content with `cites` yourself; it reports every count a surviving criterion, gate line or critical-path sentence states that the rotation makes false, refusing without `--allow-stale-claims` and amend those claims when you pass it; and it asserts the open count, gate count, STANDING count and open IDs identical. A file with wrapped open lines is refused as non-conforming; reflow it first. Two shapes the checks do not cover, from the first consumer rotation: a dropped block can EXPLAIN tokens that stay — a note inside a leaving Learning saying why L18 to L22 are skipped, which the script's own numbering note (ranges by tag) does not carry — and an explanation is not a citation, so after the rotation grep the new file for every ID a dropped note governed and carry the note back if any is still absent, since a skipped ID with nothing saying why is the collision the note prevented; and a STANDING criterion's superseded HOLDS cycles are spent the way an accreting gate line's entries are (Move 2), so condense them to the newest re-check before measuring — seventeen kilobytes of re-check history once kept a rotated file over the SIZE line the rotation exists to clear.

## Move 4 — Criteria evidence

Re-check each Deletion Criterion against current evidence: file, commit, or command output. In a closing workstream this is the material for the user gate, which stays with `/workstream-close`. In a never-closing one it is the standing-health check the rule requires each cycle and nothing else runs — a criterion that has drifted out of true is the finding, and so is a criterion SATISFIED and unticked: read the Purpose's done condition alongside the criteria — a workstream whose done condition is met is a closure candidate that should not go on accreting follow-on rows. A criterion naming a SET is re-checked over the whole set, never over one instance of it — the narrow scope leaves no trace when it happens to agree.

A criterion satisfied by a downstream gate is satisfied only if that gate names it: check the destination, not the declaration. A note parking an item against a PENDING or WINDING-DOWN destination is a deferral, not a disposition — re-verify each cycle that the destination is still real and reachable.

## Invocation paths

- **From `/workstream-review`**, when the drift scan surfaces accretion symptoms rather than plan drift. Review restructures the backlog; this drains the record. Run both when both sets of symptoms are present.
- **From `/workstream-close`**, as the periodic half of a true close. Closure keeps the narrative summary, the deletion-criteria user gate, the archive, and its own inward sweep; extraction and the outward cascade are this skill. Under a close this is the LAST run: nothing may be deferred, and a disposition naming a future task in the closing workstream is not a disposition, because the tag lands before that task does; one naming an open task in another live workstream whose line names the source is, verified by `cites` on the destination as Move 1 prescribes.
- **From `/workstream-close` on a workstream that should not close.** Closure's own first move turns that request around and sends it here. Expect a file whose bulk is completed records rather than live scope, and expect Move 3 and Move 4 to be the substance of the run.

## Record

Commit the drained state in the session that changes it, and update ACTIVE.md with what moved and what is next. Report what was extracted, what was condensed, what was archived in place, every criterion that failed its re-check, and the file's composition — bytes per section, with the completed-to-open ratio beside the total — since a file that is mostly finished work and still oversized is a condensation backlog while one that is mostly open work is live scope, and the size signal alone cannot tell them apart; "already extracted, still large" is never by itself a reason to split a workstream — a drain that names nothing it moved did not run. Compute the composition rather than estimating it — hand-rolled it came out three different ways in a day:

```sh
python3 .claude/scripts/workstream-record.py <project root> | jq '.workstreams[] | select(.path | endswith("<type>/<name>/workstream.md")) | .composition'
```

`sections` is bytes per `## ` heading, largest first; `checkbox_bytes` counts checkbox BLOCKS (a line and its continuations, to the next blank line or heading), so a completion-note block scores as done.
