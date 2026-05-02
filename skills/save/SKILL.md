---
name: save
description: Capture conversation content into the 2ndBrain Obsidian vault with alias-driven classification, dry-run previews, and safe routing. Supports four entry branches — whole conversation, specific passage, dictated note, and ADR — plus a `--backfill` mode that ingests historical session-*.jsonl transcripts. Every write is security-scrubbed, classification-transparent, and commit-prefixed `[bot:save]` so n8n W1 does not re-fire.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# save — conversation capture into 2ndBrain

Shared schema: see `../references/wiki-schema.md` (source of truth for frontmatter keys, folder roles, and linking grammar used by both `save` and `wiki`).

`save` is the single canonical entry point for "commit this conversation (or this slice of it, or this thing I just dictated) to the vault." It replaces every ad-hoc "just append to Inbox" habit. It is classification-first, preview-before-write, and append-only toward existing notes — never overwrite an existing file without showing the diff and getting explicit approval.

## 1. Entry prompt

`/save` with no args takes the **FAST PATH**: branch 1 (whole conversation), depth 3 (full transcript), tool-call traces ON, artifacts ON. No menu. No Q&A. Skip directly to classification (§2) → preview (§3) → write/commit. The user has run this enough times that the menu is friction; the answer is always `1` then `3yy`.

The menu is still reachable explicitly:

- `/save menu` — print the menu and wait for `1..5`.
- `/save 2`, `/save 3`, `/save 4` — jump straight to that branch (no menu shown).
- `/save 1 --ask` — branch 1 but with the original Q&A (rare; only when defaults are wrong for this one capture).

The menu, when shown, MUST be exactly:

```
What are you saving?
  1. Whole conversation      — summary, transcript, decisions, artifacts
  2. Specific passage        — quote/excerpt from this thread with commentary
  3. Dictated note           — fresh thought, not tied to transcript
  4. ADR (Architecture Decision Record) — durable engineering decision
  5. Exit
```

If the user types a number not in `1..5`, re-prompt. If they describe the content instead of picking (only relevant when they explicitly invoked `/save menu`), infer the branch but announce the inference (e.g., "Reading that as branch 2 — specific passage. Confirm?") and wait for `y`.

## 2. Aliases as classification source

Before routing any content, load `Claude-Memory/aliases.yaml` from the vault root via `Read`. The aliases file maps natural-language signals to canonical vault destinations. Schema recap (full definition in `../references/wiki-schema.md`):

```yaml
aliases:
  - key: <person-h>
    names: [<person-h>, <person-h>, <project-b>, <project-c>]
    destination: 05-Projects/MMA/<PROJECT-B>/<PROJECT-B>.md
    tags: [mma, client, <person-h>]
    confidence_boost: 0.15
  - key: morgen-mcp
    names: [morgen mcp, morgen-mcp, morgen bot, w1, obsidian-tasks-sync]
    destination: 05-Projects/<ORG-A>/morgen-mcp.md
    ...
```

Classification procedure:
1. Tokenize the incoming content (user text + any tool-call titles).
2. Score each alias by (a) exact-name hit, (b) substring hit, (c) frontmatter-tag overlap, (d) co-occurrence with already-confirmed keys in the same chunk.
3. Weight with `confidence_boost`.
4. Return the top candidate plus any candidate with score within 10% of the top — these become the ambiguity set.

### The 50/50 wikilink rule

If the top two candidates score within 10% of each other, the content is AMBIGUOUS. The skill MUST NOT pick one silently. Instead:

1. Write the full content to the higher-scored destination (the "primary").
2. Create or append a short stub at the second destination containing:
   ```
   > See [[primary-note-basename]] — classification was 50/50 between this project and that one. Resolved to primary on {{date}}.
   ```
3. Call out the stub in the dry-run preview so the user can flip the decision before `y`.

This prevents two failure modes at once: unflagged misfiling (the stub breadcrumb always shows where content went) and lossy routing (user can flip the decision with one keystroke).

## 3. Dry-run preview (mandatory, all branches)

Before any `Write` or `Edit`, print a table:

