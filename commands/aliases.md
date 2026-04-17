---
description: "Manage the alias classifier — add, edit, or audit entries in Claude-Memory/aliases.yaml with confidence-boost tuning."
---

Read the `aliases` skill at `skills/aliases/SKILL.md`, then run the workflow. Subcommands: `list` prints current aliases sorted by destination, `add` creates a new alias with a guided prompt (key, names, destination, tags, confidence_boost), `edit` modifies an existing alias, `audit` reports aliases whose destination no longer resolves or whose names never matched a classification in the last 90 days. The file schema is defined in `references/wiki-schema.md` and mirrored in `skills/save/SKILL.md` §2. Commit prefix `[bot:wiki-add]` for adds, `[bot:wiki-heal]` for audits.
