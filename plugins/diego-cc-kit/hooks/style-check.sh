#!/bin/bash
# Style Check Hook - Warns about code issues after writing
# Receives JSON via stdin, outputs warnings to stderr
# Exit 0 = Allow (always), just provides warnings

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')

# If no file path, skip
if [ -z "$file_path" ]; then
    exit 0
fi

# Only check JS/TS files
if ! echo "$file_path" | grep -qE '\.(js|jsx|ts|tsx)$'; then
    exit 0
fi

warnings=""

# Check for console.log
if echo "$content" | grep -qE 'console\.(log|debug|info)\('; then
    warnings="${warnings}⚠️  console.log/debug/info found - remember to remove before commit\n"
fi

# Check for debugger statements
if echo "$content" | grep -q 'debugger'; then
    warnings="${warnings}⚠️  debugger statement found - remember to remove\n"
fi

# Check for TODO/FIXME
if echo "$content" | grep -qiE '(TODO|FIXME|XXX|HACK):'; then
    warnings="${warnings}📝 TODO/FIXME comment found - track this\n"
fi

# Check for hardcoded secrets (simple patterns)
if echo "$content" | grep -qE "(api_key|apikey|secret|password)\s*[:=]\s*['\"][^'\"]+['\"]"; then
    warnings="${warnings}🚨 POSSIBLE HARDCODED SECRET - review carefully!\n"
fi

# Check for 'any' type in TypeScript
if echo "$file_path" | grep -qE '\.tsx?$'; then
    if echo "$content" | grep -qE ':\s*any\b|as\s+any\b'; then
        warnings="${warnings}📝 'any' type used - consider adding proper types\n"
    fi
fi

# Output warnings if any found
if [ -n "$warnings" ]; then
    echo "" >&2
    echo "=== Style Check Warnings ===" >&2
    echo -e "$warnings" >&2
    echo "These are warnings only - no action blocked." >&2
fi

# Always exit 0 - this hook warns but doesn't block
exit 0
