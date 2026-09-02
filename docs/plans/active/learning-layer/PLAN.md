# Learning Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the seven-mechanism learning layer on top of the triage→implement→verify pipeline so every plan passes through Diego's head at three cheap points (why / explain the diff / `/btw`), and repos in learn mode also hand him one slice to write, debug with hints, and feed a drill queue.

goal: from `/home/dieco/dev/tools/diego-cc-kit`, `bash plugins/diego-cc-kit/hooks/tests/run.sh` exits 0 with no hook script modified, AND `grep -q '## Por qué' plugins/diego-cc-kit/skills/triage/SKILL.md && grep -q 'Tajada \[human\]' plugins/diego-cc-kit/skills/implement/SKILL.md && grep -q 'Concepts:' plugins/diego-cc-kit/agents/verifier.md && test -f plugins/diego-cc-kit/output-styles/aprender.md && test -f plugins/diego-cc-kit/skills/drill/SKILL.md && [ "$(jq -r .version plugins/diego-cc-kit/.claude-plugin/plugin.json)" = 0.5.0 ]` exits 0, AND `grep -q '## Modos de trabajo' ~/.claude/CLAUDE.md`, AND every git repo under `~/dev/personal`, `~/dev/projects`, `~/dev/hobby` reports `outputStyle` = `aprender` from its `.claude/settings.local.json` while nothing under `~/dev/work` changes.

**Architecture:** Two independent chains, like the previous plan. Chain B edits the kit (skill prose, one new skill, one new output style, README, bump to 0.5.0). Chain A edits `~/.claude/CLAUDE.md` and stamps `outputStyle` into the local settings of every personal/projects/hobby repo. The mode switch is one field: `outputStyle: "aprender"` in the repo's `.claude/settings.local.json`. That same field turns on the custom style for the main conversation and is what the kit skills read to decide learn vs deliver mode. No new hooks, no new scripts.

**Tech Stack:** Markdown instruction files, one output-style markdown shipped by the plugin (`output-styles/` is a supported plugin directory), `jq`, `bump.sh`, git, chezmoi.

**Spec:** `~/dev/docs/research/aprender-mientras-delegas-2026-09.md` §5 (the seven mechanisms), §7 (kit changes). Merged reader version: https://claude.ai/code/artifact/833d3d54-65fb-4efd-afcb-00d1a68fdc03, Part III.

## Decisions taken while planning (read these before saying "1")

1. **One custom style, not two.** The spec names `Learning` (for the `[human]` slice) and a separate `pistas` style (for hints). Only one `outputStyle` can be active, so this plan ships one style, `aprender`, that does both, with `keep-coding-instructions: true`. Built-in `Learning` stays available from `/config` if you ever prefer it.
2. **Mode = the settings field, not the folder.** Skills detect learn mode with `jq -r '.outputStyle // empty' .claude/settings.local.json` printing `aprender`. The folder rule (personal/projects/hobby = learn, work = deliver) is how the field gets stamped in Task 8; it isn't re-derived by the skills, so it works the same on the other PC and in a repo you move.
3. **Mechanism 4 (hints before fixes) lives only in the output style.** It covers bugs you bring to the main conversation. The `implement` gate loop (an implementer subagent fixing its own red gate) is unchanged: subagents don't see output styles, and that loop isn't the "iterative AI debugging" the study warns about, because you never touch it.
4. **The defense answer is a gate, in both modes.** `implement` refuses to start until `PROGRESS.md` carries `defensa:` with your answer. It asks you in chat if it's missing; it never writes the answer itself.
5. **The PR explanation is a gate, in both modes.** Missing three sentences → the PR opens as a draft with `pendiente`, never as ready.
6. **Mechanism 7 (monthly walkthrough, feature without agent) is not config.** The only trace is one reminder line at the end of `/drill` when no `walkthrough` entry exists in the last 30 days. Calendar is yours.
7. **`til.md` lives in `docs/agent/`**, per your "Dónde va el conocimiento" rule, indexed from that folder's `README.md`. Deliver-mode repos (work/) get no `til.md`, because nothing versioned goes into company repos.

## Global Constraints

