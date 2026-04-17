---
description: "Run the living-wiki workflow — add a concept, heal dead links, or audit the graph scoped to sources/concepts/indexes."
---

Read the `wiki` skill at `skills/wiki/SKILL.md`, then run the workflow the user asked for. Subcommands: `add` creates a new concept or MOC with inbound+outbound guarantees, `heal` repairs dead wikilinks and missing frontmatter, `audit` reports without writing, `promote` upgrades a `needs_review: true` concept once it has 3+ inbound links. All targets and rules resolve from `references/wiki-schema.md`. The skill is FORBIDDEN from writing under `06-Tasks/**` — that is `save`-only territory.
