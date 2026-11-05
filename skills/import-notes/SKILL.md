---
name: import-notes
description: One-shot import of existing notes from Apple Notes, OneNote, Notion, Evernote, or raw files (docx/pptx/xlsx/html/rtf/md/txt) into the 2ndBrain-mogging vault. Converts non-markdown via pandoc + xlsx2csv, validates each file, classifies each note against the folder layout, writes cross-project sources to 02-Library/sources/, splits atomic ideas into 02-Library/ideas/, and tethers project-tied material into 01-Projects/<project>/notes/. Alias-classified, dry-run-previewed.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# import-notes — bring an existing notes pile into the vault

One-shot ingest of a folder full of exported notes. Designed to run once per export dump per source. For ongoing per-note capture, `/save` is the daily driver; for Claude / ChatGPT conversation history specifically, `/import-claude` is the right tool.

## Supported sources

| Source | How the user exports | What lands in the staging folder |
|---|---|---|
| **Apple Notes** | Exporter.app (Mac App Store) → Markdown | one `.md` per note, folder hierarchy preserved |
| **OneNote** | File → Export → Word `.docx` per section | one `.docx` per section |
| **Notion** | Settings → Export → Markdown & CSV | `.md` + `.csv` with the Notion workspace hierarchy |
| **Evernote** | File → Export Notes → Evernote XML | one or more `.enex` archives |
| **Raw files** | Any folder you have | `.md`, `.txt`, `.docx`, `.pptx`, `.xlsx`, `.html`, `.htm`, `.rtf` |

## Pre-requisites

1. A mogged vault (has `01-Projects/`, `02-Library/`, and `CLAUDE.md` at its root). A legacy vault that still has `02-Sources/` and `03-Concepts/` should run `scripts/migrate-to-library.sh` first; this skill never writes into those retired folders.
2. The notes already exported to a folder on disk.
3. Helpers installed:
   - `pandoc` — converts `.docx` / `.pptx` / `.html` / `.rtf` / `.epub` → markdown
   - `xlsx2csv` — converts Excel spreadsheets (via `pip3 install xlsx2csv`)
4. The helper script has been run: `bash scripts/import-notes.sh` checks the environment and finds candidate folders. Run it first so the user knows what converters are missing before this skill starts writing.

## Flags

| Flag | Purpose |
|---|---|
| `--source <path>` | The folder holding exported notes. Required. |
| `--kind <apple|onenote|notion|evernote|raw>` | Hint at the source type. Optional — the skill auto-detects from file extensions. |
| `--scan` | Inventory only: count files by type, estimate conversion cost. No writes. |
| `--dry-run` | Full classification pass in memory. Show every file it would write. Default. |
| `--apply` | Execute the writes. Requires explicit `yes` confirmation after the dry-run preview. |
| `--project <name>` | Force every file under this folder to tether to one project in `01-Projects/`. |
| `--resume` | Read `Claude-Memory/import-notes-state.json`, skip already-processed files, continue. |

## Pipeline

### 1. Inventory

Walk `--source`. For each file:

- Extension → source type (`apple`/`onenote`/`notion`/`evernote`/`raw`)
- Byte size
- Whether it needs conversion

Emit a summary broken down by type.

### 2. Convert non-markdown files

For every non-markdown candidate, run a conversion step first. Output goes to a scratch folder under `<vault>/.import-staging/<timestamp>-notes-converted/`.

| Input | Command |
|---|---|
| `.docx` | `pandoc input.docx -t markdown -o output.md` |
| `.pptx` | `pandoc input.pptx -t markdown -o output.md` |
| `.xlsx` | `xlsx2csv input.xlsx output.csv` then wrap as a markdown table block |
| `.html` / `.htm` | `pandoc input.html -t markdown-smart -o output.md` |
| `.rtf` | `pandoc input.rtf -t markdown -o output.md` |
| `.enex` | Parse XML → split into one `.md` per `<note>` block, preserve title + body + created timestamp |
| `.json` | Treat as Notion / raw JSON — parse if it matches a known shape, otherwise flag for review |

Skip files that:

- are empty after conversion
- produced a pandoc error
- have no detectable text content

Each skip is logged with a reason.

### 3. Validate each converted file

- At least 1 non-whitespace line of body text
- Title inferable from filename or first heading
- No malformed frontmatter
- File size under a sanity cap (default 500KB — larger gets flagged for human split)

### 4. Alias-classify each note

Apply the same alias lookup `/save` uses. Read `Claude-Memory/aliases.yaml`; for each note:

