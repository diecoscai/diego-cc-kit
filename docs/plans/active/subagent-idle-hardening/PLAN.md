# Subagent Idle Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar las causas evitables de subagentes que terminan idle sin entregar resultado, y dejar un protocolo de recuperación cuando igual pase.

**Architecture:** Tres capas: (1) reglas de spawn en `orchestrate/SKILL.md` que evitan las rutas rotas del harness, (2) un hook `SubagentStop` que bloquea paradas sin reporte (máx 2 reintentos), (3) un script de diagnóstico para inspeccionar subagentes colgados desde disco. Todo vive en el plugin `diego-cc-kit`.

**Tech Stack:** Bash, jq, Claude Code hooks (`SubagentStop`), plugin diego-cc-kit.

**Spec:** Research de sesión 2026-08-19 (abajo, §Contexto). No hay spec doc aparte.

## Contexto (research 2026-08-19)

Bugs upstream relevantes a este setup, ordenados por aplicabilidad:

1. **#71723** (confirmado por mantenedores, `reproduced`): con team config activa — y este setup tiene `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — pasar `name` al Agent tool cambia el spawn al protocolo teammate: el resultado llega como `idle_notification` al inbox del equipo y el caller nunca recibe `task-notification`. **Es la causa más probable de "terminan idle" acá.**
2. **#78782**: un subagente in-process no tiene wake inlet. Si lanza Bash `run_in_background: true` y cierra turno, nunca se despierta. `Monitor` dentro de un subagente se descarta, no se encola.
3. **#87009**: `idle_notification` llega vacío o con 30-40 min de retraso; un segundo nudge explícito ("mandá tu reporte completo ahora") trae el contenido de inmediato.
4. **#47936**: paradas prematuras silenciosas (`stop_reason: None`, mensaje truncado) reportadas como `completed`.
5. Doc oficial: los subagentes en background corren con tool set reducido **sin el Agent tool** — un subagente en background no puede delegar; pedírselo se ve como idle.
6. **Descartado**: el bug de permission-mode no propagado (#61547) — verificado en JSONL local (subagentes ejecutan tools normalmente, 51 tool calls en muestra).

Recuperación: el trabajo casi siempre está en disco en
`~/.claude/projects/<cwd-encoded>/<session-id>/subagents/agent-<id>.jsonl`.

## Global Constraints

- Los cambios de hooks van en `plugins/diego-cc-kit/hooks/` y se registran en `plugins/diego-cc-kit/hooks/hooks.json` (patrón existente: `"${CLAUDE_PLUGIN_ROOT}"/hooks/<script>.sh`).
- Scripts bash: `set -euo pipefail`, sin dependencias fuera de `jq` (ya requerido por bump.sh).
- El hook `SubagentStop` NUNCA debe poder bloquear indefinidamente: tope duro de 2 reintentos por agent_id.
- No setear `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` global ni tocar `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — quedan documentados como fallback (§Fallbacks), no como cambio.
- Tras mergear: `./bump.sh diego-cc-kit` + commit + push + `claude plugin update diego-cc-kit@diego-cc-kit` + reiniciar Claude Code (el cache de plugins es por versión).

---

### Task 1: Reglas de spawn e idle-recovery en orchestrate/SKILL.md

**Files:**
- Modify: `plugins/diego-cc-kit/skills/orchestrate/SKILL.md` (agregar sección después de "## Sub-Agent Spawn Template", antes de "## Routing")

**Interfaces:**
- Produces: sección `## Spawn Hygiene & Idle Recovery` que Task 2 y 3 referencian por nombre.

- [ ] **Step 1: Agregar la sección al SKILL.md**

Insertar exactamente este bloque después de las "Rules for composing it" del Spawn Template:

```markdown
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
```

- [ ] **Step 2: Verificar consistencia interna**

Run: `grep -n "subagent-diag.sh" plugins/diego-cc-kit/skills/orchestrate/SKILL.md`
Expected: 1 match (la ruta que Task 3 crea: `scripts/subagent-diag.sh`).

- [ ] **Step 3: Commit**

```bash
git add plugins/diego-cc-kit/skills/orchestrate/SKILL.md
git commit -m "Add spawn hygiene and idle recovery rules to orchestrate skill"
```

---

### Task 2: Hook SubagentStop — gate de reporte con tope de reintentos

**Files:**
- Create: `plugins/diego-cc-kit/hooks/subagent-stop-gate.sh`
- Create: `plugins/diego-cc-kit/hooks/test-subagent-stop-gate.sh`
- Modify: `plugins/diego-cc-kit/hooks/hooks.json` (agregar bloque `SubagentStop`)

**Interfaces:**
- Consumes: JSON de Claude Code por stdin con campos `agent_id`, `last_assistant_message` (evento `SubagentStop`).
- Produces: exit 0 (dejar parar) o exit 2 + stderr (el subagente continúa y emite su reporte). Contadores en `${TMPDIR:-/tmp}/claude-subagent-gate/`.

- [ ] **Step 1: Escribir el test que falla**

Crear `plugins/diego-cc-kit/hooks/test-subagent-stop-gate.sh`:

```bash
#!/usr/bin/env bash
# Self-check del gate: mensaje vacío bloquea (máx 2), con contenido pasa.
set -uo pipefail
cd "$(dirname "$0")"
export TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
g=./subagent-stop-gate.sh

run() { echo "$1" | bash "$g" >/dev/null 2>&1; echo $?; }

fail=0
check() { [ "$2" = "$3" ] || { echo "FAIL: $1 (got $2, want $3)"; fail=1; }; }

check "mensaje con contenido pasa" \
  "$(run '{"agent_id":"a1","last_assistant_message":"Reporte final: PASS con evidencia."}')" 0
check "mensaje vacío bloquea (1er intento)" \
  "$(run '{"agent_id":"a2","last_assistant_message":""}')" 2
check "mensaje vacío bloquea (2do intento)" \
  "$(run '{"agent_id":"a2","last_assistant_message":""}')" 2
check "3er intento deja pasar (tope de reintentos)" \
  "$(run '{"agent_id":"a2","last_assistant_message":""}')" 0
check "campo ausente bloquea" \
  "$(run '{"agent_id":"a3"}')" 2
check "solo whitespace bloquea" \
  "$(run '{"agent_id":"a4","last_assistant_message":"  \n "}')" 2
check "JSON inválido pasa (fail-open)" \
  "$(run 'not-json')" 0

[ $fail -eq 0 ] && echo "OK: 7/7"
exit $fail
```

- [ ] **Step 2: Correrlo y verificar que falla**

Run: `chmod +x plugins/diego-cc-kit/hooks/test-subagent-stop-gate.sh && plugins/diego-cc-kit/hooks/test-subagent-stop-gate.sh`
Expected: FAIL (subagent-stop-gate.sh no existe todavía).

- [ ] **Step 3: Escribir el hook**

Crear `plugins/diego-cc-kit/hooks/subagent-stop-gate.sh`:

```bash
#!/usr/bin/env bash
# SubagentStop gate: si el subagente intenta terminar sin mensaje final,
# exit 2 lo fuerza a continuar y emitir su reporte (bug upstream #47936:
# paradas prematuras con stop_reason None reportadas como completed).
# Tope duro de 2 reintentos por agent_id — nunca bloquea indefinidamente.
set -uo pipefail

input="$(cat)" || exit 0
agent_id="$(jq -r '.agent_id // empty' <<<"$input" 2>/dev/null)" || exit 0
[ -z "$agent_id" ] && exit 0   # fail-open: sin JSON válido no bloqueamos nada

msg="$(jq -r '.last_assistant_message // ""' <<<"$input" 2>/dev/null | tr -d '[:space:]')"
[ -n "$msg" ] && exit 0        # hay reporte: dejar parar

dir="${TMPDIR:-/tmp}/claude-subagent-gate"
mkdir -p "$dir"
count_file="$dir/${agent_id//[^a-zA-Z0-9_-]/}"
count=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
echo "$count" >"$count_file"

# ponytail: tope fijo de 2; si el canal está roto de verdad, bloquear más solo quema tokens
[ "$count" -gt 2 ] && exit 0

echo "Tu turno terminó sin reporte final. Emití AHORA tu resultado completo como único mensaje (intento $count/2)." >&2
exit 2
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `chmod +x plugins/diego-cc-kit/hooks/subagent-stop-gate.sh && plugins/diego-cc-kit/hooks/test-subagent-stop-gate.sh`
Expected: `OK: 7/7`, exit 0.

- [ ] **Step 5: Registrar el hook en hooks.json**

En `plugins/diego-cc-kit/hooks/hooks.json`, agregar dentro de `"hooks"` (hermano de `"PostToolUse"`):

```json
"SubagentStop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/subagent-stop-gate.sh"
      }
    ]
  }
]
```

Run: `jq . plugins/diego-cc-kit/hooks/hooks.json >/dev/null && echo JSON-OK`
Expected: `JSON-OK`

- [ ] **Step 6: Commit**

```bash
git add plugins/diego-cc-kit/hooks/subagent-stop-gate.sh plugins/diego-cc-kit/hooks/test-subagent-stop-gate.sh plugins/diego-cc-kit/hooks/hooks.json
git commit -m "Add SubagentStop gate blocking empty final reports (max 2 retries)"
```

---

### Task 3: Script de diagnóstico de subagentes colgados

**Files:**
- Create: `plugins/diego-cc-kit/scripts/subagent-diag.sh`

**Interfaces:**
- Consumes: `~/.claude/projects/<cwd-encoded>/*/subagents/agent-*.jsonl` (estructura verificada 2026-08-19: una entrada JSON por línea con `agentId`, `timestamp`, `type`, `message.content[]`).
- Produces: tabla por stdout: agent id, nº tool calls, timestamp de última entrada, último texto del assistant (primeros 120 chars). Lo invoca el paso 3 del protocolo de recuperación (Task 1).

- [ ] **Step 1: Escribir el script**

Crear `plugins/diego-cc-kit/scripts/subagent-diag.sh`:

```bash
#!/usr/bin/env bash
# Lista los subagentes recientes del proyecto actual con señales de vida,
# para decidir entre nudge / leer resultado de disco / re-despachar.
# Uso: subagent-diag.sh [horas]   (default: 24)
set -euo pipefail

hours="${1:-24}"
proj="$HOME/.claude/projects/$(pwd | sed 's|/|-|g')"
[ -d "$proj" ] || { echo "sin sesiones para $(pwd)"; exit 0; }

found=0
while IFS= read -r f; do
  found=1
  id="$(basename "$f" .jsonl)"
  tools="$(grep -c '"type":"tool_use"' "$f" || true)"
  last_ts="$(tail -1 "$f" | jq -r '.timestamp // "?"' 2>/dev/null)"
  last_txt="$(jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | last // "" | .[0:120]' "$f" 2>/dev/null | tr '\n' ' ')"
  printf '%s\n  tools:%s  last:%s\n  msg: %s\n  file: %s\n\n' "$id" "$tools" "$last_ts" "${last_txt:-<sin texto>}" "$f"
done < <(find "$proj" -path '*/subagents/agent-*.jsonl' -newermt "-${hours} hours" 2>/dev/null | sort)

