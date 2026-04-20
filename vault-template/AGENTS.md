---
title: "AGENTS.md — 2ndBrain vault template"
type: index
owner: human
last_confirmed: 2026-04-20
---

# AGENTS.md — 2ndBrain

This file mirrors `CLAUDE.md` for non-Claude agents (Codex, Cursor agents, custom CLI agents, and any other coding or automation tool operating inside this vault). The content is the same; the framing is adapted for tools that don't share Claude's default conventions.

If you are Claude Code, read `CLAUDE.md` instead — this file is not loaded automatically for you.

## Vault purpose

Personal knowledge management system (PKM) — a Second Brain built on Zettelkasten principles. Notes live in an Obsidian-compatible folder structure. Format is plain Markdown with YAML frontmatter and `[[wikilinks]]`. The goal is graph density: every note should connect to at least one other note.

## Folder structure (7 folders)

```
Vault/
├── 01-Conversations/       # agent conversations, session logs, exports
│   └── VAULT/              # meta-conversations ABOUT the vault itself
│       ├── architecture-sessions/
│       ├── graph-repairs/
│       ├── mogging-pack-dev/
│       └── reports/        # daily / audit / weekly / health reports
├── 02-Sources/             # literature notes from external content
├── 03-Concepts/            # atomic permanent notes
├── 04-Index/               # Maps of Content (MOCs) and master Index
├── 05-Projects/            # active projects, each with matching index note
│   └── INCUBATOR/          # staging lane for pre-project ideas
├── 06-Tasks/               # Obsidian Tasks plugin files
└── Claude-Memory/          # symlinked on install; auto-memory + aliases.yaml
```

Folder rules:

- `01-Conversations/VAULT/` is reserved for meta-work about the vault. Never put project content there.
- `02-Sources/` — one note per source. Filename `LIT-<slug>.md` or `SRC-<YYYY-MM-DD>-<slug>.md`. Source URL in frontmatter.
- `03-Concepts/` — atomic notes. One idea per file. Filename is kebab-case.
- `04-Index/` — MOCs, master Index, `Projects-Index.md`, `Map.canvas`.
- `05-Projects/` — every project folder must have an index note whose filename matches the folder name exactly. Do not use a `-Index` suffix.
- `06-Tasks/` — `TASKS.md` is the hub. Per-area files are `TASKS-<AREA>.md`.
- `Claude-Memory/` — do not write here unless updating `MEMORY.md`.

### Retired folders — never write to these

The 2026-04-16 mogging collapsed an older layout into the 7 folders above. These directories are gone and must never be re-created or referenced:

```
00-Inbox/      01-Fleeting/   02-Literature/   03-Permanent/
04-MOC/        05-Templates/  06-Assets/       07-Projects/   08-Tasks/
```

## Four regimes

1. **Capture** — raw inbound content lands in `01-Conversations/` or `02-Sources/`. Minimal processing.
2. **Connect** — promote captures into `03-Concepts/` as atomic notes. Link to concepts and to at least one MOC.
3. **Curate** — maintain `04-Index/` and project indexes in `05-Projects/`. Bidirectional links mandatory.
4. **Complete** — drive tasks through `06-Tasks/` and project indexes. Archive completed projects.

## Skills (12 total)

| Command | Purpose |
|---|---|
| `/save` | Capture conversation content — whole conversation, passage, dictated note, or ADR. Alias-classified, dry-run-previewed, commit-prefixed `[bot:save]`. |
| `/wiki` | Graph-aware workflow with four branches: `add` (ingest source), `audit` (read-only integrity), `heal` (safe reversible repairs), `find` (semantic search with wikilink citations). |
| `/challenge` | Adversarial vault agent. Argues against an idea using your own past notes and feedback. Read-only unless `--save`. |
| `/emerge` | Pattern-miner. Scans the last N days, clusters signals, names candidate concepts. Powers weekly review. |
| `/connect` | Bridges two notes by semantic overlap, structural pattern, and candidate intermediate notes. Read-only. |
| `/tether` | Audits and repairs `05-Projects/` tethering rules. Dry-run default, atomic per-project on `--execute`. |
| `/backfill` | Ingests historical Claude Code session JSONLs into the vault as structured conversation notes. |
| `/aliases` | Bootstraps and maintains `Claude-Memory/aliases.yaml` — the entity→project disambiguation registry. |
| `/autoresearch` | Three-round web research loop with source-freshness hardening and factual-only literature notes. |
| `/canvas` | Generates and maintains Obsidian Canvas files. Central `Map.canvas` uses a Fibonacci-spiral layout. |
| `/import-claude` | One-shot import of a Claude.ai or ChatGPT data-export zip into the vault. |
| `/import-notes` | One-shot import of exported notes from Apple Notes, OneNote, Notion, Evernote, or raw files. |

