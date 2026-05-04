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
> Canonical source: https://github.com/<ORG-A>/2ndBrain-mogging

### Post-mogging folder contract (7 folders)

Every write path in every skill resolves its target against this table. If a skill disagrees with this layout, the skill is the bug — fix the skill.

| Folder | Role | Primary writer | Notes |
|---|---|---|---|
| `01-Conversations/` | `/save` output + scheduled-agent reports; mirrors `05-Projects/` subfolders | `save` (branches 1–3) | Append-only per file. Scheduled agents write reports under `01-Conversations/VAULT/reports/` and nowhere else. Vault-about-vault notes live under `01-Conversations/VAULT/`. |
| `02-Sources/` | Source-of-truth notes for external content (articles, videos, transcripts, emails, PDFs, books) | `save` (branch 2 `--source`), `autoresearch`, `wiki add` | Each file carries `source_url` + `source_type` + `captured` in frontmatter. Body is summary; raw fetched text lives in a `> [!source]` callout or a fenced block. Replaces legacy `02-Literature/`. |
| `03-Concepts/` | Refined atomic concept notes — one concept per file | `wiki` | Needs ≥1 inbound from a `02-Sources/` note and ≥1 outbound to `04-Index/`. First write sets `needs_review: true`; `wiki promote` flips it once the note has 3+ inbound links. Replaces legacy `03-Permanent/`. Existing notes grandfathered with `owner: human` are never silently rewritten. |
| `04-Index/` | Maps of content (indexes), hub pages, topic guides | `wiki`, `tether` | Never freeform prose — only link lists + terse one-liners. Must list every concept in its topic cluster. Contains `Index.md`, `Home-Index`, `Projects-Index`, `Poetry-Index`, `Tech-Index`, and `Map.canvas`. Replaces legacy `04-MOC/`. |
| `05-Projects/` | Project hubs mirroring Claude Projects; includes `INCUBATOR/` | `save` (branches 1–3), `tether` | Every project folder has an index note where filename = folder name (`FOO/FOO.md`, never `FOO-Index.md`). Bidirectional links up to `04-Index/Projects-Index.md` are mandatory. |
| `06-Tasks/` | Obsidian Tasks plugin files + inline tasks | `save` (UUID-preserving edits only) | `/wiki` and `/autoresearch` are FORBIDDEN from writing here. `/save` is edit-safe only with strict UUID preservation. No agent writes here. Live n8n ↔ Morgen ↔ Notion sync is wired through this folder; the `06-Tasks/` git submodule is preserved. |
| `Claude-Memory/` | Plugin working state: aliases, ADRs, session manifests, hot context | `aliases`, `save` (ADR branch + backfill manifest), `emerge` (hot.md) | Symlink to `~/.claude/projects/<project-slug>/memory/`. Treat as config, not user-facing notes. `aliases.yaml` is the canonical alias source; `adr/` holds ADRs; `backfill-manifest.jsonl` is append-only. |

**Killed folders** (pre-mogging layout, do not recreate): `00-Inbox/`, `01-Fleeting/`, `05-Templates/`, `06-Assets/`. If a skill sees one of these in a legacy vault, it treats the content as residue and routes it through `/save` migration — it does not reanimate the folder.

### Note-type contract (frontmatter `type:`)

Closed set. A skill encountering an unknown `type` halts with a parse error rather than guessing.

**Post-mogging canonical types:**

| Type | Folder | Purpose |
|---|---|---|
| `source` | `02-Sources/` | External input (article, video, transcript, email, PDF, book). Must have `source_url`, `source_type`, `captured`. |
| `concept` | `03-Concepts/` | Refined atomic concept. Needs `last_confirmed`, `needs_review`, `owner`. |
| `index` | `04-Index/` | Map of content, hub, topic index. Body is a link list, not prose. |
| `conversation` | `01-Conversations/` | `/save` output + scheduled-agent reports. No per-type additions beyond universal fields. |
| `adr` | `Claude-Memory/adr/` | Architectural decision record. Has `status`, `supersedes`, `superseded_by`. |
| `synthesis` | `03-Concepts/` or `04-Index/` | Cross-concept rollup. Has `answers_question`, `sources`. |

