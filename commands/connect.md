---
description: "Suggest new wikilinks between concepts the skill believes are related but currently unlinked — proposes, does not auto-apply."
---

Read the `connect` skill at `skills/connect/SKILL.md`, then run the workflow. The skill embeds every `03-Concepts/` note, finds pairs with cosine similarity ≥0.82 that lack a direct wikilink in either direction, and produces a proposal list. Each proposal shows the two notes, the overlap signal (shared tags, shared sources, embedding score), and a suggested anchor sentence for the link. The user confirms per-pair before any write. Commit prefix `[bot:wiki-add]` on accepted proposals. All writes obey `references/wiki-schema.md`.
