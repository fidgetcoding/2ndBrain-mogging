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

## First session / onboarding (do this)

On a **fresh vault** (just installed, few or no notes yet) or any time the operator is **setting things up** — adding a folder, creating a new project, importing notes — invoke `/vault-coach`. That skill carries the full setup-and-maintenance playbook: it forces an index note on every new folder, registers it in `03-Index/Projects-Index.md`, and wires the bidirectional links so nothing ends up orphaned.

Concretely: if this is the first session in a new vault, **offer to run `/vault-coach`** before doing anything else. If the operator asks to add a folder or project, **run `/vault-coach`** rather than hand-creating the index note. The durable rule is: on first session or any setup task, the answer is `/vault-coach`.

The deeper human reference is `docs/MAINTAINING-YOUR-BRAIN.md` in the `2ndBrain-mogging` repo. (It ships with the repo, not necessarily inside an installed vault — so point the operator to `/vault-coach`, which carries the same guidance, and cite the repo doc as further reading.)

## Folder structure (5 folders)

```
Vault/
├── 01-Projects/            # active projects, each with matching index note
│   ├── <PROJECT>/
│   │   ├── <PROJECT>.md    # hub note (filename = folder name)
│   │   ├── conversations/  # agent captures about this project
│   │   ├── notes/          # everything written for it, incl. its own sources
│   │   └── assets/         # images, PDFs, media (no code)
│   ├── MISC/               # catch-all: conversations that belong to no single project
│   ├── VAULT/              # meta-conversations ABOUT the vault itself
│   │   └── conversations/reports/   # daily / audit / weekly / health reports
│   └── INCUBATOR/          # staging lane for pre-project ideas
├── 02-Library/             # cross-project reference only
│   ├── people/             # one note per person
│   ├── tools/              # one note per tool, app, service, model, library
│   ├── ideas/              # one idea per note
│   └── sources/            # outside sources not tied to one project
├── 03-Index/               # maps of content only (MOCs, master Index)
├── 04-Tasks/               # Obsidian Tasks plugin files
└── Claude-Memory/          # symlinked on install; auto-memory + aliases.yaml
```

The numbered folders run 01 to 04 with no gaps. `03-Index/` was `04-Index/` and `04-Tasks/` was `05-Tasks/` until 2026-11-05.

Folder rules:

- `01-Projects/VAULT/conversations/` is reserved for meta-work about the vault. Never put project content there.
- `01-Projects/<project>/conversations/` holds that project's captures. A conversation with no single project goes to the catch-all project (`01-Projects/MISC/` unless `aliases.yaml` names another). Conversations never go in `02-Library/`.
- `01-Projects/<project>/notes/` holds what's written for the project, including sources tied to it (`type: source`).
- `02-Library/sources/` — one note per outside source no single project owns. Filename `LIT-<slug>.md` or `SRC-<YYYY-MM-DD>-<slug>.md`. Source URL in frontmatter.
- `02-Library/ideas/` — atomic notes. One idea per file. Filename is kebab-case. `people/` and `tools/` work the same way (`type: concept`, tagged `person` or `tool`).
- `03-Index/` — maps of content only: MOCs, master Index, `Projects-Index.md`, `Map.canvas`. Never reports, audits, logs or dailies.
- `01-Projects/` — every project folder must have an index note whose filename matches the folder name exactly. Do not use a `-Index` suffix.
- `04-Tasks/` — `TASKS.md` is the hub. Per-area files are `TASKS-<AREA>.md`.
- `Claude-Memory/` — do not write here unless updating `MEMORY.md`.

### Retired folders — never write to these

The 2026-04-16 mogging collapsed an older layout into the folders above. On 2026-11-05 (Library v2) `02-Sources/` and `03-Concepts/` merged into `02-Library/`, `04-Index/` became `03-Index/`, and `05-Tasks/` became `04-Tasks/`. These directories are retired and must never be re-created or written to:

```
00-Inbox/      01-Fleeting/   02-Literature/   02-Sources/    03-Concepts/   03-Permanent/
04-Index/      04-MOC/        05-Tasks/        05-Templates/  06-Assets/     07-Projects/   08-Tasks/
```

A vault from before Library v2 may still have `02-Sources/`, `03-Concepts/`, `04-Index/` and `05-Tasks/`. Read them if you need to; never write there. `scripts/migrate-to-library.sh` in the `2ndBrain-mogging` repo moves the first two into `02-Library/sources/` and `02-Library/ideas/` and renames the other two to `03-Index/` and `04-Tasks/`. Anything outside the vault that names `05-Tasks/` by path has to be updated by hand.

## Four regimes

1. **Capture** — raw inbound content lands in `01-Projects/<PROJECT>/conversations/` (post-2026-05-08; the old top-level `01-Conversations/` was retired), the project's `notes/`, or `02-Library/sources/` for a source no single project owns. Minimal processing.
2. **Connect** — promote captures into `02-Library/ideas/` (or `people/`, `tools/`) as atomic notes. Link to other notes and to at least one MOC.
3. **Curate** — maintain `03-Index/` and project indexes in `01-Projects/`. Bidirectional links mandatory.
4. **Complete** — drive tasks through `04-Tasks/` and project indexes. Archive completed projects.

## Skills (13 total)

