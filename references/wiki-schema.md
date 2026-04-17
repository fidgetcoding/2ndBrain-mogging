# wiki-schema.md — canonical rules for 2ndBrain-mogging

This file is the single source of truth for every skill in `skills/*/SKILL.md`. Any skill that writes, reads, or audits the vault must resolve its folder targets, frontmatter keys, link grammar, sec<person-i>ty posture, and git contract from here. If a skill contradicts this doc, the doc wins.

Downstream consumers (all required to reference this file):

- `skills/save/SKILL.md`
- `skills/wiki/SKILL.md`
- `skills/challenge/SKILL.md`
- `skills/emerge/SKILL.md`
- `skills/backfill/SKILL.md`
- `skills/aliases/SKILL.md`
- `skills/autoresearch/SKILL.md`
- `skills/canvas/SKILL.md`
- `skills/tether/SKILL.md`
- `skills/connect/SKILL.md`
- `agents/{morning,nightly,weekly,health}.md`
- `hooks/stop-save.sh`

## 1. Folder contract

The vault follows Nathan's stripped operator layout. The plugin treats each folder as having exactly one writer role plus a set of constraints. Skills that violate the writer role get hard-rejected in their own failure-mode table.

| Folder | Role | Primary writer | Secondary writers | Constraints |
|---|---|---|---|---|
| `01-Conversations/` | Conversation captures, daily notes, scheduled-agent reports | `save` (branches 1–3) | `agents/morning`, `agents/nightly`, `agents/weekly`, `agents/health` | Append-only per file; daily reports live under `01-Conversations/VAULT/reports/`; scheduled agents write here and nowhere else. |
| `02-Sources/` | Source-of-truth notes for external content (articles, videos, transcripts, emails) | `save` (branch 2 `--source`), `autoresearch` | `wiki` (heal only) | Each file must carry `source_url` + `source_type` + `captured` in frontmatter. Body is summary; raw fetched text lives in a `> [!source]` callout or a fenced block. |
| `03-Concepts/` | Refined atomic concept notes | `wiki` | `save` (branch 3, type `p`), `emerge` | One concept per file. Must have ≥1 inbound from a `02-Sources/` note and ≥1 outbound to `04-Index/`. `needs_review: true` on first write; promoted by `wiki` once it has 3+ inbound links. |
| `04-Index/` | Maps of content (MOCs), hub pages, topic indexes | `wiki`, `tether` | `emerge` (weekly only) | Never append freeform text — only link lists + terse one-liners. Must list every concept in its topic cluster; `tether` fails the graph audit if an `03-Concepts/` note has no MOC entry. |
| `05-Projects/` | Project hubs mirroring Claude Projects | `save` (branches 1–3), `tether` | `wiki` (heal only) | Each project folder has an index note where filename matches folder name (`FOO/FOO.md`, never `FOO-Index.md`). Bidirectional links up to `04-Index/MOC-Projects.md` are mandatory. |
| `06-Tasks/` | Obsidian Tasks plugin files + inline tasks | `save` (UUID-preserving edits only) | none | `/wiki` and `/autoresearch` are FORBIDDEN from writing here. `/save` is edit-safe only with strict UUID preservation (§5). No agent writes here. |
| `Claude-Memory/` (vault root) | Plugin working state: aliases, ADRs, manifests, hot context | `aliases`, `save` (ADR branch + backfill manifest), `emerge` (hot.md) | `agents/morning` (hot.md prime) | Not user-facing notes — treat as config. `aliases.yaml` is the canonical alias source; `adr/` holds ADRs; `backfill-manifest.jsonl` is append-only. |
| `.obsidian/` (root sidecar) | Obsidian app config | none (user-owned) | none | Forbidden path (§8). |
| `CLAUDE.md` (vault root) | Vault instructions for Claude Code | user | `wiki` (append-only to "Updated rules" section) | Never rewritten wholesale. New rules are appended with a date heading. |
| `README.md` (vault root) | Human-readable vault overview | user | `wiki` (heal only, edit existing sections) | Never created by a skill if absent — warn instead. |

## 2. Three non-negotiables

These override every skill-local policy. A skill that skips one of these must be treated as broken and halted.

1. **Backup-before-write.** Before overwriting ANY file that already exists on disk, snapshot it to `Claude-Memory/backups/YYYY-MM-DD/HHMMSS--<relpath>.bak`. Preserve directory structure in the backup path (flatten separators with `--`). If the backup write fails (disk full, permissions), abort the primary write. No exceptions.

