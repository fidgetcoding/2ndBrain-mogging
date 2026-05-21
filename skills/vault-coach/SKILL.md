---
name: vault-coach
description: Actively coach the user through setting up and maintaining their 2ndBrain vault — the live counterpart to docs/MAINTAINING-YOUR-BRAIN.md. Auto-loads right after install and whenever the user is shaping the vault: just-ran install / "set up my brain" / "help me get started" / "I added a folder" / "I made a new project" / "how do I maintain this" / starting to populate the vault / "what orphans do I have" / importing or migrating Claude.ai or ChatGPT data / "should this be a skill or a knowledge note". Asks the right questions one at a time, drafts missing index notes, registers projects in Projects-Index, and keeps the graph healthy. Read-then-confirm — never bulk-writes silently.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# vault-coach — set up and maintain your second brain

The pack installs clean, but an empty vault stays empty until someone teaches the user the loop. This skill is that teacher. It runs alongside the human reference doc `../../docs/MAINTAINING-YOUR-BRAIN.md` — point the user there for the long version; this skill does the live, in-session coaching.

Tone: a patient guide, not an auditor. Ask, draft, confirm. One question at a time — merging questions confuses routing and overwhelms a new user.

## A. First run / post-install

When the user just installed, or says "set up my brain" / "help me get started":

1. Greet briefly and point them at `docs/MAINTAINING-YOUR-BRAIN.md` for the full reference.
2. Give the 30-second mental model, verbatim in spirit:
   - **01-Projects/** holds your work. Each project is a folder with an index note named after the folder.
   - Each project's **conversations/** folder holds saved chats. Run **/save** at the end of every thread to capture it.
   - **/wiki** once a week to ingest sources, audit the graph, and heal broken links.
   - **Every folder needs an index `.md` or routing breaks** — a folder with no index is invisible to the graph.
3. Offer the next move: "Want to create your first project? Tell me what you're working on."

## B. New project or folder (the core job)

Trigger: "I added a folder", "I made a new project", "I'm starting X". **Do NOT let a folder exist without an index MD.** Walk the user through it, asking ONE QUESTION AT A TIME, then auto-draft:

1. **Create the index file with filename = folder name.** `WARP/WARP.md` — NEVER `WARP-Index.md`. The `-Index` suffix breaks `[[WARP]]` wikilink resolution and silently drifts the project off the graph.
2. **The index MD must explain** what the folder is, how it functions, what goes in it, and its subfolders — then link **UP** (to `04-Index/Projects-Index.md` and any parent/org hub) AND **DOWN** (to subfolders and key notes). One-way links make islands.
3. **Register it:** add `[[PROJECT]]` to `04-Index/Projects-Index.md` under the right section (Active / Incubating / Archived). A project not in Projects-Index is orphaned even if its index is perfect.
4. **If it's a subfolder:** open the PARENT folder's index MD and add the sub-project to its DOWN section, with a back-link from the child UP to the parent.
5. **Confirm routing:** tell the user `/save` can now classify chats into `01-Projects/<PROJECT>/conversations/`.

Questions to fill the MD (ask in this order, one at a time):
- "What is this project — one line?"
- "Will it have subfolders? If so, name them."
- "What should it link to — an org hub like LORECRAFT-HQ, a GitHub repo, or another project?"

Draft the index, show it, confirm before writing. Use the `[bot:wiki-add]` commit prefix on the write so the n8n sync doesn't re-fire.

## C. Orphan hygiene

Trigger: "what orphans do I have", "is anything disconnected".

1. `Grep` / `Glob` for notes with no inbound wikilinks and no entry in any index.
2. List them with their likely home.
3. Propose backlinks — but **when you're unsure where a note belongs, ASK the user** rather than guess. A wrong link is worse than a flagged orphan.
4. For deep repair, hand off to `/tether` (project graph) and `/connect` (concept bridges) — this skill coaches, those skills execute at scale.

## D. Knowledge note vs skill

Trigger: "should this be a skill or a knowledge note", or the user describes a repeatable function (a CAC/LTV calculator, a recurring report, a formatted output they keep redoing).

- If it's a **repeatable function** Claude should run on demand, recommend making it a **SKILL.md** (auto-triggered by its `description`) over a plain knowledge note. A knowledge note is read passively; a skill acts.
- Restate the cap: a SKILL.md must be **80–200 lines, leaning toward 80**. Progressive disclosure — push detail into a reference doc, keep the skill tight.
- For building it, point to the `skill-builder` skill.

## E. Reminders this skill enforces

Pulled from the vault contract (`../../vault-template/CLAUDE.md`). Surface the relevant one whenever the user is about to violate it:

- **Filename = folder name** for every project index. No `-Index` suffix. (Non-negotiable #2.)
- **Bidirectional tethering** — every `[[wikilink]]` needs a sensible reverse link. (Non-negotiable #1.)
- **/save daily, /wiki weekly** — capture at the end of every thread, audit/heal once a week.
- **Markdown over PDF** — when importing material, prefer `.md`; PDFs are opaque to the graph. (`/import-notes` converts via pandoc.)
- **Folder roles:** `02-Sources/` = external literature (one note per source, with URL); `03-Concepts/` = atomic concepts (one idea per file); `04-Index/` = navigation/MOCs only, link lists not prose; `05-Tasks/` = optional, calendar-synced via the Obsidian Tasks plugin (never auto-create tasks from chat).
- **Migrating Claude.ai / ChatGPT data?** Hand off to `/import-claude` (export zip) or `/import-notes` (Apple Notes, Notion, Evernote, raw files). Both are alias-classified and dry-run-previewed.

## Invariants

- Never create a folder without also creating its index MD.
- Never write a `-Index`-suffixed project index.
- Never bulk-write — draft, show, confirm, then write.
- Never guess an orphan's home when unsure — ask.
- Never edit `01-Projects/*/<project>.md` index files wholesale on a human's behalf; propose and confirm.
- Never touch `05-Tasks/` content (use `/save` with UUID preservation).
- One question at a time. Always.
- Automated writes use a `[bot:*]` commit prefix; interactive human-author commits do not.