| Command | Purpose |
|---|---|
| `/save` | Capture conversation content — whole conversation, passage, dictated note, or ADR. Alias-classified, dry-run-previewed, commit-prefixed `[bot:save]`. |
| `/wiki` | Graph-aware workflow with four branches: `add` (ingest source), `audit` (read-only integrity), `heal` (safe reversible repairs), `find` (semantic search with wikilink citations). |
| `/challenge` | Adversarial vault agent. Argues against an idea using your own past notes and feedback. Read-only unless `--save`. |
| `/emerge` | Pattern-miner. Scans the last N days, clusters signals, names candidate concepts. Powers weekly review. |
| `/connect` | Bridges two notes by semantic overlap, structural pattern, and candidate intermediate notes. Read-only. |
| `/tether` | Audits and repairs `01-Projects/` tethering rules. Dry-run default, atomic per-project on `--execute`. |
| `/backfill` | Ingests historical Claude Code session JSONLs into the vault as structured conversation notes. |
| `/aliases` | Bootstraps and maintains `Claude-Memory/aliases.yaml` — the entity→project disambiguation registry. |
| `/autoresearch` | Three-round web research loop with source-freshness hardening and factual-only source notes in `02-Library/sources/`. |
| `/canvas` | Generates and maintains Obsidian Canvas files. Central `Map.canvas` uses a Fibonacci-spiral layout. |
| `/import-claude` | One-shot import of a Claude.ai or ChatGPT data-export zip into the vault. |
| `/import-notes` | One-shot import of exported notes from Apple Notes, OneNote, Notion, Evernote, or raw files. |
| `/vault-coach` | Onboarding + maintenance coach. Auto-loads after install and on new-folder/new-project. Drafts the missing index note (filename = folder name), registers it in `03-Index/Projects-Index.md`, enforces bidirectional tethering, runs orphan hygiene, asks one question at a time. Live counterpart to `docs/MAINTAINING-YOUR-BRAIN.md`. |

Each skill's full contract lives in `skills/<name>/SKILL.md`. Read it before calling the skill.

## Scheduled agents (4 total)

Four launchd agents run on a cron schedule. All are audit-only by default. Each agent's full contract lives in `agents/<name>.md`.

1. **morning** — 8:00 AM ET daily. Pulls today's Morgen events + overdue/today tasks, primes `Claude-Memory/hot.md`, writes `01-Projects/VAULT/conversations/reports/daily-YYYY-MM-DD.md`.
2. **nightly** — 10:00 PM ET daily. Runs `/wiki audit` on `02-Library` and `03-Index`. Writes `audit-YYYY-MM-DD.md` + updates `Claude-Memory/lint-counter.json`. No writes to idea or source notes.
3. **weekly** — 6:00 PM ET Fridays. Runs `/emerge --days 7 --audit` and writes `weekly-YYYY-WW.md` covering new concepts, killed ideas, contradictions, audit trend.
4. **health** — 9:00 PM ET Sundays. Four-gate integrity check: symlinks, Obsidian plugins, n8n sync freshness, Morgen↔Obsidian task parity. Writes `health-YYYY-MM-DD.md`.

## 3 non-negotiables

1. **Bidirectional links or no link.** Every `[[wikilink]]` needs a reverse link from the target.
2. **Filename = folder name for project indexes.** `01-Projects/foo/foo.md`, not `foo-Index.md`.
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
| Capture a URL | `02-Library/sources/` and the project's `notes/` (dedupe), this file § Skills (`/wiki add`) |
| Add a task | `04-Tasks/TASKS.md`, `04-Tasks/TASKS-<AREA>.md`, § 3 non-negotiables |
| Create a new project | `03-Index/Projects-Index.md`, `01-Projects/INCUBATOR/`, § Folder rules |
| Promote capture → idea | `02-Library/ideas/` existing siblings, target MOC in `03-Index/` |
| Update a MOC | `03-Index/Index.md`, the specific MOC file |
| Graph repair | `03-Index/Map.canvas`, `03-Index/Index.md`, § 3 non-negotiables |
| Sync with external tool | `SOUL.md`, `CRITICAL_FACTS.md`, relevant area task file |
| Identity / personal facts | `SOUL.md`, `CRITICAL_FACTS.md` |

## Hard rules

1. Always read a file before editing it.
2. Never save to the vault root except for the six files named above.
3. Filenames: kebab-case for ideas, people and tools, `LIT-` / `SRC-` prefix for sources, `TASKS-` prefix for task area files.
4. Frontmatter is required on every note.
5. Never use a `-Index` suffix on project index files.
6. Every project must appear in `03-Index/Projects-Index.md`.
7. Bidirectional linking is mandatory.
8. Never commit secrets, credentials, or `.env` files.
9. Link liberally. Wrap concept mentions in `[[wikilinks]]`.
10. Keep notes under 500 lines.
11. Never proactively create documentation unless asked.
12. Never suggest Todoist or a paid task manager. Task management lives in `04-Tasks/` via the Obsidian Tasks plugin.

## Bot-prefix commit rule

Automated edits MUST prefix commit messages with `[bot:<name>]`. Common prefixes: `[bot:save]`, `[bot:wiki-add]`, `[bot:wiki-heal]`, `[bot:tether]`, `[bot:nightly]`, `[bot:morning]`, `[bot:weekly]`, `[bot:health]`. Without the prefix, a single bot edit can trigger duplicate tasks, cascading graph repairs, or sync loops.

If you are running in an interactive session, do not use the bot prefix.

---

[[index]] · [[Projects-Index]]
