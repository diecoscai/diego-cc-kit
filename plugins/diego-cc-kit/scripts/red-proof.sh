#!/usr/bin/env bash
# Proves a new/changed test is load-bearing: it must FAIL when the
# implementation it covers is reverted to the base branch.
#
# Usage: red-proof.sh --test-cmd '<command>' <impl-file>...
#
# Exit codes:
#   0  RED-PROOF OK — test fails without the implementation (load-bearing).
#   1  NOT RED — test still passes without the implementation (verdict: not load-bearing).
#   2  refused — dirty working tree, or bad usage.
#   3  execution error — base ref / merge-base didn't resolve, or revert failed.
#      Not a verdict; fix BASE_REF or the invocation and rerun.
set -euo pipefail

BASE_REF="${BASE_REF:-origin/main}"

test_cmd=""
impl_files=()
while [ $# -gt 0 ]; do
  case "$1" in
    --test-cmd)
      test_cmd="$2"
      shift 2
      ;;
    *)
      impl_files+=("$1")
      shift
      ;;
  esac
done

if [ -z "$test_cmd" ] || [ ${#impl_files[@]} -eq 0 ]; then
  echo "Usage: red-proof.sh --test-cmd '<command>' <impl-file>..." >&2
  exit 2
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Refusing to run: working tree is dirty. Commit or stash first." >&2
  exit 2
fi

if ! merge_base="$(git merge-base HEAD "$BASE_REF" 2>/dev/null)"; then
  echo "cannot resolve base ($BASE_REF) — set BASE_REF" >&2
  exit 3
fi

restore() {
  git checkout HEAD -- "${impl_files[@]}" 2>/dev/null || true
}
trap restore EXIT

# Partition: files that existed at the base get checked out to their base
# content; files new since the base have no base content to check out —
# reverting them means removing them (git checkout would fail with a
# pathspec error, which `set -e` would then misreport as exit 1 / NOT RED).
existing_files=()
new_files=()
for f in "${impl_files[@]}"; do
  if git cat-file -e "$merge_base:$f" 2>/dev/null; then
    existing_files+=("$f")
  else
    new_files+=("$f")
  fi
done

if [ ${#existing_files[@]} -gt 0 ]; then
  if ! git checkout "$merge_base" -- "${existing_files[@]}"; then
    echo "error reverting files to base ($merge_base) — aborting" >&2
    exit 3
  fi
fi

for f in "${new_files[@]}"; do
  rm -f -- "$f"
  echo "$f: new since base — reverted by deletion"
done

set +e
bash -c "$test_cmd"
result=$?
set -e

if [ $result -eq 0 ]; then
  echo "NOT RED: new tests pass without the implementation — they are not load-bearing"
  exit 1
fi

echo "RED-PROOF OK"
exit 0
