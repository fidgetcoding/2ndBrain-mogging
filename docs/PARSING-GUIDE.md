# Parsing Methodology Guide

This doc tells Claude **where to put things** when you run `/import-claude`, `/import-notes`, `/save`, or `/wiki add`. It's the rulebook the skills read before writing anything to your vault. If you ever want to tune how stuff gets classified, this is the file to edit.

---

## General rules (apply to every skill that writes)

1. **Read every file before categorizing it.** Don't sort by filename alone. Open the content.
2. **One idea per note in `02-Library/ideas/`.** If a source covers multiple ideas, split them into separate concept notes and link them.
3. **Always write in the user's own words.** Factual notes (`02-Library/sources/`, or a project's `notes/`) summarize — never copy-paste long passages.
4. **Link everything.** Every note should connect to at least one other note or index.
5. **Bidirectional links are mandatory.** If A links to B, B must link back to A. `/tether` will fix drift if you forget.
6. **Never put wikilinks inside tables.** Use bullet lists instead — Obsidian's graph can't see links inside table cells.
7. **Never auto-mutate `owner: human` files.** If a collision forces a write, use a `-<timestamp>` suffix and flag it.
8. **Never touch `01-Projects/<project>/<project>.md` directly.** Project index files are human-curated. Let `/tether` propose backlinks; the human accepts.

---

## Folder routing (the vault map)

This is the post-mogging vault layout. On 2026-11-05 (Library v2) `02-Sources/` and `03-Concepts/` merged into `02-Library/`, `04-Index/` became `03-Index/`, and `05-Tasks/` became `04-Tasks/`, so the numbers run 01 to 04 with no gaps. The folders below are the only writable targets — the skills will refuse to write anywhere else without explicit user confirmation.

### `01-Projects/<PROJECT>/!!conversations/` (post-2026-05-08; the old top-level `01-Conversations/` was retired) — full-fidelity chat captures

- Output of `/save` and `/import-claude`.
- Subfolder-mirrors the structure of `01-Projects/` (so `<ORG-C>/` conversations land under `01-Projects/<ORG-C>/!!conversations/`).
- Filename: `YYYY-MM-DD-<slug>.md`.
- Frontmatter: `type: conversation`, `owner: human` — blocks future auto-mutation.
- A `VAULT/` subtree holds vault-about-vault captures (conversations *about* the system itself).
- Cross-cutting chats (no single project) go to the catch-all project's `!!conversations/` — `01-Projects/MISC/!!conversations/` by default, or whichever project `aliases.yaml` marks as the catch-all. A fresh vault has no catch-all folder yet; the first import or `/save` that needs it makes it, hub note included. Conversations never go in the Library.

### `02-Library/` — cross-project reference only

Things that belong to no single project. Four subfolders:

- `02-Library/sources/` — external inputs, factual-only. Articles, videos, book notes, podcasts, PDFs that aren't tied to one project. A source tied to one project goes in that project's `notes/` instead (it keeps `type: source`).
  - Naming: `SRC-<YYYY-MM-DD>-<slug>.md` for external sources, `LIT-<slug>.md` (grandfathered). The old `LIT-conversation-*` mirror pattern is retired: write no new mirrors.
  - Must include the source URL or reference.
  - **Factual-only.** Interpretation lives in `02-Library/ideas/`. If you catch yourself writing "I think X means Y," that sentence belongs in a concept note, not here.
  - Typical `owner: wiki` (skills can update). Legacy conversation LIT-mirrors that moved here keep `owner: human`.
- `02-Library/ideas/` — refined atomic notes (what `03-Concepts/` held).
  - One clear idea per note, densely linked.
  - Written in complete sentences as if explaining to someone else — not headline fragments.
  - Filename: `brief-concept-name.md`.
  - Grandfathered `owner: human` notes exist (pre-mogging). **Never auto-edit those.** New concept stubs created by skills get `owner: wiki`.
  - This folder is the graph. If it's sparse, the graph is sparse.
- `02-Library/people/` — one note per person. `type: concept`, tag `person`.
- `02-Library/tools/` — one note per tool, app, service, model, or library. `type: concept`, tag `tool`.

`02-Sources/` and `03-Concepts/` are retired. Skills read them if a legacy vault still has them and never write there. `scripts/migrate-to-library.sh` moves them into `02-Library/sources/` and `02-Library/ideas/`.

### `03-Index/` — maps of content (navigation hubs)

- Group and link related concepts into a topic map.
- Filename: `<Topic>-Index.md` (e.g. `Tech-Index.md`, `Poetry-Index.md`).
- Also lives here: `Map.canvas` if you build one.
- Maps only. No reports, audits, logs, or dailies: `/wiki audit` output goes to `01-Projects/VAULT/REPORTS/audit-YYYY-MM-DD.md`.
- No content lives in `03-Index/` beyond structure + wikilinks — don't dump prose here.

### `01-Projects/` — active work

