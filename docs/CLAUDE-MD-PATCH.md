# CLAUDE.md Patch — 2ndBrain-mogging

This document contains the **canonical text** that `2ndBrain-mogging` appends to a vault's `CLAUDE.md` d<person-i>ng install (or via `/aliases init`). Agent 1 of the `/rswarmmax` refactor swarm performs the actual append in Phase B10 — this file is the reference source of truth that agent reads from.

## Contract

- The patch is delimited by HTML comment markers so it can be cleanly re-applied, idempotently updated, or removed without touching any hand-authored content.
- **Start marker:** `<!-- mogging:start -->`
- **End marker:** `<!-- mogging:end -->`
- Both markers MUST appear at the end of the CLAUDE.md file on their own lines, with a single blank line before the start marker and no trailing content after the end marker (except a terminal newline).
- Anything between the markers is owned by the plugin and may be overwritten on upgrade. Everything outside the markers is user-owned and untouched.
- `/aliases update-claudemd` and the plugin installer both read THIS file and write the exact block below verbatim between the markers. Update this file first, then re-run the installer — never hand-edit the markers in a live vault.

## Exact text to append

Copy EVERYTHING between (and including) the two `<!-- mogging:... -->` lines below. Do not strip the markers. Do not collapse blank lines. Do not reformat the tables — Obsidian preview and downstream parsers both rely on the column alignment.

```markdown
<!-- mogging:start -->

## 2ndBrain-mogging (plugin-managed section)

> This section is managed by the `2ndBrain-mogging` Claude Code plugin. It is regenerated on plugin upgrade. Do not hand-edit between the markers — edit `docs/CLAUDE-MD-PATCH.md` in the plugin repo and re-run `/aliases update-claudemd`, OR edit `Claude-Memory/aliases.yaml` directly for entity changes.

### Entity registry

The canonical entity dictionary for this vault lives at `Claude-Memory/aliases.yaml` (a symlink to `~/.claude/projects/<project-slug>/memory/aliases.yaml`). Every `/save`, `/cingest`, and `/wiki` call consults this file BEFORE writing. If an entity appears in a conversation but is not in `aliases.yaml`, the skill either:

1. Auto-classifies it with a confidence score and writes a dry-run plan listing the unresolved name, OR
2. Halts and prompts the user for disambiguation if the name is flagged `ambiguous:` in the registry.

Entities are grouped into four buckets: `people`, `concepts`, `orgs`, `projects`. Each entry has a stable `canonical_id` (snake_case, prefixed by bucket) that never changes even if the display name is renamed — downstream wikilinks route through the ID, not the name.

**Manage entries:**

- Add / rename / split: `/aliases` (interactive) or edit `Claude-Memory/aliases.yaml` directly.
- Validate shape: `python3 -c "import yaml; yaml.safe_load(open('Claude-Memory/aliases.yaml'))"`.
- The file is version-controlled in the repo's `.git` (the symlink target lives under `~/.claude/projects/`, which is separately backed up).

### Regime ownership

Every note file has exactly one regime. Skills check the regime before writing.

| Regime | Who writes it | Can skills rewrite? | Example paths |
|---|---|---|---|
| HUMAN | You, hand-edited | NO — propose diffs only | `03-Permanent/*.md`, poems, essays, project briefs |
| PROJECT | You + agents, negotiated | YES — after diff preview | `05-Projects/**/*.md` index notes, `08-Tasks/TASKS-*.md` |
| SYNC | A bot, round-trip | NO — owned by sync pipeline | Morgen task mirrors, GitHub issue shadows, calendar pins |
| LLM-COMPILED | The plugin, re-derivable | YES — idempotent regen | `03-Permanent/wiki-*.md` re-compiled from `02-Literature/` |

A HUMAN note is never silently rewritten. A PROJECT note is diffed before write. A SYNC note is refused outright unless the caller is the sync pipeline itself (detected by `[bot:*]` commit prefix). An LLM-COMPILED note may be regenerated at any time without approval.

### Scheduled agents

The plugin installs four launchd jobs. Each one invokes Claude Code headlessly and writes a single report file into `00-Inbox/` prefixed with the agent name. Deleting the plist disables the agent.

| Agent | When | Writes to | Purpose |
|---|---|---|---|
| morning | 07:00 local | stdout report (no file) | Review yesterday's transcripts, flag unsaved content |
| nightly | 23:30 local | `00-Inbox/NIGHTLY-<date>.md` | `/tether` audit + `/connect` suggestions |
| weekly | Sunday 18:00 | `00-Inbox/WEEKLY-<date>.md` | `/emerge` pass over `03-Permanent/` |
| health | every 6h | `00-Inbox/HEALTH-<date>.md` | Broken wikilinks, orphan files, missing frontmatter |

Every scheduled write carries commit prefix `[bot:<agent>]` so the n8n 3-way sync skips it (bot-prefix-skip rule is enforced in W1's filter node).

### Routing conventions for `/save` and `/cingest`

When a capture arrives, the skill walks this decision tree — first match wins:

1. **Explicit project flag** (`/save --project <ORG-B>`) → write under `05-Projects/<ORG-B>/` with a dated filename.
2. **Alias hit** on an entity in `Claude-Memory/aliases.yaml` with `confidence: high` → write under the `project:` path on that entity, and tether to the project index.
3. **Alias hit with `confidence: medium` or `needs_review`** → write to `00-Inbox/` with a dry-run plan listing the candidate project(s) and request confirmation.
4. **Ambiguous name** (listed under `ambiguous:` in the registry, or multiple high-confidence matches) → halt, prompt user.
5. **No alias match, sourced content** (URL, PDF, video) → `02-Literature/LIT-<slug>.md` with the source frontmatter, link to any MOC it touches.
6. **No alias match, unsourced thought** → `01-Fleeting/<date>-<slug>.md`.
7. **No alias match, raw capture** → `00-Inbox/<date>-<slug>.md` for later triage.

The decision log for each capture is written to `00-Inbox/.save-decisions/<timestamp>.jsonl` so the classifier's accuracy can be audited and `/aliases` can learn from corrections.

### Public-safety filter

Some entities carry `public_safe: false` in the registry (e.g. private individuals, internal project codenames). When any skill produces an artifact destined for a public channel (README, release notes, issue body, PR description, blog post, social media draft), it filters out every name flagged `public_safe: false`. The skill will either:

- Rewrite with a placeholder (`<contact>`, `<internal-project>`) and show a diff, OR
- Halt and list the flagged names so you can rewrite manually.

Current high-priority `public_safe: false` entities (see `aliases.yaml` for the full list): <PERSON-A>, <PERSON-B>, <PERSON-D>. Never reference these in any public repo artifact.

### Project index note rules

These rules are enforced by `/tether` and the nightly agent. Violations are listed in `00-Inbox/NIGHTLY-<date>.md`:

1. **Filename = folder name.** `05-Projects/FOO/FOO.md`, never `FOO-Index.md`. The wikilink `[[FOO]]` must resolve.
2. **Bidirectional tethering.** Every project index links UP (to parent / MOC-Projects / org hub) AND DOWN (to sub-projects, key notes).
3. **Client work tethers to its org.** Projects built under <ORG-A> or <ORG-B> link the org hub in Related; the org's index lists the project in `## Repos` or `## Projects`.
4. **Code projects tether to `[[GITHUB]]`.** If a project has a cloned repo in `05-Projects/GITHUB/`, it links `[[GITHUB]]` in Related and `GITHUB.md` lists the project under `## Owned By`.
5. **Never orphan on rename.** If an index is renamed, grep the vault for all stale references and update them in the same commit.

