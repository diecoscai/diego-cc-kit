#!/bin/bash
# Stop gate — deterministic "don't stop while the project gate is red".
# Opt-in per repo: an executable .claude/gate at the repo root (exit 0 = green).
# Runs only when the working tree has uncommitted changes (the gate file itself
# excluded, so an untracked gate doesn't keep the tree permanently dirty); a
# clean tree has nothing to gate. Exit 0 = allow stop, exit 2 = block (Claude
# Code lifts the block after 8 consecutive refusals).
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
cwd=${cwd:-$PWD}

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
gate="$root/.claude/gate"
[ -x "$gate" ] || exit 0
[ -n "$(git -C "$root" status --porcelain -- . ':!.claude/gate' 2>/dev/null)" ] || exit 0

out=$(cd "$root" && "$gate" 2>&1)
status=$?
[ "$status" -eq 0 ] && exit 0

{
  echo "🚨 stop-gate: .claude/gate exited $status — fix it before finishing (or commit/stash if the failure is pre-existing)."
  echo "$out" | tail -20
} >&2
exit 2