```
┌───────────────────────────────┬────────────────────────────────────────────────────┬──────────────┐
│ Signal                        │ Destination                                        │ Confidence   │
├───────────────────────────────┼────────────────────────────────────────────────────┼──────────────┤
│ "<person-h>", "<project-c>"   │ 05-Projects/MMA/<PROJECT-B>/…/2026-04-16.md        │ 0.88         │
│ "stripe webhook" (ambiguous)  │ 05-Projects/<ORG-A>/stripe-notes.md  [stub]   │ 0.41         │
│ "tax deduction"               │ 05-Projects/LEGAL-FINANCE/tax-notes-2025.md        │ 0.72         │
└───────────────────────────────┴────────────────────────────────────────────────────┴──────────────┘

Commit on all writes: [bot:save] capture <person-h> session 2026-04-16
Proceed? (y/n/edit)
```

`edit` drops the user into a mini-loop where they can re-map any row (`row 2 → <ORG-A>/stripe.md`). Only `y` triggers writes. `n` aborts cleanly with zero side effects.

### Auto-commit when nothing is ambiguous

The `Proceed? (y/n/edit)` prompt is **skipped entirely** — the skill writes + commits without asking — when ALL of the following are true:

- No 50/50 ambiguity row (no `[stub]` entries in the table).
- No security-scrub redactions fired (§9 found nothing).
- No destination is blocked by `owner: human` frontmatter.
- No forbidden-path violations (§13).
- The top classification candidate is at least 0.60 confidence AND the second candidate is below 0.40 (clear winner, no near-tie).

When auto-committing, the skill still prints the preview table after the fact, plus the commit SHA, so the user can see what landed. Auto-commit is the default-default — the explicit `Proceed? (y/n/edit)` prompt fires only when at least one of the above flags trips. To force the prompt regardless, pass `--confirm` (e.g., `/save --confirm`).

## 4. Branch 1 — Whole conversation

**Defaults (the fast path, no Q&A):**

- Depth 3 — full transcript preserved.
- Tool-call traces: ON.
- Artifacts: ON (any files written this thread are listed with absolute paths + one-line purpose).

These match what the operator picks every time. Skip directly to classification + preview + write.

Behavior:

1. Classification pass against `aliases.yaml`.
2. Print preview table (§3).
3. Auto-commit if no flags fire (§3 auto-commit rule); else prompt `y/n/edit`.
4. On write: split per depth-3 layout — `02-Sources/LIT-conversation-<slug>-<date>.md` (the canonical full-transcript file) plus a pointer note in `01-Conversations/<project-mirror>/YYYY-MM-DD-<slug>.md` that wikilinks to the LIT mirror.

**Q&A tree (only on `/save 1 --ask`):**

1. "Summary depth? 1=headlines, 2=decisions-and-why, 3=full transcript preserved." Default 3.
2. "Include tool-call traces? (y/n)" Default y.
3. "Include artifacts emitted in this thread? (y/n)" Default y.

Frontmatter for the primary capture file:

```yaml
---
title: "Conversation — <short description>"
date: 2026-04-16
type: source
source: "claude-cli session <session-id>"
tags: [conversation, <alias-tags...>]
related: [[<alias destinations as wikilinks>]]
---
```

## 5. Branch 2 — Specific passage

1. "Paste the passage (end with a single line containing `---END---`)."
2. "One-line why this matters?" — becomes the note's lede.
3. Classification + preview + write.
4. Append rather than overwrite if the destination file already exists; new block starts with `## <date> — <short title>` so the file remains chronological.

## 6. Branch 3 — Dictated note

1. "Is this a fleeting thought, a source-style capture, or a permanent atomic note? (f/l/p)"
2. Based on answer, route to `02-Sources/` (for `f` and `l`) or `03-Concepts/` (for `p`) with the corresponding filename convention from `CLAUDE.md` (never the root). The pre-mogging `01-Fleeting/` and `03-Permanent/` folders were killed during the 2026-04-16 mogging refactor — fleeting thoughts now land in `02-Sources/` alongside other source notes. Source captures use `type: source`; concept captures use `type: concept` (per `docs/PARSING-GUIDE.md` decision table — the canonical type set is `source | concept | index | conversation | adr | synthesis`).
3. Still run alias classification on the content to propose `related: []` wikilinks in frontmatter. Show them in the preview so the user can accept/edit.

## 7. Branch 4 — ADR

ADRs are the one branch with a rigid template. Ask:

1. "ADR number?" — auto-suggest by scanning `Claude-Memory/adr/` with `Glob` for `ADR-*.md` and incrementing the max.
2. "Title?"
3. "Status? (proposed / accepted / superseded)"
4. "Context (what's the pressure)?"
5. "Decision (what we're doing)?"
6. "Consequences (what breaks / what we accept)?"

Write to `Claude-Memory/adr/ADR-<nnn>-<slug>.md`. Auto-link in `Claude-Memory/adr/INDEX.md`. If `superseded`, also link the new ADR from the old one (bidirectional tether per vault rules).

## 8. Obsidian Tasks plugin syntax (06-Tasks writes)

Anything the skill emits into `06-Tasks/` (any branch, any path under that prefix) MUST obey the plugin grammar — the operator's entire task pipeline is downstream of this file's exact shape.

Required grammar:

```
- [ ] <task text> <priority?> 📅 YYYY-MM-DD <🔁 recurrence?> 🆔 <uuidv4>
```

Priority glyphs: 🔺 highest · ⏫ high · 🔼 medium · 🔽 low · ⏬ lowest.
Dates: `📅` due · `⏳` scheduled · `🛫` start · `✅` done.
Recurrence example: `🔁 every week`, `🔁 every 2 weeks`, `🔁 every month on the 1st`.

### UUID preservation rule

On edit of an existing task line, the skill MUST preserve the `🆔 <uuid>` verbatim — byte-for-byte. The UUID is the stable join key for the n8n 3-way sync (Obsidian ↔ Morgen ↔ Notion). Rewriting it creates a duplicate in Morgen and Notion that cannot be silently undone.

On create of a new task line, generate a fresh UUIDv4:

```bash
uuidgen | tr '[:upper:]' '[:lower:]'
```

Insert it as the final trailing token after the date/recurrence tokens. Never as a prefix, never inside the body.

## 9. Security scrub (every write, every branch, no exceptions)

Before any content is written, pipe it through this regex panel and replace matches with `[REDACTED:<TYPE>]`:

| Pattern                                      | Type                      |
|----------------------------------------------|---------------------------|
| `sk-ant-[A-Za-z0-9_-]{20,}`                  | `ANTHROPIC_KEY`           |
| `ntn_[A-Za-z0-9]{20,}`                       | `NOTION_INTEGRATION_TOKEN`|
| `ghp_[A-Za-z0-9]{36,}` / `github_pat_[\w]+`  | `GITHUB_PAT`              |
| `AKIA[0-9A-Z]{16}`                           | `AWS_ACCESS_KEY`          |
| `xox[baprs]-[A-Za-z0-9-]{10,}`               | `SLACK_TOKEN`             |
| `sk_live_[A-Za-z0-9]{24,}`                   | `STRIPE_LIVE_KEY`         |
| `eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}` | `JWT` |
| Morgen API keys (`morgen_[A-Za-z0-9]{30,}` or known prefix)     | `MORGEN_KEY` |
| Any line matching `^[A-Z][A-Z0-9_]+=.+` inside content that looks like `.env` | `ENV_LINE` |

If ANY match fires, the preview table MUST add a row:

```
⚠ Security scrub: 3 secrets redacted (ANTHROPIC_KEY×1, GITHUB_PAT×2). Content sanitized before write.
```

Redactions apply to BOTH file content and commit messages. The skill never emits a real secret to git, even in a message.

## 10. Commit prefix

All commits from this skill MUST use prefix `[bot:save]` at the start of the commit subject line. This is the same contract the `obsidian-tasks-sync` repo uses to skip n8n W1 re-processing. Example:

```
[bot:save] capture <person-h> session 2026-04-16
```

If the user runs the skill outside a git repo (rare — the vault is not a repo), print a WARN line and continue writing files, but do not `git commit`.

## 11. Never auto-fire on Stop hook

The skill is opt-in. It MUST NOT be wired into the `Stop` / `SessionEnd` hook by default. A user wanting automatic capture runs:

```
/save --auto
```

which records intent for the CURRENT session only and prints a one-line confirmation. The Stop hook checks for that intent flag and, if present, runs branch 1 with depth 2, `include-tool-calls=n`, `include-artifacts=y`. If the flag is absent, Stop does nothing. This is to avoid the "wait I didn't want you to save that" footgun.

## 12. `--backfill` flag

`/save --backfill` ingests historical Claude CLI transcripts into the vault. Source path:

```
~/.claude/projects/<vault-encoded-path>/session-*.jsonl
```