- **Never edit the marketplace cache** (`~/.claude/plugins/marketplaces/**`, `~/.claude/plugins/cache/**`). The editable kit source is `/home/dieco/dev/tools/diego-cc-kit`.
- **Plugin edits are inert until version bump.** `./bump.sh diego-cc-kit 0.5.0` → commit → push → restart (this PC loads the kit via `--plugin-dir`; the other PC runs `claude plugin marketplace update diego-cc-kit && claude plugin update diego-cc-kit@diego-cc-kit`).
- **`~/.claude/CLAUDE.md` is chezmoi-managed** (source `~/dev/dotfiles`, branch `chore/opus5-config-tuning`, commit `d1bb8bc` not pushed). Capture with `/update-dotfiles` at the end; do not push dotfiles unless asked.
- **The wording is the deliverable.** Instruction files are read by a model; apply proposed text verbatim. Kit prose stays in English; text Diego reads in chat (CLAUDE.md block, style replies) is Spanish or "the user's language".
- **No versioned files in company repos.** Task 8 touches only `.claude/settings.local.json` (excluded from git) and only under personal/projects/hobby.
- **Subagents run no git.** The main session commits, merges, bumps, pushes.
- **Hook scripts are untouched.** `bash plugins/diego-cc-kit/hooks/tests/run.sh` must still print 18 PASS lines at the end.
- **One cheap check per task** (a grep, a jq, one test run).

---

## File Structure

**Chain B — kit repo `/home/dieco/dev/tools/diego-cc-kit`, branch `feat/learning-layer` in worktree `../wt-learning-layer` (Tasks 1–6):**
- `plugins/diego-cc-kit/skills/triage/SKILL.md` — mode detection; `## Por qué`, `## Pregunta de defensa`, `## Tajada [human]` in the plan contract; red flags
- `plugins/diego-cc-kit/skills/implement/SKILL.md` — `defensa:` gate; `[human]` handover; PR `## Explicación`; `til.md` line
- `plugins/diego-cc-kit/agents/verifier.md` and `skills/verify/SKILL.md` — concept tags on findings, `Concepts:` line
- `plugins/diego-cc-kit/output-styles/aprender.md` — new
- `plugins/diego-cc-kit/skills/drill/SKILL.md` — new, user-invoked only
- `README.md`, `plugins/diego-cc-kit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — docs + bump

**Chain A — `~/.claude` and repos (Tasks 7–8, then 9–10):**
- `~/.claude/CLAUDE.md` — new `## Modos de trabajo` block after `## Planning gates`
- `<repo>/.claude/settings.local.json` for every git repo under `~/dev/personal`, `~/dev/projects`, `~/dev/hobby` — `outputStyle: "aprender"`

---

### Task 1: Triage writes the "why", the defense question and the human slice

**Files:**
- Modify: `plugins/diego-cc-kit/skills/triage/SKILL.md`

- [ ] **Step 1: Add mode detection to the procedure**

Replace the current steps 4–7 of `## Procedure`:

```
4. Classify scope (above).
5. Write the plan files (contract below).
6. If the project's workflow posts plans to the tracker (issue comment, ticket), do so.
7. Hand the plan to the user to read before anything executes. The plan is the leverage point; the implementation is not.
```

with:

```
4. Classify scope (above).
5. Detect the mode. At the repo root run `jq -r '.outputStyle // empty' .claude/settings.local.json 2>/dev/null`. Output `aprender` → **learn mode**: the plan carries a `## Tajada [human]` section. Anything else (empty, `Default`, missing file) → **deliver mode**: omit that section. Everything else in the contract applies to both modes.
6. Write the plan files (contract below).
7. If the project's workflow posts plans to the tracker (issue comment, ticket), do so.
8. Hand the plan to the user to read before anything executes. They read it and answer the `## Pregunta de defensa` in chat; write their answer into `PROGRESS.md` as one line, `defensa: <their words>`, verbatim. Never write that answer yourself, and never start `implement` without it. The plan is the leverage point; the implementation is not.
```

- [ ] **Step 2: Extend the plan contract**

In `## Plan contract`, after the `## Risks / rollback` bullet and before `## Open questions`, insert:

```
- `## Por qué` — exactly three lines, in the user's language: `patrón:` the technique or pattern the plan relies on, by its name and where it applies (e.g. "optimistic update en el hook useCart", "idempotency key en POST /orders"; if none, say "ninguno, código procedural"); `descartado:` the alternative you did not take and why; `riesgo:` the main way this change could fail in production.
- `## Pregunta de defensa` — one question, tagged `(can-explain)` or `(can-defend)`, that the user must be able to answer from the plan before approving it. Ask for the trade-off or the failure mode ("¿cuándo NO usarías X?", "¿qué se rompe si Y?"), never for a definition. `implement` does not start until `PROGRESS.md` carries the `defensa:` answer.
- `## Tajada [human]` — learn mode only. The ONE step the user writes by hand: normally the first failing test or the interface/type the rest builds on. Give the file path, what it must contain (names, cases, signature), and the command that proves it is done. `implement` stops at this step and hands it over.
```

- [ ] **Step 3: Add the red flags**

Append to `## Red flags`:

