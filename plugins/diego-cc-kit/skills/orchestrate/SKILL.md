---
name: orchestrate
description: Use when deciding how to delegate work across sub-agents — choosing between self-handling, one agent, parallel agents, or a worktree-isolated team — and for model routing and git-worktree conventions for parallel work.
---

# Agent Team Orchestration

## Delegation Decision
- **Self-handle** (< 30 seconds): quick fix, one-liner, status check, single file read/grep
- **1 subagent** (Agent tool): single focused task — implementation, research, test writing
- **2-3 parallel subagents** (Agent tool, single message): independent tasks that don't share files
- **Agent team** (TeamCreate): 4+ parallel tickets needing worktree isolation and coordination

First instinct on any task: "Who handles this?" Default to delegation unless trivially fast.

## Responsibility Split
- **Main session**: task decomposition, git operations (commit, push, PR), GitHub issue updates, final integration, verification coordination
- **Sub-agents**: codebase exploration, implementation, test writing, documentation
- Sub-agents must NOT: commit, create PRs, update GitHub issues, modify files outside assigned scope

## Executor ≠ Verifier
- The agent that did the work never verifies its own output
- After implementation, spawn a **separate verification agent** with fresh context (see the `verify` skill)
- Verification agent reports structured results (PASS/PARTIAL/FAIL with evidence)

## Finishing Beats Starting
Always check for review/verification/blocked work before starting new tasks. Completing in-flight work has higher priority than spawning new work.

## Sub-Agent Spawn Template
```
## Inputs        — what the agent needs to start (file paths, context, existing patterns)
## Deliverables  — what "done" looks like concretely
## Verification  — how to confirm the work is correct (tests, lint, assertions)
## Worktree      — path and branch (when using parallel agents)
CRITICAL:        — one imperative sentence (the single most important constraint)
```

## Model Routing
Choose the cheapest model that handles the task:
- **haiku**: file lookups, simple searches, reading docs, quick research, status checks
- **sonnet**: implementation, test writing, code review, documentation, most daily work (default)
- **opus**: complex architecture decisions, large file refactors (700+ lines), multi-system reasoning

## Git Worktree Rules
When using agent teams for parallel work, each task gets an isolated worktree:
```bash
git worktree add ../wt-GH-<number>-<slug> -b feat/GH-<number>-<slug>
```
- Main worktree stays on integration branch
- One agent per worktree — never two agents in the same worktree
- Branch naming: feature/, fix/, chore/ (existing convention)
- After merge, cleanup: `git worktree remove ../wt-GH-<number>-<slug>`
