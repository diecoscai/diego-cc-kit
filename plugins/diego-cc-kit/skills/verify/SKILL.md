---
name: verify
description: Use after implementation work to verify it with a fresh-context agent — never self-verify. Defines the check order and the PASS/PARTIAL/FAIL report format with evidence.
---

# Verification Protocol

After implementation agents finish, spawn a separate `verifier` sub-agent (fresh context,
read-only). The full protocol — including the exact report format — lives in
`agents/verifier.md`; this skill only summarizes when/why.

## Independence check (mechanical, not vibes)

The verifier's `agent_id` must differ from the implementer's — record both in the report.
An agent verifying its own diff is not verification; if the ids match, that's an automatic
stop, not a PASS.

## The four layers (cheapest first — see `agents/verifier.md` for the full protocol)

1. **L1 Gate re-run** — confirms the implementer's report matches reality; not a verdict on its own.
2. **L2 Exceptions audit** — the highest-signal layer: hunts self-granted exceptions in the diff
   (disabled lint/type checks, skipped/removed tests, edits to guard files).
3. **L3 Red-proof** — a new test only counts if it fails without the implementation
   (`scripts/red-proof.sh`); property tests also need one manual mutation to confirm they can fail.
4. **L4 Adversarial + evidence** — try to refute the implementer's claims; UI changes require
   runtime evidence, not static review alone.

If the repo has `.claude/arch.yml`, also run `"${CLAUDE_PLUGIN_ROOT}"/scripts/dae_arch.py --full`:
nonzero is an automatic finding.

PASS → ready for commit. PARTIAL → human decides. FAIL → retry with failure context.

## Steering loop

Any failure pattern seen twice becomes a sensor — a hook, a `.claude/guard-files.txt` entry, or
a feedback memory — in the same session it was seen twice, not deferred to later.
