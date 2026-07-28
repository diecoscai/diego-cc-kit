# Opus 5 Config Tuning — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align Diego's Claude Code config with the official "Prompting Claude Opus 5" guide — stop forcing verification the model already does, stop biasing toward delegation the model already over-does, and add the verbosity controls the config has never had.

**Architecture:** Prose edits to instruction files in two locations with different propagation mechanics. Half the changes live in the `diego-cc-kit` git repo (require bump → commit → push → `plugin update` → restart before they take effect). Half live in `~/.claude/` (take effect next session, and are chezmoi-managed so they need re-adding to the dotfiles source). No code, no tests, no dependencies.

**Tech Stack:** Markdown instruction files, one JS workflow script, `bump.sh` + `jq`, git, chezmoi.

## Global Constraints

- **Never edit the marketplace cache.** `~/.claude/plugins/marketplaces/**` and `~/.claude/plugins/cache/**` are overwritten on every plugin update. The editable source for diego-cc-kit is `/home/dieco/dev/tools/diego-cc-kit`. Superpowers and code-review have **no** editable source here — override them from `~/.claude/CLAUDE.md` instead.
- **Plugin edits do not take effect until version bump.** `bump.sh` states it: without a version bump, `claude plugin update` no-ops and stale content keeps running. The full chain is `./bump.sh diego-cc-kit` → commit → push → `claude plugin update diego-cc-kit@diego-cc-kit` → restart Claude Code.
- **`~/.claude/CLAUDE.md` is chezmoi-managed.** After editing, run `/update-dotfiles` (live → source) or the edits are lost on the next chezmoi apply.
- **The wording IS the deliverable.** These are instruction files read by a model; paraphrasing changes behavior. Apply the proposed text verbatim.
- **No `settings.json` changes.** `effortLevel: medium`, `model: opus[1m]` and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` all stay — each is already aligned with the guide. Changing them would be change for its own sake.
- **Verification in this plan is deliberately one cheap check per task** (usually a grep). This plan's whole subject is over-verification; a heavyweight verification ritual here would be self-refuting.

---

## File Structure

**Repo `/home/dieco/dev/tools/diego-cc-kit` (Tasks 1–4):**
- `plugins/diego-cc-kit/skills/verify/SKILL.md` — when a verifier spawns, and which layers run
- `plugins/diego-cc-kit/agents/verifier.md` — the verifier's actual protocol
- `plugins/diego-cc-kit/skills/implement/SKILL.md` — Phase 3 scoping
- `plugins/diego-cc-kit/skills/orchestrate/SKILL.md` — delegation gates, routing, spawn template
- `plugins/diego-cc-kit/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version (via `bump.sh`)

**`~/.claude/` (Tasks 5–8):**
- `CLAUDE.md` — always-loaded; absorbs every override that has no editable upstream
- `skills/orchestrator/SKILL.md` + `WORKFLOW.md` — narrow: remove Team Mode / Stage T
- `workflows/deep-research-lean.js` — per-spawn effort

**Untouched, deliberately:** `settings.json`, all six `agents/*.md` model pins, `skills/triage/`, `skills/codegraph-usage/`, the git-worktree rules, all hooks.

---

### Task 1: Scope the verification protocol to real trust boundaries

**Files:**
- Modify: `plugins/diego-cc-kit/skills/verify/SKILL.md`
- Modify: `plugins/diego-cc-kit/agents/verifier.md`

**Interfaces:**
- Produces: the boundary rule ("is this reading a claim, or redoing my own work?") that Tasks 2, 3 and 5 all reference. Do this task first.

The distinction that drives every edit here: **L1/L2/L3 read a claim another agent made — keep them. L4 re-reviews an already-clean diff — make it conditional. Nothing verifies work the main session did itself.**

- [ ] **Step 1: Rewrite the verify skill's frontmatter and intro**

In `skills/verify/SKILL.md`, replace:

```
---
name: verify
description: Use after implementation work to verify it with a fresh-context agent — never self-verify. Defines the check order and the PASS/PARTIAL/FAIL report format with evidence.
---

# Verification Protocol

After implementation agents finish, spawn a separate `verifier` sub-agent (fresh context,
read-only). The full protocol — including the exact report format — lives in
`agents/verifier.md`; this skill only summarizes when/why.
```

with:

```
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
```

The `description:` change is the load-bearing part: it is what stops this skill auto-selecting on self-authored work at all.

- [ ] **Step 2: Make L4 conditional in the verify skill**

In the same file, replace:

```
## The four layers (cheapest first — see `agents/verifier.md` for the full protocol)

1. **L1 Gate re-run** — confirms the implementer's report matches reality; not a verdict on its own.
2. **L2 Exceptions audit** — the highest-signal layer: hunts self-granted exceptions in the diff
   (disabled lint/type checks, skipped/removed tests, edits to guard files).
3. **L3 Red-proof** — a new test only counts if it fails without the implementation
   (`scripts/red-proof.sh`); property tests also need one manual mutation to confirm they can fail.
4. **L4 Adversarial + evidence** — try to refute the implementer's claims; UI changes require
   runtime evidence, not static review alone.
```

