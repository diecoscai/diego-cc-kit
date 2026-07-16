#!/usr/bin/env bash
# Bump a plugin's version in BOTH plugin.json and the marketplace.json entry,
# keeping them in sync. Claude Code caches plugins by version — without a bump,
# `claude plugin update` no-ops and stale content keeps running.
#
# Usage:
#   ./bump.sh <plugin> [version]   # explicit version, e.g. ./bump.sh diego-cc-kit 0.2.0
#   ./bump.sh <plugin>             # auto-increment patch (0.1.1 -> 0.1.2)
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
plugin="${1:-}"
newver="${2:-}"

[ -z "$plugin" ] && { echo "usage: ./bump.sh <plugin> [version]"; exit 1; }
command -v jq >/dev/null || { echo "jq is required"; exit 1; }

manifest="$repo/plugins/$plugin/.claude-plugin/plugin.json"
market="$repo/.claude-plugin/marketplace.json"
[ -f "$manifest" ] || { echo "no plugin.json at $manifest"; exit 1; }
[ -f "$market" ]   || { echo "no marketplace.json at $market"; exit 1; }

cur="$(jq -r '.version' "$manifest")"

if [ -z "$newver" ]; then
  IFS=. read -r major minor patch <<<"$cur"
  newver="$major.$minor.$((patch + 1))"
fi

# plugin.json
tmp="$(mktemp)"
jq --arg v "$newver" '.version = $v' "$manifest" >"$tmp" && mv "$tmp" "$manifest"

# marketplace.json entry matched by name
jq -e --arg n "$plugin" '.plugins[] | select(.name == $n)' "$market" >/dev/null \
  || { echo "no entry named '$plugin' in marketplace.json"; exit 1; }
tmp="$(mktemp)"
jq --arg n "$plugin" --arg v "$newver" \
  '(.plugins[] | select(.name == $n) | .version) = $v' "$market" >"$tmp" && mv "$tmp" "$market"

echo "$plugin: $cur -> $newver"
echo
echo "next:"
echo "  git add -A && git commit -m \"chore: bump $plugin to $newver\" && git push"
echo "  claude plugin update $plugin@diego-cc-kit    # local dev PC"
echo "  # other PC: claude plugin marketplace update diego-cc-kit && claude plugin update $plugin@diego-cc-kit"
echo "  # then restart Claude Code"
