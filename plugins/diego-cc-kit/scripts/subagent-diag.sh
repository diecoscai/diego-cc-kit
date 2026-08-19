#!/usr/bin/env bash
# Lista los subagentes recientes del proyecto actual con señales de vida,
# para decidir entre nudge / leer resultado de disco / re-despachar.
# Uso: subagent-diag.sh [horas]   (default: 24)
set -euo pipefail

hours="${1:-24}"
proj="$HOME/.claude/projects/$(pwd | sed 's|[/._]|-|g')"
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