with:

```
## The layers

Every layer here exists to test a claim made by someone else. None of them is a second
opinion on your own work.

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
```

- [ ] **Step 3: Update the verifier agent's run mandate**

In `agents/verifier.md`, replace:

```
Re-running the implementer's own gate is confirmation, not a verdict — it mechanically
cannot catch a self-granted exception, a tautological test, or a claim that doesn't hold up
under challenge. That's what Layers 2–4 are for. Run all four layers, in order, cheapest first.
Any layer failing is enough to fail the whole verification — don't average across layers.
```

with:

```
Re-running the implementer's gate is confirmation, not a verdict — it mechanically cannot
catch a self-granted exception or a tautological test. That's what L2 and L3 are for. Run
L1, L2 and L3 in that order on every diff you're handed. Run L4 only when the change touches
auth/permissions, multi-tenancy scoping, money, data migrations, deletion paths, or UI
behavior that static review cannot observe; otherwise mark it N/A and say why. Any layer you
ran that fails is enough to fail the whole verification — don't average across layers.
```

Without this step the skill's new policy is decorative — this file is what actually drives the agent.

- [ ] **Step 4: Make the verifier's L4 section conditional**

In `agents/verifier.md`, replace:

```
## L4 — Adversarial + evidence

Try to refute the implementer's claims — don't confirm them. Re-derive "why is this correct"
from the diff yourself rather than accepting the stated reasoning. For UI-affecting changes,
static review is not sufficient: require runtime evidence (run the app, screenshot, curl the
endpoint, exercise the flow) before calling it PASS. Runtime evidence has caught real bugs
that static review alone passed — don't skip it because the diff "looks right."
```

with:

```
## L4 — Adversarial + evidence (conditional)

Run this layer only on risk-bearing changes: auth/permissions, multi-tenancy scoping, money,
data migrations, deletion paths, or a UI change whose behavior static review cannot observe.
On those, try to refute the implementer's claims rather than confirm them, and re-derive "why
is this correct" from the diff yourself. For UI-affecting changes, static review is not
sufficient: require runtime evidence (run the app, screenshot, curl the endpoint, exercise the
flow) before calling it PASS. Runtime evidence has caught real bugs that static review alone
passed — don't skip it on a change in this list because the diff "looks right." On a diff
outside this list that cleared L1–L3, report L4 as N/A rather than performing it.
```

- [ ] **Step 5: Add the N/A slot to the report format**

In `agents/verifier.md`, replace:

```
  L4 Adversarial: PASS | FAIL — [what was refuted/confirmed, runtime evidence if UI]
```

with:

```
  L4 Adversarial: PASS | FAIL | N/A — [risk category triggering it + what was refuted, runtime evidence if UI; or "N/A — no risk trigger"]
```

Without an N/A slot the agent runs L4 just to have something to write on the line.

- [ ] **Step 6: Confirm the edits landed**

Run:
```bash
cd /home/dieco/dev/tools/diego-cc-kit
grep -c "N/A — no risk trigger" plugins/diego-cc-kit/agents/verifier.md
grep -c "Not for work you did yourself in-session" plugins/diego-cc-kit/skills/verify/SKILL.md
```
Expected: `1` and `1`.

- [ ] **Step 7: Commit**

```bash
git add plugins/diego-cc-kit/skills/verify/SKILL.md plugins/diego-cc-kit/agents/verifier.md
git commit -m "Scope verification to trust boundaries, make L4 conditional"
```

---

### Task 2: Scope the implement skill's Phase 3

**Files:**
- Modify: `plugins/diego-cc-kit/skills/implement/SKILL.md`

**Interfaces:**
- Consumes: Task 1's boundary rule and conditional-L4 policy.

This skill always delegates writing and always ends in a PR, so both boundary conditions hold — Phase 3 stays. Only its depth and its summary line change.

- [ ] **Step 1: Scope Phase 3 to delegated work**

Replace:

```
## Phase 3 — independent verification (never self-verify)

After the last step, get a fresh-context PASS before opening the PR: a verifier agent that did not write the code checks the diff against the plan's acceptance checklist through the full L1–L4 protocol in `agents/verifier.md` (gate re-run, exceptions audit, red-proof on new tests, adversarial + evidence review), per the `verify` skill's PASS/PARTIAL/FAIL format. PARTIAL/FAIL → back to Phase 2. The implementer's own test run is evidence, not a verdict.
```

with:

```
## Phase 3 — independent verification (never self-verify)

The diff was written by an agent that is not you, and it's heading to a PR — both reasons this phase exists. After the last step, get a fresh-context PASS before opening the PR: a verifier agent that did not write the code checks the diff against the plan's acceptance checklist per `agents/verifier.md` — L1 gate re-run, L2 exceptions audit, L3 red-proof on new tests, and L4 only if the change carries the risk L4 names. Report in the `verify` skill's PASS/PARTIAL/FAIL format. PARTIAL/FAIL → back to Phase 2. The implementer's own test run is evidence, not a verdict.

If you implemented a step yourself in the main session instead of delegating it, that part of the diff needs no separate verification pass — your own gate run is the evidence for it.
```

