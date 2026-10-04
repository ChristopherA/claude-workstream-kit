#!/bin/sh
# Offline acceptance test for `workstream-record.py git`: the status
# skill's three git reads and, with --tags, the closure reads. Builds a
# repository with a bare clone as its remote: a tag whose commit is
# pushed and whose ref is not (ref-only); a tag on an unpushed commit,
# with the count; an annotated tag, so the ^{} dereference is filtered
# and the remote count is not doubled; a repository with no remote,
# reported as such rather than as every tag dangling; a repository with
# no upstream set and --remote naming the branch. Fixture state is
# asserted before each negative.
set -eu

KIT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$KIT_DIR/.claude/scripts/workstream-record.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/ws-git-test.XXXXXX")
RESULT=0
trap 'rm -rf "$T"' EXIT

check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; RESULT=1; fi; }

git init -q --bare "$T/remote.git"
mkdir -p "$T/work" && cd "$T/work"
git init -q -b main
git config user.email fixture@example.invalid
git config user.name Fixture
git config commit.gpgsign false
# A user config forcing signed or annotated tags would turn the
# lightweight fixture tag into an annotated one and ask for a message.
git config tag.gpgsign false
git config tag.forceSignAnnotated false
mkdir -p .state/workstreams/feature/a
printf -- '---\nworkstream: feature/a\ntask: none\n---\n## Now\nx\n' > .state/ACTIVE.md
printf -- '## Backlog\n- [ ] #A-1: task\n' > .state/workstreams/feature/a/workstream.md
git add -A && git commit -q -m "one"
git remote add origin "$T/remote.git"
git push -q -u origin main
git tag -a ws/pushed-commit -m "annotated, commit pushed, ref not"
git tag ws/on-remote
git push -q origin ws/on-remote
printf -- '- [ ] #A-2: second task\n' >> .state/workstreams/feature/a/workstream.md
git add -A && git commit -q -m "two (unpushed)"
git tag -a ws/unpushed -m "annotated tag on an unpushed commit"
printf 'uncommitted\n' >> .state/ACTIVE.md

python3 "$SCRIPT" git "$T/work" --tags > "$T/out.json"
q() { jq -r "$1" "$T/out.json"; }
tagq() { jq -r ".tags.entries[] | select(.tag == \"$1\") | $2" "$T/out.json"; }

echo "== Sanity"
check "the remote holds main at commit one and only ws/on-remote as a tag" \
  "[ \"\$(git -C $T/remote.git rev-list --count main)\" = 1 ] && [ \"\$(git -C $T/remote.git tag -l)\" = ws/on-remote ]"
check "ws/pushed-commit and ws/unpushed are annotated (cat-file -t is tag)" \
  "[ \"\$(git cat-file -t ws/pushed-commit)\" = tag ] && [ \"\$(git cat-file -t ws/unpushed)\" = tag ]"
check "an unfiltered ls-remote lists the one lightweight tag on the remote once" \
  "[ \"\$(git ls-remote --tags origin 'refs/tags/ws/*' | wc -l | tr -d ' ')\" = 1 ]"

echo "== The three status reads"
check "branch main, upstream origin/main, ahead 1" '[ "$(q ".branch") $(q ".upstream") $(q ".ahead")" = "main origin/main 1" ]'
check "last_commit is set for the workstream file and ACTIVE.md" \
  '[ "$(q "[.files[] | select(.last_commit != null)] | length")" = "2" ]'
check "uncommitted lists ACTIVE.md" '[ "$(q ".uncommitted | join(\",\")")" = " M .state/ACTIVE.md" ]'

echo "== The closure reads"
check "ws/pushed-commit: commit on remote, tag not -- ref-only" \
  '[ "$(tagq ws/pushed-commit "\"\(.commit_on_remote) \(.tag_on_remote) \(.unpushed_commits)\"")" = "true false 0" ]'
check "ws/on-remote: commit and tag both on the remote" \
  '[ "$(tagq ws/on-remote "\"\(.commit_on_remote) \(.tag_on_remote)\"")" = "true true" ]'
