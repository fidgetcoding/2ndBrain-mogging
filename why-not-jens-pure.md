# Why not NulightJens's pack directly

[NulightJens/ai-second-brain-skills](https://github.com/NulightJens/ai-second-brain-skills) is the most faithful implementation of Karpathy's LLM Wiki idea in the Claude Code plugin ecosystem. It is a Karpathy-minimal MVP: two skills (`/save` and `/wiki`), one schema file, and a strict discipline of not over-scaffolding. If the Karpathy gist is the seed, Jens's pack is the seed planted correctly in the Claude Code soil.

If you want the minimum-viable second brain, use Jens's pack directly. It will do the job. This pack is what I wrote after I ran his for a few weeks and found the exact edges I needed more surface area against.

## What I kept from it

**The minimal-MVP stance.** Jens's discipline of shipping only what is necessary is a real virtue. Every skill I added past his original two required explicit justification ("why is this not already covered by `/save` or `/wiki`?"). I rejected about half of the feature ideas I had for this pack under that test. The four thinking tools that survived (`/challenge`, `/emerge`, `/connect`, `/autoresearch`) each do something structurally different from `/save` + `/wiki`, which is why they made it in.

**The self-heal pattern.** When Jens's `/save` encounters a missing schema file or a malformed frontmatter block, it doesn't crash — it announces the issue, proposes a fix, and asks for confirmation. I lifted this pattern directly. Every skill in this pack self-heals rather than erroring, which matters when you're half-asleep at the terminal dictating into `/save`.

**Karpathy-faithfulness.** Jens treats the Karpathy gist as canonical — `Inbox/` → `Sources/` → `Wiki`, compilation-over-retrieval, sources are factual and accreted, wiki is distilled and re-derivable. I kept the same primitives. My `/wiki` command is a superset of his; it still produces the same compile-from-sources output for the same input.

**The "discuss before write" etiquette.** Jens's `/save` asks "does this feel right?" before writing. I expanded this into the mandatory dry-run preview table that every destructive skill in this pack prints, but the etiquette is his idea.

## What I added beyond it

**Ten commands, not two.** Jens ships `/save` and `/wiki`. I added `/challenge`, `/emerge`, `/connect`, `/tether`, `/backfill`, `/aliases`, `/autoresearch`, and `/canvas` — eight more. Each one corresponds to a specific pattern I hit repeatedly in my own vault that `/save` + `/wiki` didn't cover.

**Tier 2 thinking tools.** Jens's pack is tier 1 only — passive compile. I added the tier-2 layer (thinking tools that actively question, connect, surface). The philosophy note explains the tier model in detail. Short version: once you have a vault of 1000+ compiled wiki notes, the bottleneck stops being "can I compile from sources" and becomes "can I see patterns across what I've already compiled." Tier 2 is the layer that addresses that.

**Slash-command surface.** Jens's skills are invoked as Claude Code skills. I wired each one to a slash command (`/save`, `/wiki`, etc.) so they're addressable from the CLI and from other skills. This also means the skills can call each other — `/backfill` internally invokes `/save` in a loop, `/tether` can invoke `/connect` on each orphan it finds, and so on.

**Infrastructure integration.** Jens's pack is vault-only. It doesn't know about n8n, Morgen, calendar syncs, or the Obsidian Tasks plugin. This pack does — the `[bot:*]` commit prefix is sync-filter-aware, the task syntax is Obsidian-Tasks-compatible, and the regime model exists specifically to not trample external sync pipelines. If your vault has no external infrastructure, Jens's pack has a smaller surface area with less risk. If your vault has sync pipelines, this pack's infrastructure awareness is load-bearing.

## When Jens's pack is still better

If you are a solo writer on a Karpathy-pure vault with no sync infrastructure, no Obsidian Tasks integration, no scheduled agents, and no need to audit bidirectional links — Jens's pack is strictly simpler and will serve you well. It is also a better starting point if you want to read every line of the skill and understand it; this pack is larger and has more moving parts.

Jens's pack is credited in [`docs/CREDITS.md`](docs/CREDITS.md) and analyzed in [`docs/foundations/02-jens-analysis.md`](docs/foundations/02-jens-analysis.md).
