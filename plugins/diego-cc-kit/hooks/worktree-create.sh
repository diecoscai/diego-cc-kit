#!/bin/bash
# WorktreeCreate Hook - creates a git worktree for isolated agent work
# Receives JSON via stdin: {branch_name|branch|ref, worktree_path|path, ...}
# Exit 0 = worktree created, Exit 1 = failed (reason on stderr)

payload=$(cat)
b=$(echo "$payload" | jq -r '.branch_name // .branch // .ref // empty')
w=$(echo "$payload" | jq -r '.worktree_path // .path // empty')

if [ -z "$b" ] || [ -z "$w" ]; then
    echo "WorktreeCreate: missing branch or path in payload" >&2
    exit 1
fi

root=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$root" ]; then
    echo "WorktreeCreate: cwd $(pwd) is not a git repo" >&2
    exit 1
fi

cd "$root" || exit 1

if git show-ref --verify --quiet "refs/heads/$b"; then
    # Branch already exists - attach a worktree to it (no -b).
    err=$(git worktree add "$w" "$b" 2>&1) && exit 0
    if echo "$err" | grep -qi "already used by worktree\|already checked out"; then
        echo "WorktreeCreate: branch '$b' is already checked out in another worktree" >&2
    else
        echo "WorktreeCreate: failed to add worktree for existing branch '$b': $err" >&2
    fi
    exit 1
fi

git worktree add -b "$b" "$w"
