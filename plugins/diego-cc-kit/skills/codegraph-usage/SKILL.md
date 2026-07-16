---
name: codegraph-usage
description: Use when a project has a CodeGraph MCP server (codegraph_* tools) and a .codegraph/ index, to answer structural questions (what calls what, where defined, blast radius) faster than grep. Skip if .codegraph/ does not exist.
---

# CodeGraph

CodeGraph is a tree-sitter-parsed knowledge graph of every symbol, edge, and file. Reads are sub-millisecond and return structural information grep cannot. Only relevant when the current project has a `.codegraph/` index and the `codegraph_*` MCP tools are available.

## When to prefer codegraph over native search
Use codegraph for **structural** questions — what calls what, what would break, where is X defined, what is X's signature. Use native grep/read only for **literal text** queries (string contents, comments, log messages) or after you already have a specific file open.

| Question | Tool |
|---|---|
| "Where is X defined?" / "Find symbol named X" | `codegraph_search` |
| "What calls function Y?" | `codegraph_callers` |
| "What does Y call?" | `codegraph_callees` |
| "What would break if I changed Z?" | `codegraph_impact` |
| "Show me Y's signature / source / docstring" | `codegraph_node` |
| "Give me focused context for a task/area" | `codegraph_context` |
| "Survey an unfamiliar module/topic" | `codegraph_explore` |
| "What files exist under path/" | `codegraph_files` |
| "Is the index healthy?" | `codegraph_status` |

## Rules of thumb
- **Trust codegraph results.** They come from a full AST parse. Do NOT re-verify them with grep.
- **Don't grep first** when looking up a symbol by name. `codegraph_search` is faster and returns kind + location + signature in one call.
- **Don't chain `codegraph_search` + `codegraph_node`** when you just want context — `codegraph_context` is one call.
- **`codegraph_explore` is the heavy hitter** for unfamiliar areas — returns full source from all relevant files in one call, but is token-heavy. Spawn a subagent for explore-class questions to keep main context clean.
- **Index lag**: the file watcher debounces ~500ms behind writes; don't re-query immediately after editing a file in the same turn.

## If `.codegraph/` doesn't exist
The MCP server returns "not initialized." Ask the user: *"This project doesn't have CodeGraph initialized. Want me to run `codegraph init -i` to build the index?"*
