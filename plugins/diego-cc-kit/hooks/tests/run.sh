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

# --- test-guard (Edit mode reads the real on-disk file, so fixtures live here) ---
tg_dir=$(mktemp -d)

# --- test-guard: blocks a dropped expect() on Edit ---
printf 'it("a", () => {\n  expect(a).toBe(1); expect(b).toBe(2);\n});\n' > "$tg_dir/drop.test.ts"
payload=$(printf '{"tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"drop.test.ts","old_string":"expect(a).toBe(1); expect(b).toBe(2);","new_string":"expect(a).toBe(1);"}}' "$tg_dir")
out=$(echo "$payload" | "$hooks_dir/test-guard.sh" 2>&1)
status=$?
[ "$status" -eq 2 ] && pass "test-guard blocks a dropped expect() on Edit" \
    || fail "test-guard should exit 2 on a dropped expect() (got $status): $out"

# --- test-guard: blocks a newly-added .only( on Edit ---
printf 'it("works", () => {});\n' > "$tg_dir/only.test.ts"
payload=$(printf '{"tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"only.test.ts","old_string":"it(\\"works\\", () => {});","new_string":"it.only(\\"works\\", () => {});"}}' "$tg_dir")
out=$(echo "$payload" | "$hooks_dir/test-guard.sh" 2>&1)
status=$?
[ "$status" -eq 2 ] && pass "test-guard blocks a newly-added .only(" \
    || fail "test-guard should exit 2 on a newly-added .only( (got $status): $out"

# --- test-guard: allows moving an expect() within the file (file-wide count
#     unchanged) — the chunk-only diff used to false-positive on this ---
printf 'function helper() { return 1; }\nit("a", () => {\n  const x = helper();\n  expect(x).toBe(1);\n});\n' > "$tg_dir/move.test.ts"
move_old='it("a", () => {
  const x = helper();
  expect(x).toBe(1);
});'
move_new='function assertOne(x) { expect(x).toBe(1); }
it("a", () => {
  const x = helper();
  assertOne(x);
});'
payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","cwd":sys.argv[1],"tool_input":{"file_path":"move.test.ts","old_string":sys.argv[2],"new_string":sys.argv[3]}}))' \
    "$tg_dir" "$move_old" "$move_new")
out=$(echo "$payload" | "$hooks_dir/test-guard.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "test-guard allows moving an expect() within the file" \
    || fail "test-guard should exit 0 when an expect() moves within the file (got $status): $out"

# --- test-guard: still blocks a genuine file-wide expect() deletion on Edit ---
printf 'it("a", () => {\n  expect(1).toBe(1);\n  expect(2).toBe(2);\n});\n' > "$tg_dir/delete.test.ts"
del_old='it("a", () => {
  expect(1).toBe(1);
  expect(2).toBe(2);
});'
del_new='it("a", () => {
  expect(1).toBe(1);
});'
payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","cwd":sys.argv[1],"tool_input":{"file_path":"delete.test.ts","old_string":sys.argv[2],"new_string":sys.argv[3]}}))' \
    "$tg_dir" "$del_old" "$del_new")
out=$(echo "$payload" | "$hooks_dir/test-guard.sh" 2>&1)
status=$?
[ "$status" -eq 2 ] && pass "test-guard blocks a genuine file-wide expect() deletion" \
    || fail "test-guard should exit 2 on a genuine file-wide deletion (got $status): $out"

# --- test-guard: always allows a brand-new test file Write ---
out=$(printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"new.test.ts","content":"it.skip(\\"x\\", () => {});"}}' "$tg_dir" \
    | "$hooks_dir/test-guard.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "test-guard allows Write to a brand-new test file" \
    || fail "test-guard should exit 0 on a new test file Write (got $status): $out"

# --- test-guard: escape hatch allows an otherwise-blocked edit ---
out=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.test.ts","old_string":"expect(a).toBe(1); expect(b).toBe(2);","new_string":"expect(a).toBe(1);"}}' \
    | CCKIT_ALLOW_TEST_EDITS=1 "$hooks_dir/test-guard.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "test-guard escape hatch (CCKIT_ALLOW_TEST_EDITS=1) allows the edit" \
    || fail "test-guard escape hatch should exit 0 (got $status): $out"

rm -rf "$tg_dir"

# --- handoff-gate: a complete PROGRESS.md passes ---
hg_dir=$(mktemp -d)
cat > "$hg_dir/PROGRESS.md" <<'EOF'
## Step 1: First
status: done
- [x] done thing

## Step 2: Second
status: done
- [x] done thing
EOF
out=$("$hooks_dir/../scripts/handoff-gate.sh" "$hg_dir/PROGRESS.md" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "handoff-gate passes a complete PROGRESS.md" \
    || fail "handoff-gate should exit 0 on a complete PROGRESS.md (got $status): $out"

# --- handoff-gate: an incomplete PROGRESS.md fails ---
cat > "$hg_dir/PROGRESS-incomplete.md" <<'EOF'
## Step 1: First
status: done
- [ ] not done yet
EOF
out=$("$hooks_dir/../scripts/handoff-gate.sh" "$hg_dir/PROGRESS-incomplete.md" 2>&1)
status=$?
[ "$status" -eq 1 ] && pass "handoff-gate fails an incomplete PROGRESS.md" \
    || fail "handoff-gate should exit 1 on an incomplete PROGRESS.md (got $status): $out"
rm -rf "$hg_dir"

# --- stop-gate: no .claude/gate → allows the stop ---
sg_repo=$(mktemp -d)
git -C "$sg_repo" init -q -b main
git -C "$sg_repo" commit -q --allow-empty -m init
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "stop-gate allows stop when no gate exists" \
    || fail "stop-gate should exit 0 without a gate (got $status): $out"

# --- stop-gate: failing gate + dirty tree → blocks the stop ---
mkdir -p "$sg_repo/.claude"
printf '#!/bin/bash\necho "1 test failed"\nexit 1\n' > "$sg_repo/.claude/gate"
chmod +x "$sg_repo/.claude/gate"
git -C "$sg_repo" add .claude/gate && git -C "$sg_repo" commit -q -m gate
echo dirty > "$sg_repo/file.txt"
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 2 ] && echo "$out" | grep -q "1 test failed" && pass "stop-gate blocks stop on a failing gate with a dirty tree" \
    || fail "stop-gate should exit 2 with gate output (got $status): $out"

# --- stop-gate: failing gate + clean tree → allows the stop ---
rm "$sg_repo/file.txt"
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "stop-gate allows stop when the tree is clean" \
    || fail "stop-gate should exit 0 on a clean tree (got $status): $out"

# --- stop-gate: untracked gate + otherwise clean tree → allows the stop ---
git -C "$sg_repo" rm -q --cached .claude/gate
git -C "$sg_repo" commit -q -m "untrack gate"
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "stop-gate ignores an untracked gate file in the dirty check" \
    || fail "stop-gate should exit 0 when only the gate itself is untracked (got $status): $out"

# --- stop-gate: cwd in a subdirectory still finds the root gate ---
mkdir -p "$sg_repo/sub"
echo dirty > "$sg_repo/sub/file.txt"
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo/sub" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 2 ] && pass "stop-gate finds the root gate from a subdirectory cwd" \
    || fail "stop-gate should exit 2 from a subdir with a dirty tree and a red gate (got $status): $out"

rm -rf "$sg_repo"

exit $failed
