---
name: triage
description: Use when starting work on a GitHub issue, bug report, or feature request in any repo, before writing code — to investigate it and produce a plan another agent can execute; also when asked to triage, plan, or investigate an issue.
---

# Triage — issue to executable plan (generic)

Read-only investigation of one issue/request producing a plan file that `implement` (or any agent) can execute without ambiguity. The ONLY writes allowed: the plan files (and an issue comment where the project's workflow calls for one).

`method: triage/v1` — project repos may ship their own instantiation of this method with parameters pre-baked (e.g. a project's own `skills/triage`). When the current repo has one, use it instead of this skill.

## Convention discovery (do this FIRST, in order)

You are in an arbitrary repo. Discover its conventions before planning; never assume them:

1. `CLAUDE.md` / `AGENTS.md` (root, then nested) — overrides everything below.
2. `CONTRIBUTING.md`, `docs/` — workflow, checklists, plan locations.
3. `package.json` scripts / `Makefile` / `pyproject.toml` / CI workflows (`.github/workflows/`) — the real build/test/lint commands and target branches.
4. `README.md` — last resort.

**Every command you write into the plan must be proven to exist** — name its source (a script in `package.json`, a Makefile target, a CI step). A verification gate that invents `npm test` in a repo whose script is `check` fails on its first run.

**Undiscoverable convention → ask the user** (plan location, branch target, release flow). If you must proceed non-interactively, put it in an `## Open questions` section of the plan — never silently invent a convention.

## Scope / governance

If the repo carries a scope-governance doc (SOW, contract, roadmap, milestone plan): classify the issue against it in the plan header (`scope:` + `scope-evidence:`), and mark work with no trace as needing an explicit human ack (`scope-ack: pending`) before implementation. No governance doc → one line in the header: `scope: none — no governance doc found`.

## Procedure

1. Read the issue/request and everything linked (comments, PRs, referenced code).
2. Verify its claims against the current code — issues go stale; record what you confirmed vs corrected.
3. **Interview before designing (features and anything with unknowns; skip for a bug with a reproducible symptom).** Use `AskUserQuestion` in rounds until nothing material is left: technical approach, edge cases, UI/UX, out-of-scope, and explicitly "how could this fail?" (the failure modes of the mechanism you are about to depend on). Do not ask what the code already answers. Answers go into the plan as `## Verified facts` and `## Non-goals`, not into a separate transcript.
4. Classify scope (above).
5. Detect the mode. At the repo root run `jq -r '.outputStyle // empty' .claude/settings.local.json 2>/dev/null`. Output `aprender` → **learn mode**: the plan carries a `## Tajada [human]` section. Anything else (empty, `Default`, missing file) → **deliver mode**: omit that section. Everything else in the contract applies to both modes.
6. Write the plan files (contract below).
7. If the project's workflow posts plans to the tracker (issue comment, ticket), do so.
8. Hand the plan to the user to read before anything executes. They read it and answer the `## Pregunta de defensa` in chat; write their answer into `PROGRESS.md` as one line, `defensa: <their words>`, verbatim. Never write that answer yourself, and never start `implement` without it. The plan is the leverage point; the implementation is not.

## Plan contract

Write to the project's plan location (discovered or asked; suggest `docs/plans/active/<slug>/` if the user has no preference):

**`PLAN.md`** — these sections, in order:
- Header: `scope:` / `scope-evidence:` / `scope-ack:` / `branch:` (off the discovered target) / `goal:` — one verifiable end state in a single sentence, naming the command that proves it and any constraint that must hold on the way (e.g. `goal: `npm test` and `npm run lint` exit 0 with the three acceptance boxes checked; no test file outside src/auth is modified`). `implement` runs the whole plan under `/goal <this line>`; if it can't be judged from command output in the transcript, it isn't a goal, rewrite it.
- `## Objective` — 1 sentence, measurable
- `## Verified facts` — issue claims vs code
- `## Files to touch` — paths, in change order
- `## Non-goals`
- `## Verification gate` — exact, source-proven commands
- `## Acceptance checklist` — success criteria as literal checkboxes, each with a command or observable behavior
- `## Risks / rollback`
- `## Por qué` — exactly three lines, in the user's language: `patrón:` the technique or pattern the plan relies on, by its name and where it applies (e.g. "optimistic update en el hook useCart", "idempotency key en POST /orders"; if none, say "ninguno, código procedural"); `descartado:` the alternative you did not take and why; `riesgo:` the main way this change could fail in production.
- `## Pregunta de defensa` — one question, tagged `(can-explain)` or `(can-defend)`, that the user must be able to answer from the plan before approving it. Ask for the trade-off or the failure mode ("¿cuándo NO usarías X?", "¿qué se rompe si Y?"), never for a definition. `implement` does not start until `PROGRESS.md` carries the `defensa:` answer.
- `## Tajada [human]` — learn mode only. The ONE step the user writes by hand: normally the first failing test or the interface/type the rest builds on. Give the file path, what it must contain (names, cases, signature), and the command that proves it is done. `implement` stops at this step and hands it over.
- `## Open questions` — anything undiscoverable you couldn't ask about

**`PROGRESS.md`** — created with just a header; `implement` appends per-step status.

Ambiguity or missing info: list it explicitly instead of guessing. Don't redesign what the request already specifies.

## Red flags

- "npm test is standard, it'll exist" → prove every command from its source file or don't write it.
- "I'll just put the plan somewhere sensible" → discovered convention, or ask, or `## Open questions` — inventing paths silently is the failure mode.
- "This repo has no governance doc, skip the scope section" → the explicit `scope: none` line IS the section.
- "The issue explains itself, skip claim verification" → issues go stale; verify against code and say what you checked.
- "The request is clear enough, skip the interview" → for a feature, the unknowns you didn't ask about become the implementer's guesses. Interview; it costs minutes.
- "goal: implement the feature" → not judgeable from a transcript. A goal names a command and an exit state.
- "`patrón: buenas prácticas`" → name it (Repository, optimistic update, idempotency key, debounce) or say there is none. A pattern the user can't look up teaches nothing.
- "Defense question: ¿qué hace este PR?" → too easy to answer from the title. Ask for the trade-off or the failure mode.
- "The [human] slice is the boilerplate, it's the easiest to hand off" → it's the step that teaches most (the test or the contract), not the cheapest one.
