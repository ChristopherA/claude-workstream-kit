---
name: workstream-upgrade
description: >-
  Upgrades the installed claude-workstream-kit in this project from a kit
  checkout: refresh the checkout, preview with install.sh --dry-run, stop
  on any locally edited payload file, stash uncommitted work AFTER the
  preview, apply, commit the kit-owned changes, restore the stash.
  WHEN: the session-start hook's `Kit:` line reports the installed
  version behind the kit checkout's; the user says "/workstream-upgrade",
  "upgrade the kit", "update the workstream kit".
  WHEN NOT: a first install (run install.sh from the checkout, README,
  Install); upgrading the kit's own checkout (that is a git pull there);
  porting a local payload edit back into the kit (report it as an issue
  on the kit repository first, README, Reporting a gap).
---

# Workstream Upgrade

Upgrading is re-running `install.sh` from a newer kit checkout (README, Upgrading). This skill is the order around that one command, and every step in it exists because the obvious order once lost work. Show the evidence at each step, and STOP and show the user rather than guess when anything is not what the step expects.

## Move 1 — Locate the kit checkout

The path comes from `WORKSTREAM_KIT_DIR` in `.claude/settings.json`'s `env`, which `install.sh` recorded when it last ran; an argument the user gives wins over it. If neither names a directory holding `install.sh` and `VERSION`, stop and ask where the checkout is or whether to clone `github.com/ChristopherA/claude-workstream-kit` -- never clone to a path the user did not name, since the recorded path is what every later upgrade reads.

## Move 2 — Refresh the checkout

- `git -C <kit> status --short`. If it is not clean, show the changes and ask before touching it: the user may be working on the kit itself.
- If clean, `git -C <kit> pull --ff-only`. Report the commit before and after and the resulting `VERSION`. A pull that is not a fast-forward means the checkout diverged; stop and show it rather than merge or rebase on the user's behalf.
- A checkout carrying commits past its last tag is an unreleased build; the hook's `Kit:` line says so. Upgrading a project to one is the user's call, said out loud.

## Move 3 — Confirm the target

The target is this project's root, `git rev-parse --show-toplevel`. Show the path. It should carry `.claude/workstream-kit.version`; if it does not, this is a first install rather than an upgrade -- say so and confirm before continuing.

## Move 4 — Preview, writing nothing

Run `sh <kit>/install.sh --dry-run <project root>` and show the whole report (README, What the dry run reports). The preview's exit code is part of the report, not a failure: 0 in sync, 1 drift or a behind stamp (the expected code before any upgrade), 2 usage, 3 a payload the target's git cannot track — so never chain it with `&&`, and read the code as a finding. Then act on it:

- **In sync** -- nothing to upgrade. Report that and stop.
- Any file marked **instance-ahead** -- STOP. It was edited locally and matches no kit version, so a real run would overwrite a local improvement; the installer refuses, and `--force` would not. List each and ask how to handle it (report it to the kit and port it, or discard the local edit) before applying anything.
- Only **instance-behind**, **would create**, **stamp-behind** and no-op merges -- a safe upgrade. Continue.

## Move 5 — Stash uncommitted work, then apply

`git status --short` in the project. If anything is uncommitted, `git stash push -u -m "pre-kit-upgrade"` and report what went in; an empty tree needs no stash, so say that rather than stashing nothing.

The order is load-bearing: **the stash comes after the preview, never before it.** The dry run's instance-ahead classification is the only thing that surfaces a payload file someone edited locally, and an uncommitted edit is exactly the case it must catch. Stash first and the report comes back clean, the upgrade lands, and the pop drops a stale edit on top of new payload with nothing having noticed. Stash even though the installer refuses to overwrite a locally modified payload file, because that refusal's escape hatch is `--force`, which is safe only against COMMITTED content: a discarded uncommitted edit has no commit to cite and nothing to say it existed.

Then `sh <kit>/install.sh <project root>`. It copies the payload, merges the hook registration and the kit path into `settings.json`, and re-stamps `workstream-kit.version` and `workstream-kit.source`. Existing `.state/` is never overwritten; a seed file that is missing (`.state/PROJECT.md` most often) is restored AND STAGED, so expect it in the index afterwards.

Several projects in one pass do this per project -- stash, apply, commit, restore, then the next. Never carry one stash across two repositories.

## Move 6 — Review and commit the kit-owned changes

- Show `git status --short` and the diff to `.claude/`.
- `git add -A -- .claude` first: a release that adds a skill leaves new files untracked, and a pathspec commit skips untracked files.
- Commit ONLY what the kit owns: the `.claude/` payload directories, the kit block in `CLAUDE.md`, `settings.json`, the two stamp files, and any seed file the installer staged (it prints each as `staged .state/...`). With the stash in place the tree should hold nothing else; anything beyond that is shown to the user, not committed around.
- Message: `Upgrade claude-workstream-kit to <version> (<source sha>)`, in the repository's own commit conventions.
- Do not push; that is a separate decision.

## Move 7 — Restore the stash

`git stash pop`, then `git status --short` to confirm the work came back. A conflict here is a finding rather than a nuisance: the stashed work touched a file the upgrade also changed, which is a locally edited payload file that never reached the kit. Resolve it, then route the edit to the kit as an issue rather than re-applying it in place, or the same conflict returns at every upgrade.

The session-start hook and the skills are read at the next session start and the next invocation, so a session that upgraded itself keeps running on the old text until then; say so.
