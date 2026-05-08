# Parsing Methodology Guide

This doc tells Claude **where to put things** when you run `/import-claude`, `/import-notes`, `/save`, or `/wiki add`. It's the rulebook the skills read before writing anything to your vault. If you ever want to tune how stuff gets classified, this is the file to edit.

---

## General rules (apply to every skill that writes)

1. **Read every file before categorizing it.** Don't sort by filename alone. Open the content.
2. **One concept per note in `03-Concepts/`.** If a source covers multiple ideas, split them into separate concept notes and link them.
3. **Always write in the user's own words.** Factual notes (`02-Sources/`) summarize — never copy-paste long passages.
4. **Link everything.** Every note should connect to at least one other note or index.
5. **Bidirectional links are mandatory.** If A links to B, B must link back to A. `/tether` will fix drift if you forget.
6. **Never put wikilinks inside tables.** Use bullet lists instead — Obsidian's graph can't see links inside table cells.
7. **Never auto-mutate `owner: human` files.** If a collision forces a write, use a `-<timestamp>` suffix and flag it.
8. **Never touch `01-Projects/<project>/<project>.md` directly.** Project index files are human-curated. Let `/tether` propose backlinks; the human accepts.

---

## Folder routing (the 7-folder map)

This is the post-mogging vault layout. The folders below are the only writable targets — the skills will refuse to write anywhere else without explicit user confirmation.

### `01-Projects/<PROJECT>/conversations/` (post-2026-05-08; `01-Projects/<PROJECT>/conversations/` was retired) — full-fidelity chat captures

- Output of `/save` and `/import-claude`.
- Subfolder-mirrors the structure of `01-Projects/` (so `FIDGETCODING/` conversations land under `01-Projects/FIDGETCODING/conversations/`).
- Filename: `YYYY-MM-DD-<slug>.md`.
- Frontmatter: `type: conversation`, `owner: human` — blocks future auto-mutation.
- A `VAULT/` subtree holds vault-about-vault captures (conversations *about* the system itself).

### `02-Sources/` — external inputs, factual-only

- Articles, videos, book notes, podcasts, PDFs, conversation mirrors from `01-Projects/<PROJECT>/conversations/` (post-2026-05-08; `01-Projects/<PROJECT>/conversations/` was retired).
- Naming: `SRC-<YYYY-MM-DD>-<slug>.md` for external sources, `LIT-<slug>.md` for conversation mirrors (grandfathered).
- Must include the source URL or reference.
- **Factual-only.** Interpretation lives in `03-Concepts/`. If you catch yourself writing "I think X means Y," that sentence belongs in a concept note, not here.
- Typical `owner: wiki` (skills can update) unless it's a conversation LIT-mirror (those are `owner: human`).

### `03-Concepts/` — refined atomic notes

- One clear idea per note, densely linked.
- Written in complete sentences as if explaining to someone else — not headline fragments.
- Filename: `brief-concept-name.md`.
- Grandfathered `owner: human` notes exist (pre-mogging). **Never auto-edit those.** New concept stubs created by skills get `owner: wiki`.
- This folder is the graph. If it's sparse, the graph is sparse.

### `04-Index/` — maps of content (navigation hubs)

- Group and link related concepts into a topic map.
- Filename: `<Topic>-Index.md` (e.g. `Tech-Index.md`, `Poetry-Index.md`).
- Also lives here: `audit-YYYY-MM-DD.md` output from `/wiki audit`, and `Map.canvas` if you build one.
- No content lives in `04-Index/` beyond structure + wikilinks — don't dump prose here.

### `01-Projects/` — active work

- One folder per active project. The folder name matches the index filename exactly (`FOO/FOO.md`, never `FOO/FOO-Index.md`).
- Subfolders for `content/`, `misc-building/`, `GITHUB/`, etc. are up to each project — use whatever makes sense, as long as the project's top-level index links them.
- `INCUBATOR/` is the staging lane for ideas not yet formal project folders.
- **Never auto-rewrite a project index file.** Add backlinks via `/tether` proposals; let the human merge.

### `05-Tasks/` — Obsidian Tasks plugin area

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
| A full chat transcript (Claude / ChatGPT / voice memo) | `01-Projects/<PROJECT>/conversations/<sub>/YYYY-MM-DD-<slug>.md` | `type: conversation`, `owner: human` |
| A summary of that chat (factual) | `02-Sources/LIT-conversation-<slug>-<date>.md` | `type: source`, `owner: human` |
| A summary of an article, video, podcast, or paper | `02-Sources/SRC-<YYYY-MM-DD>-<slug>.md` | `type: source`, `source: <url>` |
| A refined atomic idea in the user's voice | `03-Concepts/<slug>.md` | `type: concept`, `owner: wiki` (new) or `human` (user-written) |
| Notes tied to a specific active project | `01-Projects/<project>/<subfolder>/<slug>.md` | `type: source` or `concept`, `related: [[<project>]]` |
| A new topic grouping that clusters 3+ concepts | `04-Index/<Topic>-Index.md` | `type: index` |
| A task / todo | **Not auto-written.** User writes it in `05-Tasks/` with Tasks-plugin syntax + UUID. | — |
| Raw unclear dumps | `02-Sources/` with `tags: [raw, triage]` | flag for human review |

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
3. `/wiki audit` — writes a dated audit report to `04-Index/audit-YYYY-MM-DD.md` so you can see what still needs a human pass.

This replaces the old monolithic "wire the vault" step with three targeted skills you can run on demand.