**Grandfathered legacy types** (read-only mapping for notes created pre-mogging; skills normalize on next write):

| Legacy type | Maps to | Treatment |
|---|---|---|
| `literature` | `source` | Folder moves from `02-Literature/` → `02-Sources/`. Body unchanged. |
| `permanent` | `concept` | Folder moves from `03-Permanent/` → `03-Concepts/`. If `owner: human` is set, the note is locked — skills propose diffs instead of rewriting. |
| `moc` | `index` | Folder moves from `04-MOC/` → `04-Index/`. Wikilinks of the shape `[[MOC-*]]` are rewritten to `[[*-Index]]` by `/wiki heal`. |
| `fleeting` | `inbox-residue` | Body is preserved verbatim; the note is re-routed to its most likely project under `05-Projects/` (or surfaced for human decision if no alias hits). `01-Fleeting/` itself is killed and never recreated. |

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

### 12 skills (plugin `2ndbrain-mogging`, auto-namespaced)

`/save` `/wiki` `/challenge` `/emerge` `/backfill` `/aliases` `/autoresearch` `/canvas` `/tether` `/connect` `/import-claude` `/import-notes`

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
| `/tether` | Audit `05-Projects/` bidirectional links, MOC membership, hub wiring; fix orphans. |
| `/connect` | Propose `[[wikilinks]]` between notes that share concepts but don't link yet. |
| `/import-claude` | One-shot import your Claude.ai or ChatGPT data export — full conversation history, alias-classified, spawns concept stubs where ideas repeat. |
| `/import-notes` | One-shot import existing notes (Apple Notes, OneNote, Notion, Evernote, raw `.md` / `.docx` / `.pptx` / `.xlsx` / `.html`); pandoc under the hood, dry-run preview. |

Local installs use **hardlinks** (preferred) or symlinks — `install.sh --apply` hardlinks by default. Editing either side edits both. If a skill file ever drifts, the mogging repo is the source of truth.

### 4 scheduled agents (audit-only by default)

| Agent | When | Writes to | Purpose |
|---|---|---|---|
| `morning` | 08:00 local | `01-Conversations/VAULT/reports/MORNING-<date>.md` (opt-in) | Review yesterday's transcripts, flag unsaved content. |
| `nightly` | 22:00 local | `01-Conversations/VAULT/reports/NIGHTLY-<date>.md` | `/tether` audit + `/connect` suggestions. |
| `weekly` | Friday 18:00 | `01-Conversations/VAULT/reports/WEEKLY-<date>.md` | `/emerge` pass over `03-Concepts/`. |
| `health` | Sunday 21:00 | `01-Conversations/VAULT/reports/HEALTH-<date>.md` | Broken wikilinks, orphan files, missing frontmatter. |

Scheduled agents are audit-only by default. Any write-capable scheduled agent requires explicit opt-in via its plist. Every scheduled write carries commit prefix `[bot:<agent>]` so the n8n 2-way sync's loop-prevention skips it. (Notion was dropped from the sync stack on 2026-05-04 — `task-maxxing` is now Obsidian ↔ Morgen only; the W3 worker is a no-op stub.)

### 3 non-negotiables

These override every skill-local policy. A skill that skips one of these is broken and must be halted.

