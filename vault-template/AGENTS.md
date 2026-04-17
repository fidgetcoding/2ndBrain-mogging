# AGENTS.md — 2ndBrain

This file mirrors `CLAUDE.md` for non-Claude agents (Codex, Cursor agents, custom CLI agents, and any other coding or automation tool operating inside this vault). The content is the same; the framing is adapted for tools that don't share Claude's default conventions.

If you are Claude Code, read `CLAUDE.md` instead — this file will not be loaded automatically for you.

## Vault Purpose

This vault is a personal knowledge management system (PKM) — a "Second Brain" built on Zettelkasten principles for capturing, connecting, and retrieving knowledge. Notes live in an Obsidian-compatible folder structure. The file format is plain Markdown with YAML frontmatter and `[[wikilinks]]`. The goal is graph density: every note should connect to at least one other note.

## Folder Structure (7 folders)

```
Vault/
├── 01-Conversations/    # agent conversations, session logs, exports
│   └── VAULT/           # meta-conversations ABOUT the vault itself
├── 02-Sources/          # literature notes from external content
├── 03-Concepts/         # atomic permanent notes
├── 04-Index/            # Maps of Content (MOCs) and master Index
├── 05-Projects/         # active projects, each with matching index note
│   └── INCUBATOR/       # staging lane for pre-project ideas
├── 06-Tasks/            # Obsidian Tasks plugin files
└── Claude-Memory/       # symlinked on install; auto-memory
```

Folder rules:

- `01-Conversations/VAULT/` is reserved for meta-work about the vault. Never put project content there.
- `02-Sources/`: one note per source, filename `LIT-brief-description.md`, source URL in frontmatter.
- `03-Concepts/`: atomic notes. One idea per file. Filename is kebab-case.
- `04-Index/`: MOCs and the master Index. Every new concept should be linked from at least one index.
- `05-Projects/`: every project folder must have an index note whose filename matches the folder name exactly. Do not use a `-Index` suffix.
- `06-Tasks/`: `TASKS.md` is the hub. Per-area files are `TASKS-{AREA}.md`.
- `Claude-Memory/`: do not write here unless updating `MEMORY.md`.

## Four Regimes

The vault operates under four regimes:

1. **Capture** — raw inbound content lands in `01-Conversations/` or `02-Sources/`. Minimal processing.
2. **Connect** — promote captures into `03-Concepts/` as atomic notes. Link to concepts and to at least one MOC.
3. **Curate** — maintain `04-Index/` and project indexes in `05-Projects/`. Bidirectional links are mandatory.
4. **Complete** — drive tasks through `06-Tasks/` and project indexes. Archive completed projects.

## 10 Commands Summary

| Command | Purpose |
|---------|---------|
| `/capture <text-or-url>` | One-shot capture, routes to 01 or 02. |
| `/promote <note>` | Promote a capture into an atomic concept in 03. |
| `/link <a> <b>` | Create a bidirectional wikilink. |
| `/moc <topic>` | Create or update a Map of Content. |
| `/project <name>` | Scaffold a new project folder + index + MOC entry. |
| `/task <area> <text>` | Add a task to `TASKS-{AREA}.md`. |
| `/wiki` | Rebuild `04-Index/Index.md`. |
| `/aliases --bootstrap` | Seed `aliases.yaml` at repo root. |
| `/graph-repair` | Scan for orphans, `-Index` suffixes, broken wikilinks. |
| `/archive <project>` | Move a completed project to archived section. |

## 4 Scheduled Agents

Four agents run on a cron/hook schedule:

1. **Graph Repair Agent** — daily; structural violation scan.
2. **Inbox Processor** — every 6 hours; promotes mature captures.
3. **Task Syncer** — every 15 minutes; reconciles Obsidian Tasks with external tools.
4. **Weekly Curator** — Sunday nights; re-scores MOC candidates and flags stale notes.

## 3 Non-Negotiables

These three rules override every other consideration. If a command seems to violate them, stop.

1. **Bidirectional links or no link.** Every `[[wikilink]]` needs a reverse link from the target.
2. **Filename = folder name for project indexes.** `05-Projects/FOO/FOO.md`, not `FOO-Index.md`.
3. **Bot-prefix commits for automated edits.** Scheduled-agent commits must start with `[bot:<name>]`. Humans must not use this prefix.

## Routing Table

For any incoming task, read these files first before acting:

| Task Type | Read These Files First |
|-----------|------------------------|
| Capture a URL | `02-Sources/README.md`, WebFetch workflow in this file |
| Add a task | `06-Tasks/TASKS.md`, `06-Tasks/TASKS-{AREA}.md`, § 3 Non-Negotiables |
| Create a new project | `04-Index/Projects-Index.md`, `05-Projects/INCUBATOR/INCUBATOR.md`, § Folder rules |
| Promote fleeting → permanent | `03-Concepts/` target MOC in `04-Index/` |
| Update a MOC | `04-Index/Index.md`, the specific MOC file |
| Graph repair | `04-Index/Map.canvas`, `04-Index/Index.md`, § 3 Non-Negotiables |
| Sync with external tool | `SOUL.md`, `CRITICAL_FACTS.md`, relevant area task file |
| Identity / personal facts | `SOUL.md`, `CRITICAL_FACTS.md` |

## Hard Rules (12)

1. Always read a file before editing it.
2. Never save to the vault root except for the files named in this document.
3. Filenames: kebab-case for concepts, `LIT-` prefix for sources, `TASKS-` prefix for task area files.
4. Frontmatter is required on every note.
5. Never use `-Index` suffix on project index files.
6. Every project must appear in `04-Index/Projects-Index.md`.
7. Bidirectional linking is mandatory.
8. Never commit secrets, credentials, or `.env` files.
9. Link liberally. Wrap concept mentions in `[[wikilinks]]`.
10. Keep notes under 500 lines.
11. Never proactively create documentation (READMEs, summaries) unless asked.
12. Never suggest Todoist or a paid task manager. Task management lives in `06-Tasks/` via the Obsidian Tasks plugin.

## Bot-Prefix Commit Rule

Automated edits made by scheduled agents MUST prefix commit messages with `[bot:<agent-name>]`. Downstream sync agents use this prefix to avoid processing bot changes as human edits. Without the prefix, a single bot edit can trigger duplicate tasks, cascading graph repairs, or sync loops.

Examples:

- Human commit: `Add <ORG-C> to Projects-Index`
- Bot commit: `[bot:graph-repair] Normalize <ORG-C>-Index → <ORG-C>`
- Bot commit: `[bot:task-syncer] Reconcile TASKS-<ORG-E>WORK.md with external`

If you are running as a scheduled agent, use the bot prefix. If you are running in an interactive session, do not.

---

[[Home-Index]] · [[Projects-Index]] · [[Index]]
