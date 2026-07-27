#!/bin/bash
# Test Guard Hook - blocks Write/Edit that weaken a test file (dropped
# expect()s, newly-added .skip/.only/.todo/xit/xdescribe markers)
# Receives JSON via stdin, reason to stderr
# Exit 0 = Allow, Exit 2 = Block (PreToolUse can block)

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$file_path" ] && exit 0

# Only test files
echo "$file_path" | grep -qE '\.(test|spec)\.|(^|/)__tests__/' || exit 0

if [ "${CCKIT_ALLOW_TEST_EDITS:-}" = "1" ]; then
    exit 0
fi

markers=('\.skip\(' '\.only\(' '\.todo\(' '\bxit\(' '\bxdescribe\(')

count_expect() { grep -o 'expect(' <<< "$1" | wc -l; }
count_marker() { grep -oE "$1" <<< "$2" | wc -l; }

# Compares an old/before WHOLE-FILE text to a new/after WHOLE-FILE text;
# exits 2 on regression. Must always be whole-file — comparing only the
# edited chunk false-positives on e.g. moving an expect() into a helper.
check_regression() {
    local old="$1" new="$2" old_n new_n
    old_n=$(count_expect "$old")
    new_n=$(count_expect "$new")
    if [ "$new_n" -lt "$old_n" ]; then
        echo "🚨 BLOCKED: test-guard — expect() count dropped ($old_n -> $new_n) in ${file_path}." >&2
        echo "If intentional, ask the user before setting CCKIT_ALLOW_TEST_EDITS=1 and retrying." >&2
        exit 2
    fi
    for pat in "${markers[@]}"; do
        old_n=$(count_marker "$pat" "$old")
        new_n=$(count_marker "$pat" "$new")
        if [ "$new_n" -gt "$old_n" ]; then
            echo "🚨 BLOCKED: test-guard — new skip/only/todo marker ('$pat') introduced in ${file_path}." >&2
            echo "If intentional, ask the user before setting CCKIT_ALLOW_TEST_EDITS=1 and retrying." >&2
            exit 2
        fi
    done
}

cwd=$(echo "$input" | jq -r '.cwd // empty')
case "$file_path" in
    /*) abs_path="$file_path" ;;
    *) abs_path="${cwd:-.}/$file_path" ;;
esac

if [ "$tool_name" = "Edit" ]; then
    [ -f "$abs_path" ] || exit 0  # unseen path — let the tool call fail on its own
    old_string=$(echo "$input" | jq -r '.tool_input.old_string // empty')
    new_string=$(echo "$input" | jq -r '.tool_input.new_string // empty')
    # Simulate the edit: replace the FIRST literal occurrence of old_string
    # in the on-disk file, then compare WHOLE-FILE counts (not the chunk) —
    # a python3 literal replace avoids sed/awk metacharacter footguns.
    post_edit=$(python3 -c '
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding="utf-8", errors="replace").read()
if old not in text:
    sys.exit(3)
sys.stdout.write(text.replace(old, new, 1))
' "$abs_path" "$old_string" "$new_string")
    [ $? -eq 3 ] && exit 0  # old_string not found — let the tool call fail on its own
    current=$(cat "$abs_path" 2>/dev/null)
    check_regression "$current" "$post_edit"
    exit 0
fi

if [ "$tool_name" = "Write" ]; then
    [ -f "$abs_path" ] || exit 0  # new test file — always allowed
    content=$(echo "$input" | jq -r '.tool_input.content // empty')
    old_content=$(cat "$abs_path" 2>/dev/null)
    check_regression "$old_content" "$content"
    exit 0
fi

exit 0
