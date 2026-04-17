# 05 — Karpathy extensions analysis

This note covers three smaller projects that extend the Karpathy primitive in different directions. None of them is the primary influence on this pack, but each contributes a specific pattern worth naming. Sources:

- rohitg00/LLM-Wiki-v2 — https://github.com/rohitg00/LLM-Wiki-v2
- NicholasSpisak/second-brain — https://github.com/NicholasSpisak/second-brain
- huytieu/COG — https://github.com/huytieu/COG

## rohitg00/LLM-Wiki-v2

LLM-Wiki-v2 is a straightforward evolution of the Karpathy gist with a slightly larger command surface and Python tooling around the compile step. Its main contribution is **explicit templating for the compile output**. Rather than having the LLM decide on the wiki note structure each time, the project ships a set of templates (concept note, how-to, reference, tutorial) and the compile operation selects the template based on the topic.

**What I adopted:** the template-per-output-type idea, applied narrowly to `02-Literature/` entries. My literature template (source-page format) is derived from a combination of this project's template catalog and NicholasSpisak's source-page template.

**What I did not adopt:** the full template catalog. Most of the templates in LLM-Wiki-v2 are specific to software documentation use cases, which is not the primary use case for this pack. For general-purpose permanent notes, template-per-output-type adds process without adding signal — the note finds its own structure during compilation.

## NicholasSpisak/second-brain

NicholasSpisak's pack is covered in detail in `why-not-nicholasspisak-pure.md` at the repo root. Summary of contributions to this pack:

- **Source-page template** for `02-Literature/` entries (required frontmatter, expected body sections, no-interpretation rule)
- **Discuss-before-write etiquette** (seed of the mandatory dry-run preview)
- **Factual-content-in-Sources-only rule** (enforced in my `/save` routing between factual captures and commentary)
- **Prefer-update-over-create rule** (my `/save` appends to existing notes by default)
- **Bash test harness pattern** (my `tests/` directory follows his shape)
- **`wiki-schema.md` as single source of truth** (same pattern, same file location in the skill folder)

The five upstream sources make different trades; NicholasSpisak's trade is the strictest rule-set with the smallest implementation. If you are building a small, personal, highly-disciplined vault and the rules matter more to you than the surface area, his pack is the correct choice. This pack has the same rules plus more surface area.

## huytieu/COG (Chain-of-Going)

COG is less a second-brain pack and more a prompt-engineering pattern for LLM-driven research. The Chain-of-Going idea: when researching a topic, the LLM maintains a visible chain of "next steps" that it commits to before executing each one. Each step produces an artifact and an updated next-step list. The chain is appended to a durable file so the user can follow the research trajectory.

**What I adopted:** the visible-trajectory pattern, in `/autoresearch`. My three-round research loop writes an explicit "round 2 follow-up queries" section before executing round 3, so the operator can see what the LLM intended to do next and intervene if needed. This is lifted from COG's chain pattern, adapted for a bounded three-round structure rather than COG's open-ended chain.

**What I did not adopt:** the open-ended chain format itself. COG's chains can run indefinitely, producing chain files that grow to hundreds of steps. For a personal knowledge base this is too unstructured — the chain becomes an artifact of its own that needs maintaining. The three-round structure is a cap that keeps the output bounded and re-runnable.

COG is also interesting as a demonstration that prompt patterns can be their own shippable artifact, not just skill code. The whole project is, substantively, a prompt template. This pack ships prompt patterns inside SKILL.md files rather than as standalone artifacts, but the influence is legible.

## Summary

None of these three projects is the primary influence on this pack, but each contributes something specific:

- **LLM-Wiki-v2:** template-per-output-type for literature notes
- **NicholasSpisak:** the full discipline layer (source-page template, discuss-before-write, factual-only Sources, update-over-create, bash tests, single-source-of-truth schema)
- **COG:** the visible-trajectory pattern inside the `/autoresearch` three-round loop

The Karpathy gist is the spine. Jens is the minimal MVP. eugeniughelbur is the thinking-tool catalog. AgriciDaniel is the architectural clean version. NicholasSpisak is the rule layer. This pack is the amalgamation.
