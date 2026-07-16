---
name: implement
description: Use when executing an implementation plan (a PLAN.md produced by triage) in any repo — implementing, continuing, or finishing planned work that should end in a PR.
---

# Implement — plan to verified PR (generic)

Executes one triage plan end to end. Single writer: no parallel agents editing the same files. Done = verification gate green + acceptance checklist checked + independent PASS + PR open. Not before, not "mostly".

`method: implement/v1` — project repos may ship their own instantiation with parameters pre-baked (e.g. a project's own `skills/implement`). When the current repo has one, use it instead of this skill.

## Gate 0 — scope-ack (BEFORE anything else)

Read the plan header. `scope-ack: pending` → **STOP. Write no code, create no branch.** Report that the plan awaits a human scope decision; they flip it to `approved`. `approved`, `not-required`, or no scope-ack line at all → proceed.

There are no code-neutral exceptions: no "prep work", no "just the tests", no "I'll implement while we wait".

## Phase 1 — validate the plan (before touching code)

- Is every acceptance-checklist box verifiable (a command or an observable behavior)?
- Does every verification-gate command actually exist (check its named source)? A plan citing an invented command gets corrected here, not discovered mid-loop.
- Are the plan's claims still true on the current base branch? Plans go stale like issues do.
- Does the change order respect dependencies?
- Any `## Open questions` that block the steps you're about to execute → ask the user first.

Gaps → fix the plan file, log the correction in `PROGRESS.md`, then execute the corrected plan. A fundamentally broken plan goes back to triage, not into improvisation.

## Phase 2 — execute (the loop)

For each plan step:
1. Implement that step only.
2. Run the plan's verification gate.
3. Failures: fix and re-run. **Max 3 fix attempts per step** — then stop, record the exact error verbatim in `PROGRESS.md`, and report the blocker. Never weaken a test, an assertion, or an acceptance box to get past the gate.
4. Pre-existing failures: diff the failing list against the unmodified base before claiming "pre-existing" — zero NEW failures is the bar, and the diff is your evidence.
5. **Commit the step** (project's commit convention; reference the issue) and append a `PROGRESS.md` entry: step, status, evidence. One step = one commit = one progress entry — no batch commits at the end.

## Phase 3 — independent verification (never self-verify)

After the last step, get a fresh-context PASS before opening the PR: a verifier agent that did not write the code checks the diff against the plan's acceptance checklist and re-runs the gate (use the `verify` skill's PASS/PARTIAL/FAIL protocol). PARTIAL/FAIL → back to Phase 2. The implementer's own test run is evidence, not a verdict.

## Phase 4 — the PR

- Target the branch the plan names; if the project has a release-branch flow, that flow wins over a default-branch PR.
- Title per the project's convention; body references the issue, quotes the plan's `scope:` line, and includes verification output (gate results + verifier verdict).
- Do not merge. Acceptance stays human-owned.

## Red flags

- "The ack is a formality, the plan is good" → the ack is a scope decision, not a code review. Stop at Gate 0.
- "I'll commit everything at the end, cleaner history" → one step, one commit. Batch commits erase the audit trail the loop exists for.
- "The test failures look unrelated" → prove it: diff failing lists against the unmodified base, or they're yours.
- "Third attempt is nearly there, one more try" → 3 means 3. Record the blocker and report.
- "I ran the tests, it's verified" → you wrote it; you don't get to be the verifier. Phase 3 is someone else.
