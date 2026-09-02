# Agentic Workflow Tuning — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align Diego's Claude Code setup with what the Claude Code team, Anthropic's internal engineers and OpenAI's Codex guidance actually do in 2026: less always-on context, a cheap verification loop that closes without a human, planning gated by uncertainty instead of habit, and permissions via auto mode instead of a bypass flag.

**Architecture:** Two independent chains. Chain A edits `~/.claude/` and the shell alias (live next session, chezmoi-captured at the end). Chain B edits the `diego-cc-kit` plugin (inert until bump → push → `plugin update` → restart). One new hook script with tests; everything else is prose in instruction files, a frontmatter flag, and JSON.

**Tech Stack:** Markdown instruction files, bash hook + plain-bash test harness (`hooks/tests/run.sh`), `jq`, `bump.sh`, git, chezmoi.

**Spec:** `~/dev/docs/research/agentic-workflows-referentes-2026-09.md` (§7 "Diagnóstico de tu setup" lists the ten gaps; this plan closes gaps 1–8 and 10; gap 9 is per-repo work, see Non-goals).

## Global Constraints

- **Never edit the marketplace cache** (`~/.claude/plugins/marketplaces/**`, `~/.claude/plugins/cache/**`). The editable kit source is `/home/dieco/dev/tools/diego-cc-kit`.
- **Plugin edits are inert until version bump.** Chain: `./bump.sh diego-cc-kit` → commit → push → `claude plugin update diego-cc-kit@diego-cc-kit` → restart Claude Code.
- **`~/.claude/CLAUDE.md`, `settings.json`, `skills/` and `~/.zshrc` are chezmoi-managed** (source: `~/dev/dotfiles`, branch currently `chore/opus5-config-tuning`). Capture with `/update-dotfiles` at the end or the edits die on the next `chezmoi apply`. Only 27 of the 68 live skills are tracked in dotfiles; the rest (seo-*, render-*, design, …) are untracked and stay untracked.
- **The wording is the deliverable.** Instruction files are read by a model; apply proposed text verbatim.
- **Skill visibility semantics:** `disable-model-invocation: true` hides the skill from Claude entirely until Diego types `/<name>`. Only hide skills Diego triggers by name; keep visible the ones that must auto-select from situation (a trace id, a Railway error, "guardá en obsidian").
- **Hook contract (Stop):** stdin JSON with `cwd`; exit 0 = allow stop, exit 2 + stderr = block the stop; Claude Code ends the turn anyway after 8 consecutive blocks.
- **One cheap check per task** (a grep, a count, one test run). This plan's subject is context hygiene; a heavy verification ritual here is self-refuting.

---

## File Structure

**Chain A — `~/.claude` and shell (Tasks 0–4, then 9):**
- `~/.claude/skills/*/SKILL.md` — frontmatter flag on 56 skills
- `~/.zshrc:196` and `~/dev/dotfiles/dot_zshrc.tmpl` — `cc` alias flags
- `~/.claude/settings.json` — drop one env var
- `~/.claude/CLAUDE.md` — add "Planning gates"; move stack-specific rules out
- `~/.claude/rules/react-ts.md` — new, path-scoped

**Chain B — kit repo `/home/dieco/dev/tools/diego-cc-kit` (Tasks 5–8):**
- `plugins/diego-cc-kit/skills/triage/SKILL.md` — interview phase, `goal:` header line
- `plugins/diego-cc-kit/skills/implement/SKILL.md` — run under `/goal`, UI evidence by default
- `plugins/diego-cc-kit/hooks/stop-gate.sh` — new Stop hook
- `plugins/diego-cc-kit/hooks/hooks.json` — register it
- `plugins/diego-cc-kit/hooks/tests/run.sh` — three cases
- `README.md` — one paragraph on `.claude/gate`
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version via `bump.sh`

**Untouched, deliberately:** `skills/orchestrate/`, `skills/verify/`, `agents/*.md`, existing hooks, `settings.json` model/effort, `ccs` alias (remote-control needs bypass).

---

### Task 0: Baseline measurement

**Files:**
- Modify: `docs/plans/active/agentic-workflow-tuning/PROGRESS.md`

