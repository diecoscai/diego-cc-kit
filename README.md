# diego-cc-kit

A Claude Code marketplace bundling a reusable orchestration setup — sub-agents,
triage→implement→verify skills, and safety hooks — so it's portable across
machines and projects instead of living only in `~/.claude`.

## Contents (`plugins/diego-cc-kit/`)
- **agents/** — 6 sub-agents: implementer, researcher, tester, verifier, fullstack-integrator, ts-react-reviewer
- **skills/** — `triage` (issue → executable plan, with a `## Por qué` block and a defense question), `implement` (plan → verified PR; hands over the `[human]` slice in learn mode, PR carries the author's three-sentence explanation), `orchestrate` (delegation + model routing + worktree rules), `verify` (fresh-context verification protocol, findings tagged by concept), `codegraph-usage` (on-demand CodeGraph guidance), `drill` (user-invoked: five recall questions from `docs/agent/til.md`)
- **hooks/** — bash-validator (blocks dangerous rm under HOME), style-check (post Edit/Write), secret-guard + test-guard (pre Edit/Write), mcp-snapshot + session-context (SessionStart), worktree create/remove lifecycle, and **stop-gate** (Stop): if a repo has an executable `.claude/gate`, Claude can't end its turn while the tree is dirty and the gate fails. Opt in per repo with e.g. `printf '#!/bin/bash\nnpm test && npm run lint\n' > .claude/gate && chmod +x .claude/gate && git add .claude/gate && git commit -m "Add Claude stop gate"`. Scripts referenced via `${CLAUDE_PLUGIN_ROOT}`.
- **output-styles/** — `aprender`: set `"outputStyle": "aprender"` in a repo's `.claude/settings.local.json` and the main conversation debugs with hints (max three) before fixing, leaves one `TODO(human)` slice per task, and names the pattern it uses. The same field is what `triage`/`implement` read to enter learn mode; leave it unset in repos where you only deliver.

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
