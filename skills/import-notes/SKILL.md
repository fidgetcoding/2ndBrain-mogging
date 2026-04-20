---
name: import-notes
description: One-shot import of existing notes from Apple Notes, OneNote, Notion, Evernote, or raw files (docx/pptx/xlsx/html/rtf/md/txt) into the 2ndBrain-mogging vault. Converts non-markdown via pandoc + xlsx2csv, validates each file, classifies each note against the 7-folder layout, writes factual content to 02-Sources/, splits atomic ideas into 03-Concepts/, and tethers project-tied material into 05-Projects/. Alias-classified, dry-run-previewed.
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

1. A mogged vault (has `02-Sources/`, `03-Concepts/`, `05-Projects/`, and `CLAUDE.md` at its root).
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
| `--project <name>` | Force every file under this folder to tether to one project in `05-Projects/`. |
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

- Title / body matches a known project alias → route to that project's folder in `05-Projects/<project>/<subfolder>/` or to `02-Sources/` with `related: [[<project>]]`.
- Title / body matches a known person alias → store in `02-Sources/` with `related: [[<person>]]`.
- No match → `02-Sources/` with `tags: [imported, review]` flagged for human triage.

### 5. Decide destination folder

| If the note is… | Write it to… |
|---|---|
| A summary of an article, video, podcast, or external read | `02-Sources/SRC-<date>-<slug>.md` with `type: source` |
| A summary of a conversation (including Claude / ChatGPT one-offs) | `02-Sources/LIT-conversation-<slug>-<date>.md` |
| A refined, atomic idea in the user's voice | `03-Concepts/<slug>.md` with `owner: wiki` + `type: concept` |
| Tied to a specific active project | `05-Projects/<project>/<subfolder>/<slug>.md` (NOT the project index file) |
| Meeting notes, raw dumps, partially-formed | `02-Sources/SRC-<date>-<slug>.md` with `tags: [raw, triage]` |
| A task / todo | **Refuse to auto-write** — point the user at `06-Tasks/` and the Tasks-plugin UUID format |

Never invent a folder that doesn't exist in `05-Projects/` without asking first.

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

For each kept note, look for 1-3 atomic ideas that could promote to `03-Concepts/`. Same rules as `/import-claude`:

- existing concept → append a reference, don't mutate
- new concept → `owner: wiki` stub in the user's voice

### 8. Backlink updates

- Any new project-mirror folder → update `04-Index/Projects-Index.md`
- Any new concept → update the relevant topic index in `04-Index/`
- Any project-tied note → update `05-Projects/<project>/<project>.md` only via `/tether` (don't touch it directly here)

### 9. State checkpoint

Record each processed file path in `Claude-Memory/import-notes-state.json`. `--resume` reads this file.

### 10. Summary report

Emit:

- `N source notes written to 02-Sources/`
- `M concept stubs created in 03-Concepts/`
- `K project-tied notes written to 05-Projects/<project>/`
- `S concept references appended`
- `R notes flagged for review (under 02-Sources/ with tags:[imported, review])`
- `F files skipped` (empty, unreadable, over-size) — with reasons

Tell the user to run `/tether` next so bidirectional project-note links settle, and `/connect` to surface any cross-concept wikilinks the import couldn't see.

## Guardrails

- **Never** overwrite an existing `owner: human` file.
- **Never** write inside `05-Projects/<project>/<project>.md` directly.
- **Never** auto-create task files — tasks belong in `06-Tasks/` with the Obsidian Tasks plugin UUID format (see CLAUDE.md).
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
- [claude-project-sync-guide.md](../../docs/claude-project-sync-guide.md) — how project-tied material maps to `05-Projects/<project>/` subfolder structure
