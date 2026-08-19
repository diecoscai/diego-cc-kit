#!/usr/bin/env bash
# Self-check: un JSONL truncado no debe matar el script (set -e + jq fallando).
set -uo pipefail
cd "$(dirname "$0")"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

sub="$fixture/session/subagents"
mkdir -p "$sub"

echo '{"timestamp":"2026-08-19T00:00:00Z","type":"assistant","message":{"content":[{"type":"text","text":"agent one done"}]}}' \
  >"$sub/agent-1.jsonl"

line='{"timestamp":"2026-08-19T00:00:00Z","type":"assistant","message":{"content":[{"type":"text","text":"agent two done"}]}}'
printf '%s' "${line:0:$(( ${#line} / 2 ))}" >"$sub/agent-2.jsonl"

echo '{"timestamp":"2026-08-19T00:00:00Z","type":"assistant","message":{"content":[{"type":"text","text":"agent three done"}]}}' \
  >"$sub/agent-3.jsonl"

out="$(SUBAGENT_DIAG_PROJ="$fixture" ./subagent-diag.sh 200000)"
code=$?

fail=0
[ "$code" -eq 0 ] || { echo "FAIL: exit code (got $code, want 0)"; fail=1; }
echo "$out" | grep -q "agent-1" || { echo "FAIL: agent-1 not listed"; fail=1; }
echo "$out" | grep -q "agent-3" || { echo "FAIL: agent-3 not listed"; fail=1; }

[ $fail -eq 0 ] && echo "OK: 3/3"
exit $fail