[ "$found" -eq 0 ] && echo "sin subagentes en las últimas ${hours}h"
exit 0
```

- [ ] **Step 2: Smoke test contra datos reales**

Run: `chmod +x plugins/diego-cc-kit/scripts/subagent-diag.sh && cd /home/dieco/dev/work/aai/sbi-bids/.claude/worktrees/bridge-cse_01KGFdjH9SJFRhEKv5gvon1W 2>/dev/null && /home/dieco/dev/tools/diego-cc-kit/plugins/diego-cc-kit/scripts/subagent-diag.sh 20000; cd - >/dev/null`
Expected: al menos una entrada con `tools:` numérico y `msg:` no vacío (hay JSONLs reales de agosto en ese proyecto). Si el worktree ya no existe, correrlo desde cualquier proyecto con subagentes recientes.

- [ ] **Step 3: Commit**

```bash
git add plugins/diego-cc-kit/scripts/subagent-diag.sh
git commit -m "Add subagent-diag script for inspecting stalled subagents from disk"
```

---

### Task 4: Publicar el plugin y activar en vivo

**Files:**
- Modify: `plugins/diego-cc-kit/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` (vía `./bump.sh`)

**Interfaces:**
- Consumes: commits de Tasks 1-3 en main.

- [ ] **Step 1: Bump de versión**

Run: `./bump.sh diego-cc-kit`
Expected: `diego-cc-kit: X.Y.Z -> X.Y.Z+1`

- [ ] **Step 2: Commit y push**

```bash
git add -A && git commit -m "chore: bump diego-cc-kit for subagent idle hardening" && git push
```

- [ ] **Step 3: Actualizar el plugin instalado**

Run: `claude plugin update diego-cc-kit@diego-cc-kit`
Expected: actualiza a la versión nueva. Después reiniciar Claude Code (el usuario).

- [ ] **Step 4: Verificación en vivo (sesión nueva)**

En una sesión nueva: spawn de un subagente trivial sin `name` ("leé X y reportá Y") y confirmar que (a) el resultado llega como task-notification, (b) `/hooks` o el debug log muestra `subagent-stop-gate.sh` registrado bajo SubagentStop. Marcar este paso en PROGRESS.md con lo observado.

---

## Fallbacks (NO implementar ahora — solo si el problema persiste tras 1-2 semanas)

- **`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`** en `settings.json` → todos los subagentes a foreground; el resultado vuelve como return value del tool call, esquivando el canal de notificaciones roto. Costo: sin paralelismo, prompts bloqueantes.
- **Quitar `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** → elimina la ruta teammate por completo (#71723). Costo: sin agent teams para el orchestrator.
- **Capturar settings.json a dotfiles** (skill `update-dotfiles`) si se toca cualquiera de los dos — hay drift chezmoi pendiente.
