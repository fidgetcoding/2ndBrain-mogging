---
description: "Surface contradictions, weak claims, and under-sourced concept notes. Adversarial read of the graph — never writes a rebuttal, only flags."
---

Read the `challenge` skill at `skills/challenge/SKILL.md`, then run the workflow. The skill does an adversarial pass over `03-Concepts/` and `04-Index/` — finds pairs of notes whose claims disagree, concepts without sources, and synthesis notes whose `answers_question` field is not actually answered by the body. Output is a challenge report, never an edit. Follow the schema at `references/wiki-schema.md` for all reads. If the user provides a scope (`--scope=concept-slug`), limit the pass to that concept's neighborhood.
