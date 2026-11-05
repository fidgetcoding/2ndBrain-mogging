---
description: "Run the living-wiki workflow — add a concept, heal dead links, or audit the graph scoped to sources/concepts/indexes."
---

Read the `wiki` skill at `skills/wiki/SKILL.md`, then run its entry menu (1. Add · 2. Audit · 3. Heal · 4. Find · 5. Exit) and wait for the user's number. `add` ingests a source (URL/file/paste/YouTube/PDF) through the 02-Library (sources → ideas/people/tools) → 03-Index pipeline with discuss-before-write; `audit` is a read-only integrity scan of `02-Library/` and `03-Index/` that writes its report to `01-Projects/VAULT/REPORTS/audit-YYYY-MM-DD.md` (never `03-Index/`, which holds maps only); `heal` applies safe repairs on a dry-run `wiki-heal/YYYY-MM-DD` branch; `find` is semantic retrieval with wikilink-cited synthesis. The skill is FORBIDDEN from writing `owner: human` files, `01-Projects/*/<project>.md` index files, and anything under `04-Tasks/**`.
