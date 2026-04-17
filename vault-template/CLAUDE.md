# CLAUDE.md — 2ndBrain

This file provides guidance to Claude Code when working with this Obsidian vault. It is loaded on every session and defines the canonical rules for reading, writing, linking, and routing inside the vault.

## Vault Purpose

This vault is your personal knowledge management system (PKM) — a "Second Brain" built on Zettelkasten principles for capt<person-i>ng, connecting, and retrieving knowledge. It holds conversations, sources (articles, videos, PDFs), concepts (atomic notes), indexes (maps of content), projects, and tasks. The goal is graph density: every note should connect to at least one other note, so retrieval works by association rather than search.

## Folder Structure (7 folders)

```
Vault/
├── 01-Conversations/    # Claude / agent conversations, session logs, exports
│   └── VAULT/           # meta-conversations ABOUT the vault itself
│       ├── architecture-sessions/
│       ├── graph-repairs/
│       ├── mogging-pack-dev/
│       └── reports/
├── 02-Sources/          # Literature notes from external content (URLs, books, videos)
├── 03-Concepts/         # Permanent atomic notes — one concept per note, densely linked
├── 04-Index/            # Maps of Content (MOCs) and the master Index
├── 05-Projects/         # Active projects, each with an index note matching the folder name
│   └── INCUBATOR/       # staging lane for ideas not yet promoted to full projects
├── 06-Tasks/            # Obsidian Tasks plugin files — TASKS.md hub + per-area task files
└── Claude-Memory/       # Symlinked on install; holds Claude's auto-memory MEMORY.md
```

### Folder rules