- One folder per active project. The folder name matches the index filename exactly (`FOO/FOO.md`, never `FOO/FOO-Index.md`).
- `!!conversations/` holds the project's saved chats, `notes/` holds everything written for it (including project-specific sources), and `assets/` holds images, PDFs, and media.
- Other subfolders (`REPO/`, `!ARCHIVE/`, `research/`, etc.) are up to each project — use whatever makes sense, as long as the project's top-level index links them.
- A fresh install creates only `01-Projects/VAULT/`. Every other project folder is yours to make, and the vault's `README.md` shows example layouts.
- **Never auto-rewrite a project index file.** Add backlinks via `/tether` proposals; let the human merge.

### `04-Tasks/` — Obsidian Tasks plugin area

- One `TASKS-<AREA>.md` per project area (mirrors `01-Projects/`).
- Tasks use the Obsidian Tasks plugin syntax + a stable `🆔 <uuid>` per task.
- If `task-maxxing` is running, this folder is a git submodule with its own live 2-way sync to Morgen. (Notion was dropped from the sync stack on 2026-05-04.)
- **Never auto-write task lines.** Tasks need the Obsidian Tasks UUID format, and `/import-notes` refuses to generate them. Point the user at their Tasks panel.

### `Claude-Memory/` — persistent memory + aliases

- Symlink to `~/.claude/projects/<vault>/memory/`.
- Contains `MEMORY.md`, `aliases.yaml` (gitignored), and typed memory shards.
- `/save` and `/wiki` read `aliases.yaml` before classifying entities — it's the canonical entity → project/person dictionary.

---

## Decision table (what goes where)

| If the incoming note is… | Send it to… | Frontmatter hints |
|---|---|---|
| A full chat transcript (Claude / ChatGPT / voice memo) | `01-Projects/<PROJECT>/!!conversations/<sub>/YYYY-MM-DD-<slug>.md` | `type: conversation`, `owner: human` |
| A cross-cutting chat (no single project) | `01-Projects/MISC/!!conversations/YYYY-MM-DD-<slug>.md` (the catch-all project) | `type: conversation`, `owner: human` |
| A summary of an article, video, podcast, or paper (cross-project) | `02-Library/sources/SRC-<YYYY-MM-DD>-<slug>.md` | `type: source`, `source: <url>` |
| A source tied to one project | `01-Projects/<project>/notes/SRC-<YYYY-MM-DD>-<slug>.md` | `type: source`, `related: [[<project>]]` |
| A refined atomic idea in the user's voice | `02-Library/ideas/<slug>.md` | `type: concept`, `owner: wiki` (new) or `human` (user-written) |
| A person | `02-Library/people/<name>.md` | `type: concept`, `tags: [person]` |
| A tool, app, service, model, or library | `02-Library/tools/<name>.md` | `type: concept`, `tags: [tool]` |
| Notes tied to a specific active project | `01-Projects/<project>/notes/<slug>.md` | `type: source` or `concept`, `related: [[<project>]]` |
| A new topic grouping that clusters 3+ concepts | `03-Index/<Topic>-Index.md` | `type: index` |
| A task / todo | **Not auto-written.** User writes it in `04-Tasks/` with Tasks-plugin syntax + UUID. | — |
| Raw unclear dumps | the catch-all project (`01-Projects/MISC/notes/`) with `tags: [raw, triage]` | flag for human review |

---

## File conversion rules

When `/import-notes` encounters non-markdown, it converts first and classifies second.

### `.docx` (Word)
```bash
pandoc input.docx -t markdown -o output.md
```

### `.pptx` (PowerPoint)
```bash
pandoc input.pptx -t markdown -o output.md
```

### `.xlsx` (Excel)
```bash
xlsx2csv input.xlsx output.csv
# then wrap the csv as a markdown table inside a fenced block
```

### `.html` / `.htm`
```bash
pandoc input.html -t markdown-smart -o output.md
```

### `.rtf`
```bash
pandoc input.rtf -t markdown -o output.md
```

### `.enex` (Evernote)
Parse XML manually — one `<note>` block = one output markdown file. Preserve the `<title>`, `<content>` (convert from ENML to markdown), and `<created>` timestamp.

### `.json` (Claude / ChatGPT export, Notion export)
Each source has its own shape. `/import-claude` handles the known ones; `/import-notes` flags unknown JSON for review.

---

## Owner contract (who is allowed to touch what)

| Value | Meaning |
|---|---|
| `owner: wiki` | Skills are allowed to update the body + frontmatter. Typical for new source notes + auto-generated concept stubs. |
| `owner: human` | Skills must NOT modify body or frontmatter. Only backlinks and bidirectional link repair (via `/tether`) are allowed. Typical for user-written concepts, conversation captures, and project index files. |

If a skill encounters an `owner: human` file during a write pass:

1. Don't write.
2. Open a `-<timestamp>` variant alongside.
3. Flag in the summary report with a line like `conflict: human-owned <path>`.

---

## After import: what to run next

Once `/import-claude` or `/import-notes` finishes, run these in order:

1. `/tether` — audits bidirectional project links and fixes orphans.
2. `/connect` — proposes `[[wikilinks]]` between notes that share concepts but don't link yet.
3. `/wiki audit` — writes a dated audit report to `01-Projects/VAULT/REPORTS/audit-YYYY-MM-DD.md` so you can see what still needs a human pass.

This replaces the old monolithic "wire the vault" step with three targeted skills you can run on demand.