Each skill's full contract lives in `skills/<name>/SKILL.md`. Read it before calling the skill.

## Scheduled agents (4 total)

Four launchd agents run on a cron schedule. All are audit-only by default. Each agent's full contract lives in `agents/<name>.md`.

1. **morning** — 8:00 AM ET daily. Pulls today's Morgen events + overdue/today tasks, primes `Claude-Memory/hot.md`, writes `01-Conversations/VAULT/reports/daily-YYYY-MM-DD.md`.
2. **nightly** — 10:00 PM ET daily. Runs `/wiki audit` on `02-Sources`, `03-Concepts`, `04-Index`. Writes `audit-YYYY-MM-DD.md` + updates `Claude-Memory/lint-counter.json`. No writes to concept or source notes.
3. **weekly** — 6:00 PM ET Fridays. Runs `/emerge --days 7 --audit` and writes `weekly-YYYY-WW.md` covering new concepts, killed ideas, contradictions, audit trend.
4. **health** — 9:00 PM ET Sundays. Four-gate integrity check: symlinks, Obsidian plugins, n8n sync freshness, Morgen↔Obsidian task parity. Writes `health-YYYY-MM-DD.md`.

## 3 non-negotiables

1. **Bidirectional links or no link.** Every `[[wikilink]]` needs a reverse link from the target.
2. **Filename = folder name for project indexes.** `05-Projects/foo/foo.md`, not `foo-Index.md`.
3. **Bot-prefix commits for automated edits.** Scheduled-agent and skill commits must start with `[bot:<name>]`. Humans must not use this prefix.

## Root-level notes

- `CLAUDE.md` — contract for Claude Code.
- `AGENTS.md` — this file; contract for non-Claude agents.
- `SOUL.md` — operator identity and long-horizon goals.
- `CRITICAL_FACTS.md` — hard facts every agent needs (timezone, defaults, tooling).
- `index.md` — top-level entry point.
- `log.md` — append-only session log.

## Routing table

| Task type | Read these first |
|---|---|
| Capture a URL | `02-Sources/` existing notes (dedupe), this file § Skills (`/wiki add`) |
| Add a task | `06-Tasks/TASKS.md`, `06-Tasks/TASKS-<AREA>.md`, § 3 non-negotiables |
| Create a new project | `04-Index/Projects-Index.md`, `05-Projects/INCUBATOR/`, § Folder rules |
| Promote capture → concept | `03-Concepts/` existing siblings, target MOC in `04-Index/` |
| Update a MOC | `04-Index/Index.md`, the specific MOC file |
| Graph repair | `04-Index/Map.canvas`, `04-Index/Index.md`, § 3 non-negotiables |
| Sync with external tool | `SOUL.md`, `CRITICAL_FACTS.md`, relevant area task file |
| Identity / personal facts | `SOUL.md`, `CRITICAL_FACTS.md` |

## Hard rules

1. Always read a file before editing it.
2. Never save to the vault root except for the six files named above.
3. Filenames: kebab-case for concepts, `LIT-` / `SRC-` prefix for sources, `TASKS-` prefix for task area files.
4. Frontmatter is required on every note.
5. Never use a `-Index` suffix on project index files.
6. Every project must appear in `04-Index/Projects-Index.md`.
7. Bidirectional linking is mandatory.
8. Never commit secrets, credentials, or `.env` files.
9. Link liberally. Wrap concept mentions in `[[wikilinks]]`.
10. Keep notes under 500 lines.
11. Never proactively create documentation unless asked.
12. Never suggest Todoist or a paid task manager. Task management lives in `06-Tasks/` via the Obsidian Tasks plugin.

## Bot-prefix commit rule

Automated edits MUST prefix commit messages with `[bot:<name>]`. Common prefixes: `[bot:save]`, `[bot:wiki-add]`, `[bot:wiki-heal]`, `[bot:tether]`, `[bot:nightly]`, `[bot:morning]`, `[bot:weekly]`, `[bot:health]`. Without the prefix, a single bot edit can trigger duplicate tasks, cascading graph repairs, or sync loops.

If you are running in an interactive session, do not use the bot prefix.

---

[[index]] · [[Projects-Index]]
