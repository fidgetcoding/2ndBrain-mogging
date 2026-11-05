# CLAUDE.md Patch — 2ndBrain-mogging

This document contains the **canonical text** that `2ndBrain-mogging` appends to a vault's `CLAUDE.md` during install (via `install.sh --apply`) or via `/aliases update-claudemd`. The installer (or the Phase B10 agent in a `/rswarm*` vault refactor) reads this file and writes the exact block below between the marker pair, verbatim, so every vault running the plugin carries the same post-mogging contract.

This file is the source of truth for the patch. Edit this file first, then re-run the installer or `/aliases update-claudemd` — never hand-edit the markers in a live vault.

## Contract

- The patch is delimited by HTML comment markers so the installer can cleanly re-apply, idempotently upgrade, or remove it without touching any hand-authored content above the markers.
- **Start marker:** `<!-- 2ndbrain-mogging:start -->`
- **End marker:** `<!-- 2ndbrain-mogging:end -->`
- Both markers MUST appear at the end of the vault's `CLAUDE.md` on their own lines, with a single blank line before the start marker and no trailing content after the end marker (except a terminal newline).
- Anything between the markers is owned by the plugin and may be overwritten on upgrade. Everything outside the markers is user-owned and untouched.
- Marker names are permanent. They identify the plugin across version bumps. Changing them breaks the idempotency contract and strands every existing install. If a future rewrite needs to reset the block, bump the version noted inside the block, not the markers.

## Exact text to append

Copy EVERYTHING between (and including) the two `<!-- 2ndbrain-mogging:... -->` lines below. Do not strip the markers. Do not collapse blank lines. Do not reformat the tables — Obsidian preview and downstream parsers both rely on the column alignment.

