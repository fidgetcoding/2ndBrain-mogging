# 2ndBrain-mogging

**The Obsidian + Claude Code second brain that respects your existing infrastructure.**

I built this plugin because every second-brain toolkit I found assumed I was starting from an empty vault. I wasn't. I had Obsidian Tasks running, a Morgen sync pipeline, a project folder structure I'd lived in for months, and three different calendar/task engines already talking to each other. Most skills I tried either ignored that substrate or overwrote it. This repo is the opposite: it treats the existing vault, the existing plugins, and the existing agent graph as the primary user, and fits around them.

The pack is an amalgamation — not an invention — of the best ideas from five upstream second-brain projects, with the rough edges sanded down for operators who already have live systems running. Full upstream attribution lives in the [Credits](#credits) section at the bottom of this file.

## What we retired

If you've been in the Obsidian + LLM space for longer than a weekend you've probably built the same four folders I built, three times in a row: `00-Inbox/`, `01-Fleeting/`, `05-Templates/`, `06-Assets/`. They feel load-bearing for about six weeks and then they quietly become where good notes go to die. This pack ships without them on purpose, and it's the single biggest reason the 7-folder layout works.

`00-Inbox/` is gone because `/save` and `/wiki add` write directly to `02-Sources/` with a dry-run preview first — the inbox stage was a tax you paid every single capture for the luxury of triaging later, which you never actually did. `01-Fleeting/` is gone because fleeting notes are just concepts you haven't written down yet; inline capture plus same-day promotion beats shuffling markdown between folders. `05-Templates/` is gone because templates belong in the plugin layer, not in your graph — the `2ndbrain-mogging` skills carry them now, and your vault stops graphing fake template files as if they were real thoughts. `06-Assets/` is gone because Obsidian's attachment defaults already handle assets in-place, and a centralized assets folder exists mostly to make your graph view lie to you about which notes are "connected."

The replacement isn't "we removed stuff." The replacement is: every note you write already has a home in one of seven folders the second you decide what kind of note it is, and if you can't decide, that ambiguity is a signal the note isn't ready to exist yet. This pack is the answer to "what happens if you take the best 200 ideas from 5 excellent PKM systems and throw out the other 800?" — the [Credits](#credits) section names the five, and [`PHILOSOPHY.md`](PHILOSOPHY.md) covers the thrown-out 800.

## A note on placeholders

This pack was extracted from a live operator's personal vault. Real personal names and private client-project names have been redacted and replaced with stable placeholders of the form `<PERSON-A>`, `<PROJECT-B>`, etc. The mapping from real name to placeholder is not included in this repository. See [`docs/placeholder-names.md`](docs/placeholder-names.md) for the full convention.

## Install

The canonical install path is the bundled `install.sh`. It is idempotent, dry-runs by default, takes a backup before writing anything, and handles the Stop-hook merge safely.

```bash
git clone https://github.com/<ORG-A>/2ndBrain-mogging.git
cd 2ndBrain-mogging

# Dry-run first (default) — shows every change without touching disk
./install.sh --vault /absolute/path/to/your/Obsidian/vault

# Then apply
./install.sh --vault /absolute/path/to/your/Obsidian/vault --apply
```

**Flags:**

| Flag | Default | Meaning |
|---|---|---|
| `--vault PATH` | — | Absolute path to your Obsidian vault. Required with `--apply`. |
| `--dry-run` | on | Simulate only — print every change, write nothing. |
| `--apply` | off | Execute the changes on disk and in `~/.claude/settings.json`. |
| `--no-launchd` | off | Skip installing the 4 scheduled-agent launchd jobs. |
| `--skip-tests` | off | Skip the `tests/test_onboarding.sh` harness at the end of install. |
| `--merge-stop` | off | Replace the existing Stop hook with ours instead of jq-merging onto it. |
| `--with-intelligence` | off | Install the optional self-learning tier (pattern-graph routing, auto-memory bridge, 5 extra hooks). Adds `$VAULT/.claude/helpers/` and `$VAULT/.claude-flow/data/` — opt-in so existing users don't get surprise hooks. See [Self-learning tier](#self-learning-tier-opt-in) below. |
| `--symlink` | off | With `--with-intelligence`: symlink helpers instead of hardlinking. Hardlink is the default (same-filesystem guarantee); use symlink if the vault lives on a different disk from this repo. |

On `--apply`, the installer will: back up `~/.claude/settings.json`, jq-merge the Stop hook (never overwrite), symlink the skills / commands / agents into `~/.claude/`, install launchd plists (unless `--no-launchd`), install the self-learning tier (only if `--with-intelligence` was passed), and run the onboarding test suite (unless `--skip-tests`).

## Self-learning tier (opt-in)

If you pass `--with-intelligence`, the installer adds a sixth upstream to the stack: ruvnet's claude-flow / ruflo intelligence loop (ADR-050). This tier wires PageRank-ranked memory into a small hook graph so `/save` and `/wiki` conversations get progressively smarter routing as the vault grows, without rewriting a single one of your notes. The 11 helper scripts in `helpers/` are verbatim-vendored MIT-licensed copies with a provenance header on each file; they read and write `$VAULT/.claude-flow/data/` and never touch `owner: human` content.

The install path hardlinks (or symlinks with `--symlink`) each helper into `$VAULT/.claude/helpers/` and jq-merges 5 additional hook types (PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SessionEnd) into `~/.claude/settings.json` using the same append-never-overwrite discipline as the Stop-hook merge. Your existing hooks — including the mogging Stop hook from `hooks/stop-save.sh` — are preserved untouched. The tier is off by default because the advertised build should work for people who just want the folder layout and the ten skills; turn it on when you want the pack to start learning from your session history.

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

These skills are auto-namespaced under the `2ndbrain-mogging` plugin. Both `/save` and `/2ndbrain-mogging:save` resolve to the same skill, so either form works inside Claude Code. The placeholder convention used in skill examples and tests is documented in [`docs/placeholder-names.md`](docs/placeholder-names.md).

## Vault structure

```
2ndBrain/
  01-Conversations/   # /save output — mirrors 05-Projects subfolders. VAULT/ subtree holds vault-about-vault notes.
  02-Sources/         # External inputs — articles, videos, transcripts, conversations. Factual.
  03-Concepts/        # Refined atomic notes. The graph lives here. Human-owned by default.
  04-Index/           # Maps of Content — Index.md, Home-Index, Projects-Index, topic-Index files, Map.canvas.
  05-Projects/        # Active work. One folder per project, index note filename = folder name. Includes INCUBATOR/.
  06-Tasks/           # Obsidian Tasks plugin area files. TASKS-{AREA}.md, 3-way Morgen sync.
  Claude-Memory/      # Symlink to ~/.claude/projects/<vault>/memory/ — aliases.yaml + auto-memory shards.

  AGENTS.md           # Scheduled-agent contract for the 4 launchd jobs (morning / nightly / weekly / health).
  CLAUDE.md           # Top-level Claude Code configuration and vault contract.
  CRITICAL_FACTS.md   # Pinned facts the LLM must never contradict.
  SOUL.md             # Operator voice / tone / first-person defaults.
  index.md            # Top-level entry point (linked from Home-Index).
  log.md              # Append-only session log.
```

This is the post-mogging 7-folder layout (canonical as of 2026-04-16). The Post-Mogging Vault Contract explicitly retires the legacy folders (`00-Inbox/`, `01-Fleeting/`, `05-Templates/`, `06-Assets/`) — the pack does not run against them. `Claude-Memory/aliases.yaml` handles entity-name remapping (person → project, alias → canonical handle) only; it is not a folder-structure compatibility layer. Vaults still on the legacy scheme need to migrate to the 7-folder layout before installing.

## The four regimes

Every note in the vault is owned by exactly one regime. The skill knows which regime it's operating in before it writes anything.

| Regime | Who writes it | What it optimizes for | Example |
|---|---|---|---|
| **HUMAN** | You, hand-edited | Voice, nuance, trust | `03-Concepts/*.md`, poems, essays, project briefs |
| **PROJECT** | You + agents, negotiated | Correctness + currency | `05-Projects/**/index.md`, `06-Tasks/TASKS-*.md` |
| **SYNC** | A bot, round-trip | Fidelity to an external system | Morgen task mirrors, GitHub issue shadows, calendar pins |
| **LLM-COMPILED** | The plugin, re-derivable | Freshness, coverage, no-loss | `03-Concepts/wiki-*.md` re-compiled from Sources |

A HUMAN note is never silently rewritten. A PROJECT note is diffed and proposed. A SYNC note is never touched outside its sync pipeline (the plugin will refuse). An LLM-COMPILED note is regenerated idempotently on demand.

## Scheduled agents

Four launchd jobs run on your machine, invoking the plugin headlessly. Delete any plist to disable that agent.

| Agent | When | What it does |
|---|---|---|
| **morning** | 08:00 local, daily | Pulls today's Morgen events, surfaces overdue + today tasks, primes `Claude-Memory/hot.md`. Writes to `01-Conversations/VAULT/reports/daily-YYYY-MM-DD.md`. |
| **nightly** | 22:00 local, daily | `/wiki audit` scoped to `02-Sources/`, `03-Concepts/`, `04-Index/` — audit-only, no writes to those folders. Writes to `01-Conversations/VAULT/reports/audit-YYYY-MM-DD.md`. |
| **weekly** | Friday 18:00 local | `/emerge --days 7 --audit` — new concepts, killed ideas, contradictions, 7-day audit trend. Writes to `01-Conversations/VAULT/reports/weekly-YYYY-WW.md`. |
| **health** | Sunday 21:00 local | Four gates: symlink resolution, Obsidian plugin presence, n8n sync freshness, Morgen↔Obsidian task-count parity. Writes to `01-Conversations/VAULT/reports/health-YYYY-MM-DD.md`. |

Every scheduled write is commit-prefixed `[bot:<agent>]` so your n8n sync pipelines know to skip it.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Short version: open an issue before large changes, one skill per PR, every PR runs the full `tests/` harness.

## License

MIT. See [`LICENSE`](LICENSE).

## Credits

This repository is an amalgamation and would not exist without the upstream work listed below. Every slash command, every pattern, every rule in this pack traces back to a specific source with a specific license. Full attribution with licenses and exact lines-of-inheritance lives in [`docs/CREDITS.md`](docs/CREDITS.md).

- [karpathy/llm-wiki-gist](https://gist.github.com/karpathy/3d3797cfe72b4fd78dab7a5c35caf0f9) — the canonical "wiki is a living artifact the LLM re-compiles from Sources" primitive. Compilation-over-retrieval stance and source-first frontmatter convention. The spine of this pack.
- [NulightJens/ai-second-brain-skills](https://github.com/NulightJens/ai-second-brain-skills) — minimal-MVP discipline (two skills: `/save` and `/wiki`) and the self-heal-on-missing-schema reflex.
- [eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) — thinking-tool concept (`/challenge`, `/emerge`, `/connect`) and the scheduled-agent pattern (morning / nightly / weekly / health).
- [AgriciDaniel/claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) — hot-cache pattern for fast re-compilation, the `/autoresearch` 3-round deepening loop, the plugin-marketplace layout, and the `/canvas` visual scratchpad.
- [NicholasSpisak/second-brain](https://github.com/NicholasSpisak/second-brain) — the source-page template, discuss-before-write etiquette, the "factual content belongs in Sources only" rule, prefer-update-over-create, the Bash-based test harness, and `wiki-schema.md` as single source of truth.
- [ruvnet/ruflo](https://github.com/ruvnet/ruflo) *(via the <ORG-A> fork [`<ORG-A>/fidgetflo`](https://github.com/<ORG-A>/fidgetflo))* — the self-learning intelligence loop (ADR-050) + auto-memory bridge (ADR-048/049). Vendored verbatim under `helpers/` and installed only when you pass `install.sh --with-intelligence`. MIT license, full provenance headers on every vendored file, full writeup in [`docs/CREDITS.md`](docs/CREDITS.md).
