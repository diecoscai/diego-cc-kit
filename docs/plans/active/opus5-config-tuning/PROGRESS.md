# Progress — Opus 5 Config Tuning

Plan: [PLAN.md](./PLAN.md) · Started 2026-07-28

## Status

| # | Task | Location | Status |
|---|---|---|---|
| 1 | Scope verification to trust boundaries | diego-cc-kit repo | **Done** (`daea9ab`) |
| 2 | Scope implement Phase 3 | diego-cc-kit repo | **Done** (`6d02f12`) |
| 3 | Invert delegation, route by effort | diego-cc-kit repo | **Done** (`f1f2819`) |
| 4 | Ship plugin (bump → push → update → restart) | diego-cc-kit repo | **Done** except restart (`2bca0d9`, v0.3.0 installed) |
| 5 | CLAUDE.md controls + overrides | ~/.claude | **Done** |
| 6 | Narrow legacy orchestrator skill | ~/.claude | **Done** |
| 7 | Per-spawn effort in deep-research-lean | ~/.claude | **Done** |
| 8 | Capture into dotfiles | chezmoi | **Done** (committed, not pushed) |

## Ordering

Two independent chains — 1→2→3→4 and 5→6→7→8 — that can run in parallel. Task 4 is a hard gate: nothing from Tasks 1–3 is live until it completes, because the marketplace cache is a git clone, not a symlink.

## Decisions taken

- **Legacy `~/.claude/skills/orchestrator/`: narrow, not retire.** Team Mode (zero-idle rule, fixed 5-agent roster) and Stage T come out; the sweep/verification lifecycle stays. Its `description:` is narrowed too, or it keeps auto-selecting against `diego-cc-kit:orchestrate`.
- **`/code-review` self-censorship: override from CLAUDE.md**, not a local command fork. The command lives in a plugin cache that updates overwrite; a fork would be ~100 lines of drift. Upstream issue not filed.
- **L1 gate re-run stays** in the cross-boundary protocol. Re-running a gate on a diff another agent wrote is reading a claim, not redoing work — it costs one command and it is the only check that catches a report not matching the tree. It is dropped only inside a single agent.
- **`settings.json` untouched.** `effortLevel: medium` is already below the guide's default and in the direction it endorses; `model: opus[1m]` is what the whole setup is built around. Re-evaluate `high` if multi-file work at `medium` starts needing a second prompt.

## Open

- ~~Task 7 Step 3 smoke test~~ — resolved, see log. `opts.effort` is accepted by the runtime.
- **Restart Claude Code** to load diego-cc-kit 0.3.0. Until then the running process still holds the 0.2.0 skills, so the new delegation gates and verification scoping are installed but not live.
- Superpowers' unqualified verification mandates are overridden by precedence, not removed. If the override stops holding in practice, the fix is a diego-cc-kit skill that supersedes `subagent-driven-development`.

## Log

- **2026-07-28** — `~/.claude` chain (Tasks 5–8) executed. `opts.effort` confirmed accepted by the workflow runtime via a 1-agent probe (`{"got":"ok"}`, 0 errors) instead of a full deep-research run. Dotfiles captured on branch `chore/opus5-config-tuning` (commit `f214e3a`), **not pushed**. Pre-existing unrelated drift left alone: `dot_claude/mcp-servers.reference.json` uncommitted in the source repo, and `settings.json` / `.zshrc` still showing `MM` from the older backlog.

- **2026-07-28** — Plan written. Three research tracks (verification / delegation+routing / verbosity+sweep) delivered; conflicting edits to `orchestrate`'s Executor ≠ Verifier section merged into Task 3 Step 3. Two propagation facts verified before planning: the marketplace cache is a GitHub clone (so plugin edits need bump+push+update+restart), and `opts.effort` is a real runtime parameter (so the deep-research change is not blocked).

- **2026-07-28** — Plugin chain (Tasks 1–4) executed via three parallel subagents on disjoint files, none permitted to run git. Main session verified the combined diff independently before committing: 4 files / +147 / −44, no stray edits, spawn-template fence and routing table intact, no old instruction surviving. Bumped to 0.3.0, pushed, `claude plugin update` reports 0.2.0 → 0.3.0 installed. **Restart of Claude Code still pending** — until then the running process holds the 0.2.0 skills.
