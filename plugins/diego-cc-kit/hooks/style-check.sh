#!/bin/bash
# Style Check Hook - informational only (never blocks; secrets are blocked
# separately by the PreToolUse secret-guard.sh)
# Receives JSON via stdin, outputs warnings to stderr
# Exit 0 = Allow (always)

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')

[ -z "$file_path" ] && exit 0

# Only check code files
echo "$file_path" | grep -qE '\.(js|jsx|ts|tsx|py)$' || exit 0

repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null)

ran_eslint=0
if [ -n "$repo_root" ] && echo "$file_path" | grep -qE '\.(js|jsx|ts|tsx)$' \
   && [ -x "$repo_root/node_modules/.bin/eslint" ] \
   && { ls "$repo_root"/eslint.config.* >/dev/null 2>&1 || ls -A "$repo_root"/.eslintrc* >/dev/null 2>&1; }; then
    eslint_out=$(cd "$repo_root" && timeout 15 npx --no-install eslint --no-warn-ignored --format stylish "$file_path" 2>&1)
    eslint_status=$?
    if [ "$eslint_status" -ne 124 ]; then
        ran_eslint=1
        if [ -n "$eslint_out" ]; then
            echo "" >&2
            echo "=== ESLint found issues in $file_path - fix them before continuing ===" >&2
            echo "$eslint_out" >&2
        fi
    fi
fi

if [ "$ran_eslint" -eq 0 ]; then
    warnings=""
    if echo "$content" | grep -qE 'console\.(log|debug|info)\('; then
        warnings="${warnings}⚠️  console.log/debug/info found - remember to remove before commit\n"
    fi
    if echo "$content" | grep -q 'debugger'; then
        warnings="${warnings}⚠️  debugger statement found - remember to remove\n"
    fi
    if [ -n "$warnings" ]; then
        echo "" >&2
        echo "=== Style Check Warnings ===" >&2
        echo -e "$warnings" >&2
        echo "These are warnings only - no action blocked." >&2
    fi
fi

exit 0
