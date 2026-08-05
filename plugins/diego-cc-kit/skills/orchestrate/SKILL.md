---
name: orchestrate
description: Use when deciding how to delegate work across sub-agents — choosing between self-handling, one agent, parallel agents, or a worktree-isolated team — and for model routing and git-worktree conventions for parallel work.
---

# Agent Team Orchestration

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

**Split by scope, never by role.** One agent owns its track end-to-end: implement, test,
clean, self-check. Do not build specialist pipelines (implementer → cleaner → hardener →
reviewer as separate agents) — every handoff loses context and serializes the work, and
the roles are an org chart, not a decomposition. The one legitimate role split is the
fresh-context verifier, and only because its value IS the independence, not the specialty.

**Caps (hard):**
- Max **3** concurrent subagents. Reaching 3 is a signal to re-check Gate 2, not a target.
- **4+ agents / TeamCreate**: only for pre-planned worktree-isolated tickets, and only
  when the user asked for a team or approved a plan that names one. Never spun up on your
  own initiative.
- Never spawn an agent to verify, double-check, or re-read work you just did yourself.
- Never spawn an agent for a single file read, grep, status check, or one-line fix.

**Never delegate:** git operations, PR creation, GitHub issue updates, final integration,
the decision of what to delegate.

**Known control flow → script it, don't supervise it.** If the steps and their order are
known before starting (fixed pipeline, fan-out over an enumerable list), the sequencing
belongs in deterministic code — a Workflow script (only when the user opted into
workflows) or a plain loop in the main session — with agents at the nodes. An agent
deciding transitions that are already fixed adds nondeterminism exactly where you wanted
none. Reserve agent judgment for steps whose outcome actually changes what happens next.

A scripted pipeline needs its fail-path designed too, not just the happy path:
- **On a step failure, resume at that step** with the failure context attached — never
  restart the whole chain, never fall back to ad-hoc per-step judgment.
- **Draft the terminal acceptance check before spawning stage 1.** A check written after
  seeing the output tends to fit the output.
- **Dry-run the chain on paper first**: for 2+ chained spawns, check each stage's output
  contract against the next stage's Inputs before spawning stage 1. A gap found here
  costs one sentence; found after stage 2 spawns, it costs a wasted agent.

## Responsibility Split
- **Main session**: task decomposition, git operations (commit, push, PR), GitHub issue updates, final integration, verification coordination
- **Sub-agents**: codebase exploration, implementation, test writing, documentation
- Sub-agents must NOT: commit, create PRs, update GitHub issues, modify files outside assigned scope

## Executor ≠ Verifier — for delegated work only

This rule exists because you cannot audit a sub-agent's diff from its own summary. It does
not apply to work you did yourself.

The dominant sub-agent failure is not a crash or a timeout — it is plausible-wrong output
delivered with a confident DONE. Two consequences:
- **You design the check, not the agent.** The `## Verification` field in the brief is the
  orchestrator's contribution: the property that must be true, chosen before spawning. An
  agent left to pick its own check picks one its output passes.
- **A report's narrative counts as nothing.** Only command output the agent pasted (or you
  re-ran) is evidence. "Tests pass" without the test output is a claim, not a result.

- **Work a sub-agent produced, heading for commit/PR** → spawn a fresh-context verifier
  (see the `verify` skill). You did not watch it happen; its report is a claim, not evidence.
  It reports PASS/PARTIAL/FAIL with evidence, and never modifies code.
- **Work you did yourself** → no verifier. Run the project's gate inline, read the output,
  move on. Don't re-run your own gate for ceremony, and don't spawn an agent to check your
  own diff.
- **Delegated work you can confirm in one command** (a one-line fix, a config edit, a doc
  change) → just run the command. A verifier agent costs more than the check it performs.

## Finishing Beats Starting
Always check for review/verification/blocked work before starting new tasks. Completing in-flight work has higher priority than spawning new work.

