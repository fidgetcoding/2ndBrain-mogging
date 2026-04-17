# Why not AgriciDaniel's pack directly

[AgriciDaniel/claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) is the closest thing in the open-source ecosystem to what I wanted out of the box. If I had found it six weeks earlier, I would have used it and saved myself most of the work that produced this pack. It ships a hot-cache pattern, a three-round research loop, a canvas-integrated scratchpad, and a plugin-marketplace-ready layout. Architecturally it is the most mature pack in the space.

I still had to rewrite a couple of its core primitives to match my operational reality, and I added a tier-2 layer it doesn't ship. But the DNA is closer to this pack's than any other upstream.

## What I ported directly

**Hot cache pattern.** AgriciDaniel keeps a small rolling cache of the last N compiled wiki notes hot in a scratch folder, so that downstream compilation passes — `/wiki` on a related topic, `/autoresearch` round 2, `/emerge` across recent work — don't re-read the same sources from disk. This speeds up chained operations measurably and is the reason his `/autoresearch` loop is bearable to run. I ported the cache directly, kept his cache-invalidation rules (modified-time stamp + sources-set hash), and use it in `/wiki`, `/autoresearch`, and `/emerge`.

**`/autoresearch` three-round loop.** Round 1: shallow sweep over the question, produce a draft. Round 2: identify gaps in the draft, issue follow-up research queries. Round 3: synthesize into a final note. This is his structure, I use it verbatim. The prompt scaffolding that makes each round produce actionable output for the next round is a small but nontrivial piece of engineering, and I did not improve on it.

**Plugin marketplace structure.** AgriciDaniel's repo layout — `.claude-plugin/plugin.json`, `skills/*/SKILL.md`, `commands/*.md`, `hooks/`, `scheduled/`, `vault-template/` — is the clean version of how a Claude Code plugin should be organized for discoverability. I mirrored it exactly. Every folder in this repo has an analogue in his, and the mapping is intentional.

**`/canvas`.** An Obsidian Canvas scratchpad pre-wired to a set of notes you name is a surprisingly useful mode for thinking-out-loud with an LLM in the loop. You can see the notes, the LLM can read them, both of you can add cards. I ported his `/canvas` essentially unchanged. It is the one skill in this pack I have not meaningfully touched from his version.

## What I rebuilt

**`/save` with classifier + alias + tethering.** AgriciDaniel's `/save` is roughly a transcript-dump into the Inbox. Mine is a full classification pipeline: load `aliases.yaml`, score every alias against the content, present the top candidates with confidence scores in a dry-run table, route to the primary destination, leave a stub at the runner-up destination if classification was within 10%, and run a `/tether` pass on any touched project index to make sure bidirectional links stay intact. This is five times the code of his `/save` and I rewrote it from scratch. His was doing the right thing for an empty vault; mine has to survive a 4000-note operator vault with live sync.

## What I added

**Tier-2 thinking tools.** `/challenge`, `/emerge`, `/connect` are all additive. AgriciDaniel's pack is strong on compilation and research (tier 1, extended) but does not ship thinking tools that work on top of the compiled corpus. These are net-new in this pack relative to his.

**`/backfill`.** Walk a directory of historical Claude Code session transcripts (`~/.claude/projects/**/session-*.jsonl`) and route each one through `/save` as if it had been invoked at the time the session ran. This was mission-critical for my migration — I had three months of unsaved conversations and no appetite for replaying them by hand. Not in his pack.

**`/aliases`.** Manage `Claude-Memory/aliases.yaml` — add a new alias, split an overloaded one, rename, audit for overlap. The file is the single point of truth for classification, so it needs a dedicated editing skill, not just hand-editing YAML. Not in his pack.

**`/tether`.** Audit project-index bidirectional links, MOC membership, GITHUB/LORECRAFT-HQ hub wiring, and sub-project back-references. Report orphans. Fix them (with dry-run default). The graph-tethering rules in my vault are load-bearing; when they break, my graph view becomes useless. `/tether` keeps them intact. Not in his pack.

## When AgriciDaniel's pack is still better

If you want the core compilation + research primitive done well and don't need regime awareness, tier-2 thinking tools, classifier-driven `/save`, or graph-tether auditing — his pack is smaller, cleaner, and the code is easier to read in one sitting. He also has a less opinionated folder schema, which is easier to drop into a vault that doesn't match mine.

His pack is credited in [`docs/CREDITS.md`](docs/CREDITS.md) and analyzed command-by-command in [`docs/foundations/04-agricidaniel-analysis.md`](docs/foundations/04-agricidaniel-analysis.md).
