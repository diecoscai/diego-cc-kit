---
name: verify
description: Use when a diff written by a DIFFERENT agent has to be trusted — before a PR, a merge, or accepting a sub-agent's work. Defines the check order and the PASS/PARTIAL/FAIL report format with evidence. Not for work you did yourself in-session.
---

# Verification Protocol

## When this applies

Spawn a `verifier` sub-agent (fresh context, read-only) when there is a real trust boundary:

- the diff was written by a **different agent** than the one deciding it's done, or
- the change is about to become a **PR, a merge to main, or a release**.

## When it does not

Work the main session wrote itself, in-session, gets **no verification step**. Run the
project's gate once as part of doing the work and report the result — do not re-run it, do
not adversarially re-review your own diff, and do not spawn an agent to check you. That
is not rigor; it is the same check twice.

The full protocol — including the exact report format — lives in `agents/verifier.md`;
this skill only summarizes when/why.

## Independence check (mechanical, not vibes)

The verifier's `agent_id` must differ from the implementer's — record both in the report.
An agent verifying its own diff is not verification; if the ids match, that's an automatic
stop, not a PASS.

## The layers

Every layer here exists to test a claim made by someone else. None of them is a second
opinion on your own work.

Every finding carries a concept tag (`[race condition]`, `[N+1]`, `[validation at the boundary]`) and the report ends with a `Concepts:` list. A review only teaches if it names the class of mistake, not only the line.

**Always, across the boundary:**

1. **L1 Gate re-run** — the implementer's "tests pass" is text until you run the gate. One
   command; it is the only thing that catches a report that doesn't match the tree.
2. **L2 Exceptions audit** — the highest-signal layer: hunts self-granted exceptions in the diff
   (disabled lint/type checks, skipped/removed tests, edits to guard files).
3. **L3 Red-proof** — a new test only counts if it fails without the implementation
   (`scripts/red-proof.sh`); property tests also need one manual mutation to confirm they can fail.

**L4 Adversarial + evidence — only when the change carries risk L1–L3 can't see:**
auth/permissions, multi-tenancy scoping, money, data migrations, deletion paths, or a UI
change whose behavior static review cannot observe (then runtime evidence is required, not
optional). On an ordinary diff that cleared L1–L3, skip L4 and say so in the report.

If the repo has `.claude/arch.yml`, also run `"${CLAUDE_PLUGIN_ROOT}"/scripts/dae_arch.py --full`:
nonzero is an automatic finding.

PASS → ready for commit. PARTIAL → human decides. FAIL → retry with failure context.

## Steering loop

Any failure pattern seen twice becomes a sensor — a hook, a `.claude/guard-files.txt` entry, or
a feedback memory — in the same session it was seen twice, not deferred to later.
