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
| 7 | `stop-gate.sh` hook + tests + README | kit | done (aeef641 + fix 38176c8, 18/18 hook tests PASS) |
| 8 | Bump 0.4.0 → push → update → restart | kit | done (c70abb4 on origin/main); restart pending Diego — this PC loads the kit via `--plugin-dir`, so `plugin update` is N/A here |
| 9 | After `/context`, `/doctor`, Stop hook smoke | ~/.claude | pending |
| 10 | `/update-dotfiles` capture | chezmoi | pending |

## Baseline

- 2026-09-02 — visible-skill count (`grep -L '^disable-model-invocation: true' */SKILL.md | wc -l`): **67** of 68 (only `push` hidden). CLAUDE.md: 81 lines. `/context` totals: **pending Diego** (interactive; run in a fresh session before Task 9).

## After

(Task 9 writes here.)

## Log

- **2026-09-02** — Chains A and B executed via two parallel sonnet implementers on disjoint files; controller re-verified every confirm command. Task 7 plan defect found by the implementer: the test fixture left `.claude/gate` untracked, so the "clean tree" case was dirty. Ruling: fix the fixture (commit the gate), keep the hook's dirty-check as written, because an untracked file created by Claude is a change worth gating. Branch `feat/agentic-workflow-tuning` in worktree `../wt-agentic-workflow-tuning`, 3 commits; whole-branch review dispatched before merge/bump.
- **2026-09-02** — Whole-branch review (opus): 0 critical, 3 important, 6 minor. Fixed in one wave (`38176c8`): the hook now resolves the repo root from `cwd` and excludes `.claude/gate` from the dirty check; README recipe commits the gate; CLAUDE.md says the `goal:` line lives in the plan header. Two tests added (untracked gate → allow; subdir cwd → block). Parked minors: `stop_hook_active` unchecked (8-block cap bounds it), 600 s hook timeout, gate = repo-owned code execution (opt-in by design), CLAUDE.md interview wording. Merged to main, bumped 0.4.0, pushed. `claude plugin update` is N/A on this PC (kit loads via `--plugin-dir`); other PC: `claude plugin marketplace update diego-cc-kit && claude plugin update diego-cc-kit@diego-cc-kit`.

## Rulings made during execution (from the SDD ledger)
- Ruling: interactive steps (T0 /context, T2.3, T4.5, T9) are recorded as "pending Diego" — subagents do the scriptable part; skipping them costs a missing before/after number, not correctness.
- Ruling: Chain A (T1–T4) and Chain B (T5–T7) dispatched as ONE implementer each, in parallel, disjoint file sets — per CLAUDE.md "prefer one agent over several" and SDD "batch small same-shape work". Cost if wrong: one agent's partial failure blocks its whole chain, not the other.
- Ruling: model sonnet / effort medium for both implementers — every edit is verbatim text or fully specified code (routing table: mechanical from complete spec). Cost if wrong: a fix round on opus.
- Ruling: per-task reviewer skipped (CLAUDE.md override: optional unless risk-bearing or DONE_WITH_CONCERNS); one whole-branch review at the end covers both chains.
- Ruling: subagents run no git; main session commits/merges/pushes.
- Ruling: fix the TEST, not the hook — commit the gate in the fixture right after creating it (`git add .claude/gate && git commit -q -m gate`), because in a real repo the gate is a tracked file and an untracked file created by Claude IS a change worth gating. Cost if wrong: a repo that keeps .claude/gate untracked would gate every stop; documented opt-in says commit it.
- Ruling: I-1 fixed both ways — hook probe excludes `.claude/gate` from the dirty check (pathspec `:!.claude/gate`) AND README recipe commits the gate. Cost if wrong: none visible; a tracked gate and an untracked one both behave.
- Ruling: I-2 fixed by resolving `git rev-parse --show-toplevel` from cwd; gate runs from the repo root. Cost if wrong: a repo whose gate expects a subdir cwd — none exist.
- Ruling: I-3 fixed by rewording CLAUDE.md to "carries a `goal:` line in its header".
- Ruling: minors — jq stderr silenced (trivial, included); stop_hook_active unchecked → parked, the harness's 8-block cap already bounds it; 600s timeout → parked, gate scripts are the repo's own test command; "gate = repo code execution" → parked, opt-in by design and same trust as running `npm test`; CLAUDE.md interview "unconditional" → parked, the line already scopes it to "feature or multi-file change with unknowns"; unlogged fixture deviation → already logged in PROGRESS.md.
- Ruling: ONE fix dispatch (sonnet) then controller verifies the fix diff by test run + single read instead of a re-review agent (CLAUDE.md: skip the reviewer for diffs judgeable in one read). Cost if wrong: a missed regression in ~40 lines of bash that 18 tests cover.
