#!/bin/bash
# Stop gate — deterministic "don't stop while the project gate is red".
# Opt-in per repo: an executable .claude/gate (exit 0 = green).
# Runs only when the working tree has uncommitted changes; a clean tree has
# nothing to gate. Exit 0 = allow stop, exit 2 = block (Claude Code lifts the
# block after 8 consecutive refusals).
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd=${cwd:-$PWD}
gate="$cwd/.claude/gate"

[ -x "$gate" ] || exit 0
git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] || exit 0

out=$(cd "$cwd" && "$gate" 2>&1)
status=$?
[ "$status" -eq 0 ] && exit 0

{
  echo "🚨 stop-gate: .claude/gate exited $status — fix it before finishing (or commit/stash if the failure is pre-existing)."
  echo "$out" | tail -20
} >&2
exit 2