- [ ] **Step 2: Close the loophole in the header's definition of done**

Replace:

```
Executes one triage plan end to end. Single writer: no parallel agents editing the same files. Done = verification gate green + acceptance checklist checked + independent PASS + PR open. Not before, not "mostly".
```

with:

```
Executes one triage plan end to end. Single writer: no parallel agents editing the same files. Done = verification gate green + acceptance checklist checked + independent PASS on delegated work + PR open. Not before, not "mostly".
```

The unqualified "independent PASS" in the summary line re-imposes universal verification over Phase 3's new scoping.

- [ ] **Step 3: Rewrite the red-flag line**

Replace:

```
- "I ran the tests, it's verified" → you wrote it; you don't get to be the verifier. Phase 3 is someone else.
```

with:

```
- "The implementer said the tests pass" → that's a claim, not a result. Phase 3 re-runs the gate on the diff someone else wrote. (If you wrote the step yourself, your own run stands — don't re-run it for ceremony.)
```

The old line reads as "never trust your own test run" — the exact self-recheck the guide says to drop. The rewrite keeps the anti-cheat meaning.

- [ ] **Step 4: Confirm and commit**

Run:
```bash
grep -c "independent PASS on delegated work" plugins/diego-cc-kit/skills/implement/SKILL.md
```
Expected: `1`.

```bash
git add plugins/diego-cc-kit/skills/implement/SKILL.md
git commit -m "Scope implement Phase 3 verification to delegated work"
```

---

### Task 3: Invert the delegation default and rebuild routing around effort

**Files:**
- Modify: `plugins/diego-cc-kit/skills/orchestrate/SKILL.md`

**Interfaces:**
- Consumes: Task 1's boundary rule (Step 3 below is the merge point of the verification track and the delegation track — both tracks proposed edits to this same section).
- Produces: the `~10 tool calls` gate and the max-3 cap that Task 5 mirrors into CLAUDE.md.

This file currently pushes the opposite way twice: it tells the model to default to delegation, and separately that "over-routing is the default failure, not under-routing."

- [ ] **Step 1: Replace the Delegation Decision section**

Replace:

```
## Delegation Decision
- **Self-handle** (< 30 seconds): quick fix, one-liner, status check, single file read/grep
- **1 subagent** (Agent tool): single focused task — implementation, research, test writing
- **2-3 parallel subagents** (Agent tool, single message): independent tasks that don't share files
- **Agent team** (TeamCreate): 4+ parallel tickets needing worktree isolation and coordination

First instinct on any task: "Who handles this?" Default to delegation unless trivially fast.
```

with:

```
## Delegation Decision

Default is **self-handle**. Delegation is the exception you justify, not the reflex.

Run both gates in order. Delegate only if BOTH pass:

**Gate 1 — Size.** Can you finish it yourself in roughly ten tool calls or fewer?
Yes → do it yourself. No exceptions for "but an agent could do it in parallel";
spawning costs more wall-clock than ten reads.

**Gate 2 — Independence.** Do the tracks touch disjoint file sets, share no state, and
have no ordering between them? If any track needs another's output, or two would edit the
same file, it is one track — hand it to one agent, or do it yourself.

Both gates pass → **one** agent. Only split into several when the tracks are so large
that one agent would run out of room, not because splitting "feels parallel".

**Caps (hard):**
- Max **3** concurrent subagents. Reaching 3 is a signal to re-check Gate 2, not a target.
- **4+ agents / TeamCreate**: only for pre-planned worktree-isolated tickets, and only
  when the user asked for a team or approved a plan that names one. Never spun up on your
  own initiative.
- Never spawn an agent to verify, double-check, or re-read work you just did yourself.
- Never spawn an agent for a single file read, grep, status check, or one-line fix.

**Never delegate:** git operations, PR creation, GitHub issue updates, final integration,
the decision of what to delegate.
```

- [ ] **Step 2: Remove the "over-routing is fine" instruction**

Replace:

```
**Cost as a lazy-router check.** If opus/fable spend climbs without the tasks actually getting harder, the router went lazy — check `/usage` (per-model breakdown) and re-justify each expensive spawn. A growing main-model bar means the orchestrator is executing instead of delegating. Over-routing is the default failure, not under-routing.
```

with:

```
**Cost as a router check.** If spend climbs without the tasks getting harder, check
`/usage` (per-model breakdown) and re-justify. Two distinct leaks, with different fixes:
effort set higher than the task needs (fix: drop to `low`/`medium`), and agents spawned
for work the main session should have done (fix: apply the two gates). A growing
main-model bar is NOT a problem by itself — the orchestrator doing a ten-tool-call job
itself is the correct outcome, not a routing failure.
```

