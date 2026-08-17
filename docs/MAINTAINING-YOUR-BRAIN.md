# Maintaining Your Brain

You just ran `install.sh`. Now what? This is the one doc that explains how to **set up** and **maintain** your second brain after install — the folder model, the daily and weekly habits, and how to bring your old stuff in. If you only read one file, read this one.

The system is your **second brain**, also called the **vault**. It's an Obsidian folder full of markdown notes that a terminal-based Claude (the slash commands `/save` and `/wiki`) reads from and writes to. The more you use it, the better it gets at putting things where they belong.

A note on where the vault lives: the default is `~/MyVault`. Don't put it on your Desktop — macOS protects that folder and the sync and backup scripts break against it.

---

## The one rule that makes everything work

Every folder needs an index `.md` file, and **its filename must equal the folder name**.

- `Project-A/` gets `Project-A/Project-A.md`
- `research/` gets `research/research.md`
- **Never** `Project-A-Index.md`. The `-Index` suffix breaks `[[Project-A]]` link resolution from everywhere else in the vault.

That index file is not a formality. It's how your second brain knows what the folder is. A good index `.md` explains:

- what the folder is
- how it functions and what it does
- how it interacts with other folders
- what kind of info goes in it
- a list of its subfolders

Here's the chain of cause and effect, because it's the whole game:

- **New folder, no index `.md`?** `/save` has no idea what it is and can't route anything into it.
- **Added subfolders but didn't update the parent's `.md`?** `/save` gets slower and misroutes until it discovers them on its own.
- **Index files all current?** Routing is fast and accurate.

The more you save, the more it understands where things go — *as long as the index files are honest about what each folder holds.*

---

## The folder model

```
~/MyVault/
├── 01-Projects/    # one folder per project you actually work on
├── 02-Sources/     # literature — things NOT tied to a project
├── 03-Concepts/    # your own ideas, in your words, distilled from sources
├── 04-Index/       # navigation — teaches the brain how to operate itself
├── 05-Tasks/       # tasks (optional)
└── Claude-Memory/  # aliases + memory (leave it alone)
```

### `01-Projects/` — your actual work

One folder per project. Each project folder contains a `conversations/` subfolder, and **every saved Claude chat about that project lands there.**

```
01-Projects/
└── Project-A/
    ├── Project-A.md       ← index note (filename = folder name)
    ├── conversations/     ← every /save'd chat about Project-A
    └── research/          ← a subfolder you added
        └── research.md    ← its own index note
```

### `02-Sources/` — literature

Things that are worth remembering but **not tied to a project**. A cool fact. Something someone told you. A useful process worth keeping.

Example: there's no project for "a friend you talked to." But if someone tells you something interesting about coding, that's a source — it goes in `02-Sources/`.

### `03-Concepts/` — your ideas

One idea per note, in your own words, linked to related notes. This is where a source turns into your own understanding: you read something in `02-Sources/`, then write the idea that matters as a concept note.

### `04-Index/` — navigation

This is the layer that **teaches your second brain how to operate itself.** Maps of content, the `Projects-Index`, the graph map. When you add a project, this is where you register it.

### `05-Tasks/` — tasks (optional)

Only useful if you sync your Obsidian tasks to a calendar through an API. Most new users don't need it — skip it until you do.

---

## Daily flow: `/save`

At the end of any thread in your terminal (Ghostty), **before you close it**, run:

```
/save
```

It figures out where the conversation belongs and shows you a **confidence score** for the routing. You can also `/save` mid-conversation if you want to capture something before you're done.

