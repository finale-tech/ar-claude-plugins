#!/usr/bin/env bash
# review-pr: create or refresh the review worktree for a PR.
#
# Usage: setup-worktree.sh <REPO_ROOT> <BRANCH> <N>
#
#   REPO_ROOT  local checkout of the PR's repository
#   BRANCH     the PR's headRefName; also the local branch name
#   N          PR number; the code comes from refs/pull/<N>/head on the remote
#
# Worktree: <REPO_ROOT>/.claude/worktrees/<BRANCH>, or .../pr-<N> when the
# branch name is longer than 60 characters.
#
# Exit 0  stdout: one JSON object
#         {"worktree", "branch", "created", "head", "updated"}
# Exit 1  stderr: the reason. Never resets a worktree with uncommitted
#         changes, and never takes over a local branch it did not create.
#
# REVIEW_PR_REMOTE overrides the remote name (default: origin).

set -u

fail() { echo "setup-worktree: $*" >&2; exit 1; }

[ $# -eq 3 ] || fail "usage: setup-worktree.sh <REPO_ROOT> <BRANCH> <N>"
REPO_ROOT="$1"
BRANCH="$2"
N="$3"
REMOTE="${REVIEW_PR_REMOTE:-origin}"

case "$N" in
  ''|*[!0-9]*) fail "PR number must be a positive integer, got '$N'." ;;
esac
[ -n "$BRANCH" ] || fail "branch name is empty."
git check-ref-format --branch "$BRANCH" >/dev/null 2>&1 || fail "'$BRANCH' is not a valid branch name."
[ -d "$REPO_ROOT" ] || fail "repo root does not exist: $REPO_ROOT"

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
TOP="$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null)" || fail "not a git repository: $REPO_ROOT"
[ "$TOP" = "$REPO_ROOT" ] || fail "$REPO_ROOT is inside $TOP; pass the repository root."
git -C "$REPO_ROOT" remote get-url "$REMOTE" >/dev/null 2>&1 || fail "remote '$REMOTE' not found in $REPO_ROOT."

if [ "${#BRANCH}" -gt 60 ]; then
  DIR_NAME="pr-$N"
else
  DIR_NAME="$BRANCH"
fi
WORKTREE="$REPO_ROOT/.claude/worktrees/$DIR_NAME"

# Keep review worktrees out of the main checkout's `git status`
# (local exclude file only; no tracked file changes).
COMMON_DIR="$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
if [ -n "$COMMON_DIR" ]; then
  EXCLUDE="$COMMON_DIR/info/exclude"
  mkdir -p "$COMMON_DIR/info"
  grep -qxF '/.claude/worktrees/' "$EXCLUDE" 2>/dev/null || echo '/.claude/worktrees/' >> "$EXCLUDE"
fi

# Fetch the current PR head (works for forks too: GitHub publishes every PR
# as refs/pull/<N>/head on the base repository).
if ! FETCH_ERR="$(git -C "$REPO_ROOT" fetch --quiet --no-tags "$REMOTE" "+refs/pull/$N/head" 2>&1)"; then
  fail "could not fetch refs/pull/$N/head from '$REMOTE': $FETCH_ERR"
fi
PR_SHA="$(git -C "$REPO_ROOT" rev-parse FETCH_HEAD)" || fail "could not resolve the fetched PR head."

MARKER_KEY="branch.$BRANCH.reviewPr"
created=false
updated=false

git -C "$REPO_ROOT" worktree prune

if [ -e "$WORKTREE" ]; then
  WT_TOP="$(git -C "$WORKTREE" rev-parse --show-toplevel 2>/dev/null)" \
    || fail "$WORKTREE exists but is not a git worktree; remove it and re-run."
  [ "$WT_TOP" = "$WORKTREE" ] || fail "$WORKTREE is not a worktree root; remove it and re-run."
  if [ -n "$(git -C "$WORKTREE" status --porcelain --untracked-files=normal)" ]; then
    fail "worktree $WORKTREE has uncommitted changes; refusing to reset it. Clean it or remove it (git -C $REPO_ROOT worktree remove $WORKTREE), then re-run."
  fi
  CURRENT_BRANCH="$(git -C "$WORKTREE" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [ "$CURRENT_BRANCH" = "$BRANCH" ] \
    || fail "worktree $WORKTREE is on '${CURRENT_BRANCH:-detached HEAD}', expected '$BRANCH'; remove it and re-run."
  OLD_SHA="$(git -C "$WORKTREE" rev-parse HEAD)"
  git -C "$WORKTREE" reset --quiet --hard "$PR_SHA" || fail "could not reset $WORKTREE to $PR_SHA."
  [ "$OLD_SHA" = "$PR_SHA" ] || updated=true
else
  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    OWNER_PR="$(git -C "$REPO_ROOT" config --get "$MARKER_KEY" 2>/dev/null || true)"
    if [ "$OWNER_PR" != "$N" ]; then
      fail "a local branch '$BRANCH' already exists and was not created by review-pr for PR #$N. Review from a clean clone, or rename that branch, then re-run."
    fi
    # Our own branch from an earlier review whose worktree was removed.
    git -C "$REPO_ROOT" worktree add --quiet "$WORKTREE" "$BRANCH" \
      || fail "git worktree add failed for $WORKTREE."
    git -C "$WORKTREE" reset --quiet --hard "$PR_SHA" || fail "could not reset $WORKTREE to $PR_SHA."
  else
    mkdir -p "$(dirname "$WORKTREE")"
    git -C "$REPO_ROOT" worktree add --quiet -b "$BRANCH" "$WORKTREE" "$PR_SHA" \
      || fail "git worktree add failed for $WORKTREE."
    git -C "$REPO_ROOT" config "$MARKER_KEY" "$N"
  fi
  created=true
fi

HEAD_SHORT="$(git -C "$WORKTREE" rev-parse --short HEAD)"

python3 -c 'import json, sys
print(json.dumps({"worktree": sys.argv[1], "branch": sys.argv[2],
                  "created": sys.argv[3] == "true", "head": sys.argv[4],
                  "updated": sys.argv[5] == "true"}))' \
  "$WORKTREE" "$BRANCH" "$created" "$HEAD_SHORT" "$updated"