**Interfaces:**
- Produces: the before-numbers that Task 9 compares against.

- [ ] **Step 1: Record startup context cost**

In a fresh Claude Code session in any repo, run `/context`. Copy into `PROGRESS.md` under `## Baseline`: total tokens at startup, the "Skills" line, the "Memory files" line (CLAUDE.md size), and the MCP tools line.

- [ ] **Step 2: Record the skill count the model sees**

Run:
```bash
cd ~/.claude/skills && grep -L '^disable-model-invocation: true' */SKILL.md | wc -l
```
Expected: `67`. Write it into `PROGRESS.md` next to the `/context` numbers.

---

### Task 1: Hide user-invoked skills from the model

**Files:**
- Modify: `~/.claude/skills/<name>/SKILL.md` for the 56 names below (frontmatter only)

**Interfaces:**
- Produces: a 12-skill visible set (11 kept + `push`, already hidden) that Task 9 measures.

Keep visible (auto-select from situation): `railway`, `render-debug`, `langfuse`, `cloudflare-tunnel`, `sequential-thinking`, `obsidian`, `update-dotfiles`, `portfolio-evidence`, `excel-evidence`, `humanizer`, `create-pr`. Everything else is invoked by name.

- [ ] **Step 1: Add the flag to the 56 hide-list skills**

Run:
```bash
cd ~/.claude/skills
hide="aws-answerai banner-design brand canva-dev design-system design generate-best-practices humanize-text mcp-setup notebooklm orchestrator pencil prompt-optimizer render-deploy render-migrate-from-heroku render-monitor render-workflows seo-ahrefs seo-audit seo-backlinks seo-bing seo-cluster seo-competitor-pages seo-content-brief seo-content seo-dataforseo seo-drift seo-ecommerce seo-firecrawl seo-flow seo-geo seo-google seo-hreflang seo-image-gen seo-images seo-local seo-maps seo-page seo-plan seo-profound seo-programmatic seo-schema seo-seranking seo-sitemap seo-sxo seo-technical seo-unlighthouse seo skill-creator skill-reviewer slides sync-dotfiles test-create ui-styling ui-ux-pro-max web-design-guidelines"
for n in $hide; do
  f="$n/SKILL.md"
  [ -f "$f" ] || { echo "MISSING $f"; continue; }
  grep -q '^disable-model-invocation:' "$f" && continue
  # insert right after the frontmatter `name:` line
  sed -i '0,/^name:/{/^name:/a disable-model-invocation: true
}' "$f"
done
echo "$hide" | wc -w
```
Expected: no `MISSING` lines; last line prints `56`.

- [ ] **Step 2: Confirm the count and that no keep-list skill was touched**

Run:
```bash
cd ~/.claude/skills
grep -l '^disable-model-invocation: true' */SKILL.md | wc -l
grep -L '^disable-model-invocation: true' */SKILL.md | sed 's#/SKILL.md##' | tr '\n' ' '
```
Expected: `57` (56 + `push`), and the second line lists exactly: `cloudflare-tunnel create-pr excel-evidence humanizer langfuse obsidian portfolio-evidence railway render-debug sequential-thinking update-dotfiles`.

- [ ] **Step 3: Confirm the frontmatter still parses**

Run:
```bash
cd ~/.claude/skills && for f in seo/SKILL.md design/SKILL.md orchestrator/SKILL.md; do head -5 "$f"; echo ---; done
```
Expected: each shows `---`, `name: …`, `disable-model-invocation: true`, then the next original key. If `orchestrator` shows `version:` between `name:` and the flag, that is fine; the flag only has to sit inside the frontmatter block.

---

### Task 2: Start `cc` in auto mode instead of bypass

**Files:**
- Modify: `~/.zshrc:196`
- Modify: `~/dev/dotfiles/dot_zshrc.tmpl` (same alias line)

- [ ] **Step 1: Replace the flag in both files**

