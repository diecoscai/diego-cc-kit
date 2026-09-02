# Agentic Workflow Tuning — Progress

Plan: `PLAN.md` (same directory). Spec: `~/dev/docs/research/agentic-workflows-referentes-2026-09.md` §7.

| # | Task | Where | Status |
|---|------|-------|--------|
| 0 | Baseline `/context` + visible-skill count | ~/.claude | partial — count recorded, `/context` pending Diego |
| 1 | Hide 56 user-invoked skills | ~/.claude/skills | done |
| 2 | `cc` alias → `--permission-mode auto` | ~/.zshrc + dotfiles | done (smoke test pending Diego) |
| 3 | Drop `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | ~/.claude/settings.json | done |
| 4 | Planning gates + `rules/react-ts.md` | ~/.claude | done (`/context` check pending Diego) |
| 5 | Triage: interview step + `goal:` line | kit | done (ba5b39b, worktree branch) |
| 6 | Implement: `/goal` + UI evidence | kit | done (436168b) |
| 7 | `stop-gate.sh` hook + tests + README | kit | done (aeef641, 16/16 hook tests PASS) |
| 8 | Bump 0.4.0 → push → update → restart | kit | pending |
| 9 | After `/context`, `/doctor`, Stop hook smoke | ~/.claude | pending |
| 10 | `/update-dotfiles` capture | chezmoi | pending |

## Baseline

- 2026-09-02 — visible-skill count (`grep -L '^disable-model-invocation: true' */SKILL.md | wc -l`): **67** of 68 (only `push` hidden). CLAUDE.md: 81 lines. `/context` totals: **pending Diego** (interactive; run in a fresh session before Task 9).

## After

(Task 9 writes here.)

## Log

- **2026-09-02** — Chains A and B executed via two parallel sonnet implementers on disjoint files; controller re-verified every confirm command. Task 7 plan defect found by the implementer: the test fixture left `.claude/gate` untracked, so the "clean tree" case was dirty. Ruling: fix the fixture (commit the gate), keep the hook's dirty-check as written, because an untracked file created by Claude is a change worth gating. Branch `feat/agentic-workflow-tuning` in worktree `../wt-agentic-workflow-tuning`, 3 commits; whole-branch review dispatched before merge/bump.