`<vault-encoded-path>` is Claude Code's slug for the absolute vault path — leading slash replaced with `-`, every remaining `/` replaced with `-`. Derive it at runtime from `$VAULT_ROOT` (e.g. `/Users/nathandavidovich/Desktop/BRAIN2` → `-Users-nathandavidovich-Desktop-BRAIN2`). Do NOT hardcode a vault-specific slug in this file — the vault may be renamed or moved.

Pipeline:

1. `Glob` all `session-*.jsonl` under the project dir.
2. For each file: parse JSONL, extract user/assistant turns only (skip tool-output noise unless `--include-tools`).
3. **Chunked summarize** for any session with >20k tokens: split on `Stop` boundaries, summarize each chunk, then summarize the summaries. Never send a >128k-token body to a single LLM call.
4. **Dedup.** Compute SHA-256 of normalized content AND an embedding for each chunk. Skip any chunk whose SHA-256 exists in `Claude-Memory/backfill-manifest.jsonl` OR whose embedding cosine-similarity is ≥ 0.92 against an already-captured chunk.
5. **Rate limit** to ≤ 20 concurrent summarization calls. Use a semaphore, not a fire-and-forget loop.
6. **Cost estimate before apply.** Print:
   ```
   Backfill scope: 412 sessions, ~8.3M input tokens, ~1.1M output tokens after dedup.
   Estimated cost: $4.20 (Sonnet) / $0.85 (Haiku mixed).
   Apply? (y/n)
   ```
   Nothing runs until the user types `y`.
7. **`--resume` for kill-9 recovery.** The manifest at `Claude-Memory/backfill-manifest.jsonl` is append-only — one line per (session-id, chunk-index, sha256, destination). On `--resume`, the skill reads the manifest, skips everything already captured, and picks up from the first un-captured chunk. A kill during step 4 or 5 is safe; the next run continues cleanly.

Backfill commits use `[bot:save --backfill]` as the prefix so they're still W1-transparent but trivially filterable in `git log`.

## 13. Failure modes

| Failure                                                | Detection                                | Recovery                                                                 |
|--------------------------------------------------------|------------------------------------------|--------------------------------------------------------------------------|
| `aliases.yaml` missing or malformed                    | YAML parse error, file not found         | Abort before any write; print path + parse error; suggest `/wiki add` to create initial alias set. |
| Destination file exists but is owned by a human (frontmatter `owner: human`) | Read frontmatter before write | Skip write, route to `02-Sources/save-blocked-2026-04-16-<slug>.md` instead (the pre-mogging `00-Inbox/` was killed), and note the block in the commit. |
| Secret detected in content                             | Regex panel §9                           | Redact inline, add warning row in preview, continue.                     |
| Secret detected in commit message                      | Regex panel §9                           | Redact in message, print a warning, continue.                            |
| UUID missing on an existing task                       | Task regex with no `🆔` token            | Mint a new UUIDv4 and append it; log the mint event to `Claude-Memory/task-uuid-mints.log`. |
| User picks `n` at the preview                          | Explicit abort                           | Exit cleanly; no partial writes; no commit.                              |
| Write to forbidden path (`.env`, `.git/`, `node_modules`, root `CLAUDE.md`) | Path allowlist check | Hard-refuse, print the blocked path, suggest a legal sibling.            |
| 50/50 ambiguity with NO second candidate above 30% confidence | Score threshold | Fall through to `02-Sources/` with a TODO note (the pre-mogging `00-Inbox/` was killed); do NOT stub a random second file. |
| Backfill manifest corrupt                              | JSONL parse fail on `--resume`          | Move corrupt manifest to `.bak`, refuse to proceed without explicit `--force-reindex`. |

## 14. Non-goals (explicitly out of scope)

- `save` does not write to `05-Projects/*/index.md` files. Project index maintenance is the `wiki` skill's job.
- `save` does not touch `06-Tasks/` other than obeying the plugin grammar when the user-provided content happens to land there. It never auto-creates tasks from conversational intent.
- `save` does not run audits, heals, or contradiction detection — that is also `wiki`.
- `save` does not touch `.env*`, `.claude/settings.json`, or anything outside the vault tree.

Reference: `../references/wiki-schema.md` is the binding definition for every frontmatter key, folder role, and linking grammar token referenced above.