Run:
```bash
sed -i "s/claude --dangerously-skip-permissions --remote-control --chrome/claude --permission-mode auto --remote-control --chrome/" ~/.zshrc ~/dev/dotfiles/dot_zshrc.tmpl
grep -n "alias cc=" ~/.zshrc ~/dev/dotfiles/dot_zshrc.tmpl
```
Expected: both lines contain `--permission-mode auto` and neither contains `--dangerously-skip-permissions`. The `ccs` alias (line 197) stays on `bypassPermissions`: remote-control sessions have no prompt surface.

- [ ] **Step 2: Confirm the guardrail survives the mode switch**

Auto mode's classifier and the kit's `bash-validator.sh` (PreToolUse) are independent; the hook still fires. Run:
```bash
grep -c bash-validator ~/dev/tools/diego-cc-kit/plugins/diego-cc-kit/hooks/hooks.json
```
Expected: `1`.

- [ ] **Step 3: Smoke test in a new shell**

Open a new terminal, run `cc` in any repo, then `/permissions`. Expected: the status shows auto mode; `settings.json` already has `"defaultMode": "auto"` and `"skipAutoPermissionPrompt": true`, so no first-run dialog.

---

### Task 3: Turn off experimental agent teams

**Files:**
- Modify: `~/.claude/settings.json` (`env` object)

The kit's own rule limits teams to an approved plan, the docs mark them experimental and without worktree isolation, and the official path for 2–3 independent tracks is agent view + worktrees. Leaving the flag on only invites the harness to reach for teams.

- [ ] **Step 1: Delete the env var**

Run:
```bash
cd ~/.claude && jq 'del(.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)' settings.json > settings.json.new && mv settings.json.new settings.json
jq '.env | has("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")' settings.json
```
Expected: `false`.

- [ ] **Step 2: Confirm nothing else moved**

Run:
```bash
cd ~/.claude && jq '.model, .permissions.defaultMode, (.env | length)' settings.json
```
Expected: `"opus[1m]"`, `"auto"`, `7`.

---

### Task 4: Planning gates in CLAUDE.md; stack rules move to a path-scoped rule

**Files:**
- Modify: `~/.claude/CLAUDE.md`
- Create: `~/.claude/rules/react-ts.md`

**Interfaces:**
- Produces: the `goal:` convention and the "interview first" rule that Tasks 5 and 6 implement inside the kit. CLAUDE.md states the rule; the skills carry the procedure.

- [ ] **Step 1: Create the path-scoped rule**

Write `~/.claude/rules/react-ts.md`:

```markdown
---
paths:
  - "**/*.{ts,tsx,js,jsx,mjs,cjs}"
---

# React / TypeScript conventions

- Functional components, hooks over classes
- async/await over callbacks/promises
- TypeScript preferred, JavaScript when simpler
- 2-space indentation, single quotes
- Multi-tenancy: every query on a tenant-owned table filters by `organizationId`
- Authentication checks on every protected route
```

- [ ] **Step 2: Remove those lines from CLAUDE.md**

In `~/.claude/CLAUDE.md`, replace:

```
## Development Preferences
- Full-stack: React/Next.js frontend, Node.js/Python backend
- TypeScript preferred, JavaScript when simpler
- 2-space indentation, single quotes
- Functional components, hooks over classes
- async/await over callbacks/promises
```

with:

```
## Development Preferences
- Full-stack: React/Next.js frontend, Node.js/Python backend. Stack-specific conventions live in `~/.claude/rules/` and load only when matching files are touched.
```

and in `## Quality Gates`, delete the two lines:

```
- Multi-tenancy compliance (organizationId filters)
- Authentication checks on protected routes
```

(they now live in the rule, phrased as checkable properties).

- [ ] **Step 3: Add the planning gates**

In `~/.claude/CLAUDE.md`, insert immediately before `## Git Workflow`:

```
## Planning gates
- Diff describable in one sentence → do it directly. No plan mode, no triage.
- Feature or multi-file change with unknowns → `diego-cc-kit:triage`. It starts by interviewing me with AskUserQuestion until the unknowns are gone, including "how could this fail?". I read the plan myself before any code is written.
- Every plan ends with a `goal:` line (one verifiable end state + the command that proves it). Execution runs under `/goal <that line>` in auto mode, so the loop closes without me.
- After two failed corrections on the same issue: `/clear`, better prompt. Corrections that would repeat become a CLAUDE.md line or a hook, not a third message.
```