```markdown
<!-- 2ndbrain-mogging:start -->

## 2ndBrain-mogging (plugin-managed section)

> This section is managed by the `2ndBrain-mogging` Claude Code plugin (post-mogging contract, 2026-04-16 onward). It is regenerated on plugin upgrade. Do not hand-edit between the markers — edit `docs/CLAUDE-MD-PATCH.md` in the plugin repo and re-run the installer, OR edit `Claude-Memory/aliases.yaml` directly for entity changes.
>
> Canonical source: https://github.com/fidgetcoding/2ndBrain-mogging

### Post-mogging folder contract (Library v2, 5 folders)

Every write path in every skill resolves its target against this table. If a skill disagrees with this layout, the skill is the bug — fix the skill.

| Folder | Role | Primary writer | Notes |
|---|---|---|---|
| `01-Projects/<PROJECT>/!!conversations/` (post-2026-05-08; the old top-level `01-Conversations/` was retired) | `/save` output: text chats with AI assistants only (never audio captures, reports or logs); mirrors `01-Projects/` subfolders. Named `!!conversations/` since 2026-11-05 so it sorts first in Finder | `save` (branches 1–3) | Append-only per file. A conversation with no single project goes to the catch-all project's `!!conversations/` (the `aliases.yaml` entry aliased `catch-all`; `01-Projects/MISC/` by default), never to `02-Library/`. The `LIT-conversation-*` mirror is retired. Scheduled agents write reports under `01-Projects/VAULT/REPORTS/` and nowhere else. Vault-about-vault notes live under `01-Projects/VAULT/!!conversations/`. |
| `01-Projects/<PROJECT>/notes/` | Everything written for one project, including sources tied to it | `save` (branch 2 `--source`), `wiki add` | A source owned by one project lives here, not in the Library, and keeps `type: source`. |
| `02-Library/sources/` | Source-of-truth notes for external content no single project owns (articles, videos, transcripts, emails, PDFs, books) | `save` (branch 2 `--source`), `autoresearch`, `wiki add` | Cross-project only. Each file carries `source_url` + `source_type` + `captured` in frontmatter. Body is summary; raw fetched text lives in a `> [!source]` callout or a fenced block. Replaces legacy `02-Sources/` (and `02-Literature/` before it). |
| `02-Library/ideas/` | Refined atomic idea notes — one idea per file | `wiki` | `type: concept`. Needs ≥1 inbound from a source (`02-Library/sources/` or a project's `notes/`) and ≥1 outbound to `03-Index/`. First write sets `needs_review: true`; `wiki promote` flips it once the note has 3+ inbound links. Replaces legacy `03-Concepts/` (and `03-Permanent/` before it). Existing notes grandfathered with `owner: human` are never silently rewritten. |
| `02-Library/people/`, `02-Library/tools/` | One note per person; one note per tool, app, service, model or library | `wiki` | `type: concept` plus tag `person` or `tool`. Cross-project only. Same link minimum as `ideas/`. |
| `03-Index/` | Maps of content (indexes), hub pages, topic guides | `wiki`, `tether` | Maps only — link lists + terse one-liners. Never reports, audits, logs or dailies. Must list every idea in its topic cluster. Contains `Index.md`, `Home-Index`, `Projects-Index`, `Poetry-Index`, `Tech-Index`, and `Map.canvas`. Replaces legacy `04-MOC/`. |
| `01-Projects/` | Project hubs mirroring Claude Projects; includes `INCUBATOR/` and the catch-all `MISC/` | `save` (branches 1–3), `tether` | Every project folder has an index note where filename = folder name (`FOO/FOO.md`, never `FOO-Index.md`), plus `!!conversations/`, `notes/` and `assets/` as needed. Bidirectional links up to `03-Index/Projects-Index.md` are mandatory. |
| `04-Tasks/` | Obsidian Tasks plugin files + inline tasks | `save` (UUID-preserving edits only) | `/wiki` and `/autoresearch` are FORBIDDEN from writing here. `/save` is edit-safe only with strict UUID preservation. No agent writes here. Live n8n ↔ Morgen 2-way sync is wired through this folder (Notion was dropped 2026-05-04); the `04-Tasks/` git submodule is preserved. |
| `Claude-Memory/` | Plugin working state: aliases, ADRs, session manifests, hot context | `aliases`, `save` (ADR branch + backfill manifest), `emerge` (hot.md) | Symlink to `~/.claude/projects/<project-slug>/memory/`. Treat as config, not user-facing notes. `aliases.yaml` is the canonical alias source; `adr/` holds ADRs; `backfill-manifest.jsonl` is append-only. |

The numbered folders run 01 to 04 with no gaps. `03-Index/` was `04-Index/` and `04-Tasks/` was `05-Tasks/` until 2026-11-05.

**Killed folders** (pre-mogging layout, do not recreate): `00-Inbox/`, `01-Fleeting/`, `05-Templates/`, `06-Assets/`. If a skill sees one of these in a legacy vault, it treats the content as residue and routes it through `/save` migration — it does not reanimate the folder.

**Retired by Library v2 (2026-11-05):** `02-Sources/` → `02-Library/sources/`, `03-Concepts/` → `02-Library/ideas/`, `04-Index/` → `03-Index/`, `05-Tasks/` → `04-Tasks/`, every `01-Projects/**/conversations/` → `!!conversations/`, and `01-Projects/VAULT/conversations/reports/` → `01-Projects/VAULT/REPORTS/`. Skills may read them while a vault still has them; they never write there. `scripts/migrate-to-library.sh` in the plugin repo moves and renames them (dry run by default, `--apply` to act; `git mv` in a git vault, so a tasks submodule follows). People and tools get sorted into `people/` and `tools/` later. Anything outside the vault that names `05-Tasks/` by path (a sync daemon, a launchd plist, an n8n path filter) has to be updated by hand.

### Note-type contract (frontmatter `type:`)

Closed set. A skill encountering an unknown `type` halts with a parse error rather than guessing.

**Post-mogging canonical types:**

| Type | Folder | Purpose |
|---|---|---|
| `source` | `02-Library/sources/`, or a project's `notes/` | External input (article, video, transcript, email, PDF, book). Must have `source_url`, `source_type`, `captured`. |
| `concept` | `02-Library/ideas/`, `people/`, `tools/` | Refined atomic idea, person or tool (tag `person` / `tool`). Needs `last_confirmed`, `needs_review`, `owner`. |
| `index` | `03-Index/` | Map of content, hub, topic index. Body is a link list, not prose. |
| `conversation` | `01-Projects/<PROJECT>/!!conversations/` (post-2026-05-08; the old top-level `01-Conversations/` was retired) | `/save` output (text chats with AI assistants). No per-type additions beyond universal fields. |
| `adr` | `Claude-Memory/adr/` | Architectural decision record. Has `status`, `supersedes`, `superseded_by`. |
| `synthesis` | `02-Library/ideas/` or `03-Index/` | Cross-concept rollup. Has `answers_question`, `sources`. |

**Grandfathered legacy types** (read-only mapping for notes created pre-mogging; skills normalize on next write):

| Legacy type | Maps to | Treatment |
|---|---|---|
| `literature` | `source` | Folder moves from `02-Literature/` (later `02-Sources/`) → `02-Library/sources/`. Body unchanged. |
| `permanent` | `concept` | Folder moves from `03-Permanent/` (later `03-Concepts/`) → `02-Library/ideas/`. If `owner: human` is set, the note is locked — skills propose diffs instead of rewriting. |
| `moc` | `index` | Folder moves from `04-MOC/` (later `04-Index/`) → `03-Index/`. Wikilinks of the shape `[[MOC-*]]` are rewritten to `[[*-Index]]` by `/wiki heal`. |
| `fleeting` | `inbox-residue` | Body is preserved verbatim; the note is re-routed to its most likely project under `01-Projects/` (or surfaced for human decision if no alias hits). `01-Fleeting/` itself is killed and never recreated. |

### Universal frontmatter

Every note the plugin writes opens with:

```yaml
---
title: "Human-readable title"              # required, quote if it contains :
date: 2026-04-17                           # ISO date, required
type: source | concept | index | conversation | adr | synthesis
tags: [lowercase-hyphenated]                # list, may be empty
aliases: ["Alt Name 1", "Alt Name 2"]       # list, used by Obsidian link autocomplete
---
```

Per-type additions are documented in the plugin's `references/wiki-schema.md`.

### 13 skills (plugin `2ndbrain-mogging`, auto-namespaced)

`/save` `/wiki` `/challenge` `/emerge` `/backfill` `/aliases` `/autoresearch` `/canvas` `/tether` `/connect` `/import-claude` `/import-notes` `/vault-coach`

| Skill | Purpose |
|---|---|
| `/save` | Capture conversation / passage / dictated note / ADR into the vault with alias-driven classification + dry-run preview. |
| `/wiki` | Re-compile a topic note from its sources — add, audit, heal, find. |
| `/challenge` | Steel-man the opposing view of any claim using the user's own prior notes. |
| `/emerge` | Surface patterns, rising topics, and killed ideas across recent vault activity. |
| `/backfill` | Walk historical Claude Code session JSONLs and route them as if `/save` had run at the time. |
| `/aliases` | Manage `Claude-Memory/aliases.yaml` — add, rename, split entities. |
| `/autoresearch` | Three-round web research loop — shallow sweep, follow-up, synthesis. |
| `/canvas` | Generate an Obsidian Canvas pre-wired to a named set of notes. |
| `/tether` | Audit `01-Projects/` bidirectional links, MOC membership, hub wiring; fix orphans. |
| `/connect` | Propose `[[wikilinks]]` between notes that share concepts but don't link yet. |
| `/import-claude` | One-shot import your Claude.ai or ChatGPT data export — full conversation history, alias-classified, spawns concept stubs where ideas repeat. |
| `/import-notes` | One-shot import existing notes (Apple Notes, OneNote, Notion, Evernote, raw `.md` / `.docx` / `.pptx` / `.xlsx` / `.html`); pandoc under the hood, dry-run preview. |
| `/vault-coach` | Coach the user through setting up + maintaining the vault. Auto-loads post-install and on new-folder/new-project; enforces index-note-per-folder, Projects-Index registration, bidirectional tethering, one-question-at-a-time. Live counterpart to `docs/MAINTAINING-YOUR-BRAIN.md`. |

Local installs use **hardlinks** (preferred) or symlinks — `install.sh --apply` hardlinks by default. Editing either side edits both. If a skill file ever drifts, the mogging repo is the source of truth.

### 4 scheduled agents (audit-only by default)

| Agent | When | Writes to | Purpose |
|---|---|---|---|
| `morning` | 08:00 local | `01-Projects/VAULT/REPORTS/MORNING-<date>.md` (opt-in) | Review yesterday's transcripts, flag unsaved content. |
| `nightly` | 22:00 local | `01-Projects/VAULT/REPORTS/NIGHTLY-<date>.md` | `/tether` audit + `/connect` suggestions. |
| `weekly` | Friday 18:00 | `01-Projects/VAULT/REPORTS/WEEKLY-<date>.md` | `/emerge` pass over `02-Library/`. |
| `health` | Sunday 21:00 | `01-Projects/VAULT/REPORTS/HEALTH-<date>.md` | Broken wikilinks, orphan files, missing frontmatter. |

Scheduled agents are audit-only by default. Any write-capable scheduled agent requires explicit opt-in via its plist. Every scheduled write carries commit prefix `[bot:<agent>]` so the n8n 2-way sync's loop-prevention skips it. (Notion was dropped from the sync stack on 2026-05-04 — `task-maxxing` is now Obsidian ↔ Morgen only; the W3 worker is a no-op stub.)

### 3 non-negotiables

These override every skill-local policy. A skill that skips one of these is broken and must be halted.

1. **Backup before mutation.** Before any multi-file structural change, tarball the vault to `~/WORK/<vault-name>-BACKUPS/<vault-name>-backup-*.tar.gz` — NEVER `~/Desktop/` (TCC-protected on modern macOS, and Desktop tarballs are forbidden outright). Before overwriting ANY single file that already exists, snapshot it to `Claude-Memory/backups/YYYY-MM-DD/HHMMSS--<relpath>.bak`. If the backup write fails (disk full, permissions), abort the primary write. No exceptions.
2. **Stop-hook jq-merge discipline.** The `Stop` hook payload MUST be merged into `~/.claude/settings.json` using `jq --slurp 'add'` semantics — never naive concatenation, never overwrite. Raw string append corrupts settings and breaks `/save --backfill --resume`. If `jq` is unavailable on the system path, the hook prints a WARN and no-ops rather than writing partial state.
3. **n8n path filters stay current.** Any skill that adds a new top-level vault folder or a new externally-synced `01-Projects/<ORG>/<repo>/` subtree MUST update the n8n W1 path filter so the new subtree is ingested. The W1/W2 filters were migrated from legacy `08-Tasks/` to `05-Tasks/` in the 2026-04-17 swarm; W2 phantom-write prefix is removed, defensive strippers are left as no-ops. Library v2 (2026-11-05) renamed the folder to `04-Tasks/`, so any filter or daemon that names the folder by vault path must follow. (W3 was deprecated 2026-05-04 when Notion was dropped from the sync stack.) The canonical path-filter file lives in the private `obsidian-tasks-sync` config repo — if it is not mounted, the skill prints a TODO row in its report and continues rather than silently creating an untracked subtree.

### Bot-prefix commits

Automated commits MUST use one of the `[bot:*]` prefixes so n8n W1 skips re-ingesting them (filter node enforces skip). A missing prefix creates a duplicate-task loop.

| Prefix | Used by |
|---|---|
| `[bot:save]` | `/save` (all non-backfill branches) |
| `[bot:save --backfill]` | `/save --backfill` historical ingest |
| `[bot:wiki-add]` | `/wiki add`, `/connect`, `/tether` (new-note paths) |
| `[bot:wiki-heal]` | `/wiki heal`, nightly audit fixups |
| `[bot:wiki-fix]` | `/wiki` targeted repairs |
| `[bot:backfill]` | `/backfill` skill (non-save entry) |
| `[bot:import-claude]` | `/import-claude` one-shot Claude.ai / ChatGPT export import |
| `[bot:import-notes]` | `/import-notes` one-shot pandoc-driven note import (Apple Notes, OneNote, Notion, Evernote, raw files) |
| `[bot:reconcile]` | Post-import reconciliation pass (alias re-classification, orphan backlinking) |
| `[bot:mogging-*]` | Mogging-repo maintenance (e.g., `[bot:mogging-fix]`) |
| `[bot:morning]` / `[bot:nightly]` / `[bot:weekly]` / `[bot:health]` | Scheduled agents |
| `[bot:daemon]` | obsidian-tasks-sync local daemon — auto-commits 04-Tasks edits made in Obsidian between n8n cycles |

Every prefix in this table MUST be listed in the n8n W1 filter.

### Hard rules

- **Never auto-rewrite `01-Projects/*/<project>.md` index files.** Filename-equals-folder rule is preserved; violations break `[[PROJECT]]` wikilink resolution.
- **Never edit `04-Tasks/` content directly.** Use `/save` with Obsidian Tasks plugin syntax and strict UUID preservation. A task with no 🆔 stays that way until W1 mints one on its next sync.
- **Never use `[[MOC-*]]` wikilinks.** Legacy shape, dead after the `04-MOC/` → `04-Index/` rename (`03-Index/` since 2026-11-05). Use `[[*-Index]]`. `/wiki heal` rewrites existing `[[MOC-*]]` references automatically.
- **Never remove a note or wikilink** without flagging it for human review. Dead wikilinks get struck through with an HTML comment (`~~[[orphaned]]~~ <!-- dead: YYYY-MM-DD -->`), never silently deleted.
- **Always check `Claude-Memory/aliases.yaml`** before classifying entities. If `jq`/`yaml` can't parse it, the skill halts — partial classification is worse than no classification.
- **Respect the `graph-clean` workspace filter.** Excludes `MISC-CLAUDE/`, `<PRIVATE-PROJECT>/`, `node_modules/`, `.claude/`, `.agents/`, `READMEs`, and `SKILL.md` files from the graph view.
- **`/wiki` and `/autoresearch` are forbidden from writing under `04-Tasks/**`.** Task management is human-sovereign plus `/save`-only.
- **No skill writes to `CLAUDE.md` wholesale.** The plugin-managed block between the `2ndbrain-mogging:*` markers is regenerated by the installer; everything above the start marker is user-owned.
- **Bidirectional tethering on every project.** Every `01-Projects/<PROJECT>/<PROJECT>.md` links UP (to `Projects-Index` / parent hub) AND DOWN (to sub-projects, key notes). Client work tethers to its org hub; code projects tether to `[[GITHUB]]`.

### Obsidian Tasks syntax

Canonical line (token order is mandatory — the Tasks plugin parses positionally):

```
- [ ] <task text> <priority?> 📅 YYYY-MM-DD <🔁 recurrence?> 🆔 m-XXXXXXXX
```

- Priorities: 🔺 highest · ⏫ high · 🔼 medium · 🔽 low · ⏬ lowest
- Dates: 📅 due · ⏳ scheduled · 🛫 start · ✅ done · ❌ cancelled
- Recurrence: `🔁 every week`, `🔁 every 2 weeks`, `🔁 every month on the 1st`
- 🆔 is `m-XXXXXXXX` (8 lowercase hex chars), mandatory on every new task, minted by W1 on first sync. Edits preserve it byte-for-byte. A line missing its 🆔 stays ID-less until W1 mints one, and no skill invents a token. (Pre-2026-05-04 entries used UUIDv4 format; W1 only matches `m-[0-9a-f]{8}` so legacy entries are stranded but archived — do not auto-rewrite.)

Rewriting tokens in the wrong order or dropping the 🆔 breaks the n8n W1/W2 sync and creates duplicate tasks in Morgen that cost ~15 minutes of manual deduping to undo. (W3 was deprecated 2026-05-04 when Notion was dropped from the sync stack.)

### Calendar + task ops default

Calendar and task operations default to **Morgen** (`mcp__morgen__*`). Motion (`mcp__motion*`) is used only for the feature gaps Morgen lacks in its public API: teammate events, full-text event search, all-day event queries, and calendar management. If Motion is desired for any other reason, pass `--engine motion` on the relevant slash command.

### Anti-drift guarantees

The plugin enforces these invariants on every write. Violations abort the write and surface a diff:

- File size stays under 500 lines.
- Every public API has a typed interface.
- Input validation happens at every system boundary.
- No secrets in source. No `.env` committed. No hardcoded tokens. Every write passes through the security scrub regex panel defined in `references/wiki-schema.md §6` before landing on disk.
- File paths are sanitized against directory traversal.
- Commit messages use present-tense, imperative mood, include a one-line rationale, and carry the correct `[bot:*]` prefix for automated writes.

<!-- 2ndbrain-mogging:end -->
```

## How the installer applies this

`install.sh --apply` (or the Phase B10 agent in a `/rswarm*` vault refactor):

1. Reads the source file at `docs/CLAUDE-MD-PATCH.md` in this repo.
2. Reads the vault's `CLAUDE.md` (at `$VAULT/CLAUDE.md`). If absent, creates it with a single trailing newline, then proceeds.
3. If the vault's `CLAUDE.md` already contains `<!-- 2ndbrain-mogging:start -->`, replaces everything between the two markers (inclusive) with the new block. If not, appends a single blank line followed by the entire block from this doc.
4. Does NOT touch any text outside the markers.
5. Runs `python3 -c "import yaml; yaml.safe_load(open('$VAULT/Claude-Memory/aliases.yaml'))"` to verify the registry is valid after the patch.
6. Commits the vault as `[bot:mogging-install] apply CLAUDE.md patch` so n8n W1 skips re-ingesting it.

Re-running the installer is safe and idempotent — the marker pair guarantees the block is replaced, not duplicated.

## Update procedure

When a future release changes plugin semantics:

1. Edit the fenced code block above. Keep the markers intact and unchanged.
2. Bump `version` in `Claude-Memory/aliases.yaml` if the registry shape changes.
3. Add a `CHANGELOG.md` entry noting the patch change and what the marker block now contains.
4. Re-run `install.sh --apply` (or `/aliases update-claudemd`) in every vault that has the plugin installed — the installer reads this file and rewrites the marker block verbatim.
