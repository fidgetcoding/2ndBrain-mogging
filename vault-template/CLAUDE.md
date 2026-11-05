---
title: "CLAUDE.md — 2ndBrain vault template"
type: index
owner: human
last_confirmed: 2026-04-20
---

# CLAUDE.md — 2ndBrain

This file tells Claude Code (and any agent running against this vault) how to read, write, link, and route inside it. It gets loaded on every session. Keep it honest — if the contract drifts from what the skills and agents actually do, the vault drifts with it.

## Vault purpose

Personal knowledge management system (PKM) — a Second Brain built on Zettelkasten principles. It holds conversations, sources (articles, videos, PDFs, exports), atomic concepts, maps of content, project indexes, and tasks. The goal is graph density: every note connects to at least one other note so retrieval works by association, not search.

## First session / onboarding (do this)

On a **fresh vault** (just installed, few or no notes yet) or any time the operator is **setting things up** — adding a folder, creating a new project, importing notes — invoke `/vault-coach`. That skill carries the full setup-and-maintenance playbook: it forces an index note on every new folder, registers it in `03-Index/Projects-Index.md`, and wires the bidirectional links so nothing ends up orphaned.

Concretely: if this is the first session in a new vault, **offer to run `/vault-coach`** before doing anything else. If the operator asks to add a folder or project, **run `/vault-coach`** rather than hand-creating the index note. The durable rule is: on first session or any setup task, the answer is `/vault-coach`.

The deeper human reference is `docs/MAINTAINING-YOUR-BRAIN.md` in the `2ndBrain-mogging` repo. (It ships with the repo, not necessarily inside an installed vault — so point the operator to `/vault-coach`, which carries the same guidance, and cite the repo doc as further reading.)

## Folder structure (5 folders)

```
Vault/
├── 01-Projects/            # active projects, each with an index note matching the folder name
│   ├── <PROJECT>/
│   │   ├── <PROJECT>.md    # the project's hub note (filename = folder name)
│   │   ├── !!conversations/  # /save captures: your text chats with AI assistants about it
│   │   ├── notes/          # everything written for the project, incl. its own sources
│   │   └── assets/         # images, PDFs, media (no code)
│   ├── MISC/               # catch-all: conversations that belong to no single project
│   ├── VAULT/              # work ABOUT the vault itself
│   │   ├── log.md          # the append-only vault log
│   │   └── REPORTS/        # daily / audit / weekly / health reports
│   └── INCUBATOR/          # staging lane for pre-project ideas
├── 02-Library/             # cross-project reference only: things that belong to no single project
│   ├── people/             # one note per person
│   ├── tools/              # one note per tool, app, service, model, library
│   ├── ideas/              # one idea per note
│   └── sources/            # outside sources not tied to one project (SRC-*.md, LIT-*.md)
├── 03-Index/               # maps of content only: MOCs, Projects-Index, Map.canvas
├── 04-Tasks/               # Obsidian Tasks plugin files — TASKS.md hub + per-area files
└── Claude-Memory/          # symlinked on install; holds MEMORY.md + aliases.yaml
```

The numbered folders run 01 to 04 with no gaps. `03-Index/` was `04-Index/` and `04-Tasks/` was `05-Tasks/` until 2026-11-05.

### Folder rules