- [ ] **Step 4: Confirm**

Run:
```bash
cd ~/.claude && wc -l CLAUDE.md && grep -c "## Planning gates" CLAUDE.md && grep -c "organizationId" CLAUDE.md rules/react-ts.md
```
Expected: line count ≤ 85; `1`; `CLAUDE.md:0` and `rules/react-ts.md:1`.

- [ ] **Step 5: Confirm the rule loads only where it should**

Start Claude Code in `~/dev/personal/exocortex` (or any non-TS repo), run `/context`: `rules/react-ts.md` must NOT be listed under memory files. Start it in `~/dev/projects/atelier`, read any `.tsx` file, run `/context`: it must be listed. Record both in `PROGRESS.md`.

---

### Task 5: Triage interviews first and ends with a `goal:` line

**Files:**
- Modify: `plugins/diego-cc-kit/skills/triage/SKILL.md`

**Interfaces:**
- Produces: the `goal:` header field consumed by Task 6 (`implement` runs `/goal` with it) and Task 7 (the Stop hook is the deterministic fallback when no goal is set).

- [ ] **Step 1: Add the interview step to the procedure**

Replace:

```
## Procedure

1. Read the issue/request and everything linked (comments, PRs, referenced code).
2. Verify its claims against the current code — issues go stale; record what you confirmed vs corrected.
3. Classify scope (above).
4. Write the plan files (contract below).
5. If the project's workflow posts plans to the tracker (issue comment, ticket), do so.
```

with:

```
## Procedure

1. Read the issue/request and everything linked (comments, PRs, referenced code).
2. Verify its claims against the current code — issues go stale; record what you confirmed vs corrected.
3. **Interview before designing (features and anything with unknowns; skip for a bug with a reproducible symptom).** Use `AskUserQuestion` in rounds until nothing material is left: technical approach, edge cases, UI/UX, out-of-scope, and explicitly "how could this fail?" (the failure modes of the mechanism you are about to depend on). Do not ask what the code already answers. Answers go into the plan as `## Verified facts` and `## Non-goals`, not into a separate transcript.
4. Classify scope (above).
5. Write the plan files (contract below).
6. If the project's workflow posts plans to the tracker (issue comment, ticket), do so.
7. Hand the plan to the user to read before anything executes. The plan is the leverage point; the implementation is not.
```

- [ ] **Step 2: Add `goal:` to the plan header contract**

Replace:

```
- Header: `scope:` / `scope-evidence:` / `scope-ack:` / `branch:` (off the discovered target)
```

with:

```
- Header: `scope:` / `scope-evidence:` / `scope-ack:` / `branch:` (off the discovered target) / `goal:` — one verifiable end state in a single sentence, naming the command that proves it and any constraint that must hold on the way (e.g. `goal: `npm test` and `npm run lint` exit 0 with the three acceptance boxes checked; no test file outside src/auth is modified`). `implement` runs the whole plan under `/goal <this line>`; if it can't be judged from command output in the transcript, it isn't a goal, rewrite it.
```

- [ ] **Step 3: Add the matching red flags**

Append to `## Red flags`:

```
- "The request is clear enough, skip the interview" → for a feature, the unknowns you didn't ask about become the implementer's guesses. Interview; it costs minutes.
- "goal: implement the feature" → not judgeable from a transcript. A goal names a command and an exit state.
```

- [ ] **Step 4: Confirm and commit**

Run:
```bash
cd /home/dieco/dev/tools/diego-cc-kit
grep -c "Interview before designing" plugins/diego-cc-kit/skills/triage/SKILL.md
grep -c "/ \`goal:\`" plugins/diego-cc-kit/skills/triage/SKILL.md
git add plugins/diego-cc-kit/skills/triage/SKILL.md
git commit -m "Add interview step and goal line to triage"
```
Expected: `1` and `1`.

---

### Task 6: Implement runs under `/goal` and always shows UI evidence