check "ws/unpushed: commit not on the remote, carrying 1 unpushed commit" \
  '[ "$(tagq ws/unpushed "\"\(.commit_on_remote) \(.tag_on_remote) \(.unpushed_commits)\"")" = "false false 1" ]'
check "ref_only is exactly ws/pushed-commit and carrying_unpushed exactly ws/unpushed" \
  '[ "$(q ".tags.ref_only | join(\",\")")" = "ws/pushed-commit" ] && [ "$(q ".tags.carrying_unpushed | join(\",\")")" = "ws/unpushed" ]'
check "annotated is reported true for the two annotated tags and false for the lightweight one" \
  '[ "$(tagq ws/pushed-commit .annotated) $(tagq ws/unpushed .annotated) $(tagq ws/on-remote .annotated)" = "true true false" ]'
# Vary one input: push the ref-only tag and it leaves ref_only.
git push -q origin ws/pushed-commit
check "fixture: the unfiltered remote listing now has THREE lines for two tags (the annotated one lists twice, once as ^{})" \
  "[ \"\$(git ls-remote --tags origin 'refs/tags/ws/*' | wc -l | tr -d ' ')\" = 3 ]"
check "after pushing ws/pushed-commit its ref is on the remote and ref_only is empty (the ^{} line did not double it)" \
  '[ "$(python3 "$SCRIPT" git "$T/work" --tags | jq -r ".tags | \"\(.ref_only | length) \(.entries[] | select(.tag == \"ws/pushed-commit\") | .tag_on_remote)\"")" = "0 true" ]'

echo "== Without --tags no remote listing is taken"
check "tags is null without --tags" '[ "$(python3 "$SCRIPT" git "$T/work" | jq -r ".tags")" = "null" ]'

echo "== No upstream set: --remote names the branch"
git branch -q --unset-upstream
check "fixture: no upstream now" "! git rev-parse --abbrev-ref @{upstream} >/dev/null 2>&1"
check "without --remote, ahead is null and upstream null" \
  '[ "$(python3 "$SCRIPT" git "$T/work" | jq -r "\"\(.upstream) \(.ahead)\"")" = "null null" ]'
check "--remote origin compares against origin/<branch>: ahead 1" \
  '[ "$(python3 "$SCRIPT" git "$T/work" --remote origin | jq -r "\"\(.compare) \(.ahead)\"")" = "origin/main 1" ]'
check "--remote origin/main names the branch outright: ahead 1, and --tags still counts ws/unpushed" \
  '[ "$(python3 "$SCRIPT" git "$T/work" --remote origin/main --tags | jq -r "\"\(.ahead) \(.tags.entries[] | select(.tag == \"ws/unpushed\") | .unpushed_commits)\"")" = "1 1" ]'

echo "== No remote configured: reported as such, not as every tag dangling"
git remote remove origin
check "fixture: no remote" "[ -z \"\$(git remote)\" ]"
check "tags.remote is null with the note, entries still list the three tags" \
  '[ "$(python3 "$SCRIPT" git "$T/work" --tags | jq -r "\"\(.tags.remote) \(.tags.note) \(.tags.entries | length)\"")" = "null no remote configured 3" ]'

echo "== Exit codes and a non-repository"
rc=0; python3 "$SCRIPT" git >/dev/null 2>&1 || rc=$?
check "git with no root: exit 2" '[ "$rc" -eq 2 ]'
mkdir -p "$T/norepo/.state"
check "a root that is not a repository reports the error rather than failing" \
  '[ "$(python3 "$SCRIPT" git "$T/norepo" | jq -r ".error")" = "not a git repository" ]'
check "beside the error, uncommitted and files are null, not lists that read as a clean tree" \
  '[ "$(python3 "$SCRIPT" git "$T/norepo" | jq -c "[.uncommitted, .files]")" = "[null,null]" ]'

echo
if [ "$RESULT" -eq 0 ]; then echo "GIT ACCEPTANCE: ALL CHECKS PASS"; else echo "GIT ACCEPTANCE: FAILURES ABOVE"; fi
exit "$RESULT"
