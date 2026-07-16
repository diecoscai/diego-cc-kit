#!/bin/bash
# Bash Validator Hook - Warns about dangerous commands
# Receives JSON via stdin, outputs warnings to stderr
# Exit 0 = Allow, Exit 2 = Block and warn

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# If no command found, allow
if [ -z "$command" ]; then
    exit 0
fi

# Dangerous patterns to warn about
dangerous_patterns=(
    "rm -rf /\$"
    "rm -rf /\*"
    "rm -rf ~\$"
    "rm -rf ~/\*"
    "rm -rf /home\$"
    "rm -rf /etc"
    "rm -rf /usr"
    "rm -rf /var"
    "git reset --hard"
    "git push .* --force"
    "git push .* -f "
    "git clean -fd"
    "chmod 777"
    "> /dev/sda"
    "mkfs\."
    "dd if=.* of=/dev"
)

for pattern in "${dangerous_patterns[@]}"; do
    if echo "$command" | grep -qE "$pattern"; then
        echo "⚠️  DANGEROUS COMMAND DETECTED" >&2
        echo "Command: $command" >&2
        echo "Pattern matched: $pattern" >&2
        echo "" >&2
        echo "This command could cause data loss or system damage." >&2
        echo "If you're sure, run it manually in terminal." >&2
        exit 2
    fi
done

# ── HOME-rooted recursive-delete guard ──────────────────────────────────────
# This hook is the ONLY guardrail when Claude runs via the `cc` alias, since
# --dangerously-skip-permissions bypasses the allow/deny/ask system entirely.
# Block `rm` with recursive AND force flags (any order) targeting important
# HOME paths, while still allowing build-artifact cleanup.
if echo "$command" | grep -qE '(^|[^[:alnum:]])rm([[:space:]]|$)'; then
    has_r=$(echo "$command" | grep -qE 'rm[^|;&]*([[:space:]]-[[:alpha:]]*r|[[:space:]]--recursive)' && echo 1)
    has_f=$(echo "$command" | grep -qE 'rm[^|;&]*([[:space:]]-[[:alpha:]]*f|[[:space:]]--force)' && echo 1)
    if [ "$has_r" = 1 ] && [ "$has_f" = 1 ]; then
        protected='(~|\$HOME|/home/[^/]+|/Users/[^/]+)/(dev|dotfiles|\.claude|\.config|\.ssh|\.gnupg|\.aws|\.local)([/[:space:]]|$)'
        safe_leaf='(node_modules|\.next|dist|build|out|\.cache|\.turbo|target|\.venv|venv|__pycache__|coverage|\.pytest_cache|\.parcel-cache)/?([[:space:]]|$)'
        if echo "$command" | grep -qE "$protected" && ! echo "$command" | grep -qE "$safe_leaf"; then
            echo "⛔ BLOCKED: recursive rm on a protected HOME path" >&2
            echo "Command: $command" >&2
            echo "Protected: ~/dev ~/dotfiles ~/.claude ~/.config ~/.ssh ~/.gnupg ~/.aws ~/.local (and subpaths)" >&2
            echo "Allowed: build-artifact leaves (node_modules, dist, build, .next, target, .venv, ...)." >&2
            echo "If intentional, run it manually in a terminal." >&2
            exit 2
        fi
    fi
fi

exit 0