**Files:**
- Modify: `plugins/diego-cc-kit/skills/implement/SKILL.md`

**Interfaces:**
- Consumes: the `goal:` header line from Task 5.

- [ ] **Step 1: Validate the goal line in Phase 1**

In `## Phase 1 — validate the plan (before touching code)`, append a bullet after the `## Open questions` bullet:

```
- Does the header carry a `goal:` line that a model could judge from command output alone? Missing or vague → write it now from the verification gate + acceptance checklist, log the correction in `PROGRESS.md`. Do not start Phase 2 without it.
```

- [ ] **Step 2: Run the loop under `/goal`**

Replace the opening line of Phase 2:

```
Execution is delegated: spawn `implementer` (or `fullstack-integrator` for cross-stack wiring) with an explicit `model` — sonnet by default, opus for a genuinely hard step (see `orchestrate`'s routing). Never let the spawn inherit the session model.
```

with:

```
Set the session goal first: `/goal <the plan's goal: line>`. From here a separate evaluator re-checks the condition after every turn, so the loop closes on evidence, not on "looks done". Execution is delegated: spawn `implementer` (or `fullstack-integrator` for cross-stack wiring) with an explicit `model` — sonnet by default, opus for a genuinely hard step (see `orchestrate`'s routing). Never let the spawn inherit the session model.
```

- [ ] **Step 3: UI evidence by default**

In Phase 2's per-step list, after item 4 (`Pre-existing failures: …`), insert:

```
5. UI change (anything a user sees): the step is not done until there is a screenshot of the running app (Chrome extension, `evidence-kit:capture-evidence`, or `/verify`) compared against the design or the previous state, with differences listed and fixed. This is independent of the verifier's L4: L4 is about risk; this is about closing the loop on something a test can't see.
```

and renumber the old item 5 (`Commit the step …`) to 6.

- [ ] **Step 4: Add the red flag**

Append to `## Red flags`:

```
- "The component renders, tests pass, it's fine" → a test doesn't see layout. Screenshot, compare, then commit.
```

- [ ] **Step 5: Confirm and commit**

Run:
```bash
cd /home/dieco/dev/tools/diego-cc-kit
grep -c "Set the session goal first" plugins/diego-cc-kit/skills/implement/SKILL.md
grep -c "^6\. \*\*Commit the step\*\*" plugins/diego-cc-kit/skills/implement/SKILL.md
git add plugins/diego-cc-kit/skills/implement/SKILL.md
git commit -m "Run implement under /goal; require UI evidence per step"
```
Expected: `1` and `1`.

---

### Task 7: Stop hook that runs the project gate

**Files:**
- Create: `plugins/diego-cc-kit/hooks/stop-gate.sh`
- Modify: `plugins/diego-cc-kit/hooks/hooks.json`
- Modify: `plugins/diego-cc-kit/hooks/tests/run.sh`
- Modify: `README.md`

**Interfaces:**
- Contract: a repo opts in by adding an executable `.claude/gate` (any script; exit 0 = green). The hook blocks the stop while the tree is dirty and the gate fails. No `.claude/gate` → no-op, so every existing repo is unaffected.

- [ ] **Step 1: Write the failing tests**

Append to `plugins/diego-cc-kit/hooks/tests/run.sh`, before the final `exit $failed`:

```bash
# --- stop-gate: no .claude/gate → allows the stop ---
sg_repo=$(mktemp -d)
git -C "$sg_repo" init -q -b main
git -C "$sg_repo" commit -q --allow-empty -m init
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "stop-gate allows stop when no gate exists" \
    || fail "stop-gate should exit 0 without a gate (got $status): $out"

# --- stop-gate: failing gate + dirty tree → blocks the stop ---
mkdir -p "$sg_repo/.claude"
printf '#!/bin/bash\necho "1 test failed"\nexit 1\n' > "$sg_repo/.claude/gate"
chmod +x "$sg_repo/.claude/gate"
echo dirty > "$sg_repo/file.txt"
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 2 ] && echo "$out" | grep -q "1 test failed" && pass "stop-gate blocks stop on a failing gate with a dirty tree" \
    || fail "stop-gate should exit 2 with gate output (got $status): $out"

# --- stop-gate: failing gate + clean tree → allows the stop ---
rm "$sg_repo/file.txt"
out=$(printf '{"cwd":"%s","hook_event_name":"Stop"}' "$sg_repo" | "$hooks_dir/stop-gate.sh" 2>&1)
status=$?
[ "$status" -eq 0 ] && pass "stop-gate allows stop when the tree is clean" \
    || fail "stop-gate should exit 0 on a clean tree (got $status): $out"
rm -rf "$sg_repo"
```

