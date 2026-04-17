# 2ndBrain-mogging

**The Obsidian + Claude Code second brain that respects your existing infrastructure.**

I built this plugin because every second-brain toolkit I found assumed I was starting from an empty vault. I wasn't. I had Obsidian Tasks running, a Morgen sync pipeline, a project folder structure I'd lived in for months, and three different calendar/task engines already talking to each other. Most skills I tried either ignored that substrate or overwrote it. This repo is the opposite: it treats the existing vault, the existing plugins, and the existing agent graph as the primary user, and fits around them.

The pack is an amalgamation — not an invention — of the best ideas from five upstream second-brain projects, with the rough edges sanded down for operators who already have live systems running. Full upstream attribution lives in the [Credits](#credits) section at the bottom of this file.

## A note on placeholders

This pack was extracted from a live operator's personal vault. Real personal names and private client-project names have been redacted and replaced with stable placeholders of the form `<PERSON-A>`, `<PROJECT-B>`, etc. The mapping from real name to placeholder is not included in this repository. See [`docs/placeholder-names.md`](docs/placeholder-names.md) for the full convention.

## Install

The canonical install path is the bundled `install.sh`. It is idempotent, dry-runs by default, takes a backup before writing anything, and handles the Stop-hook merge safely.

```bash
git clone https://github.com/lorecraft-io/2ndBrain-mogging.git
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

On `--apply`, the installer will: back up `~/.claude/settings.json`, jq-merge the Stop hook (never overwrite), symlink the skills / commands / agents into `~/.claude/`, install launchd plists (unless `--no-launchd`), and run the onboarding test suite (unless `--skip-tests`).

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

This is the post-mogging 7-folder layout (canonical as of 2026-04-16). If your vault uses a different numbering scheme or retains legacy folders (`00-Inbox/`, `01-Fleeting/`, `05-Templates/`, `06-Assets/`), `Claude-Memory/aliases.yaml` can remap and the skills will leave unknown top-level folders untouched.

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

This repository is an amalgamation and would not exist without the upstream work listed below. Every slash command, every pattern, every rule in this pack traces back to a specific source with a specific license. Full attribution with licenses and exact lines-of-inheritance lives in [`docs/CREDITS.md`](docs/CREDITS.md).

- [karpathy/llm-wiki-gist](https://gist.github.com/karpathy/3d3797cfe72b4fd78dab7a5c35caf0f9) — the canonical "wiki is a living artifact the LLM re-compiles from Sources" primitive. Compilation-over-retrieval stance and source-first frontmatter convention. The spine of this pack.
- [NulightJens/ai-second-brain-skills](https://github.com/NulightJens/ai-second-brain-skills) — minimal-MVP discipline (two skills: `/save` and `/wiki`) and the self-heal-on-missing-schema reflex.
- [eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) — thinking-tool concept (`/challenge`, `/emerge`, `/connect`) and the scheduled-agent pattern (morning / nightly / weekly / health).
- [AgriciDaniel/claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) — hot-cache pattern for fast re-compilation, the `/autoresearch` 3-round deepening loop, the plugin-marketplace layout, and the `/canvas` visual scratchpad.
- [NicholasSpisak/second-brain](https://github.com/NicholasSpisak/second-brain) — the source-page template, discuss-before-write etiquette, the "factual content belongs in Sources only" rule, prefer-update-over-create, the Bash-based test harness, and `wiki-schema.md` as single source of truth.