2. **Stop-hook-jq-merge.** The `Stop` hook payload MUST be merged into existing session state using `jq --slurp 'add'` semantics, never naive concatenation. Raw string append corrupts `Claude-Memory/sessions/<id>.json` silently and breaks `/save --backfill --resume`. If `jq` is unavailable on the system path, the hook prints a WARN and no-ops rather than writing partial state.

3. **n8n-path-filter-update.** Any skill that adds a new vault subtree (new top-level folder, new `05-Projects/<ORG>/<repo>/` with externally-synced tasks) MUST also update the n8n W1 path filter so the new subtree is ingested. The canonical path filter lives in `07-Projects/LORECRAFT-HQ/n8n-workflows/W1-paths.yaml` in the main vault. If that file is inaccessible (no symlink, no vault mounted), the skill prints a TODO row in its report and continues — it does not silently create untracked subtrees.

## 3. Linking rules

Graph density is the product. Each rule below exists to prevent an orphan.

- **Wikilinks only.** Always `[[Note Name]]` or `[[Note Name|Alias]]`. Never raw vault paths (`02-Sources/2026-04-16-<person-i>.md`) in body text — Obsidian renders them but they break on rename.
- **Inbound + outbound minimum.** Every new concept page (anything written into `03-Concepts/`) needs at least one inbound wikilink from its source(s) AND at least one outbound wikilink to a `04-Index/` MOC. Zero-inbound or zero-outbound concept pages fail `/wiki audit` and get flagged in the nightly report.
- **50/50 ambiguity.** If alias classification scores the top two candidates within 10% of each other, the content is ambiguous. Primary file is written to the higher-confidence target with full content. Stub file is written at the secondary target with `stub_of: "[[primary]]"` in frontmatter and a one-line body: `> See [[primary-basename]] — classification was 50/50. Resolved to primary on {{date}}.` Both files carry tag `#ambiguous-routing` so they can be reviewed via query. See §9 for the full rule.
- **Dead-link handling.** When `/wiki heal` or any audit detects a wikilink target that does not resolve (file deleted, renamed without update), the link is rewritten to `~~[[orphaned-target]]~~ <!-- dead: YYYY-MM-DD -->` — strike-through in Obsidian rendering plus an HTML comment carrying the detection date. The comment lets us diff history. Do NOT silently delete the link.
- **Rename propagation.** If a skill renames a note, it MUST grep the vault for all `[[old-name]]` references and update them in the same commit. An unupdated reference is a bug, not a "nice to have".
- **Never link to a folder.** `[[07-Projects]]` is not a link; `[[MOC-Projects]]` is. Folders do not have notes; MOCs do.

## 4. Frontmatter contract

Every note the plugin writes must open with YAML frontmatter. Five fields are universal; per-type additions follow.

### Universal fields (all types)

```yaml
---
title: "Human-readable title"              # required, quote if it contains :
date: 2026-04-16                           # ISO date, required
type: source | concept | synthesis | conversation | adr | moc
tags: [lowercase-hyphenated]                # list, may be empty
aliases: ["Alt Name 1", "Alt Name 2"]       # list, used by Obsidian link autocomplete
---
```

`type` is closed-set; a skill encountering an unknown type value halts with a parse error rather than guessing.

### Per-type additions

**type: source** (goes to `02-Sources/`)

```yaml
source_url: "https://example.com/article"   # required; use [REDACTED] for private Slack etc.
source_type: article | video | podcast | email | transcript | pdf | book
captured: 2026-04-16T14:22:00-04:00         # RFC 3339 with TZ
last_confirmed: 2026-04-16                  # last date a human verified the URL resolves
author: "Name or @handle"                   # optional; use "unknown" if not attributable
```

**type: concept** (goes to `03-Concepts/`)

```yaml
last_confirmed: 2026-04-16                  # required; used by /wiki audit staleness check
needs_review: true                          # auto-true on first write, flipped by /wiki promote
owner: human | llm                          # 'human' locks the note from silent LLM edits
```

**type: synthesis** (cross-concept rollups, also in `03-Concepts/` or `04-Index/`)

```yaml
answers_question: "What is the cheapest path from X to Y?"    # the question this note resolves
sources: ["[[LIT-note-a]]", "[[LIT-note-b]]"]                  # wikilinks to the sources feeding it
```

**type: adr** (goes to `Claude-Memory/adr/`)

```yaml
status: proposed | accepted | superseded
supersedes: "[[ADR-007-old-name]]"           # optional
superseded_by: "[[ADR-012-new-name]]"        # optional; filled when a later ADR overrides this
```

