---
name: workstream-create
description: >-
  Creates a workstream: a short interview, then workstream.md and ACTIVE.md
  written from templates and committed.
  WHEN: the user says "create workstream", "new workstream", "/workstream-create",
  or describes multi-session work that needs durable tracking.
  WHEN NOT: single-session tasks (just do them); adding tasks to an existing
  workstream (edit its workstream.md); closing (use /workstream-close).
---

# Workstream Create

Formats and conventions: `.claude/rules/workstreams-rule.md`. Templates: `templates/` in this skill directory.

Before starting, check `.state/workstreams/` for an existing workstream that already covers this work, and the subject's own documentation wherever this project keeps it — a master doc, a design note, a meta directory — because the workstreams are not necessarily where a project's thinking lives: a closure tag holds whatever the closed workstream held, which may be a conformance pass rather than the subject's analysis. If either plausibly covers it, surface it and ask before creating a duplicate.

## Move 1 — Interview

Ask one question at a time, only for ground the request has not already covered, and let each answer shape the next. Required ground:

1. **Purpose** — what this is and what done means. If the answer fits a single session, recommend skipping the workstream.
2. **Type** — explore / feature / fix / project / maintain / docs, and a short kebab-case name.
3. **Deletion criteria** — the verifiable conditions that gate closure. Push for checkable phrasings (artifact exists, test passes, decision documented).
4. **First tasks** — the first phase's tasks plus its `#G-` checkpoint. Don't over-plan: explore/ and maintain/ workstreams discover their scope through practice; an explore/ workstream should reach a user checkpoint within 2-3 sessions — if it can't be phrased that way, propose splitting it. An intake task that waits on another project's output names in its own description what the deliverable must carry: a bare "receive X from Y" reads as tracked on both sides and is not, because the two tasks were written independently and only the receiver knows what the thing has to contain.

Use AskUserQuestion when presenting choices (type, split proposals); use prose for open questions (purpose, criteria).

## Move 2 — Write the files

Create `.state/workstreams/<type>/<name>/workstream.md` from `templates/workstream.md` with the interview content. Load-bearing material from the conversation goes INTO the file (Purpose, Decisions, Open Questions) — never into side files that won't survive.

Update `.state/ACTIVE.md` (template: `templates/ACTIVE.md`): point it at the new workstream with the first task, unless another workstream is currently active — then ask which should be active.

## Move 3 — Review gate

Show the drafted workstream.md by reproducing its content in the message itself. Printing it from a tool call does not show it to anyone: that output is displayed to you and not reliably to the user, so an agent can satisfy "show the draft" to its own eyes and present a gate the user cannot review. A summary of the draft is not the draft — the user is approving specific wording, and paraphrase is exactly what a review gate exists to bypass. Then the user approves or directs edits; iterate until approved.

## Move 4 — Commit

Commit the new state files. Then STOP — never auto-start the first task; the user chooses when work begins (suggest `/workstream-work` when they're ready).