- [ ] **Step 3: Scope Executor ≠ Verifier (merged from both tracks)**

Replace:

```
## Executor ≠ Verifier
- The agent that did the work never verifies its own output
- After implementation, spawn a **separate verification agent** with fresh context (see the `verify` skill)
- Verification agent reports structured results (PASS/PARTIAL/FAIL with evidence)
```

with:

```
## Executor ≠ Verifier — for delegated work only

This rule exists because you cannot audit a sub-agent's diff from its own summary. It does
not apply to work you did yourself.

- **Work a sub-agent produced, heading for commit/PR** → spawn a fresh-context verifier
  (see the `verify` skill). You did not watch it happen; its report is a claim, not evidence.
  It reports PASS/PARTIAL/FAIL with evidence, and never modifies code.
- **Work you did yourself** → no verifier. Run the project's gate inline, read the output,
  move on. Don't re-run your own gate for ceremony, and don't spawn an agent to check your
  own diff.
- **Delegated work you can confirm in one command** (a one-line fix, a config edit, a doc
  change) → just run the command. A verifier agent costs more than the check it performs.
```

- [ ] **Step 4: Rebuild the spawn template to front-load the full spec**

Replace:

````
## Sub-Agent Spawn Template
```
## Inputs        — what the agent needs to start (file paths, context, existing patterns)
## Deliverables  — what "done" looks like concretely
## Verification  — how to confirm the work is correct (tests, lint, assertions)
## Worktree      — path and branch (when using parallel agents)
CRITICAL:        — one imperative sentence (the single most important constraint)
```
````

with:

````
## Sub-Agent Spawn Template

Hand over the **complete** specification in the spawn message and let the agent run to
completion. A spawn that says "start on X and report back for direction" wastes the round
trip — the agent will do better with the whole task than with the first third of it.

```
## Objective     — one measurable sentence: what is true when this is done
## Inputs        — absolute file paths, existing patterns to match, decisions already made
## Deliverables  — every file to create/change and what each must contain
## Non-goals     — what NOT to touch, refactor, rename, or "improve while in there"
## Verification  — the exact commands that prove it works (proven to exist in this repo)
## Worktree      — path and branch (required for any agent that writes files)
## Model/effort  — set explicitly at spawn (see Routing); never inherit
CRITICAL:        — one imperative sentence (the single hardest constraint)
```

Rules for composing it:
- Resolve ambiguity **before** spawning. An unresolved question in the brief comes back as
  a blocked agent or an invented answer.
- Every value the agent must use verbatim (names, paths, magic numbers, signatures) goes
  in the brief. Do not make it re-derive them.
- Do not paste session history. The agent needs its task, the interfaces it touches, and
  the constraints — nothing else.
- Say "deliver exactly this scope; if you think the spec is wrong, say so in one sentence
  and continue as specified." Opus 5 expands scope on its own otherwise.
- Do not ask for progress check-ins. Ask for one final report.
````

- [ ] **Step 5: Replace Model Routing with effort-first routing**

Replace:

```
## Model Routing
Choose the cheapest model that handles the task:
- **haiku**: file lookups, simple searches, reading docs, quick research, status checks
- **sonnet**: implementation, test writing, code review, documentation, most daily work (default)
- **opus**: complex architecture decisions, large file refactors (700+ lines), multi-system reasoning
- **fable**: main-loop only — never spawn a sub-agent on fable. If a subtask seems to need fable-level judgment, it isn't a subtask: handle it in the main session.

**Per-spawn, not per-agent.** These are choices you make at each spawn, via the Agent tool's `model` param — they override the sub-agent's frontmatter `model:`. A pinned `implementer: sonnet` is a *default, not a ceiling*: bump to opus for a genuinely hard step (debugging, edge cases, multi-system), drop to haiku for a trivial one. Set it explicitly at spawn; never let difficulty inherit the default.
```

with:

```
## Routing — effort is the primary lever, model is secondary

Pick **effort** first: it is the main control on token cost and latency, and `low`/`medium`
hold quality on most work. Only then pick the model. Reaching for a cheaper model to save
cost, while leaving effort high, optimizes the wrong knob.

| Task shape | model | effort |
|---|---|---|
| File lookup, grep, "where is X", status check | haiku | low |
| Broad read-only sweep across many files | sonnet | low |
| Docs/API lookup, summarizing a known source | haiku | low |
| Single-file mechanical edit from a complete spec | sonnet | low |
| Test writing against an existing pattern | sonnet | medium |
| **Multi-file feature, refactor, end-to-end implementation** | **opus** | **medium** |
| Review of a diff (first pass — report everything, filter after) | opus | low |
| Debugging with an unknown root cause | opus | high |
| Architecture / plan design / hard trade-off | opus | high |
| The above, and a medium/high attempt already failed | opus | xhigh |
| Orchestrator's own loop (triage, dispatch, bookkeeping) | session model | low–medium |

`fable`: main-loop only — never spawn a sub-agent on fable. If a subtask seems to need
fable-level judgment, it isn't a subtask: handle it in the main session.

**Multi-file implementation goes to opus.** It is the strongest model available at exactly
that shape of work. Routing it to sonnet to save money trades a real quality drop for a
saving that dropping effort would have given you anyway.

**Escalate effort, not model, first.** An agent that stalls or returns a shallow result at
`medium` usually needs `high` on the same model, not a different model. Step to `xhigh`
only for demanding agentic work that already failed at `high`.

**Per-spawn, not per-agent.** Set `model` AND `effort` explicitly on every Agent call —
they override the sub-agent's frontmatter. A pinned `implementer: sonnet, effort: medium`
is a floor for trivial work, not a ceiling: a multi-file task spawned on that pin is
mis-routed. In workflow scripts, the same two knobs are `opts.model` and `opts.effort`
(`'low'|'medium'|'high'|'xhigh'|'max'`).
```