```
- "`patrón: buenas prácticas`" → name it (Repository, optimistic update, idempotency key, debounce) or say there is none. A pattern the user can't look up teaches nothing.
- "Defense question: ¿qué hace este PR?" → too easy to answer from the title. Ask for the trade-off or the failure mode.
- "The [human] slice is the boilerplate, it's the easiest to hand off" → it's the step that teaches most (the test or the contract), not the cheapest one.
```

- [ ] **Step 4: Confirm and commit**

Run: `grep -c '## Por qué\|## Pregunta de defensa\|## Tajada \[human\]\|Detect the mode' plugins/diego-cc-kit/skills/triage/SKILL.md`
Expected: `5` (three contract bullets, procedure step 5, procedure step 8)

```bash
git add plugins/diego-cc-kit/skills/triage/SKILL.md
git commit -m "feat(triage): why block, defense question, human slice in learn mode"
```

---

### Task 2: Implement gates on the defense answer, hands over the human slice, and closes with explanation + TIL

**Files:**
- Modify: `plugins/diego-cc-kit/skills/implement/SKILL.md`

- [ ] **Step 1: Phase 1 gate on `defensa:`**

In `## Phase 1 — validate the plan`, after the bullet that begins `- Does the header carry a `goal:` line`, add:

```
- Does `PROGRESS.md` carry a `defensa:` line answering the plan's `## Pregunta de defensa`? Missing → ask the user the question in chat now (free text, not `AskUserQuestion`), write `defensa: <their words>` into `PROGRESS.md`, then continue. Never write the answer yourself: it is the user's evidence of understanding, not a form field.
```

- [ ] **Step 2: Phase 2 handover of the `[human]` step**

In `## Phase 2 — execute (the loop)`, after the paragraph that ends `Never let the spawn inherit the session model.`, add a paragraph:

```
Learn mode (`jq -r '.outputStyle // empty' .claude/settings.local.json` prints `aprender`) and the plan has a `## Tajada [human]` section: when the loop reaches that step, do not implement it and do not delegate it. Write a stub at the path the plan names containing only a `TODO(human)` comment that restates what the section asks for and the command that proves it, then stop and hand over in chat. The user writes it and commits it. Resume at the next step only when they say it's done and `git status --porcelain -- <path>` is clean. If the user says "hacelo vos", implement it, log `human slice skipped by user` in `PROGRESS.md`, and continue.
```

- [ ] **Step 3: Phase 4 explanation gate and TIL line**

Replace the `## Phase 4 — the PR` bullet list with:

```
- Target the branch the plan names; if the project has a release-branch flow, that flow wins over a default-branch PR.
- Title per the project's convention; body references the issue, quotes the plan's `scope:` line, and includes verification output (gate results + verifier verdict).
- Body carries `## Explicación` with the user's own three sentences: **qué cambia, por qué funciona, qué lo rompería**. Ask for them in chat before opening the PR and paste them verbatim. If the user can't give them, open the PR as **draft** with `## Explicación: pendiente` and say so in the report. A PR its author can't explain isn't ready; that is knowledge debt, not a formality.
- Learn mode: after the PR exists, append one line to `docs/agent/til.md` (create it with a `# TIL` header if missing) in the form `- YYYY-MM-DD · <concept, the plan's patrón:> · <one sentence on what you'd tell a colleague> · <PR url>`, add `- [TIL](til.md) — conceptos por PR, insumo de /drill` to `docs/agent/README.md` if that line is absent, and commit both on the branch with `docs: til <concept>`.
- Do not merge. Acceptance stays human-owned.
```

- [ ] **Step 4: Red flags**

Append to `## Red flags`:

```
- "I'll write the `defensa:` answer myself to unblock" → the answer is the user's, or Phase 1 isn't done.
- "The [human] step is just a test, I'll fill it" → the value of that step is the user writing it. Stub, hand over, wait.
- "The explanation can be filled in later" → then the PR is a draft, and the report says why.
```

- [ ] **Step 5: Confirm and commit**

Run: `grep -c 'defensa:\|Tajada \[human\]\|## Explicación\|til.md' plugins/diego-cc-kit/skills/implement/SKILL.md`
Expected: `5` (lines: Phase 1 gate, Phase 2 handover, Phase 4 explanation, Phase 4 TIL, the `defensa:` red flag)

