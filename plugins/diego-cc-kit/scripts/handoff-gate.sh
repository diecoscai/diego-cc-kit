#!/bin/bash
# handoff-gate.sh — deterministic gate over a plan's PROGRESS.md.
#
# Usage: handoff-gate.sh <path-to-PROGRESS.md> [--through N]
#
# Contract: steps are `## Step <N>` sections (a trailing ": title" on the
# header line is fine). A step is complete iff its section contains a line
# `status: done` and has no unchecked `- [ ]` boxes. No `--through` -> check
# every step found in the file. `--through N` -> check only steps 1..N.
#
# Exit codes:
#   0  all checked steps complete ("HANDOFF OK")
#   1  an incomplete step found (name + first unmet item on stderr)
#   3  missing file / bad usage

set -u

usage() {
    echo "usage: handoff-gate.sh <path-to-PROGRESS.md> [--through N]" >&2
}

file="${1:-}"
through=""
if [ "${2:-}" = "--through" ]; then
    through="${3:-}"
fi

if [ -z "$file" ] || [ ! -f "$file" ]; then
    usage
    exit 3
fi

# Step numbers present in the file, in header order.
steps=$(grep -oE '^## Step [0-9]+' "$file" | grep -oE '[0-9]+')

if [ -n "$through" ]; then
    check_steps=$(seq 1 "$through")
else
    check_steps="$steps"
fi

for n in $check_steps; do
    if ! grep -qx "$n" <<< "$steps"; then
        echo "handoff-gate: Step $n not found in $file" >&2
        exit 1
    fi

    # This step's section: from its header (exclusive) to the next
    # '## Step' header (exclusive) or EOF.
    section=$(awk -v n="$n" '
        /^## Step [0-9]+/ {
            line = $0
            sub(/^## Step /, "", line)
            sub(/[^0-9].*/, "", line)
            if (in_step) { exit }
            if (line == n) { in_step = 1; next }
        }
        in_step { print }
    ' "$file")

    if ! grep -qE '^[[:space:]]*status:[[:space:]]*done[[:space:]]*$' <<< "$section"; then
        echo "handoff-gate: Step $n incomplete — missing 'status: done'" >&2
        exit 1
    fi

    unmet=$(grep -m1 -F -- '- [ ]' <<< "$section")
    if [ -n "$unmet" ]; then
        echo "handoff-gate: Step $n incomplete — unchecked item: ${unmet# }" >&2
        exit 1
    fi
done

echo "HANDOFF OK"
exit 0
