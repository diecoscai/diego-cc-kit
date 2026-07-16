---
name: verify
description: Use after implementation work to verify it with a fresh-context agent — never self-verify. Defines the check order and the PASS/PARTIAL/FAIL report format with evidence.
---

# Verification Protocol

After implementation agents finish, spawn a separate verification agent:
- Fresh context — zero knowledge of how work was done
- Check order: automated (tests, lint, type-check) → functional (does it work?) → quality (follows patterns?)
- Report format:
  ```
  ## Verification: [task]
  Status: PASS | PARTIAL | FAIL
  Checks:
    ✓ [what passed]
    ✗ [what failed — specific reason]
  Evidence: [test output, file diffs]
  ```
- PASS → ready for commit. PARTIAL → human decides. FAIL → retry with failure context.
- When a failure reveals a pattern, save it as feedback memory so it doesn't recur.

The agent that did the work never verifies its own output. Use the `verifier` sub-agent (fresh context, read-only) for this.
