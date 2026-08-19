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
check "agent_id degenerado sanitiza a vacío, pasa (1/3)" \
  "$(run '{"agent_id":"//..","last_assistant_message":""}')" 0
check "agent_id degenerado sanitiza a vacío, pasa (2/3)" \
  "$(run '{"agent_id":"//..","last_assistant_message":""}')" 0
check "agent_id degenerado sanitiza a vacío, pasa (3/3)" \
  "$(run '{"agent_id":"//..","last_assistant_message":""}')" 0

run '{"agent_id":"a9","last_assistant_message":""}' >/dev/null 2>&1
run '{"agent_id":"a9","last_assistant_message":"listo"}' >/dev/null 2>&1
check "tras reportar, count file de a9 se borra" \
  "$([ -e "$TMPDIR/claude-subagent-gate/a9" ] && echo exists || echo gone)" gone

[ $fail -eq 0 ] && echo "OK: 9/9"
exit $fail
