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
3. Classify scope (above).
4. Write the plan files (contract below).
5. If the project's workflow posts plans to the tracker (issue comment, ticket), do so.

## Plan contract

Write to the project's plan location (discovered or asked; suggest `docs/plans/active/<slug>/` if the user has no preference):

**`PLAN.md`** — these sections, in order:
- Header: `scope:` / `scope-evidence:` / `scope-ack:` / `branch:` (off the discovered target)
- `## Objective` — 1 sentence, measurable
- `## Verified facts` — issue claims vs code
- `## Files to touch` — paths, in change order
- `## Non-goals`
- `## Verification gate` — exact, source-proven commands
- `## Acceptance checklist` — success criteria as literal checkboxes, each with a command or observable behavior
- `## Risks / rollback`
- `## Open questions` — anything undiscoverable you couldn't ask about

**`PROGRESS.md`** — created with just a header; `implement` appends per-step status.

Ambiguity or missing info: list it explicitly instead of guessing. Don't redesign what the request already specifies.

## Red flags

- "npm test is standard, it'll exist" → prove every command from its source file or don't write it.
- "I'll just put the plan somewhere sensible" → discovered convention, or ask, or `## Open questions` — inventing paths silently is the failure mode.
- "This repo has no governance doc, skip the scope section" → the explicit `scope: none` line IS the section.
- "The issue explains itself, skip claim verification" → issues go stale; verify against code and say what you checked.
