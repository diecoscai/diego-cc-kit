#!/bin/bash
# WorktreeRemove Hook - removes a git worktree
# Receives JSON via stdin: {worktree_path|path, ...}
# Exit 0 = removed, Exit 1 = failed

payload=$(cat)
w=$(echo "$payload" | jq -r '.worktree_path // .path // empty')
[ -z "$w" ] && exit 1

root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 1

cd "$root" || exit 1
git worktree remove --force "$w" 2>/dev/null || rm -rf "$w"