- Title / body matches a known project alias → route to that project's `01-Projects/<project>/notes/` (or an existing project subfolder) with `related: [[<project>]]`.
- Title / body matches a known person alias → store in the person's home project `notes/` with `related: [[<person>]]`, or in `02-Library/sources/` when the person has no single home project. A note that is a profile of the person themselves goes to `02-Library/people/`.
- No match → the catch-all project's `notes/` with `tags: [imported, review]` flagged for human triage. The catch-all is the `Claude-Memory/aliases.yaml` project entry whose `aliases` list includes "catch-all"; if no entry has it, `01-Projects/MISC/`. Never the Library.

### 5. Decide destination folder

| If the note is… | Write it to… |
|---|---|
| A summary of an article, video, podcast, or external read | `02-Library/sources/SRC-<date>-<slug>.md` with `type: source`, or the project's `notes/` when it is tied to one project |
| A summary of a conversation (including Claude / ChatGPT one-offs) | `01-Projects/<project>/!!conversations/<date>-<slug>.md`, or the catch-all project's `!!conversations/` when it spans projects. Never the Library; the old `LIT-conversation-*` mirror is retired |
| A refined, atomic idea in the user's voice | `02-Library/ideas/<slug>.md` with `owner: wiki` + `type: concept` (`02-Library/people/` or `tools/` for a note about one person or one tool, tagged `person` / `tool`) |
| Tied to a specific active project | `01-Projects/<project>/notes/<slug>.md` (NOT the project index file) |
| Meeting notes, raw dumps, partially-formed | the matching project's `notes/` (catch-all project when nothing matches) with `tags: [raw, triage]` |
| A task / todo | **Refuse to auto-write** — point the user at `04-Tasks/` and the Tasks-plugin UUID format |

Never invent a folder that doesn't exist in `01-Projects/` without asking first.

### 6. Write the note

Standard frontmatter:

```yaml
---
title: "<inferred title>"
date: <creation date from export, or today>
type: source | concept
owner: wiki
source: apple-notes | onenote | notion | evernote | raw
source_file: <original path>
tags: [imported, <kind>]
related: []
---
```

Then the body — copy as-is for markdown sources, best-effort clean-up for pandoc output (strip pandoc wrappers like `::: {}` blocks when safe).

### 7. Spawn concept stubs

For each kept note, look for 1-3 atomic ideas that could promote to `02-Library/ideas/`. Same rules as `/import-claude`:

- existing concept → append a reference, don't mutate
- new concept → `owner: wiki` stub in the user's voice

### 8. Backlink updates

- Any new project-mirror folder → update `03-Index/Projects-Index.md`
- Any new concept → update the relevant topic index in `03-Index/`
- Any project-tied note → update `01-Projects/<project>/<project>.md` only via `/tether` (don't touch it directly here)

### 9. State checkpoint

Record each processed file path in `Claude-Memory/import-notes-state.json`. `--resume` reads this file.

### 10. Summary report

Emit:

- `N source notes written to 02-Library/sources/`
- `M concept stubs created in 02-Library/ideas/`
- `K project-tied notes written to 01-Projects/<project>/notes/`
- `S concept references appended`
- `R notes flagged for review (under the catch-all project's notes/ with tags:[imported, review])`
- `F files skipped` (empty, unreadable, over-size) — with reasons

Tell the user to run `/tether` next so bidirectional project-note links settle, and `/connect` to surface any cross-concept wikilinks the import couldn't see.

## Guardrails

- **Never** overwrite an existing `owner: human` file.
- **Never** write inside `01-Projects/<project>/<project>.md` directly.
- **Never** write into a retired folder (`02-Sources/`, `03-Concepts/`, or the older killed list).
- **Never** auto-create task files — tasks belong in `04-Tasks/` with the Obsidian Tasks plugin UUID format (see CLAUDE.md).
- **Always** dry-run first. Require explicit `yes` before `--apply`.
- **Always** scrub secrets before writing.
- Commits use the `[bot:import-notes]` prefix.

## Typical invocations

```
/import-notes --source ~/Desktop/apple-notes-export --scan
/import-notes --source ~/Desktop/apple-notes-export --dry-run
/import-notes --source ~/Desktop/apple-notes-export --apply
/import-notes --source ~/Desktop/notion-export --kind notion --project <ORG-E> --apply
/import-notes --resume
```

## Related

- `/save` — single-note / single-passage capture (daily driver)
- `/import-claude` — Claude.ai / ChatGPT conversation history
- `/backfill` — Claude Code terminal session JSONLs
- [PARSING-GUIDE.md](../../docs/PARSING-GUIDE.md) — the categorization rules that drive every routing decision
- [claude-project-sync-guide.md](../../docs/claude-project-sync-guide.md) — how project-tied material maps to `01-Projects/<project>/` subfolder structure