- **01-Projects/<project>/!!conversations/** — raw conversation captures and session transcripts for that project. A conversation that belongs to no single project goes to the catch-all project's `!!conversations/` (`01-Projects/MISC/` unless `aliases.yaml` names another). Conversations never go in `02-Library/`. `VAULT/` is reserved for meta-work about the vault itself; never put project content there.
- **01-Projects/<project>/notes/** — everything written for the project, including sources tied to it (they keep `type: source`).
- **02-Library/** — cross-project reference only. `sources/` holds one note per outside source that no single project owns: filename `LIT-<slug>.md` or `SRC-<YYYY-MM-DD>-<slug>.md`, source URL in frontmatter. `ideas/` holds atomic notes, one idea per file, kebab-case filename. `people/` and `tools/` hold one note per person or tool (`type: concept`, tagged `person` or `tool`).
- **03-Index/** — maps of content only: MOCs, the master Index, `Projects-Index.md`, and the graph `Map.canvas`. Link lists, never reports, audits, logs or dailies. Every new idea should be linked from at least one index.
- **01-Projects/** — every project folder has an index note whose filename matches the folder name exactly (e.g. `01-Projects/foo/foo.md`, never `foo-Index.md`). Sub-projects follow the same rule.
- **04-Tasks/** — `TASKS.md` is the hub that aggregates via Obsidian Tasks queries. Per-area files are `TASKS-<AREA>.md` and correspond 1:1 with a project index.
- **Claude-Memory/** — symlink target set up by `install.sh`. Do not write here unless updating the auto-memory file.

### Retired folders — never write to these

The 2026-04-16 mogging collapsed an older layout into the folders above. On 2026-11-05 (Library v2) `02-Sources/` and `03-Concepts/` merged into `02-Library/`, `04-Index/` became `03-Index/`, and `05-Tasks/` became `04-Tasks/`. The same day every project's `conversations/` became `!!conversations/` (it sorts first in Finder), and the VAULT reports moved out of it to `01-Projects/VAULT/REPORTS/`. These directories are retired and must never be re-created or written to:

```
00-Inbox/      01-Fleeting/   02-Literature/   02-Sources/    03-Concepts/   03-Permanent/
04-Index/      04-MOC/        05-Tasks/        05-Templates/  06-Assets/     07-Projects/   08-Tasks/
```

A vault from before Library v2 may still have `02-Sources/`, `03-Concepts/`, `04-Index/` and `05-Tasks/`. Skills may read them until they're moved, and never write there. `scripts/migrate-to-library.sh` in the `2ndBrain-mogging` repo moves `02-Sources/*` to `02-Library/sources/` and `03-Concepts/*` to `02-Library/ideas/`, renames `04-Index/` to `03-Index/` and `05-Tasks/` to `04-Tasks/`, and renames every `conversations/` under `01-Projects/` to `!!conversations/` (with `git mv` in a git vault, so a tasks submodule follows). Wikilinks are by note name, so the move breaks no links. Anything outside the vault that names `05-Tasks/` by path, like a sync daemon or a launchd plist, has to be updated by hand.

If a skill or config still points at any of them, it's stale — treat it as a bug, not a source of truth.

## Four regimes

The vault operates under four regimes that describe how content moves:

1. **Capture** — raw inbound thoughts, URLs, and conversations land in `01-Projects/<PROJECT>/!!conversations/` (post-2026-05-08; the old top-level `01-Conversations/` was retired), the project's `notes/`, or `02-Library/sources/` for a source no single project owns. Minimal processing.
2. **Connect** — promote captures into `02-Library/ideas/` (or `people/`, `tools/`) as atomic notes. Link to other notes and to at least one MOC in `03-Index/`.
3. **Curate** — maintain `03-Index/` and project indexes in `01-Projects/`. Keep bidirectional links tight. Orphaned notes are the enemy.
4. **Complete** — drive tasks through `04-Tasks/` and project indexes. Archive completed projects rather than deleting them.

## Skills (13 total)

Slash commands shipped with the mogging pack. Descriptions match each skill's own `SKILL.md`; read the skill file before changing behavior.

1. `/save` — capture conversation content into the vault. Four entry branches (whole conversation / specific passage / dictated note / ADR) plus `--backfill`. Alias-driven classification, dry-run preview, security-scrubbed, commits prefixed `[bot:save]`.
2. `/wiki` — the graph-aware workflow. One skill, four branches: **add** (ingest a URL / file / paste / YouTube / PDF into 02-Library/sources (or a project's notes/) → 02-Library/ideas → 03-Index), **audit** (read-only integrity scan), **heal** (safe reversible repairs on a dry-run branch), **find** (semantic search with wikilink-cited synthesis). Never touches `owner: human` notes, `01-Projects/*/index`, or `04-Tasks/`.
3. `/challenge` — adversarial vault agent. Takes an idea and argues against it using your own past notes, feedback files, and Claude-Memory — surfacing contradictions, constraints, cost patterns, stakeholder conflicts, broken dependencies. Read-only by default; writes only with `--save`.
4. `/emerge` — pattern-miner. Scans files modified in the last N days, extracts signals, clusters them, and names each cluster as a candidate concept. Powers the weekly review.
5. `/connect` — bridge two notes. Finds semantic overlap, shared structural patterns, and candidate intermediate bridge notes. Read-only. Outputs 3–5 concrete connections typed as structural analogy, transfer opportunity, or collision idea.
6. `/tether` — audits and repairs `01-Projects/`: filename-equals-folder, bidirectional links to Projects-Index and MOCs, org-hub tethering, sub-project back-links, unlinked-mention detection. Dry-run by default; atomic per-project transactions on `--execute`.
7. `/backfill` — scrapes historical Claude Code session JSONLs into the vault as structured conversation notes. Handles inventory, cost estimation, secret scrubbing, chunked summarization, dedup, and resumable batch runs. Routes to `01-Projects/<project>/!!conversations/YYYY-MM-DD-<slug>.md` using the same signals as `/save`.
8. `/aliases` — bootstraps and maintains `Claude-Memory/aliases.yaml`, the canonical entity→project disambiguation file used by `/save`, `/backfill`, `/tether`, and `/wiki`. Never overwrites the canonical file without review; emits to `aliases-pending.md` for merge.
9. `/autoresearch` — three-round web research loop. Decomposes a topic, gathers sources, gap-fills contradictions, and emits vault-ready source + idea notes (`02-Library/sources/`, `02-Library/ideas/`) with confidence labels. Factual-only for source notes.
10. `/canvas` — generates and maintains Obsidian Canvas files from vault queries. Central `03-Index/Map.canvas` uses a Fibonacci-spiral layout. Deterministic node IDs, JSON Canvas 1.0 validation, never mutates source notes.
11. `/import-claude` — one-shot import of a Claude.ai or ChatGPT data-export zip. Unzip → inspect → bucket conversations → write full-fidelity captures to `01-Projects/<PROJECT>/!!conversations/` (post-2026-05-08; the old top-level `01-Conversations/` was retired; cross-cutting chats go to the catch-all project), and linked stubs to `02-Library/ideas/`. Alias-classified, dry-run-previewed, append-only.
12. `/import-notes` — one-shot import of an existing notes pile from Apple Notes / OneNote / Notion / Evernote / raw files (docx/pptx/xlsx/html/rtf/md/txt). Pandoc + xlsx2csv conversion, per-file validation, folder classification against the layout above, dry-run-previewed.
13. `/vault-coach` — onboarding + maintenance coach. Auto-loads right after install and whenever you add a folder or project. Drafts the missing index note (filename = folder name), registers it in `03-Index/Projects-Index.md`, enforces bidirectional tethering, runs orphan hygiene, and asks one question at a time. The live counterpart to `docs/MAINTAINING-YOUR-BRAIN.md`.

## Scheduled agents (4 total)

Four launchd agents run on a cron schedule and keep the vault honest. All are audit-only by default — any write-capable scheduled work requires explicit opt-in via the agent's frontmatter. Each agent's full contract lives in `agents/<name>.md`.

1. **morning** — 8:00 AM ET daily. Pulls today's Morgen events, surfaces overdue/today tasks, primes `Claude-Memory/hot.md` with the day's context. Writes `01-Projects/VAULT/REPORTS/daily-YYYY-MM-DD.md`.
2. **nightly** — 10:00 PM ET daily. Runs `/wiki audit` scoped to `02-Library` and `03-Index`. Writes `01-Projects/VAULT/REPORTS/audit-YYYY-MM-DD.md` and updates `Claude-Memory/lint-counter.json`. Never writes to idea or source notes.
3. **weekly** — 6:00 PM ET Fridays. Runs `/emerge --days 7 --audit`, produces a week-in-review report covering new concepts, killed ideas, unresolved contradictions, and the rolling 7-day audit trend. Writes `01-Projects/VAULT/REPORTS/weekly-YYYY-WW.md`.
4. **health** — 9:00 PM ET Sundays. Four-gate vault integrity check: symlink resolution, Obsidian plugin loads, n8n sync freshness, Morgen↔Obsidian task-count parity. Writes `01-Projects/VAULT/REPORTS/health-YYYY-MM-DD.md`.

## 3 non-negotiables

These three rules override everything else. If a command seems to violate them, stop and ask.

1. **Bidirectional links or no link.** Every `[[wikilink]]` you write needs a sensible reverse link from the target. One-way links create graph islands.
2. **Filename = folder name for project indexes.** Never use the `-Index` suffix. `01-Projects/foo/foo.md`, not `01-Projects/foo/foo-Index.md`. The suffix breaks `[[foo]]` resolution from anywhere in the vault.
3. **Bot-prefix commits for automated edits.** Any commit made by a scheduled agent or skill must prefix the message with `[bot:<name>]` (e.g. `[bot:save]`, `[bot:wiki-heal]`, `[bot:nightly]`). Human commits must not use this prefix — the downstream sync filters depend on it.

## Root-level notes

Three files live at the vault root and are always safe to read. Everything else belongs inside one of the 5 folders.

- `CLAUDE.md` — this file.
- `AGENTS.md` — the same contract, framed for non-Claude agents (Codex, Cursor, custom CLIs).
- `SOUL.md` — operator identity, long-horizon goals, and a **Critical facts** section (timezone, defaults, tooling, preferences). Read every session.

The master index is `03-Index/Index.md`. The append-only vault log is `01-Projects/VAULT/log.md`: agents may append dated entries there and must not rewrite history.

## Routing table

For any incoming task, read these files first:

| Task type | Read these first |
|---|---|
| Capture a URL | `02-Library/sources/` and the project's `notes/` for dedupe, `CLAUDE.md` § Skills (`/wiki add`) |
| Add a task | `04-Tasks/TASKS.md`, `04-Tasks/TASKS-<AREA>.md`, § 3 non-negotiables |
| Create a new project | `03-Index/Projects-Index.md`, `01-Projects/INCUBATOR/`, § Folder rules |
| Promote capture → idea | `02-Library/ideas/` existing siblings, target MOC in `03-Index/` |
| Update a MOC | `03-Index/Index.md`, the specific MOC file, § Connect regime |
| Graph repair | `03-Index/Map.canvas`, `03-Index/Index.md`, § 3 non-negotiables |
| Sync with external tool | `SOUL.md` (Critical facts), relevant area task file |
| Identity / personal facts | `SOUL.md` |

## Hard rules

1. Always read a file before editing it.
2. Never save to the vault root except for the three files named above (`CLAUDE.md`, `AGENTS.md`, `SOUL.md`).
3. Filenames: kebab-case for ideas, people and tools, `LIT-` / `SRC-` prefix for sources, `TASKS-` prefix for task area files.
4. Frontmatter is required on every note — at minimum `title`, `type`, `tags`. Add `owner`, `source`, `related`, `last_confirmed` as the note type requires.
5. Never use a `-Index` suffix on a project index file. Filename must match the folder name.
6. Every project must appear in `03-Index/Projects-Index.md` under the correct section (Active / Incubating / Archived).
7. Bidirectional linking is mandatory. Every link needs a reverse path.
8. Never commit secrets, credentials, or `.env` files. Scan frontmatter and body before any commit.
9. Link liberally. Wrap concept mentions in `[[wikilinks]]` — unlinked mentions are free edges left on the table.
10. Keep notes under 500 lines. Split long notes into a MOC plus sub-concepts.
11. Never proactively create documentation (READMEs, summaries, reports) unless the operator asks.
12. Never suggest Todoist or any paid task manager. Task management lives in `04-Tasks/` via the Obsidian Tasks plugin.

## Bot-prefix commit rule

Automated edits made by scheduled agents or skills MUST prefix commit messages with `[bot:<name>]`. Common prefixes:

- `[bot:save]` — `/save` output
- `[bot:wiki-add]` / `[bot:wiki-heal]` / `[bot:wiki-fix]` — `/wiki` writes
- `[bot:tether]` — `/tether --execute` repairs
- `[bot:nightly]` / `[bot:morning]` / `[bot:weekly]` / `[bot:health]` — scheduled-agent reports

Without the prefix, a single bot edit can trigger duplicate tasks, cascading graph repairs, or sync loops. If you're Claude running in an interactive session with a human, do NOT use the bot prefix — the human is the commit author.

---

[[Index]] · [[Projects-Index]]