### Task syntax

This vault uses the **Obsidian Tasks plugin** (Clare Macrae). The plugin's syntax is the only supported task format. Skills will never introduce Todoist, Notion-database, or raw-checkbox-no-metadata tasks.

```text
- [ ] task text ⏫ 📅 2026-04-15 🔁 every week 🆔 <stable-id>
```

- Priorities: `🔺` highest, `⏫` high, `🔼` medium, `🔽` low, `⏬` lowest.
- Dates: `📅` due, `⏳` scheduled, `🛫` start, `✅` done, `❌` cancelled.
- `🆔 <stable-id>` is required on any task that participates in the 3-way sync. The skill mints a fresh ULID when creating a new task; it never rewrites an existing ID.

### Calendar + task ops default

Calendar and task operations default to **Morgen** (`mcp__morgen__*`). Motion (`mcp__motion*`) is used only for the four feature gaps Morgen lacks in the public API: teammate events, full-text event search, all-day event queries, and calendar management. If you explicitly want Motion for any other reason, pass `--engine motion` on the relevant slash command.

### Anti-drift guarantees

The plugin enforces these invariants on every write. Violations abort the write and surface a diff:

- File size stays under 500 lines.
- Every public API has a typed interface.
- Input validation happens at every system boundary.
- No secrets in source. No `.env` committed. No hardcoded tokens.
- File paths are sanitized against directory traversal.
- Commit messages use present-tense, imperative mood, and include a one-line rationale.

<!-- mogging:end -->
```

## How agent 1 should apply this

Phase B10 of the `/rswarmmax` vault refactor:

1. Read the source file at `docs/CLAUDE-MD-PATCH.md` in this repo.
2. Read `$HOME/Desktop/WORK/OBSIDIAN/2ndBrain/CLAUDE.md`.
3. If the vault's CLAUDE.md already contains `<!-- mogging:start -->`, replace everything between the two markers (inclusive) with the new block. If not, append a single blank line followed by the entire block from this doc.
4. Do NOT touch any text outside the markers.
5. Run `python3 -c "import yaml; yaml.safe_load(open('Claude-Memory/aliases.yaml'))"` to verify the registry is valid after the vault refactor.
6. Commit as `chore(vault): apply mogging CLAUDE.md patch` with no `[bot:*]` prefix (this is a human-initiated refactor, not a scheduled agent write).

## Update procedure

When a future release changes plugin semantics:

1. Edit the fenced code block above. Keep the markers intact.
2. Bump `version` in `Claude-Memory/aliases.yaml` if the registry shape changes.
3. Run `/aliases update-claudemd` in every vault that has the plugin installed — the skill reads this file and rewrites the marker block verbatim.
4. Add a `CHANGELOG.md` entry noting the patch version bump.
