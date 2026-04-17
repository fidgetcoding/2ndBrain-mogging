---
description: "Fetch a URL (or resolve a literature TODO), summarize it into 02-Sources, and spawn linked concept stubs in 03-Concepts."
---

Read the `autoresearch` skill at `skills/autoresearch/SKILL.md`, then run the workflow. Given a URL or a `02-Sources/` TODO, the skill fetches the page, produces a source note with `source_url`, `source_type`, `captured`, and `last_confirmed` frontmatter per `references/wiki-schema.md` §4, extracts atomic concepts, and creates stubs in `03-Concepts/` that link back to the source. FORBIDDEN from writing under `06-Tasks/**`. Commit prefix `[bot:wiki-add]`. Always runs the sec<person-i>ty scrub before any write.
