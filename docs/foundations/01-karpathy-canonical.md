# 01 — Karpathy canonical

The `LLM Wiki` gist by Andrej Karpathy is the origin point for the second-brain-over-Claude-Code genre. This foundations note captures the exact primitives as Karpathy described them, so that downstream skills in this pack can be understood as specific extensions of a well-defined base.

Source: https://gist.github.com/karpathy/3d3797cfe72b4fd78dab7a5c35caf0f9

## The primitives

Karpathy's gist establishes three folder-level primitives and one compile operation. The folders are, in order of flow:

1. **Inbox/** — raw captures. A URL, a screenshot, a dictated thought, a conversation transcript. Unprocessed and ephemeral by convention. Anything in Inbox is expected to either graduate to Sources or be deleted.
2. **Sources/** — curated factual content with a known provenance. Each file has a source reference (URL, book citation, conversation ID) in its frontmatter. The body contains the factual content in the writer's own words or verbatim quotes, clearly marked. No interpretation, no synthesis, no opinion.
3. **Wiki/** — distilled topical notes that the LLM compiles from Sources on demand. A wiki note is a derived artifact; if it is deleted, the LLM can regenerate it by re-reading the relevant sources.

The compile operation is: given a topic and the set of sources relevant to that topic, produce or update a wiki note that summarizes the topic in a single coherent document. The wiki note is expected to be re-derivable — running the compile operation twice over the same set of sources produces equivalent notes (modulo timestamp and phrasing).

## The compilation-over-retrieval thesis

Karpathy's framing, roughly paraphrased and then given in his own wording:

> A wiki is a living artifact that an LLM re-compiles from Inbox + Sources. The important invariant is that the wiki note is derivable — if you lose it, you can regenerate it from the sources. Sources are factual and accreted; wiki notes are distilled and re-derivable.

This inverts the usual retrieval-augmented-generation stack. In RAG, the whole vault is chunked and embedded, and at query time a semantic search pulls the top-k chunks into context. The artifact is the answer to the current query; nothing durable is written back into the vault.

In compilation, the artifact is the wiki note itself. The LLM reads all the relevant sources up front and produces a coherent distilled document that a human can read, curate, and re-read. The artifact persists. The index is the filesystem — there is no vector database.

Compilation is slower per-operation than retrieval. It also produces a much higher-quality result, because the LLM has the full set of relevant sources in context while writing, and the output is a human-readable document rather than a synthesized answer to a single query. For personal knowledge management, where the value is in the quality of connections and the durability of the artifact, compilation is the right tradeoff.

## Source-first frontmatter

Every Sources note in Karpathy's model carries, at minimum:

```yaml
---
title: "Source title"
url: "https://..."          # or a book citation, or a conversation ID
date: 2026-04-16
tags: []
---
```

The `url` (or analogous provenance field) is load-bearing. Without it, the source is orphaned — the LLM cannot cite back to it, cannot re-fetch it, and cannot distinguish it from the writer's own words. Sources without provenance are not sources; they are notes, and they should live in Wiki.

## The "lose-the-wiki" invariant

If the entire Wiki folder is deleted, you should be able to regenerate it from Sources alone. This is the single most important invariant in the Karpathy model because it tells you which folder is authoritative. **Sources are authoritative. Wiki is derived.**

This has practical consequences:

- Never edit a wiki note by hand to add factual content. Facts go in Sources; the wiki note then recompiles to include them.
- Never rely on a wiki note as a primary reference. Cite the source it was compiled from.
- If a wiki note and a source disagree, the source wins.

This invariant is what makes the compilation model durable under LLM error. If the LLM hallucinates in a wiki note, you fix it by correcting the source, not by hand-editing the wiki — because the next recompile would overwrite your hand edit anyway.

## How this pack relates

Every skill in `2ndBrain-mogging` is either:

- **An extension of the compile operation** (`/wiki`, `/autoresearch`)
- **A way to get content into Sources/ correctly** (`/save`, `/backfill`)
- **A tier-2 thinking tool that operates on compiled wiki notes** (`/challenge`, `/emerge`, `/connect`)
- **An infrastructure concern that keeps the graph intact** (`/tether`, `/aliases`, `/canvas`)

The Karpathy primitives are unchanged. Inbox, Sources, Wiki (mapped in this pack to `00-Inbox/`, `02-Literature/`, `03-Permanent/`) are still the three-folder backbone. The compile operation is still the central move. Everything else is scaffolding that makes the backbone survive in an operator's working vault.

If you read only one upstream reference before using this pack, read the Karpathy gist.
