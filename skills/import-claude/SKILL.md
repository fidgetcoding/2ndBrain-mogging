---
name: import-claude
description: Walk the user through a one-shot import of their full Claude.ai (or ChatGPT) data export into the 2ndBrain-mogging vault. Unzip → inspect → bucket conversations by source project/topic → write full-fidelity captures to 01-Projects/<PROJECT>/conversations/<sub>/, factual LIT-* mirrors to 02-Sources/, and linked concept stubs to 03-Concepts/. Alias-classified, dry-run-previewed, append-only.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# import-claude — bring your Claude / ChatGPT history into the vault

One-shot ingest of a conversational AI data export. Designed to run once per export dump, not continuously. For ongoing per-session ingest, `/save` is the daily driver; for Claude Code session JSONLs specifically, `/backfill` is the right tool.

## When to use this skill

- You just exported your history from **Claude.ai** (Settings → Privacy → "Download my data") and have the zip.
- You just exported your history from **ChatGPT** (Settings → Data controls → "Export data") and have the zip.
- You have ad-hoc `.json` / `.txt` conversation dumps you want to route into the vault with the same rules.

## When NOT to use it

- For Claude Code terminal sessions: use `/backfill` — those live as JSONL in `~/.claude/projects/`, not as a web-export zip.
- For a single conversation in a single chat window: `/save` is faster.

## Pre-requisites

1. A mogged vault (has `02-Sources/`, `03-Concepts/`, `01-Projects/`, and `CLAUDE.md` at its root).
2. The export zip on disk. Easiest path: drop it in `~/Downloads/`.
3. The helper script has already staged the zip: `bash scripts/import-claude.sh` unzips it to `<vault>/.import-staging/<timestamp>-claude/`. If the user hasn't run it yet, point them at it first.

## Flags

| Flag | Purpose |
|---|---|
| `--scan` | Inventory only. Count conversations, estimate size, group by apparent project/topic. No writes. |
| `--dry-run` | Full classification pass in memory. Show every file it would write. Touches no disk. Default. |
| `--apply` | Execute the writes. Requires explicit `yes` confirmation after the dry-run preview. |
| `--since YYYY-MM-DD` | Only ingest conversations whose latest message is on/after this date. |
| `--project <name>` | Restrict to one Claude.ai project / ChatGPT folder. |
| `--resume` | Read `Claude-Memory/import-claude-state.json`, skip already-processed conversations, continue from the last incomplete one. |

## Pipeline

### 1. Locate the staging dir

Look for `<vault>/.import-staging/*-claude/` (most recent). If missing, instruct the user to run `bash scripts/import-claude.sh` first.

Expected shape (Claude.ai export):

```
.import-staging/<ts>-claude/
├── conversations.json        ← all chat conversations
├── projects.json             ← Claude.ai project definitions
└── users.json                ← user metadata
```

ChatGPT export shape:

```
.import-staging/<ts>-claude/
├── conversations.json
├── chat.html
├── message_feedback.json
├── model_comparisons.json
└── user.json
```

### 2. Inventory

Parse `conversations.json` only — never load messages into memory yet. For each conversation record, collect:

- conversation UUID / slug
- title
- created / updated timestamps
- message count
- source project / folder (if any)
- rough character count of the message payload

Emit a summary: `N conversations, grouped into P projects / folders, Q with no project`. Show the top 10 projects by volume so the user can sanity-check.

### 3. Alias-classify each conversation

Apply the same alias lookup `/save` uses. Read `Claude-Memory/aliases.yaml`; for each conversation:

- If the title, earliest system prompt, or project name matches an alias → route to that project's folder in `01-Projects/<PROJECT>/conversations/<sub>/`.
- If no alias match → route to `01-Projects/INCUBATOR/conversations/UNCATEGORIZED/` and flag for user review.

Never invent a project folder that doesn't exist in `01-Projects/` without asking first.

### 4. Write conversation captures

For each kept conversation, write:

**Primary (`01-Projects/<PROJECT>/conversations/<sub>/YYYY-MM-DD-<slug>.md`):**

```yaml
---
title: "<conversation title>"
date: <latest message date>
type: conversation
owner: human
source: claude.ai / chatgpt
source_id: <uuid>
tags: [imported, <project-tag>]
related: [[<project-index>]]
---
```

Then the full-fidelity conversation (user turns + assistant turns interleaved, no truncation). `owner: human` blocks future auto-mutation.

**Mirror (`02-Sources/LIT-conversation-<slug>-<date>.md`):**

A factual-only summary — what was discussed, what was decided, what was asked about. No interpretation. Same frontmatter, `type: source`.

### 5. Spawn concept stubs (cautiously)

For each conversation, extract 1-3 atomic ideas that could become concept notes. For each:

- Check if a `03-Concepts/<slug>.md` already exists.
- If yes → append a reference line under `## Mentions`; don't mutate the body (respect `owner: human`).
- If no → create a stub with `owner: wiki`, `type: concept`, and a single paragraph in the user's voice.

### 6. Backlink updates

- Update the project index in `01-Projects/<project>/<project>.md` with a new line under `## Conversations` (create the section if missing).
- Update `04-Index/Projects-Index.md` if a new project-mirror folder under `01-Projects/<PROJECT>/conversations/` (post-2026-05-08; `01-Projects/<PROJECT>/conversations/` was retired) was created.

### 7. State checkpoint

After each conversation successfully written, record its UUID in `Claude-Memory/import-claude-state.json`. `--resume` reads this file to avoid duplicate work if the run is interrupted.

### 8. Summary report

Emit:

- `N conversations written`
- `M LIT-* mirrors written`
- `K concept stubs created`
- `S concept references appended`
- `U conversations flagged UNCATEGORIZED for review`

Tell the user to run `/tether` next — it fixes any missed backlinks.

## Guardrails

- **Never** overwrite an existing `owner: human` file. If a collision happens, write the new capture under a `-<timestamp>` suffix and flag it.
- **Never** write inside `01-Projects/<project>/<project>.md` directly (that file is human-owned by CLAUDE.md contract).
- **Always** dry-run first. Require explicit `yes` before `--apply`.
- **Always** scrub secrets: apply the same regex set as `/save` (API keys, tokens, .env content) before committing the conversation text to disk.
- Commits use the `[bot:import-claude]` prefix.

## Typical invocations

```
/import-claude --scan
/import-claude --dry-run
/import-claude --apply
/import-claude --since 2026-01-01 --project "LORECRAFT-HQ" --apply
/import-claude --resume
```

## Related

- `/save` — single-conversation capture (daily driver)
- `/backfill` — Claude Code terminal session JSONLs
- `/import-notes` — Apple Notes / OneNote / Notion / Evernote / raw files
- [PARSING-GUIDE.md](../../docs/PARSING-GUIDE.md) — the categorization rules that drive every routing decision