- [ ] **Step 6: Confirm the inversion landed, and that nothing still says the opposite**

Run:
```bash
cd /home/dieco/dev/tools/diego-cc-kit
grep -n "Default to delegation\|Over-routing is the default failure" plugins/diego-cc-kit/skills/orchestrate/SKILL.md
grep -c "Delegation is the exception you justify" plugins/diego-cc-kit/skills/orchestrate/SKILL.md
```
Expected: the first grep prints **nothing** (exit 1); the second prints `1`.

- [ ] **Step 7: Commit**

```bash
git add plugins/diego-cc-kit/skills/orchestrate/SKILL.md
git commit -m "Invert delegation default, route by effort first"
```

---

### Task 4: Ship the plugin changes

**Files:**
- Modify (via script): `plugins/diego-cc-kit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: Tasks 1–3 committed. Nothing from those tasks is live until this task completes.

The marketplace cache is a git clone of `git@github.com:diecoscai/diego-cc-kit.git`, not a symlink to the working copy. Edits are inert until pushed and pulled back down under a new version number.

- [ ] **Step 1: Bump the version**

```bash
cd /home/dieco/dev/tools/diego-cc-kit
./bump.sh diego-cc-kit 0.3.0
```
Expected output: `diego-cc-kit: 0.2.0 -> 0.3.0`

Minor, not patch: the delegation and verification policies changed behavior, not just wording.

- [ ] **Step 2: Commit and push**

```bash
git add -A && git commit -m "chore: bump diego-cc-kit to 0.3.0" && git push
```

- [ ] **Step 3: Pull it into the running install**

```bash
claude plugin update diego-cc-kit@diego-cc-kit
```

- [ ] **Step 4: Restart Claude Code, then confirm the live copy is the new one**

After restart:
```bash
grep -c "Delegation is the exception you justify" ~/.claude/plugins/marketplaces/diego-cc-kit/plugins/diego-cc-kit/skills/orchestrate/SKILL.md
```
Expected: `1`. If it prints `0`, the update no-opped — check that the version bump was actually pushed.

---

### Task 5: Add the missing controls to CLAUDE.md

**Files:**
- Modify: `/home/dieco/.claude/CLAUDE.md`

**Interfaces:**
- Consumes: Task 3's gates and cap (mirrored here so they apply before any skill loads).
- Note: independent of Tasks 1–4. Can run in parallel with them.

CLAUDE.md carries every override whose upstream is not editable — superpowers and code-review both live in caches that plugin updates overwrite. It is also always loaded, so it is where the delegation decision must be visible: that decision happens before any skill would load.

- [ ] **Step 1: Soften Quality Gates from a pass into a property**

Replace:

```
## Quality Gates
Before commits, verify:
- No hardcoded secrets or API keys
```

with:

```
## Quality Gates
Properties any diff must satisfy (not a separate pass to run — hold them while writing):
- No hardcoded secrets or API keys
```

The list is worth keeping; "Before commits, verify:" is what reads as a mandated final verification step.

- [ ] **Step 2: Requalify the verify skill pointer**

Replace:

```
- `diego-cc-kit:verify` — fresh-context verification protocol (PASS/PARTIAL/FAIL); executor never verifies its own work
```

with:

```
- `diego-cc-kit:verify` — verification of work a *different* agent wrote, or work heading to a PR/merge (PASS/PARTIAL/FAIL). Work you did yourself in-session doesn't get a verification pass.
```

- [ ] **Step 3: Replace the orchestrator-effort bullet with effort-first + delegation caps**

Replace:

```
- **Orchestrator effort**: run triage/scan/routine steps at low-med reasoning effort; reserve high for the judgment call (plan design, scope decision, hard debugging). Your spend leaks in the orchestrator's own effort, not the fan-out — default low-med, bump deliberately.
```

with:

```
- **Effort before model**: effort is the primary cost/latency lever, model is secondary. Run triage/scan/routine steps at low-med; reserve high for the judgment call (plan design, scope decision, hard debugging), and xhigh only for demanding agentic work that already failed at high. Set `model` AND `effort` explicitly on every spawn — never inherit. Multi-file features and refactors go to opus, not sonnet.
- **Delegate reluctantly**: self-handle anything you can finish in ~10 tool calls. Delegate only for large, genuinely independent tracks; prefer one agent over several; max 3 concurrent; never spawn an agent to check work you did yourself. `diego-cc-kit:orchestrate` has the gates.
```

- [ ] **Step 4: Add the code-review override**

In the `## Tool Triggers (non-obvious only)` section, after the `deep-research-lean` bullet (the last bullet in that section), append:

