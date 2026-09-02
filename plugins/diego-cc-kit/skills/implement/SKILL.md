---
name: implement
description: Use when executing an implementation plan (a PLAN.md produced by triage) in any repo — implementing, continuing, or finishing planned work that should end in a PR.
---

# Implement — plan to verified PR (generic)

Executes one triage plan end to end. Single writer: no parallel agents editing the same files. Done = verification gate green + acceptance checklist checked + independent PASS on delegated work + PR open. Not before, not "mostly".

`method: implement/v1` — project repos may ship their own instantiation with parameters pre-baked (e.g. a project's own `skills/implement`). When the current repo has one, use it instead of this skill.

## Gate 0 — scope-ack (BEFORE anything else)

Read the plan header. `scope-ack: pending` → **STOP. Write no code, create no branch.** Report that the plan awaits a human scope decision; they flip it to `approved`. `approved`, `not-required`, or no scope-ack line at all → proceed.

There are no code-neutral exceptions: no "prep work", no "just the tests", no "I'll implement while we wait".

## Phase 1 — validate the plan (before touching code)

- Resuming mid-plan: run `"${CLAUDE_PLUGIN_ROOT}"/scripts/handoff-gate.sh <plan-dir>/PROGRESS.md --through <last-completed-step>`. Nonzero means the previous session's completion claims don't hold — stop and reconcile PROGRESS.md against the actual code before continuing.
- Is every acceptance-checklist box verifiable (a command or an observable behavior)?
- Does every verification-gate command actually exist (check its named source)? A plan citing an invented command gets corrected here, not discovered mid-loop.
- Are the plan's claims still true on the current base branch? Plans go stale like issues do.
- Does the change order respect dependencies?
- Any `## Open questions` that block the steps you're about to execute → ask the user first.
- Does the header carry a `goal:` line that a model could judge from command output alone? Missing or vague → write it now from the verification gate + acceptance checklist, log the correction in `PROGRESS.md`. Do not start Phase 2 without it.
- Does `PROGRESS.md` carry a `defensa:` line answering the plan's `## Pregunta de defensa`? Missing → ask the user the question in chat now (free text, not `AskUserQuestion`), write `defensa: <their words>` into `PROGRESS.md`, then continue. Never write the answer yourself: it is the user's evidence of understanding, not a form field.

Gaps → fix the plan file, log the correction in `PROGRESS.md`, then execute the corrected plan. A fundamentally broken plan goes back to triage, not into improvisation.

## Phase 2 — execute (the loop)

Set the session goal first: `/goal <the plan's goal: line>`. From here a separate evaluator re-checks the condition after every turn, so the loop closes on evidence, not on "looks done". Execution is delegated: spawn `implementer` (or `fullstack-integrator` for cross-stack wiring) with an explicit `model` — sonnet by default, opus for a genuinely hard step (see `orchestrate`'s routing). Never let the spawn inherit the session model.

Learn mode (`jq -r '.outputStyle // empty' .claude/settings.local.json` prints `aprender`) and the plan has a `## Tajada [human]` section: when the loop reaches that step, do not implement it and do not delegate it. Write a stub at the path the plan names containing only a `TODO(human)` comment that restates what the section asks for and the command that proves it, then stop and hand over in chat. The user writes it and commits it. Resume at the next step only when they say it's done and `git status --porcelain -- <path>` is clean. If the user says "hacelo vos", implement it, log `human slice skipped by user` in `PROGRESS.md`, and continue.

For each plan step:
1. Implement that step only.
2. Run the plan's verification gate.
3. Failures: fix and re-run. **Max 3 fix attempts per step** — then stop, record the exact error verbatim in `PROGRESS.md`, and report the blocker. Never weaken a test, an assertion, or an acceptance box to get past the gate.
4. Pre-existing failures: diff the failing list against the unmodified base before claiming "pre-existing" — zero NEW failures is the bar, and the diff is your evidence.
5. UI change (anything a user sees): the step is not done until there is a screenshot of the running app (Chrome extension, `evidence-kit:capture-evidence`, or `/verify`) compared against the design or the previous state, with differences listed and fixed. This is independent of the verifier's L4: L4 is about risk; this is about closing the loop on something a test can't see.
6. **Commit the step** (project's commit convention; reference the issue) and append a `PROGRESS.md` entry: step, status, evidence. One step = one commit = one progress entry — no batch commits at the end.

## Phase 3 — independent verification (never self-verify)

The diff was written by an agent that is not you, and it's heading to a PR — both reasons this phase exists. After the last step, get a fresh-context PASS before opening the PR: a verifier agent that did not write the code checks the diff against the plan's acceptance checklist per `agents/verifier.md` — L1 gate re-run, L2 exceptions audit, L3 red-proof on new tests, and L4 only if the change carries the risk L4 names. Report in the `verify` skill's PASS/PARTIAL/FAIL format. PARTIAL/FAIL → back to Phase 2. The implementer's own test run is evidence, not a verdict.

If you implemented a step yourself in the main session instead of delegating it, that part of the diff needs no separate verification pass — your own gate run is the evidence for it.

## Phase 4 — the PR

- Target the branch the plan names; if the project has a release-branch flow, that flow wins over a default-branch PR.
- Title per the project's convention; body references the issue, quotes the plan's `scope:` line, and includes verification output (gate results + verifier verdict).
- Body carries `## Explicación` with the user's own three sentences: **qué cambia, por qué funciona, qué lo rompería**. Ask for them in chat before opening the PR and paste them verbatim. If the user can't give them, open the PR as **draft** with `## Explicación: pendiente` and say so in the report. A PR its author can't explain isn't ready; that is knowledge debt, not a formality.
- Learn mode: after the PR exists, append one line to `docs/agent/til.md` (create it with a `# TIL` header if missing) in the form `- YYYY-MM-DD · <concept, the plan's patrón:> · <one sentence on what you'd tell a colleague> · <PR url>`, add `- [TIL](til.md) — conceptos por PR, insumo de /drill` to `docs/agent/README.md` if that line is absent, and commit both on the branch with `docs: til <concept>`.
- Do not merge. Acceptance stays human-owned.

## Red flags

- "The ack is a formality, the plan is good" → the ack is a scope decision, not a code review. Stop at Gate 0.
- "I'll commit everything at the end, cleaner history" → one step, one commit. Batch commits erase the audit trail the loop exists for.
- "The test failures look unrelated" → prove it: diff failing lists against the unmodified base, or they're yours.
- "Third attempt is nearly there, one more try" → 3 means 3. Record the blocker and report.
- "The implementer said the tests pass" → that's a claim, not a result. Phase 3 re-runs the gate on the diff someone else wrote. (If you wrote the step yourself, your own run stands — don't re-run it for ceremony.)
- "The component renders, tests pass, it's fine" → a test doesn't see layout. Screenshot, compare, then commit.
- "I'll write the `defensa:` answer myself to unblock" → the answer is the user's, or Phase 1 isn't done.
- "The [human] step is just a test, I'll fill it" → the value of that step is the user writing it. Stub, hand over, wait.
- "The explanation can be filled in later" → then the PR is a draft, and the report says why.