- [ ] **Step 2: Run the tests to see them fail**

Run:
```bash
bash /home/dieco/dev/tools/diego-cc-kit/plugins/diego-cc-kit/hooks/tests/run.sh 2>&1 | grep stop-gate
```
Expected: three `FAIL: stop-gate …` lines (script not found).

- [ ] **Step 3: Write the hook**

Create `plugins/diego-cc-kit/hooks/stop-gate.sh`:

```bash
#!/bin/bash
# Stop gate — deterministic "don't stop while the project gate is red".
# Opt-in per repo: an executable .claude/gate (exit 0 = green).
# Runs only when the working tree has uncommitted changes; a clean tree has
# nothing to gate. Exit 0 = allow stop, exit 2 = block (Claude Code lifts the
# block after 8 consecutive refusals).
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd=${cwd:-$PWD}
gate="$cwd/.claude/gate"

[ -x "$gate" ] || exit 0
git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] || exit 0

out=$(cd "$cwd" && "$gate" 2>&1)
status=$?
[ "$status" -eq 0 ] && exit 0

{
  echo "🚨 stop-gate: .claude/gate exited $status — fix it before finishing (or commit/stash if the failure is pre-existing)."
  echo "$out" | tail -20
} >&2
exit 2
```

Then:
```bash
chmod +x /home/dieco/dev/tools/diego-cc-kit/plugins/diego-cc-kit/hooks/stop-gate.sh
```

- [ ] **Step 4: Run the tests to see them pass**

Run:
```bash
bash /home/dieco/dev/tools/diego-cc-kit/plugins/diego-cc-kit/hooks/tests/run.sh; echo "exit=$?"
```
Expected: three `PASS: stop-gate …` lines, every other line still `PASS`, `exit=0`.

- [ ] **Step 5: Register the hook**

In `plugins/diego-cc-kit/hooks/hooks.json`, add a `Stop` key next to `SubagentStop`:

```json
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/stop-gate.sh",
            "timeout": 600
          }
        ]
      }
    ],
```

Run:
```bash
jq '.hooks.Stop[0].hooks[0].command' /home/dieco/dev/tools/diego-cc-kit/plugins/diego-cc-kit/hooks/hooks.json
```
Expected: `"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/stop-gate.sh"` (valid JSON, no parse error).

- [ ] **Step 6: Document the opt-in**

In `README.md`, extend the `hooks/` bullet under `## Contents`:

```
- **hooks/** — bash-validator (blocks dangerous rm under HOME), style-check (post Edit/Write), secret-guard + test-guard (pre Edit/Write), mcp-snapshot + session-context (SessionStart), worktree create/remove lifecycle, and **stop-gate** (Stop): if a repo has an executable `.claude/gate`, Claude can't end its turn while the tree is dirty and the gate fails. Opt in per repo with e.g. `printf '#!/bin/bash\nnpm test && npm run lint\n' > .claude/gate && chmod +x .claude/gate`. Scripts referenced via `${CLAUDE_PLUGIN_ROOT}`.
```

- [ ] **Step 7: Commit**

```bash
cd /home/dieco/dev/tools/diego-cc-kit
git add plugins/diego-cc-kit/hooks/stop-gate.sh plugins/diego-cc-kit/hooks/hooks.json plugins/diego-cc-kit/hooks/tests/run.sh README.md
git commit -m "Add stop-gate hook: block turn end while .claude/gate is red"
```

---

### Task 8: Ship the plugin