```
- **`/code-review`** → its finding pass says "focus on large bugs, avoid small issues and nitpicks, ignore likely false positives". Ignore that instruction: report everything you find. Steps 5–6 of that same command already filter with an explicit 0–100 confidence score, so suppressing during the search pass just loses real bugs the filter would have kept.
```

The command lives in the plugin cache and is overwritten on every update, so CLAUDE.md is the only durable place to correct it.

- [ ] **Step 5: Rescope the two superpowers verification overrides**

Replace:

```
- **`verification-before-completion`**: use the `diego-cc-kit:verify` PASS/PARTIAL/FAIL format and a fresh-context verifier, never self-verify.
```

with:

```
- **`verification-before-completion`**: keep its rule about never claiming a result you didn't observe — say what you actually ran and what it printed. Do NOT read it as a mandate to re-run checks you already ran, or to re-verify your own in-session work before every statement. A fresh-context verifier (`diego-cc-kit:verify`, PASS/PARTIAL/FAIL) is for a diff another agent wrote, or one heading to a PR/merge.
```

Then replace:

```
- **`subagent-driven-development` / `dispatching-parallel-agents`**: follow `diego-cc-kit:orchestrate` delegation rules.
```

with:

```
- **`subagent-driven-development` / `dispatching-parallel-agents`**: follow `diego-cc-kit:orchestrate` delegation rules, including its routing table — SDD's own "use the least powerful model that can handle each role" does not apply. Its per-task reviewer is optional, not mandatory: dispatch one when the task is risk-bearing (auth, money, multi-tenancy, migrations, deletion) or when the implementer reported DONE_WITH_CONCERNS. Otherwise go straight to the next task and rely on the single whole-branch review at the end. The fix loop's cap of 5 rounds is a ceiling, not a target — two rounds without convergence is already a signal to adjudicate.
- **`requesting-code-review`**: its "mandatory after each task / after every major feature" does not apply. Review once per branch, before merge. Skip the reviewer entirely for diffs you can judge in one read.
```

SDD runs implementer + task reviewer + up to five scoped re-reviews *per task*, then a whole-branch review on top. That is the guide's "legacy harness scaffolding that adds separate verification steps", multiplied by task count.

- [ ] **Step 6: Add the "Talking to me" section**

Insert immediately **above** the `## Tool Triggers (non-obvious only)` heading, followed by one blank line:

