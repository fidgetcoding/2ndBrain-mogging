# Philosophy

This is the long form of why `2ndBrain-mogging` exists in a field that already has at least five strong open-source second-brain toolkits.

## The working-operator problem

If you Google "Claude Code Obsidian second brain" today, you land on a gradient of projects. On one end: a 50-line Karpathy gist, pristine in its minimalism, that treats the vault as a directory full of markdown files and the LLM as a compiler. On the other end: 20-plus-skill packs with scheduled agents, canvases, and strong opinions about folder numbering.

All of them assume something I didn't have: an empty vault and a blank schedule. I have a vault with 4,000 notes. I have Obsidian Tasks running on 80 tasks. I have an n8n workflow called W1 that syncs tasks to Morgen tasks with a specific commit-message filter (`[bot:*]` prefix skip-list) to prevent echo loops. I have a graph filter that excludes seventeen specific subtrees so my graph view isn't useless. I have scheduled agents running on launchd already (which used to write to `00-Inbox/` pre-mogging, and now land in `02-Sources/` under the 7-folder contract) that I don't want stepped on.

Every upstream toolkit I tried broke at least one of those systems the first time I ran it. Not because the upstream author did anything wrong — they were solving a different problem, which is "help a new user build a second brain from scratch." I needed the opposite: help an operator who has already built one not burn it down while adding LLM automation.

So the first design commitment of this pack: **the existing vault is the primary user, not a blank scaffold**. Every skill checks for existing structure before writing. Every write is previewed. Every file gets classified into one of four regimes (see below) and the regime determines whether the skill is allowed to touch it at all.

## The tier model

I think of second-brain automation as three layers of ambition. Not everyone needs all three, and aiming for tier 3 before tier 1 works is how you get a useless graph.

**Tier 1 — passive compile.** The vault is a pile of markdown. The LLM reads `Inbox/` and `Sources/` and produces or updates a wiki note. No memory, no reflection, no suggestions. You run `/wiki` on a topic and get a freshly compiled note. This is what Karpathy's gist does, and honestly, if you're just starting, it's enough. Most of the value in a second brain is the act of writing the source notes — the compilation is gravy.

**Tier 2 — thinking tools.** The LLM actively questions, connects, and surfaces patterns you would have missed. `/challenge` steel-mans the opposite of a claim. `/emerge` finds clusters across notes. `/connect` proposes wikilinks between notes you didn't realize were related. This is where eugeniughelbur's project lives, and where I think the real leverage is for someone who already has a substantial vault. Patterns-across-notes is the one thing an LLM is strictly better at than a human with a good memory.

**Tier 3 — memory lifecycle.** The plugin remembers which notes you've touched recently, which ones you avoid, which ones contradict which. It has a concept of "bi-temporal facts" (what was true when I wrote it, what's true now, when did the delta land). It decays stale claims, promotes durable ones, and has opinions about which facts are foundational vs. expiring.

This pack ships tier 1 and tier 2, plus the smallest honest version of tier 3, off by default. `install.sh --with-memory` turns on `bin/memory`, which keeps dates in frontmatter and applies a decay rule and a promotion rule to them. Doing tier 3 properly still takes a graph store and a reasoner, and I haven't built either. Anyone who tells you they've solved this in a Claude Code plugin is overstating. That includes me, so the next section says what mine doesn't do.

**The default tier for this pack is tier 2.** Tier 1 alone is Karpathy's gist — use his if that's all you need.

## Compilation over retrieval

Karpathy's original framing, which I'll quote verbatim because it's the thesis of the whole genre:

> "A wiki is a living artifact that an LLM re-compiles from Inbox + Sources. The important invariant is that the wiki note is derivable — if you lose it, you can regenerate it from the sources. Sources are factual and accreted; wiki notes are distilled and re-derivable."

This matters because it inverts the usual RAG stack. In a retrieval system, you chunk-and-embed the whole vault and hope semantic search surfaces the right span at query time. In a compilation system, the LLM's job is to read all the relevant sources up front and produce a coherent distilled note that a human can then curate. The artifact is the output, not the index.

Compilation is slower per query. It's also much higher quality, and it produces human-readable intermediate artifacts (the wiki notes themselves). For a personal knowledge base where the value is the quality of connections, not the speed of lookup, compilation wins.

`/wiki`, `/save`, and `/autoresearch` are all compilation skills. There is no vector index in this repo.

## The folder is the app

From the Jens project, expressed as a design constraint: the Obsidian folder structure **is** the application's data model. There is no separate index, no sidecar database, no external registry. If a file exists at `01-Projects/<ORG-A>/<ORG-A>.md`, the plugin knows that note is a project index for `<ORG-A>`. If a file exists at `05-Tasks/TASKS-<ORG-A>.md`, the plugin knows it's the Tasks hub for the same project.

