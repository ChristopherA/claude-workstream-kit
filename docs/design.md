# Design Rationale

Why this kit exists, what the alternatives are, and why it is shaped the way it is. The design was distilled from operating a much larger predecessor system — thousands of lines of rules, multi-phase processes, and sync machinery across many projects — and keeping only what earned its place.

## The problem: sessions end, work doesn't

An agent session is a context window, and context windows are mortal. They end five ways, all routine:

- `/clear` between tasks
- auto-compaction, which replaces history with a summary that rounds off specifics
- a closed terminal, a crash, a timeout
- switching machines
- switching accounts

Multi-session work — features, migrations, audits, research — has state that must outlive all five: what the goal is, what has been decided and *why*, what remains, and what "done" means. When that state lives only in conversation history, each new session reconstructs it from scratch. The visible cost is time and tokens. The quieter cost is drift: a decision made in session three gets remade differently in session nine because nothing recorded the original reasoning.

Durable work state has to satisfy requirements that turn out to be strict:

1. **Survive everything the harness can do** — clear, compact, crash, version upgrade.
2. **Travel with the project** — across machines and accounts, with no service dependency.
3. **Be cheap to read** — by the orchestrating model, by small delegate models, and by shell tools, without parsing machinery.
4. **Carry reasoning, not just status** — decisions with their why, so they don't get re-litigated.
5. **Define done falsifiably** — closure criteria that can be checked with evidence, not vibes.
6. **Name the resume point** — a session that starts cold should know its next action in one read.

Plain markdown files committed to git satisfy all six. Most alternatives satisfy two or three.

## Where the native capabilities stop

Claude Code's built-in capabilities are good at what they target, and this kit deliberately uses them rather than competing with them. The boundary matters:

| Capability | What it covers | Where it stops |
|---|---|---|
| Tasks | step tracking within a session | not stored in your repo; doesn't define multi-session scope or closure |
| Plan mode + plan files | designing an approach before execution | a plan is a session artifact; outcomes belong somewhere durable |
| Memory | lessons and preferences recalled across sessions | account-side, not in the repo; per-fact recall, not a work ledger; doesn't travel with the project |
| /goal | keep-working-until-condition discipline | the condition needs durable state to be derived from and verified against |
| Plugins | distributing capabilities | distribution, not state |

The pattern across the right column: nothing native is **project-scoped, git-versioned, and account-portable**. That intersection is what the kit provides — and only that. Per-session steps still go to Tasks, lessons still go to memory, plans still go to plan mode. One tracker per tier; duplicating any of these in files would create two sources of truth and let one go stale.

## Alternatives, and what they're genuinely good at

**A growing CLAUDE.md.** The path of least resistance: project context accumulates in the always-loaded instructions file. It survives sessions and travels with the repo — but it is *always loaded*, so every past project's worth of "current status" taxes every future session's context window. It has no lifecycle: nothing distinguishes active work from stale notes, nothing closes, nothing gets extracted. CLAUDE.md is the right home for stable conventions; it is the wrong home for work in flight.

**SPEC.md / spec-driven development.** A spec per concern, evolved in place, committed against. Genuinely good: the spec survives as documentation, the pattern is tool-agnostic, and for single-deliverable code work it is often enough. What it lacks is the session-continuity layer — no resume pointer, no record of decisions versus open questions, no closure gate — and it fits poorly when the work is exploration whose deliverable is a *decision* rather than a document.

**Branch-as-workstream, Issues, PRs.** For team code delivery these are the right tools: review flow, notifications, ownership, search. Their state lives service-side — it needs network and auth, doesn't survive offline work, and doesn't fit research or local-only projects. The kit's handoff files note exactly this boundary: file-based handoffs are tuned for a single operator running many local projects; teams should reach for Issues.

**External project management tools.** Durable and shareable, but invisible to the agent without integration work, expensive for it to read, and decoupled from the repo's history. The work ledger ends up describing the code from a distance instead of versioning alongside it.

**Heavyweight bespoke config systems.** The predecessor of this kit: tiered rule sets, multi-phase lifecycle processes, template-sync to propagate updates, compliance scripts to verify the model actually did the steps. It worked — workstreams as a concept proved out there — but most of its mass existed to manage the *model*, not the work: checklists to keep attention from drifting, verification scripts to catch form-without-substance, sync layers that themselves drifted and overwrote local changes. Stronger models invert the economics of all that scaffolding.

## Why two files in git

The kit's entire state model is one `workstream.md` per workstream (purpose, backlog, decisions, learnings, deletion criteria) plus one `ACTIVE.md` per project (what's active, current task, next action, blockers).

- **Git is the durability and portability layer.** Anything the harness does to a session leaves the files untouched; cloning the repo moves the entire work state; the commit history *is* the progress journal, which is why the files don't carry one.
- **Flat frontmatter and checkboxes are the parse layer.** `head` reads the status; `grep -c '^- \[ \]'` counts open tasks; a Haiku-class scout or a `/goal` evaluator can verify state without a YAML library. Cheap reads are what make delegation and autonomous verification practical.
- **Two files is the floor, so two files is the design.** The predecessor used four-plus files per workstream; in practice the extra files held either journal content (git already has it) or session state (one pointer file per project suffices). A workstream.md that outgrows a few hundred lines signals the *workstream* should split, not the file.

