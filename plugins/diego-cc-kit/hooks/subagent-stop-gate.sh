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

dir="${TMPDIR:-/tmp}/claude-subagent-gate"
safe_id="${agent_id//[^a-zA-Z0-9_-]/}"
[ -z "$safe_id" ] && exit 0    # fail-open: agent_id sanitiza a vacío, no bloquear nunca
count_file="$dir/$safe_id"

if [ -n "$msg" ]; then
  rm -f "$count_file"
  exit 0                        # hay reporte: dejar parar
fi

mkdir -p "$dir"
count=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
echo "$count" >"$count_file"

# ponytail: tope fijo de 2; si el canal está roto de verdad, bloquear más solo quema tokens
[ "$count" -gt 2 ] && exit 0

echo "Tu turno terminó sin reporte final. Emití AHORA tu resultado completo como único mensaje (intento $count/2)." >&2
exit 2
