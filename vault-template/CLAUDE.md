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

## Folder structure (7 folders)

```
Vault/
├── 01-Conversations/       # conversation captures, session logs, exports
│   └── VAULT/              # meta-conversations ABOUT the vault itself
│       ├── architecture-sessions/
│       ├── graph-repairs/
│       ├── mogging-pack-dev/
│       └── reports/        # daily / audit / weekly / health reports
├── 02-Sources/             # one note per external source (LIT-*.md, SRC-*.md)
├── 03-Concepts/            # atomic permanent notes — one idea per file
├── 04-Index/               # Maps of Content (MOCs), Projects-Index, Map.canvas
├── 05-Projects/            # active projects, each with an index note matching the folder name
│   └── INCUBATOR/          # staging lane for pre-project ideas
├── 06-Tasks/               # Obsidian Tasks plugin files — TASKS.md hub + per-area files
└── Claude-Memory/          # symlinked on install; holds MEMORY.md + aliases.yaml
```

### Folder rules

- **01-Conversations/** — raw conversation captures and session transcripts. `VAULT/` is reserved for meta-work about the vault itself; never put project content there. Project captures go in `01-Conversations/<project-name>/`.
- **02-Sources/** — one note per external source. Filename `LIT-<slug>.md` or `SRC-<YYYY-MM-DD>-<slug>.md`. Always include the source URL in frontmatter.
- **03-Concepts/** — atomic notes. One idea per file. Filename is kebab-case.
- **04-Index/** — MOCs, the master Index, `Projects-Index.md`, and the graph `Map.canvas`. Every new concept should be linked from at least one index.
- **05-Projects/** — every project folder has an index note whose filename matches the folder name exactly (e.g. `05-Projects/foo/foo.md`, never `foo-Index.md`). Sub-projects follow the same rule.
- **06-Tasks/** — `TASKS.md` is the hub that aggregates via Obsidian Tasks queries. Per-area files are `TASKS-<AREA>.md` and correspond 1:1 with a project index.
- **Claude-Memory/** — symlink target set up by `install.sh`. Do not write here unless updating the auto-memory file.

### Retired folders — never write to these

The 2026-04-16 mogging collapsed an older layout into the 7 folders above. These directories are gone and must never be re-created or referenced:

```
00-Inbox/      01-Fleeting/   02-Literature/   03-Permanent/
04-MOC/        05-Templates/  06-Assets/       07-Projects/   08-Tasks/
```

If a skill or config still points at any of them, it's stale — treat it as a bug, not a source of truth.

## Four regimes

The vault operates under four regimes that describe how content moves:

1. **Capture** — raw inbound thoughts, URLs, and conversations land in `01-Conversations/` or `02-Sources/`. Minimal processing.
2. **Connect** — promote captures into `03-Concepts/` as atomic notes. Link to other concepts and to at least one MOC in `04-Index/`.
3. **Curate** — maintain `04-Index/` and project indexes in `05-Projects/`. Keep bidirectional links tight. Orphaned notes are the enemy.
4. **Complete** — drive tasks through `06-Tasks/` and project indexes. Archive completed projects rather than deleting them.

## Skills (12 total)

Slash commands shipped with the mogging pack. Descriptions match each skill's own `SKILL.md`; read the skill file before changing behavior.

1. `/save` — capture conversation content into the vault. Four entry branches (whole conversation / specific passage / dictated note / ADR) plus `--backfill`. Alias-driven classification, dry-run preview, security-scrubbed, commits prefixed `[bot:save]`.
2. `/wiki` — the graph-aware workflow. One skill, four branches: **add** (ingest a URL / file / paste / YouTube / PDF into 02-Sources → 03-Concepts → 04-Index), **audit** (read-only integrity scan), **heal** (safe reversible repairs on a dry-run branch), **find** (semantic search with wikilink-cited synthesis). Never touches `owner: human` notes, `05-Projects/*/index`, or `06-Tasks/`.
3. `/challenge` — adversarial vault agent. Takes an idea and argues against it using your own past notes, feedback files, and Claude-Memory — surfacing contradictions, constraints, cost patterns, stakeholder conflicts, broken dependencies. Read-only by default; writes only with `--save`.
4. `/emerge` — pattern-miner. Scans files modified in the last N days, extracts signals, clusters them, and names each cluster as a candidate concept. Powers the weekly review.
5. `/connect` — bridge two notes. Finds semantic overlap, shared structural patterns, and candidate intermediate bridge notes. Read-only. Outputs 3–5 concrete connections typed as structural analogy, transfer opportunity, or collision idea.
6. `/tether` — audits and repairs `05-Projects/`: filename-equals-folder, bidirectional links to Projects-Index and MOCs, org-hub tethering, sub-project back-links, unlinked-mention detection. Dry-run by default; atomic per-project transactions on `--execute`.
7. `/backfill` — scrapes historical Claude Code session JSONLs into the vault as structured conversation notes. Handles inventory, cost estimation, secret scrubbing, chunked summarization, dedup, and resumable batch runs. Routes to `01-Conversations/<project>/YYYY-MM-DD-<slug>.md` using the same signals as `/save`.
8. `/aliases` — bootstraps and maintains `Claude-Memory/aliases.yaml`, the canonical entity→project disambiguation file used by `/save`, `/backfill`, `/tether`, and `/wiki`. Never overwrites the canonical file without review; emits to `aliases-pending.md` for merge.
9. `/autoresearch` — three-round web research loop. Decomposes a topic, gathers sources, gap-fills contradictions, and emits vault-ready literature + concept notes with confidence labels. Factual-only for literature notes.
10. `/canvas` — generates and maintains Obsidian Canvas files from vault queries. Central `04-Index/Map.canvas` uses a Fibonacci-spiral layout. Deterministic node IDs, JSON Canvas 1.0 validation, never mutates source notes.
11. `/import-claude` — one-shot import of a Claude.ai or ChatGPT data-export zip. Unzip → inspect → bucket conversations → write full-fidelity captures to `01-Conversations/`, factual `LIT-*` mirrors to `02-Sources/`, and linked stubs to `03-Concepts/`. Alias-classified, dry-run-previewed, append-only.
12. `/import-notes` — one-shot import of an existing notes pile from Apple Notes / OneNote / Notion / Evernote / raw files (docx/pptx/xlsx/html/rtf/md/txt). Pandoc + xlsx2csv conversion, per-file validation, seven-folder classification, dry-run-previewed.

## Scheduled agents (4 total)

Four launchd agents run on a cron schedule and keep the vault honest. All are audit-only by default — any write-capable scheduled work requires explicit opt-in via the agent's frontmatter. Each agent's full contract lives in `agents/<name>.md`.

1. **morning** — 8:00 AM ET daily. Pulls today's Morgen events, surfaces overdue/today tasks, primes `Claude-Memory/hot.md` with the day's context. Writes `01-Conversations/VAULT/reports/daily-YYYY-MM-DD.md`.
2. **nightly** — 10:00 PM ET daily. Runs `/wiki audit` scoped to `02-Sources`, `03-Concepts`, and `04-Index`. Writes `01-Conversations/VAULT/reports/audit-YYYY-MM-DD.md` and updates `Claude-Memory/lint-counter.json`. Never writes to concept or source notes.
3. **weekly** — 6:00 PM ET Fridays. Runs `/emerge --days 7 --audit`, produces a week-in-review report covering new concepts, killed ideas, unresolved contradictions, and the rolling 7-day audit trend. Writes `01-Conversations/VAULT/reports/weekly-YYYY-WW.md`.
4. **health** — 9:00 PM ET Sundays. Four-gate vault integrity check: symlink resolution, Obsidian plugin loads, n8n sync freshness, Morgen↔Obsidian task-count parity. Writes `01-Conversations/VAULT/reports/health-YYYY-MM-DD.md`.

## 3 non-negotiables

These three rules override everything else. If a command seems to violate them, stop and ask.

1. **Bidirectional links or no link.** Every `[[wikilink]]` you write needs a sensible reverse link from the target. One-way links create graph islands.
2. **Filename = folder name for project indexes.** Never use the `-Index` suffix. `05-Projects/foo/foo.md`, not `05-Projects/foo/foo-Index.md`. The suffix breaks `[[foo]]` resolution from anywhere in the vault.
3. **Bot-prefix commits for automated edits.** Any commit made by a scheduled agent or skill must prefix the message with `[bot:<name>]` (e.g. `[bot:save]`, `[bot:wiki-heal]`, `[bot:nightly]`). Human commits must not use this prefix — the downstream sync filters depend on it.

## Root-level notes

Six files live at the vault root and are always safe to read. Everything else belongs inside one of the 7 folders.

- `CLAUDE.md` — this file.
- `AGENTS.md` — the same contract, framed for non-Claude agents (Codex, Cursor, custom CLIs).
- `SOUL.md` — operator identity + long-horizon goals. Read every session when identity context matters.
- `CRITICAL_FACTS.md` — hard facts the operator wants every agent to know (timezone, defaults, tooling, preferences). Read every session.
- `index.md` — top-level entry point into the vault; thin pointer to `04-Index/Index.md` and `04-Index/Projects-Index.md`.
- `log.md` — append-only lightweight session log. Agents may append dated entries; they must not rewrite history.

## Routing table

For any incoming task, read these files first:

| Task type | Read these first |
|---|---|
| Capture a URL | `02-Sources/` existing notes for dedupe, `CLAUDE.md` § Skills (`/wiki add`) |
| Add a task | `06-Tasks/TASKS.md`, `06-Tasks/TASKS-<AREA>.md`, § 3 non-negotiables |
| Create a new project | `04-Index/Projects-Index.md`, `05-Projects/INCUBATOR/`, § Folder rules |
| Promote capture → concept | `03-Concepts/` existing siblings, target MOC in `04-Index/` |
| Update a MOC | `04-Index/Index.md`, the specific MOC file, § Connect regime |
| Graph repair | `04-Index/Map.canvas`, `04-Index/Index.md`, § 3 non-negotiables |
| Sync with external tool | `SOUL.md`, `CRITICAL_FACTS.md`, relevant area task file |
| Identity / personal facts | `SOUL.md`, `CRITICAL_FACTS.md` |

## Hard rules

1. Always read a file before editing it.
2. Never save to the vault root except for the six files named above (`CLAUDE.md`, `AGENTS.md`, `SOUL.md`, `CRITICAL_FACTS.md`, `index.md`, `log.md`).
3. Filenames: kebab-case for concepts, `LIT-` / `SRC-` prefix for sources, `TASKS-` prefix for task area files.
4. Frontmatter is required on every note — at minimum `title`, `type`, `tags`. Add `owner`, `source`, `related`, `last_confirmed` as the note type requires.
5. Never use a `-Index` suffix on a project index file. Filename must match the folder name.
6. Every project must appear in `04-Index/Projects-Index.md` under the correct section (Active / Incubating / Archived).
7. Bidirectional linking is mandatory. Every link needs a reverse path.
8. Never commit secrets, credentials, or `.env` files. Scan frontmatter and body before any commit.
9. Link liberally. Wrap concept mentions in `[[wikilinks]]` — unlinked mentions are free edges left on the table.
10. Keep notes under 500 lines. Split long notes into a MOC plus sub-concepts.
11. Never proactively create documentation (READMEs, summaries, reports) unless the operator asks.
12. Never suggest Todoist or any paid task manager. Task management lives in `06-Tasks/` via the Obsidian Tasks plugin.

## Bot-prefix commit rule

Automated edits made by scheduled agents or skills MUST prefix commit messages with `[bot:<name>]`. Common prefixes:

- `[bot:save]` — `/save` output
- `[bot:wiki-add]` / `[bot:wiki-heal]` / `[bot:wiki-fix]` — `/wiki` writes
- `[bot:tether]` — `/tether --execute` repairs
- `[bot:nightly]` / `[bot:morning]` / `[bot:weekly]` / `[bot:health]` — scheduled-agent reports

Without the prefix, a single bot edit can trigger duplicate tasks, cascading graph repairs, or sync loops. If you're Claude running in an interactive session with a human, do NOT use the bot prefix — the human is the commit author.

---

[[index]] · [[Projects-Index]]
