#!/bin/bash
# Secret Guard Hook - blocks Write/Edit content containing hardcoded secrets
# Receives JSON via stdin, reason to stderr
# Exit 0 = Allow, Exit 2 = Block (PreToolUse can block; PostToolUse can't)

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')

[ -z "$content" ] && exit 0

# Files that legitimately hold placeholder/test secrets
if echo "$file_path" | grep -qiE '\.env\.example$|(^|/)(test|tests|__tests__|fixtures|mocks?)(/|$)'; then
    exit 0
fi

pattern="(api_key|apikey|secret|password)[[:space:]]*[:=][[:space:]]*['\"][^'\"]+['\"]"
placeholder='^(x+|changeme|redacted|test|<.*>)$'

while IFS= read -r line; do
    echo "$line" | grep -qiE "$pattern" || continue
    value=$(echo "$line" | grep -oiE "['\"][^'\"]+['\"]" | tail -1 | tr -d "'\"")
    [ -z "$value" ] && continue
    echo "$value" | grep -qiE "$placeholder" && continue
    echo "🚨 BLOCKED: possible hardcoded secret in ${file_path:-<file>}:" >&2
    echo "  $line" >&2
    echo "Move the value to an env var or config file (not a literal), then retry." >&2
    exit 2
done <<< "$content"

exit 0