```bash
git add plugins/diego-cc-kit/skills/implement/SKILL.md
git commit -m "feat(implement): defense gate, human-slice handover, PR explanation, TIL line"
```

---

### Task 3: Verifier labels every finding with its concept

**Files:**
- Modify: `plugins/diego-cc-kit/agents/verifier.md`
- Modify: `plugins/diego-cc-kit/skills/verify/SKILL.md`

- [ ] **Step 1: Rule and report format in the agent**

In `verifier.md`, append to `## Rules`:

```
6. Label every finding with the concept it exemplifies, in square brackets before the text
   (`[race condition]`, `[N+1]`, `[validation at the boundary]`, `[missing idempotency]`).
   The human reading the report learns the class of problem, not just the line.
```

In `## Report Format`, replace the `Checks:` block:

```
Checks:
  ✓ [what passed — with evidence]
  ✗ [what failed — specific reason + how to fix]
```

with:

```
Checks:
  ✓ [concept] what passed — with evidence
  ✗ [concept] what failed — specific reason + how to fix

Concepts:
  - [1–3 concepts a reader should understand to judge this diff, one phrase each, with the file:line where each shows up]
```

- [ ] **Step 2: One line in the skill**

In `skills/verify/SKILL.md`, after the `## The layers` paragraph that begins `Every layer here exists to test a claim`, add:

```
Every finding carries a concept tag (`[race condition]`, `[N+1]`, `[validation at the boundary]`) and the report ends with a `Concepts:` list. A review only teaches if it names the class of mistake, not only the line.
```

- [ ] **Step 3: Confirm and commit**

Run: `grep -c 'Concepts:' plugins/diego-cc-kit/agents/verifier.md plugins/diego-cc-kit/skills/verify/SKILL.md`
Expected: `verifier.md:1` and `SKILL.md:1`

```bash
git add plugins/diego-cc-kit/agents/verifier.md plugins/diego-cc-kit/skills/verify/SKILL.md
git commit -m "feat(verify): concept tags on findings"
```

---

### Task 4: The `aprender` output style

**Files:**
- Create: `plugins/diego-cc-kit/output-styles/aprender.md`

- [ ] **Step 1: Write the style**

```markdown
---
name: aprender
description: Modo aprender — pistas antes que fixes, una tajada tuya por tarea, el concepto con nombre
keep-coding-instructions: true
---

Reply in the user's language.

## Bugs: hints, not fixes

When the user reports a bug, a failing test, or pastes an error in the conversation, do not fix it yet. Ask for their hypothesis and the line of the stack trace or output that supports it. Then give ONE hint that narrows the search (which layer, which invariant, which call) without naming the cause. Repeat, at most three hints. When the user names the cause, or after the third hint, implement the fix and explain in two sentences why it works and what class of bug it was. This applies to the main conversation only; a red gate inside an implement loop is fixed by the implementer as usual.

## One slice is theirs

On any task with more than one step, pick the step that teaches most (usually the first failing test, or the interface/type the rest builds on) and leave it as a `TODO(human)` stub that states what it must contain and the command that proves it. Do the rest. Say which step you left and why that one. If the user says "hacelo vos", do it.

## Name the concept

When a change relies on a pattern or technique, name it once ("this is an idempotency key", "this is the N+1 problem") and say in one sentence when NOT to use it. No lecture. If the user asks a conceptual question mid-task, answer in three sentences and remind them once per session that `/btw ¿qué es X y cuándo NO usarlo?` keeps the next one out of context.
```

- [ ] **Step 2: Confirm and commit**

Run: `head -5 plugins/diego-cc-kit/output-styles/aprender.md | grep -c 'name: aprender\|keep-coding-instructions: true'`
Expected: `2`

```bash
git add plugins/diego-cc-kit/output-styles/aprender.md
git commit -m "feat: aprender output style (hints, human slice, named concepts)"
```

---

### Task 5: The `/drill` skill

**Files:**
- Create: `plugins/diego-cc-kit/skills/drill/SKILL.md`

- [ ] **Step 1: Write the skill**

