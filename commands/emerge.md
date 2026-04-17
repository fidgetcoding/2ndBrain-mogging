---
description: "Surface rising topics, killed ideas, and new links across a time window. Optional --audit flag for weekly-review output."
---

Read the `emerge` skill at `skills/emerge/SKILL.md`, then run the workflow. Accepts `--days N` (default 7) and `--audit` (default off). Produces a report of new concepts, killed concepts, rising tags, declining tags, and unresolved ambiguities in the window. Reads from commit log + lint-counter snapshots per `references/wiki-schema.md` §7. The weekly scheduled agent wraps this command — direct invocation works the same way for any custom window.
