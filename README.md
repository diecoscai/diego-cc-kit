# diego-cc-kit

A Claude Code marketplace bundling a reusable orchestration setup — sub-agents,
triage→implement→verify skills, and safety hooks — so it's portable across
machines and projects instead of living only in `~/.claude`.

## Contents (`plugins/diego-cc-kit/`)
- **agents/** — 6 sub-agents: implementer, researcher, tester, verifier, fullstack-integrator, ts-react-reviewer
- **skills/** — `triage` (issue → executable plan), `implement` (plan → verified PR), `orchestrate` (delegation + model routing + worktree rules), `verify` (fresh-context verification protocol), `codegraph-usage` (on-demand CodeGraph guidance)
- **hooks/** — bash-validator (blocks dangerous rm under HOME), style-check (post Edit/Write), secret-guard + test-guard (pre Edit/Write), mcp-snapshot + session-context (SessionStart), worktree create/remove lifecycle, and **stop-gate** (Stop): if a repo has an executable `.claude/gate`, Claude can't end its turn while the tree is dirty and the gate fails. Opt in per repo with e.g. `printf '#!/bin/bash\nnpm test && npm run lint\n' > .claude/gate && chmod +x .claude/gate`. Scripts referenced via `${CLAUDE_PLUGIN_ROOT}`.

A second plugin, **evidence-kit**, ships PR/issue evidence tooling (Playwright capture + inline GitHub embed).

## Install
```bash
/plugin marketplace add diecoscai/diego-cc-kit
/plugin install diego-cc-kit@diego-cc-kit
```
Update later:
```bash
/plugin marketplace update diego-cc-kit
/plugin update diego-cc-kit@diego-cc-kit
```
Local dev/testing: `claude --plugin-dir <clone>/plugins/diego-cc-kit`

## License
MIT