The catch: `/save` only routes correctly if your folder index files are set up right. See [the one rule](#the-one-rule-that-makes-everything-work) above. Garbage index files in, garbage routing out.

---

## Adding a new project (or subfolder), step by step

Say you're starting a project called **Project-A**, and inside it you want a **research** subfolder. Here's the exact order:

1. **Create the folder.** `01-Projects/Project-A/`
2. **Create its index `.md`.** `01-Projects/Project-A/Project-A.md` — filename equals folder name. Describe what Project-A is, what goes in it, and how it relates to other folders.
3. **Register it in the index.** Add `[[Project-A]]` to `04-Index/Projects-Index.md`.
4. **If it's a subfolder, update the parent.** Create `01-Projects/Project-A/research/research.md`, then edit `Project-A.md` to mention the `research/` subfolder.
5. **Link up and down.** `Project-A.md` links **up** (to `Projects-Index` / its parent) and **down** (to its subfolders and key notes). `research.md` links back up to `Project-A`.

Only after all of this will `/save` route into `Project-A/` and `Project-A/research/` cleanly.

---

## Cleaning up orphans

As you fill the vault, some notes show up as **orphans** — notes with no links pointing to or from them. They're invisible to the graph. Periodically clean them up:

1. Ask your terminal Claude: **"What orphans do I have in my second brain?"**
2. It identifies them.
3. Ask it to **create the proper backlinks.**

If your folders and index files are set up so projects "understand each other," it links them fast. If it's ever unsure where something goes, **tell it to ask you rather than guess.** A wrong guess is harder to undo than a question.

---

## Keeping Claude-Memory lean

One file in `Claude-Memory/` is worth maintaining: **`MEMORY.md`** — a symlink to `~/.claude/projects/<your-vault>/memory/MEMORY.md`. This is **not** a normal note. It's the index Claude **auto-loads at the start of every session**, and each line is a one-line pointer to a deeper topic file in that same `memory/` folder. (Don't confuse it with anything in `02-Sources/` or `03-Concepts/` — this is Claude's own memory index.)

**Keep it under ~18 KB.** The hard ceiling is ~24 KB; 18 is the target so you have headroom.

**Why it matters:** every line is injected into context on *every* session. Bloat means slower, costlier loads — and the facts you actually need drown in detail that belongs in the linked topic files.

**Why it creeps up:** a Stop hook makes Claude save to memory at the end of every session. Left unchecked, each save tacks on a fat multi-clause line and the file balloons. (A clean ~18 KB index can climb back to 30 KB in a few weeks of normal use.)

**How to keep it lean:**

- **One line per entry.** Emoji + linked title + date + a single clause. All the detail lives in the linked topic `.md`, never inline in `MEMORY.md`. The Stop hook is set to enforce this on every save and to warn you at session end if the file passes ~23 KB.
- **Archive the cold stuff.** "Installed-it, don't-re-suggest" tool/MCP notes and resolved or dormant projects don't need to load every session. Move them to `MEMORY-archive.md` in the same folder — still on disk, still searchable, just not auto-loaded. A 30 KB index trims to ~15 KB this way with nothing lost.
- **When it creeps up, trim + archive.** Tell your terminal Claude: *"trim MEMORY.md to one-line entries and archive the cold ones."* It's a pure relocation — reversible, no facts lost. Back it up first.

Same spirit as cleaning up orphans: a periodic tidy that keeps the brain fast.

---

## Weekly flow: `/wiki`

About once a week, run:

```
/wiki
```

It walks you through a health and self-improvement check — it tells you if it missed anything or made bad guesses while saving during the week, and suggests smarter backlinking. This is the brain improving itself.

The split to remember:

- **`/save` is per-conversation** — your daily capture habit.
- **`/wiki` is the weekly tune-up** — the brain auditing and improving itself.

---

## Migrating your existing Claude.ai data

You don't have to start empty. Two paths, depending on your account.

### Path A — regular account (data export available)

1. Do a proper data export — **download all your data** from Claude.ai.
2. Hand the export to your terminal Claude.
3. Say: **"Here's every conversation I've had. Organize it and create project folders accordingly."**

### Path B — no export available

1. Go into your Claude.ai projects and any artifacts you built (a small tool or document, for example).
2. In each chat, ask it to produce a **detailed markdown (`.md`) file** summarizing exactly what was built or discussed.
3. Copy that markdown into your terminal.
4. Say: **"Here's a summary of what I did on Project-A. Organize it into the brain."**

Either way: conversations go to `conversations/`, and reusable knowledge or assets route to wherever they belong.

### Why markdown, never PDF

Markdown is trivially easy for an AI to read — it's just headers and body text. PDFs carry extra cruft that gets in the way. **Always prefer `.md`.**

---

## Knowledge vs. skill

Not everything is a note. If something is a **repeatable function** you'll trigger often, make it a **skill**, not a knowledge note.

Example: anything you do the same way over and over — a calculation, a formatting routine, a checklist you run each time. Make it a skill `.md` file. Then Claude auto-calls it when it sees a trigger — say the phrase that names it and it jumps straight to the skill.

**Rule:** a skill `.md` should be **80–200 lines max**, and lean toward 80. Short skills get called reliably; bloated ones don't.

---

## One question at a time

When you ask your terminal Claude something, **don't merge two questions into one.** It confuses the routing and the answer. Ask one, get the answer, then ask the next.

---

## Quick reference

| When | Do this |
|---|---|
| End of any chat | Run `/save`, check the confidence score |
| New project | Folder → index `.md` → add to `Projects-Index` → link up + down |
| New subfolder | Folder → its `.md` → update parent `.md` |
| Notes pile up | Ask "what orphans do I have?" → ask it to backlink |
| `MEMORY.md` over ~18 KB | Trim to one-line entries, archive cold ones to `MEMORY-archive.md` |
| Once a week | Run `/wiki` for the self-audit |
| Repeatable function | Make a skill `.md`, 80–200 lines, lean to 80 |
| Asking Claude anything | One question at a time |

That's the whole system. Keep your index files honest, `/save` daily, `/wiki` weekly, and the brain gets smarter the more you feed it.