**Files:**
- Modify (via script): `plugins/diego-cc-kit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: Tasks 5–7 committed. Nothing from them is live until this completes.

- [ ] **Step 1: Bump**

```bash
cd /home/dieco/dev/tools/diego-cc-kit && ./bump.sh diego-cc-kit 0.4.0
```
Expected: `diego-cc-kit: 0.3.2 -> 0.4.0`. Minor: a new hook and a changed procedure, not wording.

- [ ] **Step 2: Commit and push**

```bash
git add -A && git commit -m "chore: bump diego-cc-kit to 0.4.0" && git push
```

- [ ] **Step 3: Update the installed plugin**

```bash
claude plugin update diego-cc-kit@diego-cc-kit
```
Expected: reports `0.3.2 → 0.4.0`.

- [ ] **Step 4: Restart Claude Code, then confirm the live copy**

```bash
grep -c "Interview before designing" ~/.claude/plugins/marketplaces/diego-cc-kit/plugins/diego-cc-kit/skills/triage/SKILL.md
ls ~/.claude/plugins/marketplaces/diego-cc-kit/plugins/diego-cc-kit/hooks/stop-gate.sh
```
Expected: `1` and the path. `0` or "No such file" means the update no-opped (burned version, see memory `feedback_plugin_cache_burned_version`): bump again to 0.4.1 and repeat.

---

### Task 9: After-measurement and `/doctor`

**Files:**
- Modify: `docs/plans/active/agentic-workflow-tuning/PROGRESS.md`

- [ ] **Step 1: Re-run `/context` in a fresh session**

Same repo as Task 0. Record under `## After`: total startup tokens, Skills line, Memory files line. Expected direction: Skills tokens down (56 fewer descriptions), CLAUDE.md slightly down, rules line present only in TS repos.

- [ ] **Step 2: Run `/doctor`**

Apply any trim it proposes for `~/.claude/CLAUDE.md` that passes the test "would removing this cause a mistake?"; reject the rest. Log what was cut.

- [ ] **Step 3: Confirm the Stop hook is registered**

Run `/hooks` and check `Stop → stop-gate.sh` appears. Then, in a repo with a `.claude/gate`, make a throwaway edit that breaks the gate and ask Claude to "finish": expected, the turn is blocked with the gate output in the transcript. Revert the edit.

---

### Task 10: Capture into dotfiles

**Files:**
- Modify (via skill): `~/dev/dotfiles/dot_claude/CLAUDE.md`, `dot_claude/settings.json`, `dot_claude/rules/react-ts.md` (new), `dot_claude/skills/**` (only the 27 tracked ones), `dot_zshrc.tmpl` (already edited in Task 2)

- [ ] **Step 1: Run the capture**

Invoke `/update-dotfiles`. It runs live → source and commits. Pre-existing drift in the source repo (`dot_claude/mcp-servers.reference.json`, `dot_claude/skills/tennis-coach/SKILL.md`) is not part of this plan; leave it alone or commit it separately, but don't revert it.

- [ ] **Step 2: Confirm the new rule is tracked**

```bash
cd ~/dev/dotfiles && git ls-files dot_claude/rules/ && git log --oneline -1
```
Expected: `dot_claude/rules/react-ts.md` listed; latest commit is the capture.

---

## Non-goals

- **Per-repo `.claude/settings.json` and `.claude/gate`** for `personal/` and `projects/` repos. Do it the next time you open each repo; it is one file per repo and the README in Task 7 says how.
- **HTML plans instead of markdown** (Thariq). Interesting, not a config change; try it once in Atelier and decide.
- **Agent view adoption** (`claude agents`). Behavioral, nothing to configure after Task 3.
- **Main-loop effort.** Boris runs `xhigh`; the Opus 5 guide says `medium`. Your settings pin no `effortLevel`; leave it and re-evaluate if multi-file work at the default needs a second prompt.
- **Quarterly instruction prune.** A calendar entry, not a file: "new model → `/doctor` + one pass of 'would removing this cause a mistake?'".

## Ordering

Chain A (0 → 1 → 2 → 3 → 4) and Chain B (5 → 6 → 7 → 8) are independent and can run in parallel. Task 9 needs both live (Task 8 restarted, Chain A applied). Task 10 last.
