# Why not eugeniughelbur's pack directly

[eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) is the richest second-brain pack I evaluated. Twenty-plus commands, four thinking tools, four scheduled agents, a fully developed opinion about what an Obsidian vault should look like. If you are a new Obsidian user starting from an empty vault and you want a turnkey setup, it is the best single choice in the ecosystem.

It is also the pack whose ideas I borrowed most from and whose execution I had to rework most heavily before shipping my own.

## What I kept from it

**The four thinking tools pattern.** `/challenge`, `/emerge`, `/connect`, and a bridging command together form a coherent tier-2 toolkit. Each does something that the core Karpathy primitive (compile sources into a wiki note) cannot do — steel-man, cluster, link-propose, cross-domain bridge. I kept all four in essentially the shape eugeniughelbur ships them. My `/challenge`, `/emerge`, and `/connect` are recognizable descendants.

**The scheduled-agent pattern.** Morning / nightly / weekly / health is eugeniughelbur's cadence almost verbatim. The insight that a second brain is only as good as the agents quietly tending it while you sleep — this is his contribution. I kept the four-agent schedule, tweaked what each one does to match my regime model, and kept the launchd-plist delivery mechanism.

**The opinionated stance.** eugeniughelbur's pack takes strong positions: this is where `Fleeting/` lives, this is what a permanent note looks like, this is the tag taxonomy, here is what a project index should contain. Opinions are what make a pack usable on day one. I kept the pattern of shipping opinions explicitly, even when my opinions differ from his.

## What I dropped

**Unfenced ingest that rewrites project indexes.** eugeniughelbur's `/save`-equivalent will, on classification ambiguity, write to the most likely project index and rewrite surrounding context to fit. This is great when you have no pre-existing indexes. It is catastrophic when you have carefully curated project indexes you do not want rewritten. My `/save` refuses to rewrite a project index — it appends a link, and the linking side is a stub that announces "50/50 classification, resolved to primary on <date>" so the operator can flip the decision.

**No Obsidian Tasks syntax.** eugeniughelbur's task-adjacent notes use a plain checkbox syntax that doesn't parse under the Obsidian Tasks plugin. If you aren't using Tasks, fine. If you are — as I am — this breaks your entire task query model. My pack emits `- [ ] text ⏫ 📅 2026-04-15` natively, with priority emoji and date markers the plugin understands.

**No Morgen UUID preservation.** eugeniughelbur's pack has no concept of external-system IDs. If a task in the vault has `🆔 abc123` for Morgen round-trip identity, his `/save` strips it on reformat. Mine preserves every `🆔 <id>` trailing tag on every task line, because that tag is the stable sync key for the n8n W1 pipeline. Strip it and you get duplicate tasks in Morgen within 15 minutes.

## What I improved

**Scoping.** eugeniughelbur's commands operate on the whole vault by default, which on a 4000-note vault is both slow and indiscriminate. Mine default to a scope — usually the current project, inferred from frontmatter or from pwd — and require an explicit `--all` flag to go wider. `/emerge` on the full vault takes minutes; `/emerge` on a project takes seconds and produces a tighter, more useful output.

**Dry-run default.** Every destructive command in this pack defaults to `--dry-run` on first invocation, prints a preview table of proposed changes, and waits for `y` before writing. eugeniughelbur's commands write immediately and log-after-the-fact. For a solo Obsidian user this is fine. For an operator whose vault is being touched by three other processes concurrently, dry-run-default is non-negotiable — I've saved my own vault from my own classifier twice in the first month.

**UUID safety.** In addition to Morgen UUIDs, my pack preserves any `id:` frontmatter key, any trailing `^block-ref` anchor, and any Obsidian internal link target. The rule is: if a downstream system or another note depends on a stable reference in a line, that reference survives every reformat operation in this pack. This is not a feature so much as a non-negotiable invariant.

## When eugeniughelbur's pack is still better

If you are starting from zero, building your vault around the pack rather than fitting the pack into an existing vault, and you want the richest out-of-box toolkit — his pack is better. It has more commands, more opinions, more scaffolding for new users. This pack exists because I needed the same richness without the rewrites. If you don't, you don't.

His pack is credited in [`docs/CREDITS.md`](docs/CREDITS.md) and analyzed op-by-op in [`docs/foundations/03-eugeniu-analysis.md`](docs/foundations/03-eugeniu-analysis.md).
