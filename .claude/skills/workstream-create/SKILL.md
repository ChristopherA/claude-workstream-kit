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

Before starting, check `.state/workstreams/` for an existing workstream that already covers this work — if one plausibly does, surface it and ask before creating a duplicate.

## Move 1 — Interview

Ask one question at a time; let each answer shape the next. Required ground to cover:

1. **Purpose** — what this is and what done means. If the answer fits a single session, recommend skipping the workstream.
2. **Type** — explore / feature / fix / project / maintain / docs, and a short kebab-case name.
3. **Deletion criteria** — the verifiable conditions that gate closure. Push for checkable phrasings (artifact exists, test passes, decision documented).
4. **First tasks** — the first phase's tasks plus its `#G-` checkpoint. Don't over-plan: explore/ and maintain/ workstreams discover their scope through practice; an explore/ workstream should reach a user checkpoint within 2-3 sessions — if it can't be phrased that way, propose splitting it.

Use AskUserQuestion when presenting choices (type, split proposals); use prose for open questions (purpose, criteria).

## Move 2 — Write the files

Create `.state/workstreams/<type>/<name>/workstream.md` from `templates/workstream.md` with the interview content. Load-bearing material from the conversation goes INTO the file (Purpose, Decisions, Open Questions) — never into side files that won't survive.

Update `.state/ACTIVE.md` (template: `templates/ACTIVE.md`): point it at the new workstream with the first task, unless another workstream is currently active — then ask which should be active.

## Move 3 — Review gate

Show the drafted workstream.md. The user approves or directs edits; iterate until approved.

## Move 4 — Commit

Commit the new state files. Then STOP — never auto-start the first task; the user chooses when work begins (suggest `/workstream-work` when they're ready).
