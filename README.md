# 2ndBrain-mogging

**The Obsidian + Claude Code second brain that respects your existing infrastructure.**

I built this plugin because every second-brain toolkit I found assumed I was starting from an empty vault. I wasn't. I had Obsidian Tasks running, a Morgen sync pipeline, a project folder structure I'd lived in for months, and three different calendar/task engines already talking to each other. Most skills I tried either ignored that substrate or overwrote it. This repo is the opposite: it treats the existing vault, the existing plugins, and the existing agent graph as the primary user, and fits around them.

The pack is an amalgamation — not an invention — of the best ideas from five upstream second-brain projects, with the rough edges sanded down for operators who already have live systems running.

## What I took from where

| Upstream source | What it contributes | What I dropped |
|---|---|---|
| [karpathy/llm-wiki-gist](https://gist.github.com/karpathy/3d3797cfe72b4fd78dab7a5c35caf0f9) | The canonical "wiki is a living artifact the LLM re-compiles from Inbox + Sources." Compilation-over-retrieval stance. Source-first frontmatter convention. | Nothing — this is the spine. |
| [NulightJens/ai-second-brain-skills](https://github.com/NulightJens/ai-second-brain-skills) | Minimal MVP discipline (only 2 skills: `/save` and `/wiki`). The "self-heal on missing schema" reflex. Faithfulness to the Karpathy primitive. | The minimalism itself — I needed more surface area. |
| [eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) | Thinking-tool concept (`/challenge`, `/emerge`, `/connect`, `/bridge`). Scheduled-agent pattern (morning / nightly / weekly). The 20-op expanded command surface. | Unfenced ingest paths that silently rewrote project indexes. No Obsidian Tasks syntax. No Morgen UUID preservation. |
| [AgriciDaniel/claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) | Hot-cache pattern for fast re-compilation. `/autoresearch` 3-round deepening loop. Plugin marketplace layout. `/canvas` visual scratchpad. | `/save` needed a full rewrite with a classifier, alias map, and tethering pass. |
| [NicholasSpisak/second-brain](https://github.com/NicholasSpisak/second-brain) | Source-page template. Discuss-before-write etiquette. "Factual content belongs in Sources only" rule. Prefer-update-over-create. Bash-based test harness. `wiki-schema.md` as single source of truth. | Nothing thrown out — this one is the discipline layer. |

Full attribution with licenses and exact lines-of-inheritance lives in [`docs/CREDITS.md`](docs/CREDITS.md).

## Install

**Plugin marketplace (recommended):**

```
/plugin marketplace add lorecraft-io/2ndBrain-mogging
/plugin install 2ndbrain-mogging@lorecraft-io
```

**Manual:**

```bash
git clone https://github.com/lorecraft-io/2ndBrain-mogging.git ~/.claude/plugins/2ndbrain-mogging
```

Then restart Claude Code. On first run, the plugin will discover your vault, offer to create a `Claude-Memory/aliases.yaml` seed, and verify the 7-folder skeleton.

## Commands

| Slash command | Skill | What it does |
|---|---|---|
| `/save` | `save` | Capture this conversation (or a passage, dictated note, or ADR) into the vault. Alias-classified, dry-run-previewed, append-only. Also `--backfill` mode for historical transcripts. |
| `/wiki` | `wiki` | Re-compile a topic note from its Sources. Single source of truth is `wiki-schema.md`. |
| `/challenge` | `challenge` | Steel-man the opposing view of any claim in your vault. Writes a dated `CHALLENGE-<slug>.md`. |
| `/emerge` | `emerge` | Surface patterns across N notes you'd otherwise miss. Clusters, contradictions, half-formed arguments. |
| `/connect` | `connect` | Propose new `[[wikilinks]]` between notes that share concepts but don't link yet. |
| `/tether` | `tether` | Audit project-index bidirectional links, MOC membership, and hub wiring. Fix orphans. |
| `/backfill` | `backfill` | Walk a set of historical transcripts and route them into the vault as if `/save` had run at the time. |
| `/aliases` | `aliases` | Manage the classifier dictionary in `Claude-Memory/aliases.yaml`. Add / rename / split. |
| `/autoresearch` | `autoresearch` | 3-round deepening research loop — shallow sweep, follow-up pass, synthesis. |
| `/canvas` | `canvas` | Drop an Obsidian Canvas scratchpad pre-wired to whatever set of notes you name. |

## Vault structure

```
2ndBrain/
  00-Inbox/         # Raw captures, unprocessed. Read by /wiki, cleared by you.
  01-Fleeting/      # Quick thoughts. Promoted or discarded weekly.
  02-Literature/    # Sourced content — articles, videos, conversations. Factual.
  03-Permanent/     # Refined atomic notes. The graph lives here.
  04-MOC/           # Maps of Content. Table of contents per topic.
  07-Projects/      # Active work, one folder per project, index note = folder name.
  08-Tasks/         # Obsidian Tasks plugin area files. TASKS-{AREA}.md.
```

The plugin is opinionated about where things go but flexible about what's in them. If your numbering is different, `aliases.yaml` can remap. If you have extra top-level folders (`05-Templates/`, `06-Assets/`), they're left untouched.

## The four regimes

Every note in the vault is owned by exactly one regime. The skill knows which regime it's operating in before it writes anything.

| Regime | Who writes it | What it optimizes for | Example |
|---|---|---|---|
| **HUMAN** | You, hand-edited | Voice, nuance, trust | `03-Permanent/*.md`, poems, essays, project briefs |
| **PROJECT** | You + agents, negotiated | Correctness + currency | `07-Projects/**/index.md`, `08-Tasks/TASKS-*.md` |
| **SYNC** | A bot, round-trip | Fidelity to an external system | Morgen task mirrors, GitHub issue shadows, calendar pins |
| **LLM-COMPILED** | The plugin, re-derivable | Freshness, coverage, no-loss | `03-Permanent/wiki-*.md` re-compiled from Sources |

A HUMAN note is never silently rewritten. A PROJECT note is diffed and proposed. A SYNC note is never touched outside its sync pipeline (the plugin will refuse). An LLM-COMPILED note is regenerated idempotently on demand.

## Scheduled agents

Four launchd jobs run on your machine, invoking the plugin headlessly. Delete any plist to disable that agent.

| Agent | When | What it does |
|---|---|---|
| **morning** | 07:00 local | Scans yesterday's transcripts in `~/.claude/projects/`, surfaces anything worth `/save`-ing that you skipped. Does not write — only reports. |
| **nightly** | 23:30 local | `/tether` audit + `/connect` suggestions. Writes to `00-Inbox/NIGHTLY-<date>.md`. |
| **weekly** | Sunday 18:00 | `/emerge` pass across the full `03-Permanent/` graph. One-page digest. |
| **health** | every 6h | Sanity check: broken wikilinks, orphan files, missing frontmatter, stale MOCs. Writes to `00-Inbox/HEALTH-<date>.md`. |

Every scheduled write is commit-prefixed `[bot:<agent>]` so your n8n sync pipelines know to skip it.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Short version: open an issue before large changes, one skill per PR, every PR runs the full `tests/` harness.

## License

MIT. See [`LICENSE`](LICENSE).

## Credits

This repository is an amalgamation and would not exist without the upstream work credited in [`docs/CREDITS.md`](docs/CREDITS.md). Every slash command, every pattern, every rule in this pack traces back to a specific source with a specific license, documented in that file.