A delegation round isn't finished until every spawned agent's report is collected — an
agent id with no result is unobserved work, not done work.

## Retry Policy — one different retry, then the user

Applies to a verifier FAIL and to an agent that errors out or returns nothing (treat both
as FAIL):

- **Retry once, and the retry must differ.** Carry the failure evidence into the brief
  (what failed, why) and/or escalate effort per Routing. An identical respawn is the same
  coin flip — expect the same confident-wrong DONE.
- **A second failure on the same task escalates to the user**, with both failure reports.
  Not a third attempt, not a silently shrunken scope.

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
- Require the final report to account for every `## Deliverables` item — done / partial /
  skipped, with the verification output for each. A bare DONE with no per-item accounting
  is not a report; it is how 3-of-5 gets read as 5-of-5.
- Tell the agent: on an ambiguity the brief doesn't resolve, stop and report the blocking
  question instead of guessing — a wrong guess costs more than the round trip.

## Spawn Hygiene & Idle Recovery

Reglas duras de spawn — cada una evita un bug conocido del harness (anthropics/claude-code):

- **No pasar `name` al Agent tool** salvo que necesites `SendMessage` con ese agente.
  Con agent-teams activo, `name` cambia el spawn al protocolo teammate y el resultado
  se pierde (llega como `idle_notification` vacío, nunca como `task-notification`) — #71723,
  confirmado por mantenedores. Elegís: direccionabilidad O entrega confiable, no ambas.
- **Prohibido `run_in_background: true` (Bash) dentro de un subagente.** Un subagente
  in-process no tiene wake inlet: si cierra turno esperando la notificación, queda idle
  para siempre mientras el resultado está en disco (#78782). Todo Bash de subagente es
  foreground; si algo tarda >10 min, que el subagente haga polling de un archivo marcador
  con deadline, nunca que espere una notificación.
- **Un subagente en background no tiene el Agent tool.** No pedirle que delegue a su vez;
  se ve como idle. Si la tarea necesita fan-out, el fan-out lo hace la sesión principal.
- **`Monitor` dentro de un subagente no funciona** — el wake se descarta. Solo top-level.

Protocolo de recuperación cuando un subagente queda idle sin reporte (en orden, parar
en el primer paso que funcione):

1. **Nudge 1**: `SendMessage` pidiendo el resultado.
2. **Nudge 2** (el que suele funcionar — #87009): "Mandá tu reporte completo AHORA como
   único mensaje." El agente casi siempre terminó; el reporte se perdió en el canal.
3. **Leer el trabajo de disco**: `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/subagent-diag.sh`
   lista los subagentes de la sesión con tool calls y último mensaje. El transcript
   completo está en `~/.claude/projects/<cwd-encoded>/<session-id>/subagents/agent-<id>.jsonl`.
   Si el deliverable está ahí, usalo y matá al agente (`TaskStop`).
4. **Re-despachar** solo si el JSONL muestra trabajo incompleto — y con el mismo brief,
   nunca "continuá donde quedaste" (el agente nuevo no tiene el contexto del muerto).

Nunca: reiniciar la sesión padre (no recupera nada), reintentar `SendMessage` en loop,
ni re-despachar sin mirar el JSONL primero (el trabajo suele estar completo en disco).

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

## Git Worktree Rules
**Any sub-agent that writes files gets its own worktree — never spawn a writer into the shared checkout.** A writer in the shared checkout can switch branches or dirty the tree under the main session (and under other live sessions). Read-only agents (researcher, verifier) may share the checkout.
```bash
git worktree add ../wt-GH-<number>-<slug> -b feat/GH-<number>-<slug>
```
- Main worktree stays on integration branch
- One agent per worktree — never two agents in the same worktree
- Branch naming: feature/, fix/, chore/ (existing convention)
- After merge, cleanup: `git worktree remove ../wt-GH-<number>-<slug>`