1. **Backup before mutation.** Before any multi-file structural change, tarball the vault to `~/Desktop/2ndBrain-backup-*.tar.gz`. Before overwriting ANY single file that already exists, snapshot it to `Claude-Memory/backups/YYYY-MM-DD/HHMMSS--<relpath>.bak`. If the backup write fails (disk full, permissions), abort the primary write. No exceptions.
2. **Stop-hook jq-merge discipline.** The `Stop` hook payload MUST be merged into `~/.claude/settings.json` using `jq --slurp 'add'` semantics — never naive concatenation, never overwrite. Raw string append corrupts settings and breaks `/save --backfill --resume`. If `jq` is unavailable on the system path, the hook prints a WARN and no-ops rather than writing partial state.
3. **n8n path filters stay current.** Any skill that adds a new top-level vault folder or a new externally-synced `05-Projects/<ORG>/<repo>/` subtree MUST update the n8n W1 path filter so the new subtree is ingested. The W1/W2/W3 filters have been migrated from legacy `08-Tasks/` to `06-Tasks/` as of the 2026-04-17 swarm; W2 phantom-write prefix is removed, defensive strippers are left as no-ops. The canonical path-filter file lives in the private `obsidian-tasks-sync` config repo — if it is not mounted, the skill prints a TODO row in its report and continues rather than silently creating an untracked subtree.

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

Every prefix in this table MUST be listed in the n8n W1 filter.

### Hard rules

- **Never auto-rewrite `05-Projects/*/<project>.md` index files.** Filename-equals-folder rule is preserved; violations break `[[PROJECT]]` wikilink resolution.
- **Never edit `06-Tasks/` content directly.** Use `/save` with Obsidian Tasks plugin syntax and strict UUID preservation. Missing UUID on a legacy task is mint-and-log, not rewrite.
- **Never use `[[MOC-*]]` wikilinks.** Legacy shape, dead after the `04-MOC/` → `04-Index/` rename. Use `[[*-Index]]`. `/wiki heal` rewrites existing `[[MOC-*]]` references automatically.
- **Never remove a note or wikilink** without flagging it for human review. Dead wikilinks get struck through with an HTML comment (`~~[[orphaned]]~~ <!-- dead: YYYY-MM-DD -->`), never silently deleted.
- **Always check `Claude-Memory/aliases.yaml`** before classifying entities. If `jq`/`yaml` can't parse it, the skill halts — partial classification is worse than no classification.
- **Respect the `graph-clean` workspace filter.** Excludes `MISC-CLAUDE/`, `CART-BLANCHE-HQ/`, `node_modules/`, `.claude/`, `.agents/`, `READMEs`, and `SKILL.md` files from the graph view.
- **`/wiki` and `/autoresearch` are forbidden from writing under `06-Tasks/**`.** Task management is human-sovereign plus `/save`-only.
- **No skill writes to `CLAUDE.md` wholesale.** The plugin-managed block between the `2ndbrain-mogging:*` markers is regenerated by the installer; everything above the start marker is user-owned.
- **Bidirectional tethering on every project.** Every `05-Projects/<PROJECT>/<PROJECT>.md` links UP (to `Projects-Index` / parent hub) AND DOWN (to sub-projects, key notes). Client work tethers to its org hub; code projects tether to `[[GITHUB]]`.

### Obsidian Tasks syntax

Canonical line (token order is mandatory — the Tasks plugin parses positionally):

```
- [ ] <task text> <priority?> 📅 YYYY-MM-DD <🔁 recurrence?> 🆔 <uuidv4>
```

- Priorities: 🔺 highest · ⏫ high · 🔼 medium · 🔽 low · ⏬ lowest
- Dates: 📅 due · ⏳ scheduled · 🛫 start · ✅ done · ❌ cancelled
- Recurrence: `🔁 every week`, `🔁 every 2 weeks`, `🔁 every month on the 1st`
- 🆔 is a lowercase UUIDv4, mandatory on every new task. Edits preserve it byte-for-byte. Missing UUID on a legacy line is mint-and-log (appended to `Claude-Memory/task-uuid-mints.log`), never rewrite.

Rewriting tokens in the wrong order or dropping the UUID breaks the n8n W1/W2/W3 sync and creates duplicate tasks in Morgen and Notion that cost ~15 minutes of manual deduping to undo.

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
