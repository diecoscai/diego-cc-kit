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