This is a discipline. It means the plugin cannot invent new structural concepts without expressing them as a folder or file naming rule, which keeps the surface honest. It also means an operator can move files around outside the plugin and the plugin will rediscover them correctly next run. No "re-index" step. No stale database.

The cost: you have to live with the folder taxonomy the plugin understands. `aliases.yaml` softens this by letting operators remap common names to their actual locations, but the folder discipline itself is load-bearing.

## Why four regimes

Most second-brain tools treat the vault as a flat set of markdown files with equivalent write permissions. This breaks the moment you have more than one writer. The reality in a running operator's vault is:

1. **HUMAN-authored notes.** You wrote this one. Voice matters. Nuance matters. The plugin should never rewrite it, only propose diffs.
2. **PROJECT indexes.** You and the agents share edit rights. Adding a link to a new sub-project is fine for the plugin to do. Rewriting the project summary paragraph is not.
3. **SYNC artifacts.** An external system (Morgen, GitHub, a calendar) owns the truth; the vault file is a mirror. If the plugin writes here, the next sync cycle overwrites the change, or worse, creates a duplicate at the remote end. The plugin must refuse to touch SYNC files outside the sync pipeline.
4. **LLM-COMPILED notes.** The plugin owns these, and they're idempotent — regenerating one from the same sources produces the same note (modulo a timestamp). A human can curate these but should expect their edits to be overwritten on next compile unless they lift the note to HUMAN status.

Four regimes is the minimum that lets humans, plugins, external syncs, and compiled artifacts coexist without stepping on each other. Three isn't enough (PROJECT and SYNC collapse together and Morgen starts duplicating tasks). Five is too many (the fifth category I considered was "draft" and it turned out to just be HUMAN with a `draft: true` flag).

Every write in this pack begins by asking: what regime is the target file? If the answer is SYNC, the skill refuses. If HUMAN, it asks for confirmation. If PROJECT, it diff-previews. If LLM-COMPILED, it proceeds.

This is the single design decision that most distinguishes this pack from its upstream sources, and it's the one that matters most for operators with live sync pipelines.

## Bi-temporal facts (the small version)

The thing I wanted: a notion of "true-when" vs. "true-now". A claim like "Morgen MCP is at v0.1.7" is true as of the date it was written. If I still think of it as true a month later when v0.2.0 has shipped, the vault has misled me. So the plugin should flag stale claims ("this was true as of 2026-04-14, 60 days ago, consider verifying") and decay them out of wiki compilations.

`bin/memory` does that much, with frontmatter as the only data model, because the folder is the app. No sidecar database, no index, nothing to re-sync:

- **What was true when.** `asof:` and `seenat:` date a whole note. A `bi-temporal:` list dates single claims, with `asof`, `until` and `recorded`, and `memory when 2026-05-01` answers from those.
- **Decay.** A concept or synthesis not seen in 60 days goes stale and gets `needs_review: true`. At 180 days it is decayed, and `/wiki` leaves it out of what it compiles. Sources and conversations are exempt, because they're records of what was said and that can't go stale.
- **Promotion.** A note that has held for 90 days, with 3 other notes linking to it, moves from `expiring` to `durable`, which gets three times as long. `foundational` never decays, and only a human can set it.
- **The regimes hold.** It rewrites `owner: wiki` and `owner: llm` notes, only with `--apply`, with a backup first, and only the frontmatter. For a HUMAN note or one with no owner it prints a proposal and stops. It never touches SYNC files.

What it doesn't do, and this is most of what I described above as tier 3:

- **No reasoner.** Decay is a date rule. A note that was wrong the day it was written reads as fresh for 60 days, and a note that is still right goes stale on schedule. It never reads the prose.
- **No contradiction detection.** Two notes can disagree forever and it won't notice. `/wiki audit` looks for that, using a model, and has nothing to do with this tier.
- **No inference.** It doesn't extract claims from notes. A `bi-temporal:` claim exists because someone ran `memory record`, and `until` lands because someone said what replaced it.
- **No graph store.** Promotion counts wikilinks on every run, and that is the whole of its graph. It has no idea which notes you avoid, either.
- **Nothing runs on its own.** No schedule calls it. You run it, or a skill does.

If you want the real thing, look at Anthropic's "memory" work or at graph databases. Don't let me pretend this is that.

---

If all of this sounds like a lot of opinion for what's ostensibly a slash-command pack, that's because the alternative — shipping a tool with no opinions — means your tool gets composed into someone else's running system and breaks it. I'd rather ship the opinions explicit than silent.
