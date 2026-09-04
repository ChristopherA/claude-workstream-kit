#!/bin/sh
# Acceptance test for the .state/ seed contract (README: "existing .state/ is
# never touched"): a fresh target receives each seeded file byte-identical to
# the kit's seed, and a re-install leaves a present file byte-identical to
# what the project had. Pure shell -- no Claude session. Run from anywhere:
#   sh tests/state-seed-acceptance.sh
#
# The present-file case is fired against content that DIFFERS from the seed,
# and that difference is asserted before the second run: an overwrite that
# reproduced the seed would otherwise pass as a no-op.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RESULT=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/proj"
KEEP="$WORK/keep"
mkdir -p "$PROJ" "$KEEP/workstreams"

SEEDED="ACTIVE.md PROJECT.md workstreams/ARCHIVE.md"

echo "== Run 1: a fresh target is seeded from the kit"
"$KIT_DIR/install.sh" "$PROJ" >/dev/null 2>&1
for f in $SEEDED; do
  check "run 1 seeds .state/$f"                 "[ -f \"$PROJ/.state/$f\" ]"
  check "run 1 .state/$f matches the kit seed"  "cmp -s \"$KIT_DIR/.state-seed/$f\" \"$PROJ/.state/$f\""
done
check "run 1 seeds the handoff inbox" "[ -f \"$PROJ/.state/handoffs/.gitkeep\" ]"

echo "== Fixture: the project's files now differ from the seed"
for f in $SEEDED; do
  printf '\nproject-owned line that the seed does not contain\n' >> "$PROJ/.state/$f"
  cp "$PROJ/.state/$f" "$KEEP/$f"
  check "fixture: .state/$f differs from the seed" "! cmp -s \"$KIT_DIR/.state-seed/$f\" \"$PROJ/.state/$f\""
done

echo "== Run 2: a re-install leaves present state byte-identical"
"$KIT_DIR/install.sh" "$PROJ" >/dev/null 2>&1
for f in $SEEDED; do
  check "run 2 leaves .state/$f byte-identical" "cmp -s \"$KEEP/$f\" \"$PROJ/.state/$f\""
done

echo "== Run 3: a missing seeded file is restored without touching its siblings"
rm -f "$PROJ/.state/PROJECT.md"
check "fixture: .state/PROJECT.md is absent" "[ ! -f \"$PROJ/.state/PROJECT.md\" ]"
"$KIT_DIR/install.sh" "$PROJ" >/dev/null 2>&1
check "run 3 re-seeds .state/PROJECT.md from the kit" "cmp -s \"$KIT_DIR/.state-seed/PROJECT.md\" \"$PROJ/.state/PROJECT.md\""
check "run 3 leaves .state/ACTIVE.md byte-identical" "cmp -s \"$KEEP/ACTIVE.md\" \"$PROJ/.state/ACTIVE.md\""

echo "== Run 4: in a git target, the seeded files are STAGED; a tracked, edited file is not"
GP="$WORK/gitproj"
mkdir -p "$GP"
git -C "$GP" init -q -b main
git -C "$GP" config user.name "kit tests"; git -C "$GP" config user.email "tests@example.invalid"
git -C "$GP" config commit.gpgsign false
"$KIT_DIR/install.sh" "$GP" >/dev/null 2>&1
STAGED=$(git -C "$GP" diff --cached --name-only)
for f in $SEEDED; do
  check "run 4 stages .state/$f" "printf '%s\n' \"\$STAGED\" | grep -qx \".state/$f\""
done
check "run 4 stages the inbox .gitkeep" "printf '%s\n' \"\$STAGED\" | grep -qx '.state/handoffs/.gitkeep'"
check "run 4 stages nothing outside .state/ (the payload is the user's to scope)" "! printf '%s\n' \"\$STAGED\" | grep -qv '^\.state/'"
git -C "$GP" commit -q -m 'seed' -- .state
printf '\nlocal edit after commit\n' >> "$GP/.state/ACTIVE.md"
check "fixture: ACTIVE.md is tracked and modified in the worktree" "git -C \"$GP\" status --short -- .state/ACTIVE.md | grep -q '^ M'"
"$KIT_DIR/install.sh" "$GP" >/dev/null 2>&1
check "run 4 re-install does NOT stage the tracked, edited ACTIVE.md" "git -C \"$GP\" status --short -- .state/ACTIVE.md | grep -q '^ M'"
check "run 4 re-install leaves the index empty" "[ -z \"\$(git -C \"$GP\" diff --cached --name-only)\" ]"
rm -f "$GP/.state/PROJECT.md"; git -C "$GP" rm -q --cached .state/PROJECT.md
git -C "$GP" commit -q -m 'untrack PROJECT.md' -- .state/PROJECT.md
printf '.state/PROJECT.md\n' > "$GP/.gitignore"
"$KIT_DIR/install.sh" "$GP" >/dev/null 2>&1
check "run 4 re-seeds an ignored PROJECT.md but does not stage it" "[ -f \"$GP/.state/PROJECT.md\" ] && ! git -C \"$GP\" diff --cached --name-only | grep -q 'PROJECT.md'"

[ "$RESULT" -eq 0 ] && echo "ALL PASS" || echo "SOME FAIL"
exit "$RESULT"