```markdown
---
name: drill
description: Spaced-recall drill over docs/agent/til.md — asks five concepts from recent work, records hits and misses. User-invoked; run weekly in learn-mode repos.
disable-model-invocation: true
---

# Drill — five questions from the TIL log

Reads `docs/agent/til.md` at the repo root (an argument overrides the path). TIL line format:

`- YYYY-MM-DD · <concept> · <one sentence> · <link>` followed by zero or more drill marks ` [✓ YYYY-MM-DD]` / ` [✗ YYYY-MM-DD]`.

## Procedure

1. No file or no TIL lines → say so in one line and stop.
2. Pick five lines, in this priority: last mark is ✗; never drilled; then the oldest ✓ first. Fewer than five → drill what exists.
3. One question at a time, in the user's language, in chat (free text, not `AskUserQuestion`). Ask for the trade-off or the failure mode, never the definition: "¿cuándo NO usarías X?", "¿qué se rompe si sacás X?", "¿cómo lo detectarías en producción?". Wait for the answer before the next question.
4. Judge each answer against the line's sentence and your own knowledge. ✓ = names the mechanism and one limit. ✗ = anything less; say in one sentence what was missing.
5. Append ` [✓ YYYY-MM-DD]` or ` [✗ YYYY-MM-DD]` with today's date to each drilled line. Commit: `docs: drill YYYY-MM-DD`.
6. Close with the score (`3/5`) and, if no TIL line contains the word `walkthrough` dated in the last 30 days, one extra line: "Toca un linear walkthrough: pedí uno del módulo que más creció este mes, leelo entero y dejá una línea `walkthrough` en til.md."

## Red flags

- "I'll ask all five at once" → one at a time; recall is the point.
- "Close enough, ✓" → close is ✗ plus what was missing. The queue exists for that.
- "I'll rephrase the sentence as the question" → that's recognition, not recall. Ask for the limit or the failure.
```

- [ ] **Step 2: Confirm and commit**

Run: `grep -c 'disable-model-invocation: true' plugins/diego-cc-kit/skills/drill/SKILL.md`
Expected: `1`

```bash
git add plugins/diego-cc-kit/skills/drill/SKILL.md
git commit -m "feat: /drill spaced-recall skill"
```

---

### Task 6: README, bump to 0.5.0, ship