**type: conversation** (goes to `01-Conversations/`): no per-type additions beyond universal. Rely on `source: "claude-cli session <id>"` in the body if needed.

**type: moc** (goes to `04-Index/`): no additions beyond universal. The body is the MOC structure itself.

## 5. Obsidian Tasks plugin syntax

Nathan's task pipeline (Obsidian ↔ Morgen ↔ Notion via n8n W1/W2/W3) is downstream of this exact shape. Rewriting tokens in the wrong order or dropping the UUID breaks sync.

### Canonical line

```
- [ ] <task text> <priority?> 📅 YYYY-MM-DD <🔁 recurrence?> 🆔 <uuidv4>
```

**Token order is mandatory.** The Tasks plugin parses positionally in several render paths. Deviating breaks Morgen tag-sync.

Glyphs:

- Priority: 🔺 highest · ⏫ high · 🔼 medium · 🔽 low · ⏬ lowest
- Dates: 📅 due · ⏳ scheduled · 🛫 start · ✅ done · ❌ cancelled
- Recurrence: `🔁 every week`, `🔁 every 2 weeks`, `🔁 every month on the 1st`
- 🆔 stable identifier, UUIDv4, mandatory on every new task

### UUID rules (non-negotiable)

1. **Every new task gets a 🆔.** Generate with `uuidgen | tr '[:upper:]' '[:lower:]'`. Append AFTER date/recurrence tokens, never inside the body.
2. **Edits preserve 🆔 byte-for-byte.** A rewrite that changes or drops the UUID creates a duplicate task in Morgen and Notion that cannot be silently undone. The fix costs Nathan 15+ minutes of manual deduping.
3. **Missing UUID on a legacy task = mint + log.** If a skill touches a task line that lacks 🆔, it mints one AND appends a line to `Claude-Memory/task-uuid-mints.log` recording (file, line, uuid, timestamp). The mint is a side effect, so it must be auditable.

## 6. Sec<person-i>ty scrub

Every write path — file body AND commit message — passes through this regex panel first. Matches are replaced in-place with `[REDACTED:<TYPE>]`. Matches in commit messages also cause a preview warning row so the user sees what got swapped out.

| Pattern | Type |
|---|---|
| `sk-ant-[A-Za-z0-9_-]{20,}` | `ANTHROPIC_KEY` |
| `sk-proj-[A-Za-z0-9_-]{20,}` | `OPENAI_PROJECT_KEY` |
| `ntn_[A-Za-z0-9]{20,}` | `NOTION_INTEGRATION_TOKEN` |
| `ghp_[A-Za-z0-9]{36,}` | `GITHUB_PAT_CLASSIC` |
| `gho_[A-Za-z0-9]{36,}` | `GITHUB_OAUTH_TOKEN` |
| `github_pat_[A-Za-z0-9_]{22,}` | `GITHUB_PAT_FINE` |
| `AKIA[0-9A-Z]{16}` | `AWS_ACCESS_KEY` |
| `xox[baprs]-[A-Za-z0-9-]{10,}` | `SLACK_TOKEN` |
| `ya29\.[A-Za-z0-9_-]+` | `GOOGLE_OAUTH_TOKEN` |
| `sbp_[A-Za-z0-9]{40,}` | `SUPABASE_KEY` |
| `sk_live_[A-Za-z0-9]{24,}` | `STRIPE_LIVE_KEY` |
| `rk_live_[A-Za-z0-9]{24,}` | `STRIPE_LIVE_RESTRICTED` |
| `v1\.0-[A-Za-z0-9_-]{30,}` | `CLOUDFLARE_API_TOKEN` |
| `eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}` | `JWT` |
| `-----BEGIN (RSA|EC|DSA|OPENSSH|PRIVATE) KEY-----` + body + `-----END ...-----` | `PEM_PRIVATE_KEY` |
| `^[A-Z][A-Z0-9_]+=.+$` inside a block that looks like `.env` (≥3 matching lines in a row) | `ENV_LINE` |

### Nathan-specific PII

- `nate@lorecraft.io` stays as-is in plugin code but is redacted from any note body that would land in a public-sync branch.
- Named collaborators identified as `internal_only: true` in the private aliases registry MUST be redacted from READMEs, release notes, migration docs, or any commit subject. (Memory rule: never reference internal-only collaborators by name in any public repo artifact.)
- Client names flagged `visibility: private` in the same allowlist are redacted the same way. Public mentions are fine only when the allowlist marks them `visibility: public`.

Scrub failure closed: if the regex engine errors (malformed pattern, OOM on huge paste), the write is refused rather than proceeding with partial scrub.

