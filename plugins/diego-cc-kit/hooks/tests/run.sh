#!/bin/bash
# Self-check for diego-cc-kit hooks. Plain bash, no framework.
set -u
cd "$(dirname "$0")/.." || exit 1
hooks_dir="$(pwd)"

failed=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failed=1; }

# --- secret-guard: blocks a real-looking secret ---
out=$(echo '{"tool_input":{"file_path":"src/config.ts","content":"const password = \"hunter2xyz9\";"}}' \
    | "$hooks_dir/secret-guard.sh" 2>&1)
status=$?
[ "$status" -eq 2 ] && pass "secret-guard blocks hardcoded secret" \
    || fail "secret-guard should exit 2 on a secret (got $status): $out"

# --- secret-guard: allows an obvious placeholder ---
out=$(echo '{"tool_input":{"file_path":"src/config.ts","content":"const apiKey = \"changeme\";"}}' \
    | "$hooks_dir/secret-guard.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "secret-guard allows placeholder value" \
    || fail "secret-guard should exit 0 on a placeholder (got $status): $out"

# --- style-check: skips non-code files entirely ---
out=$(echo '{"tool_input":{"file_path":"README.md","content":"console.log(1)"}}' \
    | "$hooks_dir/style-check.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && [ -z "$out" ] && pass "style-check skips non-code files" \
    || fail "style-check should silently skip .md (got $status): $out"

# --- worktree-create: new branch ---
tmp_repo=$(mktemp -d)
git -C "$tmp_repo" init -q -b main
git -C "$tmp_repo" commit -q --allow-empty -m init
wt_new="$tmp_repo-wt-new"
payload=$(printf '{"branch_name":"feat/new","worktree_path":"%s"}' "$wt_new")
out=$(cd "$tmp_repo" && echo "$payload" | "$hooks_dir/worktree-create.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && [ -d "$wt_new" ] && pass "worktree-create makes a new branch" \
    || fail "worktree-create new-branch case failed (exit $status): $out"

# --- worktree-create: existing branch, not checked out elsewhere ---
git -C "$tmp_repo" branch feat/existing
wt_existing="$tmp_repo-wt-existing"
payload=$(printf '{"branch_name":"feat/existing","worktree_path":"%s"}' "$wt_existing")
out=$(cd "$tmp_repo" && echo "$payload" | "$hooks_dir/worktree-create.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && [ -d "$wt_existing" ] && pass "worktree-create reuses an existing branch" \
    || fail "worktree-create existing-branch case failed (exit $status): $out"

rm -rf "$tmp_repo" "$wt_new" "$wt_existing"

exit $failed