**Files:**
- Modify: `README.md` (kit root)
- Modify via `bump.sh`: `plugins/diego-cc-kit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1: README**

Replace the `- **skills/**` line with:

```
- **skills/** — `triage` (issue → executable plan, with a `## Por qué` block and a defense question), `implement` (plan → verified PR; hands over the `[human]` slice in learn mode, PR carries the author's three-sentence explanation), `orchestrate` (delegation + model routing + worktree rules), `verify` (fresh-context verification protocol, findings tagged by concept), `codegraph-usage` (on-demand CodeGraph guidance), `drill` (user-invoked: five recall questions from `docs/agent/til.md`)
```

After the `- **hooks/**` line add:

```
- **output-styles/** — `aprender`: set `"outputStyle": "aprender"` in a repo's `.claude/settings.local.json` and the main conversation debugs with hints (max three) before fixing, leaves one `TODO(human)` slice per task, and names the pattern it uses. The same field is what `triage`/`implement` read to enter learn mode; leave it unset in repos where you only deliver.
```

- [ ] **Step 2: Hook tests still green**

Run: `bash plugins/diego-cc-kit/hooks/tests/run.sh | grep -c '^PASS'`
Expected: `18`

- [ ] **Step 3: Commit, merge, bump, push (main session only)**

```bash
git add README.md
git commit -m "docs: learning layer in README"
# from the kit root, on main, after merging feat/learning-layer:
./bump.sh diego-cc-kit 0.5.0
git add -A && git commit -m "chore: bump diego-cc-kit to 0.5.0" && git push
```

Confirm: `jq -r .version plugins/diego-cc-kit/.claude-plugin/plugin.json` → `0.5.0`; `jq -r '.plugins[]|select(.name=="diego-cc-kit").version' .claude-plugin/marketplace.json` → `0.5.0`.

---

### Task 7: CLAUDE.md declares the two modes

**Files:**
- Modify: `~/.claude/CLAUDE.md` (after the `## Planning gates` block, before `## Git Workflow`)

- [ ] **Step 1: Insert the block**

```markdown
## Modos de trabajo
- Dos modos por repo, elegidos por `outputStyle` en `.claude/settings.local.json`: `aprender` (personal/, projects/, hobby/) o ausente = **entregar** (work/). Los skills del kit leen ese campo; no lo deduzcas de la carpeta.
- Siempre: el plan trae `## Por qué` y una pregunta de defensa que respondo yo antes de aprobarlo (`defensa:` en PROGRESS.md); el PR lleva mi explicación del diff en tres oraciones o queda en draft; un término que no podría explicar va a `/btw ¿qué es X y cuándo NO usarlo?`.
- Solo en aprender: una tajada `[human]` por plan la escribo yo; los bugs que traigo al hilo se debuggean con pistas (máx. 3) antes del fix; cada plan cerrado deja una línea en `docs/agent/til.md` y `/drill` la repasa una vez por semana.
```

- [ ] **Step 2: Confirm**

Run: `grep -c '## Modos de trabajo\|defensa:\|/drill' ~/.claude/CLAUDE.md && wc -l ~/.claude/CLAUDE.md`
Expected: `3` and 85 lines (81 + 4)

---

### Task 8: Stamp `aprender` into every personal/projects/hobby repo

**Files:**
- Create or modify: `<repo>/.claude/settings.local.json` for each git repo (directory or worktree) directly under `~/dev/personal`, `~/dev/projects`, `~/dev/hobby`

- [ ] **Step 1: Run**

```bash
for d in ~/dev/personal/* ~/dev/projects/* ~/dev/hobby/*; do
  [ -e "$d/.git" ] || continue
  f="$d/.claude/settings.local.json"
  mkdir -p "$d/.claude"
  [ -f "$f" ] || echo '{}' > "$f"
  tmp=$(mktemp) && jq '.outputStyle = "aprender"' "$f" > "$tmp" && mv "$tmp" "$f"
  git -C "$d" check-ignore -q .claude/settings.local.json \
    || echo ".claude/settings.local.json" >> "$(git -C "$d" rev-parse --git-path info/exclude)"
  echo "$d"
done
```

`jq` merges into existing files (today they hold only `permissions`), so nothing else changes. The exclude line keeps the file out of git in forks (`actual-fork`, `Suwayomi-Server`) and worktrees.

- [ ] **Step 2: Confirm**

Run:
```bash
for d in ~/dev/personal/* ~/dev/projects/* ~/dev/hobby/*; do
  [ -e "$d/.git" ] && jq -r '.outputStyle' "$d/.claude/settings.local.json"
done | sort | uniq -c
git -C ~/dev/work/aai status --porcelain -- .claude | wc -l
```
Expected: one line, `N aprender` where N = number of repos printed in Step 1 (27 dirs listed today; the count is whatever has a `.git`); second command prints `0`.

---

### Task 9: Diego, next session (interactive)

- [ ] Restart Claude Code (kit 0.5.0 is live via `--plugin-dir`; other PC: `claude plugin marketplace update diego-cc-kit && claude plugin update diego-cc-kit@diego-cc-kit`).
- [ ] In a personal repo, `/config` → Output style shows `aprender` selected. Paste a fake stack trace: the reply asks for your hypothesis instead of fixing.
- [ ] `/context`: the `aprender` style adds system-prompt text; note the delta against the 0.4.0 baseline in `PROGRESS.md`.
- [ ] Run `diego-cc-kit:triage` on one small real issue in that repo: the plan has `## Por qué`, `## Pregunta de defensa`, `## Tajada [human]`; you answer; `implement` stops at the slice.
- [ ] After the first PR lands, `docs/agent/til.md` has one line; a week later, `/drill`.
- [ ] Deliver-mode check: in `~/dev/work/aai`, triage a small issue; no `## Tajada [human]`, but `## Por qué` and the defense question are there.

---

### Task 10: Capture into dotfiles

- [ ] `/update-dotfiles ~/.claude/CLAUDE.md` → source diff shows only the `## Modos de trabajo` block; commit on `chore/opus5-config-tuning` with `chore(dotfiles): capture learning-layer CLAUDE.md`. Do not push.

---

## Non-goals

- No hook enforces the defense answer, the explanation, or the TIL line. Prose gates in skills are enough for a first iteration; a hook comes if a gate is skipped twice (the kit's own steering rule).
- No `til.md` or drill in `work/` repos (nothing versioned in company repos). If wanted later, `~/dev/work/aai/knowledge/<proyecto>/til.md` is the place and `/drill <path>` already accepts it.
- No change to `implement`'s gate-failure loop, to subagent prompts, or to the built-in `Learning` style.
- No calendar automation for mechanism 7.

## Ordering

Chain B (Tasks 1–5) and Chain A (Tasks 7–8) are independent and can run in parallel as one implementer each on disjoint files. Task 6 needs 1–5 merged. Task 9 needs 6 and 8. Task 10 needs 7.
