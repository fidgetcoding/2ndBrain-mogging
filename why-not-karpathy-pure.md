# Why not Karpathy's gist directly

Andrej Karpathy's [LLM Wiki gist](https://gist.github.com/karpathy/3d3797cfe72b4fd78dab7a5c35caf0f9) is the seed idea for every project in this space, including this one. If you only need what it provides, use it — it is shorter, simpler, and does one thing cleanly. You do not need this pack.

## What Karpathy's gist provides

- The **compilation-over-retrieval** stance. The wiki note is a derived artifact re-compiled from `Inbox/` and `Sources/` on demand. There is no vector index.
- The **Inbox → Sources → Wiki** three-folder primitive. Raw captures land in Inbox. Curated factual content moves to Sources. Distilled topical notes are compiled into Wiki.
- The **source-first frontmatter convention**. Every Sources note carries a URL or reference so the LLM can cite back and re-fetch if needed.
- The **"if you lose the wiki you can regenerate it" invariant**. The vault is resilient because the wiki is never the authoritative form — the sources are.
- A single skill, roughly: "read the inbox and the sources folder, pick a topic, write a wiki note."

That is the whole idea. It is correct, and it is sufficient for a knowledge base under ~100 notes maintained by one person with discipline.

## What this pack adds beyond it

The moment your vault grows past a few hundred notes, or the moment more than one writer (you + a sync bot + a scheduled agent) is touching the files, Karpathy's primitive needs more scaffolding. This pack adds:

**Ten slash commands, not one.** `/wiki` is the Karpathy primitive. `/save`, `/challenge`, `/emerge`, `/connect`, `/tether`, `/backfill`, `/aliases`, `/autoresearch`, `/canvas` are tier-2 thinking tools that do not exist in the gist. They presuppose a vault that already has compiled wiki notes to think against.

**Tier 2 thinking tools.** Karpathy's gist is purely tier 1 — passive compile. It never questions a claim in your vault, never surfaces patterns across notes, never proposes new connections. Tier 2 is where the LLM is actually doing cognitive work on top of the substrate. This pack ships `/challenge` (steel-man opposing view), `/emerge` (cluster patterns across N notes), and `/connect` (propose wikilinks between notes that should be linked but aren't). These are additive, not replacement — they run on top of a compiled wiki.

**Regime awareness.** Karpathy's gist assumes one writer. This pack assumes four (human, project, sync, LLM-compiled) and refuses to touch SYNC files outside their pipeline. If your vault has no external sync, you do not need this. If it does, the gist will silently break your sync — this pack will not.

**Obsidian-specific integration.** Karpathy's gist is vault-agnostic. This pack writes Obsidian-Tasks-plugin-compatible task syntax natively, understands wikilinks (`[[note]]`) as first-class, audits MOC membership, and maintains bidirectional project-index tethering. If you use plain markdown without Obsidian, the gist is a better fit.

**Migration path for existing vaults.** The gist is a clean-slate tool. This pack ships a `/backfill` that walks historical Claude Code transcripts and routes them retroactively, a `/tether` audit that finds orphan notes in an existing graph, and an `aliases.yaml` classifier that understands your existing project structure. None of this exists in the gist because the gist does not need to exist in a messy pre-existing vault.

**Commit-prefix safety.** Every plugin write is tagged `[bot:<skill>]` so n8n / git hooks / sync filters can skip them. The gist writes with whatever message the caller supplies, which round-trips through sync pipelines as echo-loops. Small detail, large impact in practice.

## When the gist is still better

If you are starting from zero, if you have no sync pipelines, if you do not use Obsidian specifically, if you want to read 50 lines of code instead of a ten-skill plugin — use the gist. I did, for the first six months. This pack exists because I outgrew it, not because the gist is wrong.

The gist is credited in full in [`docs/CREDITS.md`](docs/CREDITS.md) and the canonical Karpathy primitives are documented at [`docs/foundations/01-karpathy-canonical.md`](docs/foundations/01-karpathy-canonical.md), including his own wording on compilation-over-retrieval verbatim.