```markdown
## Talking to me
- **Conciseness**: keep responses focused and brief. Spend most of the response on the main answer, keep caveats and disclaimers short, and when asked to explain something give a high-level summary unless I ask for depth. Explanation I explicitly asked for — a report, a walkthrough, per-phase notes — is not verbosity; give it in full.
- **Progress cadence**: before your first tool call, say in one sentence what you're about to do. While working, update me only when you find something important or change direction. When you finish, lead with the outcome — the first sentence answers "what happened" or "what did you find", supporting detail after it.
- **Written deliverable length**: match the length of files you write to disk to what the task needs. Cover the substance; do not pad with filler sections, redundant summaries, or boilerplate. This binds on `docs/plans/active/*/PLAN.md` and `PROGRESS.md`, the CV under `~/dev/personal/cv/`, Obsidian wiki pages, and SEO audit reports — the long-form artifacts, exactly where padding is easiest to hide.
```

It sits directly above the existing "announce skill use in one short sentence" line, so the two narration rules read as one cluster. The carve-out for requested explanation is reproduced near-verbatim from ponytail's own Output rule, so the two texts agree rather than compete.

- [ ] **Step 7: Add the end-of-file tone reminder**

Append at the very end of the file — one blank line after the current last line, then:

```markdown
<tone_preference>
Keep outputs reasonably concise.
</tone_preference>
```

The guide's specific advice for a long prompt is to pair the conciseness instruction with a short reminder near the end. CLAUDE.md is the last block under Diego's control.

- [ ] **Step 8: Confirm all seven edits landed**

Run:
```bash
grep -c "Talking to me\|tone_preference\|Delegate reluctantly\|Effort before model\|report everything you find\|Properties any diff must satisfy\|Review once per branch" ~/.claude/CLAUDE.md
grep -n "Before commits, verify\|Default to delegation\|never self-verify" ~/.claude/CLAUDE.md
```
Expected: first prints `7`; second prints **nothing**.

---

### Task 6: Narrow the legacy orchestrator skill

**Files:**
- Modify: `/home/dieco/.claude/skills/orchestrator/SKILL.md` (remove lines 82–116, edit lines 4 and 58)
- Modify: `/home/dieco/.claude/skills/orchestrator/WORKFLOW.md` (remove lines 275–332, i.e. the trailing `---` through EOF)

**Interfaces:**
- Consumes: Task 5's delegation caps (this task removes the text that would violate them).

This skill's Team Mode contains a "zero-idle rule: every agent always has a primary and secondary task… No agent ever waits" plus a fixed five-agent roster — it *manufactures* work to keep five agents busy, the direct inverse of the max-3 cap. It is also gated on Linear, which is not configured here (the tracker in use is GitHub via `aai-pm-github`). Decision taken: narrow, not retire.

- [ ] **Step 1: Delete the Team Mode section from SKILL.md**

Delete the entire block from the line `## Team Mode` through the line ending `...a separate verifier pass runs on final deliverables.`, plus the blank line following it. The next heading, `## How It Works`, must survive and become the section directly after `/orchestrator stats`.

- [ ] **Step 2: Delete Stage T from WORKFLOW.md**

Delete from the `---` separator that precedes `## Stage T: Team Execution` through the end of the file. `- You define the boundaries. The system operates inside them.` becomes the last line.

- [ ] **Step 3: Narrow the skill description so it stops competing for delegation questions**

The `description:` field is what makes a skill auto-select. While it advertises "expert orchestrator of agentic teams", it will keep loading on delegation questions that `diego-cc-kit:orchestrate` now owns.

In `SKILL.md`, replace line 4:

```
description: "Expert orchestrator of agentic teams. Ticket contract defines work. Independent verification harness rules completion."
```

with:

```
description: "Board-driven ticket sweep: reads tickets, dispatches one agent per ticket, rules completion via the verification harness. For how to delegate, how many agents, and model/effort routing, use diego-cc-kit:orchestrate instead."
```

And replace line 58:

```
Expert orchestrator of agentic teams. Define the ticket contract — the verification harness rules completion.
```

with:

```
Board-driven ticket sweep. Define the ticket contract — the verification harness rules completion. Delegation policy, spawn caps and model/effort routing live in `diego-cc-kit:orchestrate`; this skill defers to it.
```

- [ ] **Step 4: Confirm Team Mode is gone and the files are still well-formed**

Run:
```bash
cd ~/.claude/skills/orchestrator
grep -n -i "zero-idle\|## Team Mode\|Stage T" SKILL.md WORKFLOW.md
tail -1 WORKFLOW.md
grep -c "^## How It Works" SKILL.md
```
Expected: first grep prints **nothing**; `tail` prints `- You define the boundaries. The system operates inside them.`; last prints `1`.

---

### Task 7: Set per-spawn effort in deep-research-lean

**Files:**
- Modify: `/home/dieco/.claude/workflows/deep-research-lean.js` (six `agent()` opts objects)

**Interfaces:**
- Consumes: Task 3's routing table (this applies it to the one place that fans out widest).

The workflow's ceiling is ~58 agents (`MAX_FETCH=15`, `MAX_CENTRAL=8`, `MAX_SUPPORTING=12`). **That scale stays** — it is a deterministic pipeline with hard caps and genuinely independent tracks, which is the case the guide says delegation pays off on. What is wrong is that all six spawn sites set `model` and leave `effort` unset, so every one of those ~58 agents inherits the session default on narrow, schema-constrained work.

`opts.effort` is supported by the Workflow runtime (`'low'|'medium'|'high'|'xhigh'|'max'`) — it is handled by the harness, not by anything inside `~/.claude/workflows/`, which is why grepping that directory finds nothing.

- [ ] **Step 1: Set effort on all six spawn sites**

| Find | Replace with |
|---|---|
| `{ label: "scope", model: "sonnet", schema: SCOPE_SCHEMA }` | `{ label: "scope", model: "sonnet", effort: "medium", schema: SCOPE_SCHEMA }` |
| `label: "search:" + angle.label, phase: "Search", model: "haiku", schema: SEARCH_SCHEMA` | `label: "search:" + angle.label, phase: "Search", model: "haiku", effort: "low", schema: SEARCH_SCHEMA` |
| the `fetch:` opts object's `model: "sonnet",` line | add `effort: "low",` on the following line |
| the lens-verify opts object's `model: "sonnet",` line | add `effort: "medium",` on the following line |
| the `contra:` opts object's `model: "sonnet",` line | add `effort: "medium",` on the following line |
| `{ label: "synthesize", model: "sonnet", schema: REPORT_SCHEMA }` | `{ label: "synthesize", model: "opus", effort: "high", schema: REPORT_SCHEMA }` |

Search and fetch are schema-bound extraction — the `low`-effort sweet spot, and the bulk of the spawns. Lens votes are judgment calls, so `medium`. Synthesis determines the entire report's value and currently runs on sonnet; it is the one place in this pipeline worth spending on.

- [ ] **Step 2: Confirm the edits are syntactically valid**

Run:
```bash
node --check ~/.claude/workflows/deep-research-lean.js && grep -c "effort:" ~/.claude/workflows/deep-research-lean.js
```
Expected: no output from `--check` (valid), then `6`.

- [ ] **Step 3: Smoke-test one real run**

```
Workflow({name: 'deep-research-lean', args: 'What is the current stable release of Node.js and when was it released?'})
```
A deliberately small question. Confirm it completes and returns a report. This checks that `effort` in opts is accepted at runtime and does not throw — the parameter is documented, but this pipeline has never passed it before.

---

### Task 8: Capture everything back into dotfiles

**Files:**
- Modify: the chezmoi source for `~/.claude/CLAUDE.md`, `~/.claude/skills/orchestrator/*`, `~/.claude/workflows/deep-research-lean.js`

**Interfaces:**
- Consumes: Tasks 5, 6 and 7 complete. (Tasks 1–4 live in their own git repo and are already pushed.)

`~/.claude/CLAUDE.md` is chezmoi-managed; edits made live are lost on the next `chezmoi apply` unless re-added to the source.

- [ ] **Step 1: Run the capture skill**

```
/update-dotfiles
```
It captures live → source and commits. Confirm the diff it shows includes CLAUDE.md, the two orchestrator files, and the workflow.

- [ ] **Step 2: Confirm nothing drifted**

```bash
chezmoi diff ~/.claude/CLAUDE.md
```
Expected: no output (source matches live).

---

## Self-Review

**Spec coverage** — every finding from the three research tracks maps to a task:

| Finding | Task |
|---|---|
| verify skill: universal → boundary-scoped; L4 conditional | 1 |
| verifier agent: run mandate, L4 section, N/A report slot | 1 |
| implement Phase 3 + summary line + red-flag line | 2 |
| orchestrate: delegation default inverted, hard caps | 3 |
| orchestrate: "over-routing is the default failure" removed | 3 |
| orchestrate: Executor ≠ Verifier (merge point of both tracks) | 3 |
| orchestrate: spawn template front-loads complete spec | 3 |
| orchestrate: routing rebuilt effort-first, multi-file → opus | 3 |
| plugin propagation (bump → push → update → restart) | 4 |
| CLAUDE.md: Quality Gates phrasing | 5 |
| CLAUDE.md: verify pointer requalified | 5 |
| CLAUDE.md: effort-first + delegation caps | 5 |
| CLAUDE.md: `/code-review` "report everything" override | 5 |
| CLAUDE.md: `verification-before-completion` rescoped | 5 |
| CLAUDE.md: SDD per-task review made optional; `requesting-code-review` descoped | 5 |
| CLAUDE.md: conciseness, progress cadence, deliverable length | 5 |
| CLAUDE.md: `<tone_preference>` end-of-prompt reminder | 5 |
| legacy orchestrator: Team Mode + Stage T removed, description narrowed | 6 |
| deep-research-lean: per-spawn effort | 7 |
| chezmoi capture | 8 |

**Checked and deliberately not changed:** `settings.json` (`effortLevel: medium`, `model: opus[1m]`, agent-teams flag — all already aligned); the six agent `model:` frontmatter pins (per-spawn override is the fix, not raising the floor); git-worktree rules (filesystem isolation, orthogonal to spawn policy); `skills/triage/`; `skills/codegraph-usage/` (its "do NOT re-verify with grep" actively prevents over-verification); all hooks (facts only, nothing suppresses reasoning — so no XML-tag-leakage risk); vision workarounds (swept for stale older-model language, zero hits); `alwaysThinkingEnabled: true` (guide says keep thinking on and lower effort instead).

**Type consistency:** the boundary rule is worded identically across `verify/SKILL.md`, `verifier.md`, `implement/SKILL.md`, `orchestrate/SKILL.md` and `CLAUDE.md` — "a diff a *different* agent wrote, or work heading to a PR/merge". The L4 risk list (auth/permissions, multi-tenancy, money, migrations, deletion paths, unobservable UI) is identical in all three places it appears. The delegation cap is "max 3 concurrent" in both `orchestrate` and `CLAUDE.md`.

**Known residual tension:** superpowers' own `verification-before-completion` and `requesting-code-review` still contain their unqualified mandates; Task 5 overrides them from CLAUDE.md. This resolves by precedence (superpowers' own `using-superpowers` states user instructions outrank skills), but the two texts do disagree on their face. That is why the overrides are phrased "keep X, do not read it as Y" rather than as flat contradictions. If it ever bites in practice, the clean fix is a diego-cc-kit skill that supersedes SDD outright — the cache cannot be edited across updates.

**One unverifiable assumption, flagged rather than papered over:** the harness system prompt in this session already ships scope-discipline ("Delivering work") and correction-narration ("Corrections") rules that match the guide almost verbatim, so no task duplicates them. Whether that holds across every Claude Code version and mode is not checkable from config. If scope creep or chatty self-corrections ever reappear, those two rules are the ones to add to CLAUDE.md.
