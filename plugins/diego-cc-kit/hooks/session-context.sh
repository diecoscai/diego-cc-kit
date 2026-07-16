#!/usr/bin/env bash
# SessionStart hook — inject dynamic git context (branch + working-tree summary
# + recent commits) when the session starts inside a git repo. No-op elsewhere.
# Must never fail the session (always exit 0).
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$branch" ] && exit 0

porcelain=$(git status --porcelain 2>/dev/null)
total=$(printf '%s' "$porcelain" | grep -c .)
untracked=$(printf '%s' "$porcelain" | grep -c '^??')
changed=$((total - untracked))

sync=""
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  counts=$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
  behind=$(printf '%s' "$counts" | awk '{print $1+0}')
  ahead=$(printf '%s' "$counts" | awk '{print $2+0}')
  sync=" · ahead ${ahead:-0}/behind ${behind:-0} vs ${upstream}"
else
  sync=" · no upstream"
fi

# SessionStart adds the hook's stdout to the session context, so emit plain text.
printf "Git: branch '%s' — %s changed, %s untracked%s.\n" \
  "$branch" "$changed" "$untracked" "$sync"
git log --oneline -3 2>/dev/null | sed 's/^/  /'

exit 0