- **01-Conversations/**: Raw conversation logs, exports, session transcripts. `VAULT/` sub-folder is reserved for meta-work about the vault itself — never put project content there.
- **02-Sources/**: One note per external source. Filename `LIT-brief-description.md`. Always include the source URL in frontmatter.
- **03-Concepts/**: Atomic notes. One idea per file. Filename is the concept in kebab-case. Link liberally to other concepts and to indexes in `04-Index/`.
- **04-Index/**: MOCs, the master Index, and the graph Map canvas. Every new concept should be linked from at least one index.
- **05-Projects/**: Every project folder must have an index note **matching the folder name exactly** (e.g., `05-Projects/FOO/FOO.md`, never `FOO-Index.md`). Sub-projects follow the same rule.
- **06-Tasks/**: `TASKS.md` is the hub that aggregates via Dataview queries. Per-area files are `TASKS-{AREA}.md` and correspond 1:1 with a project index.
- **Claude-Memory/**: Symlink target created on install. Do not write directly into it unless updating the auto-memory file.

## Four Regimes

The vault operates under four regimes that dictate how you work with content:

1. **Capture** — raw inbound thoughts, URLs, and conversation snippets land in `01-Conversations/` or `02-Sources/`. Do not over-process at capture time.
2. **Connect** — promote capture into `03-Concepts/` as atomic permanent notes. Link to other concepts and to at least one MOC in `04-Index/`.
3. **Curate** — maintain `04-Index/` and project indexes in `05-Projects/`. Keep bidirectional links tight. Orphaned notes are the enemy.
4. **Complete** — drive tasks through `06-Tasks/` and project indexes. Close out finished projects into an archive section rather than deleting them.

## 10 Commands Summary

Slash commands available inside this vault:

1. `/capture <text-or-url>` — one-shot capture; routes to 01 or 02 based on content type.
2. `/promote <note>` — promote a capture into an atomic concept in 03.
3. `/link <noteA> <noteB>` — create a bidirectional wikilink with brief rationale.
4. `/moc <topic>` — create or update a Map of Content in 04-Index for `topic`.
5. `/project <name>` — scaffold a new project folder in 05 with the matching index note and MOC entry.
6. `/task <area> <text>` — add a task to `TASKS-{AREA}.md` with auto-scheduled frontmatter.
7. `/wiki` — rebuild `04-Index/Index.md` by scanning the vault for MOCs and key indexes.
8. `/aliases --bootstrap` — seed `aliases.yaml` at the repo root (people, concepts, orgs, projects).
9. `/graph-repair` — scan for orphaned notes, `-Index` suffix violations, and broken wikilinks.
10. `/archive <project>` — move a completed project to the archived section of `Projects-Index.md` without breaking backlinks.

## 4 Scheduled Agents

Four agents run on a cron/hook schedule to keep the vault healthy:

1. **Graph Repair Agent** — daily; runs `/graph-repair` and opens issues for any structural violations.
2. **Inbox Processor** — every 6 hours; reviews `01-Conversations/` captures and promotes anything mature into 02 or 03.
3. **Task Syncer** — every 15 minutes; reconciles Obsidian Tasks with external task manager (if configured).
4. **Weekly Curator** — Sunday nights; re-scores which concepts deserve MOC entries and surfaces stale or orphaned notes.

## 3 Non-Negotiables

These three rules override every other consideration. If a command seems to violate them, stop and ask.

1. **Bidirectional links or no link.** Every `[[wikilink]]` you write must have a sensible reverse link from the target. One-way links create graph islands.
2. **Filename = folder name for project indexes.** Never use the `-Index` suffix. `05-Projects/FOO/FOO.md`, not `05-Projects/FOO/FOO-Index.md`. The suffix breaks `[[FOO]]` resolution from anywhere in the vault.
3. **Bot-prefix commits for automated edits.** Any commit made by a scheduled agent or automation must prefix the message with `[bot:name]` (e.g., `[bot:graph-repair] Fix FOO-Index suffix`). Human commits must not use this prefix. The scheduled agents skip over bot-prefixed commits to avoid sync loops.

## Routing Table

For any incoming task, read these files first before acting:

| Task Type | Read These Files First |
|-----------|------------------------|
| Capture a URL | `02-Sources/README.md`, `CLAUDE.md` § WebFetch workflow |
| Add a task | `06-Tasks/TASKS.md`, `06-Tasks/TASKS-{AREA}.md`, `CLAUDE.md` § 3 Non-Negotiables |
| Create a new project | `04-Index/Projects-Index.md`, `05-Projects/INCUBATOR/INCUBATOR.md`, `CLAUDE.md` § Folder rules |
| Promote fleeting → permanent | `03-Concepts/README.md`, target MOC in `04-Index/` |
| Update a MOC | `04-Index/Index.md`, the specific MOC file, `CLAUDE.md` § Connect regime |
| Graph repair | `04-Index/Map.canvas`, `04-Index/Index.md`, `CLAUDE.md` § 3 Non-Negotiables |
| Sync with external tool | `SOUL.md`, `CRITICAL_FACTS.md`, the relevant area task file |
| Identity / personal facts | `SOUL.md`, `CRITICAL_FACTS.md` (read both every session) |

## Hard Rules (12)

1. **Always read a file before editing it.** Never guess at contents.
2. **Never save to the vault root** except for the files this CLAUDE.md explicitly names (`CLAUDE.md`, `AGENTS.md`, `SOUL.md`, `CRITICAL_FACTS.md`, `index.md`, `log.md`).
3. **Filenames are kebab-case** for concepts, `LIT-` prefix for sources, `TASKS-` prefix for task area files.
4. **Frontmatter is required** on every note (`title`, `type`, `tags`, optional `related`, `source`, `owner`).
5. **Never use `-Index` suffix** on project index files. The filename must match the folder name.
6. **Every project must appear in `04-Index/Projects-Index.md`** under the correct section (Active / Incubating / Archived).
7. **Bidirectional linking is mandatory.** Every link needs a reverse path.
8. **Never commit secrets, credentials, or `.env` files.** Check frontmatter and body before any commit.
9. **Link liberally.** If you mention a concept that has an atomic note, wrap it in `[[wikilinks]]` — don't leave unlinked mentions.
10. **Keep notes under 500 lines.** Split long notes into an MOC plus sub-concepts.
11. **Never proactively create documentation** (READMEs, summaries, reports) unless the user asks. `NEVER create files unless they're absolutely necessary for achieving your goal.`
12. **Never suggest Todoist or a paid task manager.** Task management lives in `06-Tasks/` via the Obsidian Tasks plugin.

## Bot-Prefix Commit Rule

Automated edits made by scheduled agents or hooks MUST prefix commit messages with `[bot:<agent-name>]`. This prefix is the signal that downstream sync agents (Task Syncer, Graph Repair Agent) use to avoid processing the change as if it were a human edit. Without the prefix, a single bot edit can trigger duplicate tasks, cascading graph repairs, or sync loops.

Examples:

- Human commit: `Add <ORG-C> to Projects-Index`
- Bot commit: `[bot:graph-repair] Normalize <ORG-C>-Index → <ORG-C>`
- Bot commit: `[bot:task-syncer] Reconcile TASKS-<ORG-E>WORK.md with external`

If you (Claude) are acting as a scheduled agent, use the bot prefix. If you are in an interactive session with a human, do not use the bot prefix — the human is the commit author.

---

[[Home-Index]] · [[Projects-Index]] · [[Index]]