## Built for strong models

Newer Claude models follow short, principle-level instructions reliably — and over-prescription actively degrades their output. That finding reshaped every skill in this kit:

- **A step exists only if it produces an artifact or a user decision.** Procedural steps that existed to keep a weaker model on track are gone.
- **No compliance scripts.** The predecessor verified the model's work with snapshot/diff machinery. The kit replaces that with *grounded claims*: a checkbox closes only with cited evidence (a commit, a command's output, a count), which the user can check at the gate.
- **Gates are user-authority moments only** — approving a design, accepting closure — and every gate presents substantive context, never a bare "proceed?".
- **Skills are ~100 lines and self-contained.** No companion process documents, no reference trees.

This was validated directly: in the kit's acceptance tests, fully autonomous sessions ran the create/work/close lifecycle and honored every user-authority constraint — no auto-starting work after creation, no auto-passing checkpoint gates, no self-certified closure — from the skill text alone.

**Spend the strongest model where judgment concentrates.** The delegate agents already price the mechanical work (a Haiku-class scout; Sonnet-class worker and verifier); the main loop is where top-tier cost accrues. Deep re-coherence, design decisions, and gate evidence benefit from the strongest available model at high effort; working a settled backlog runs well a tier down, or at lower effort — on current frontier models, lower effort still outperforms prior generations at full effort. This is operator guidance, not configuration: the kit names no model and works unchanged on whatever the session runs.

## Work should end well

Most tracking systems handle starting and doing; few handle ending. Unclosed work is where knowledge dies — decisions buried in stale files, lessons never extracted, "done" never actually verified. The kit treats closure as a first-class phase:

- **Deletion criteria** are written at creation: falsifiable conditions for archiving the workstream.
- **Closure presents per-criterion evidence** to the user, who decides; the model never self-certifies.
- **Learnings must reach a destination** outside the workstream — applied to a named file, handed off to another project, or dropped with stated rationale — before archive.
- **Archive is a git tag plus one index line**, so closed work stays recoverable and searchable without staying loaded.

The half of closure that never needed an ending — dispositioning learnings, moving artifacts out of the state tree, gathering criteria evidence — is factored into a periodic extract skill, so the workstreams that never close still get it.

## Reviewing artifacts for fitness

Any long-lived artifact — a skill, a rules file, a template, this document — drifts as the ecosystem and the project evolve. Strong models run a fitness review natively from a well-framed request, assembling whatever standards apply; the kit ships no machinery for it. What is worth writing down is the judgment frame:

- **Name the finding**: *fit* (aligned, no action), *drifted* (correct when written; practice moved on), *stale* (references things that no longer exist), *incomplete* (missing something current standards require), or *novel* (an outside pattern the project lacks).
- **Check evolution, not just content**: were decisions made after the artifact's last update that affect it? An artifact can be internally consistent and still wrong about the present.
- **Compare against current standards, not artifact-vs-artifact**: when weighing outside content against your own, both may be stale; the reference point is what is current, not each other.
- **Adapt, never adopt**: external patterns get mapped into the project's own conventions, not pasted in.
- **Every finding gets a disposition** — fixed now, routed to a backlog with a named home, or dismissed with rationale. A finding without a disposition is an untracked gap.

## Autonomous sessions

Durable, mechanically-checkable state is what makes goal-driven autonomy safe. The work skill derives a `/goal` condition from the backlog ("every Build-phase checkbox is checked, each with a committed artifact, and state files are committed"), states blast-radius boundaries (edits and commits proceed; user gates and anything shared-visible stop), and delegates mechanical passes to pinned cheap agents — a read-only scout, a worker that takes bounded packets, a fresh-context verifier that checks the worker's output against its spec. The state files are both the input (condition derivation) and the output (evidence-bearing checkboxes) of that loop.

## What the kit refuses to do

Mature agent configurations die by accretion — more rules, more skills, more machinery, each addition individually reasonable. The kit's last design principle is subtraction:

- **No sync layer.** Updating means re-running `install.sh`. There is nothing to drift.
- **No rule tiers.** One rule, always loaded, under two hundred lines total with the conventions file.
- **No scheduled reflection machinery — reflection fires on signals.** Lessons go to native memory as they occur; a three-question capture sweep (detection, cascade, synthesis) runs at session boundaries and at closure; and two periodic skills fire on symptoms — review when the plan has drifted, extract when the record has accreted. Each earned its place the same way: capture-as-you-go plus closure-only extraction were tried first and provably missed things — synthesis-level insights, cross-workstream cascades, and standing obligations the rule legislated while nothing ran them. What the kit still refuses is the schedule: nothing runs because an interval elapsed, and a session with no symptoms does no reflection. That much clears the bar below; the heavyweight reflection loop the predecessor ran does not.
- **No duplication of native capabilities** — the boundary table above is a commitment, not a current limitation.

If the kit ever needs more than this, the bar for adding it is the same one everything else here had to clear: does it produce an artifact or a user decision that nothing native already produces?