## 7. Git conventions

The vault is a git repo; the mogging plugin ships commits from skills and agents alike. Nathan's `obsidian-tasks-sync` infra uses commit prefixes to distinguish human commits from bot commits for n8n W1 filtering.

### Branch naming

- `wiki-add/YYYY-MM-DD-slug` — new concept, new MOC, or net-new folder scaffolding.
- `wiki-heal/YYYY-MM-DD` — audit fixes: dead links, missing frontmatter, orphan repair.
- `backfill/YYYY-MM-DD` — `/save --backfill` historical transcript ingestion.

Date format is ISO (`YYYY-MM-DD`). Slugs are lowercase, hyphenated, ≤40 chars.

### Commit prefixes (MUST appear as first token in the subject line)

| Prefix | Used by | Purpose |
|---|---|---|
| `[bot:save]` | `save` (all non-backfill branches) | Skip n8n W1 re-fire; flag for human audit. |
| `[bot:save --backfill]` | `save --backfill` | Same as above but trivially filterable in `git log`. |
| `[bot:wiki-add]` | `wiki add`, `connect`, `tether` (new-note paths) | New concept/MOC/link scaffolding. |
| `[bot:wiki-heal]` | `wiki heal`, `nightly audit` fixups | Link repair, frontmatter backfill, orphan dressing. |
| `[bot:backfill]` | `backfill` skill (non-save entry) | Historical content ingestion outside `save`. |

All five prefixes MUST be listed in the n8n W1 filter or the bot will get stuck in a self-retrigger loop. The filter is kept in `07-Projects/LORECRAFT-HQ/obsidian-tasks-sync/config/bot-prefixes.yaml` in the live vault.

### Rules

- **No force-push.** Ever. If a branch is broken, create a new one.
- **No interactive rebase via skill.** `git rebase -i` requires a human at the keyboard.
- **Direct-to-main is allowed** on the vault repo per Nathan's lorecraft-io convention — skills SHOULD still push to a short-lived branch and fast-forward merge so the branch name carries the session context, but they MUST NOT fail if the remote configuration blocks branching (degraded mode: commit to main directly).
- **Never `git commit --no-verify`** or `--no-gpg-sign`. Hooks exist to protect the repo; bypassing them erases their value.

## 8. Forbidden paths (all skills)

Every skill refuses to read, write, or list these paths. Path allowlist check runs BEFORE every `Write`/`Edit`/`Bash`:

```
.obsidian/**
.git/**
node_modules/**
**/.env*
**/credentials*
**/*.key
**/*.pem
**/*.p12
**/.ssh/**
```

Additional per-skill forbidden paths:

- **`/wiki` and `/autoresearch`** are additionally forbidden from writing anywhere under `06-Tasks/**`. Task management is human-sovereign plus `/save`-only.
- **`/save` is the sole exception** for `06-Tasks/` — and even then only edit-safe with strict UUID preservation (§5).
- **No skill writes** to `CLAUDE.md` in the vault root wholesale — only append a dated block to the "Updated rules" section if one exists.

Refusal output format (required):

```
REFUSED: <absolute path> is in the forbidden list (<rule name>).
Suggestion: <sibling legal path if obvious, else "no safe alternative — clarify intent">.
```

## 9. 50/50 wikilink rule (ambiguous classification)

When alias scoring produces two top candidates within 10% of each other, the content gets double-filed — primary at the higher-confidence target, stub at the secondary — with explicit breadcrumbs.

**Primary file** (higher confidence):

- Full content body is written here.
- Frontmatter includes the normal per-type fields plus `ambiguous_with: "[[secondary-basename]]"`.
- Tag `#ambiguous-routing` is appended to `tags`.
- Commit message calls out the ambiguity.

**Stub file** (secondary):

- Body is a single `> See [[primary-basename]] — classification was 50/50 between this project and that one. Resolved to primary on YYYY-MM-DD.`
- Frontmatter includes `stub_of: "[[primary-basename]]"` plus the same `#ambiguous-routing` tag.
- No further content. No auto-promotion. Stub stays stub until a human upgrades it with `/save` branch 2 + explicit destination.

Both files are surfaced in the dry-run preview table so the user can override with `edit` before writing. If the secondary candidate scores below 30% confidence, the 50/50 rule does NOT fire — instead, the skill routes to `00-Inbox/` with a TODO. Stubbing random weak candidates adds noise, not signal.

End of `wiki-schema.md`. Any skill contradicting this file is the bug; fix the skill.
