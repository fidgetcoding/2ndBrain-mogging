---
title: "README"
type: index
owner: human
tags: [guide]
---

# How to lay out your vault

This note is a guide. Read it, steal what you like, then delete it. Nothing in the vault needs it.

The installer gave you an almost empty vault on purpose. Your projects have your names, so it only made the folders the skills need. The rest is up to you, and this page shows the layout that works well.

## What you start with

```
MyVault/
├── 01-Projects/
│   └── VAULT/
│       └── VAULT.md          ← work about the vault itself
├── 02-Library/
│   ├── people/
│   ├── tools/
│   ├── ideas/
│   └── sources/
├── 03-Index/
│   ├── Index.md              ← the master map
│   └── Projects-Index.md     ← every project, listed
├── 04-Tasks/
│   └── TASKS.md              ← the task hub
├── Claude-Memory/            ← a link to Claude's memory for this vault
├── CLAUDE.md                 ← the rules Claude reads every session
├── AGENTS.md                 ← the same rules, for other AI tools
├── SOUL.md                   ← who you are and what you're working toward
└── README.md                 ← this guide
```

Three more things appear on their own, the first time something needs them:

- `01-Projects/MISC/` is the catch-all project. `/save` makes it the first time a chat fits no single project.
- `01-Projects/VAULT/log.md` is the vault log. `/wiki` starts it on its first run. If you already keep a `log.md` somewhere else under `01-Projects/VAULT/`, `/wiki` uses that one.
- `01-Projects/VAULT/REPORTS/` holds the reports from the scheduled agents and `/wiki audit`. The first report makes it.

## Never delete these

The skills, the agents and the installer look for these by name. Keep them, even when they're empty.

- `01-Projects/`
- `01-Projects/VAULT/` and `VAULT.md` (plus `log.md` and `REPORTS/` once they show up)
- `02-Library/` and its four folders: `people/`, `tools/`, `ideas/`, `sources/`
- `03-Index/` with `Index.md` and `Projects-Index.md`
- `04-Tasks/` with `TASKS.md`
- `CLAUDE.md`, `AGENTS.md` and `SOUL.md`
- `Claude-Memory` (the link to Claude's memory for this vault)

Everything else is yours to add, rename and delete. That includes this README.

## The house rules

1. **Folder names are ALL CAPS.** `PODCAST/`, `CLIENTS/`, `HEALTH/`. A name that reads wrong in caps can stay as it is, like `MCPs/`.
2. **Every project folder has a hub note with the same name.** `PODCAST/PODCAST.md`. The matching name is what lets `[[PODCAST]]` work from anywhere in the vault. A name like `PODCAST-Index.md` breaks that.
3. **Saved chats go in `!!conversations/`.** `/save` puts your text chats with AI assistants there. The two `!` sort it to the top of the folder. Keep it for chats only, so reports and audio transcripts live somewhere else.
4. **Park old work in `!ARCHIVE/`.** When something isn't a focus right now, move it into an `!ARCHIVE/` folder at the level where it lived. The archive's note is named after its parent: `CLIENTS/!ARCHIVE/CLIENTS-ARCHIVE.md`. Never call it `!ARCHIVE.md`.
5. **Odds and ends go in `MISC/`.** Any folder can have a `MISC/` subfolder for loose notes. Its note is named after the parent too: `PODCAST/MISC/PODCAST-MISC.md`.
6. **Code lives in `REPO/`.** A product you build gets `<PRODUCT>/<PRODUCT>.md`, a `!!conversations/` folder, and a `REPO/` folder that holds the git checkout.
7. **Rename inside Obsidian.** Obsidian rewrites every link when you rename a note or folder there. Claude's terminal tools work too, as long as they update the links. Renaming in Finder breaks them.
8. **List every project in `03-Index/Projects-Index.md`.** An unlisted project is cut off from the graph. `/vault-coach` adds the line for you.

Why the parent's name on archive and misc notes? Obsidian finds notes by name. Ten notes called `!ARCHIVE.md` would all answer to `[[!ARCHIVE]]`. With the parent's name in front, each one is unique, and `[[MISC]]` always means the catch-all.

## The structure grid

| Folder | What goes in it | Example |
|---|---|---|
| `01-Projects/<PROJECT>/` | One project: its hub note and its work | `PODCAST/PODCAST.md` |
| `<PROJECT>/!!conversations/` | Your saved text chats with AI about it | `PODCAST/!!conversations/2026-11-05-guest-ideas.md` |
| `<PROJECT>/notes/` | Notes and sources written for it | `PODCAST/notes/episode-outline.md` |
| `<PROJECT>/assets/` | Images, PDFs and media | `PODCAST/assets/cover-art.png` |
| `<PRODUCT>/REPO/` | The git checkout of something you build | `TODO-APP/REPO/` |
| `<PARENT>/!ARCHIVE/` | Things that aren't a focus right now | `CLIENTS/!ARCHIVE/CLIENTS-ARCHIVE.md` |
| `<PARENT>/MISC/` | Loose notes inside a folder | `PODCAST/MISC/PODCAST-MISC.md` |
| `01-Projects/MISC/` | The catch-all, for chats that fit no single project | `MISC/!!conversations/2026-11-05-quick-question.md` |
| `01-Projects/VAULT/` | Work about the vault: its log and reports | `VAULT/REPORTS/audit-2026-11-05.md` |
| `02-Library/people/` | One note per person | `people/jane-doe.md` |
| `02-Library/tools/` | One note per tool, app or service | `tools/obsidian.md` |
| `02-Library/ideas/` | One idea per note, in your own words | `ideas/spaced-repetition.md` |
| `02-Library/sources/` | Articles, videos and books no single project owns | `sources/SRC-2026-11-05-how-memory-works.md` |
| `03-Index/` | Maps: lists of links that point at your notes | `03-Index/Music-Index.md` |
| `04-Tasks/` | Task files for the Obsidian Tasks plugin | `04-Tasks/TASKS-PODCAST.md` |

## Example: a small vault

Two projects, nothing fancy.

```
01-Projects/
├── PODCAST/
│   ├── PODCAST.md
│   ├── !!conversations/
│   ├── notes/
│   └── assets/
├── HEALTH/
│   ├── HEALTH.md
│   └── notes/
└── VAULT/
    └── VAULT.md
```

## Example: a busier vault

Projects grouped under bigger folders, with code, an archive and a catch-all.

```
01-Projects/
├── CLIENTS/
│   ├── CLIENTS.md
│   ├── ACME/
│   │   ├── ACME.md
│   │   ├── !!conversations/
│   │   └── notes/
│   └── !ARCHIVE/
│       ├── CLIENTS-ARCHIVE.md
│       └── OLD-CLIENT/
│           └── OLD-CLIENT.md
├── PRODUCTS/
│   ├── PRODUCTS.md
│   └── TODO-APP/
│       ├── TODO-APP.md
│       ├── !!conversations/
│       └── REPO/              ← the git checkout
├── PODCAST/
│   ├── PODCAST.md
│   ├── !!conversations/
│   └── MISC/
│       └── PODCAST-MISC.md
├── MISC/                      ← the catch-all, made by /save
│   ├── MISC.md
│   └── !!conversations/
└── VAULT/
    ├── VAULT.md
    ├── log.md
    └── REPORTS/
```

A group folder like `CLIENTS/` gets a hub note too, and that note links down to each project inside it.

## Where to go next

- Run `/vault-coach` in Claude Code. It walks you through your first projects one question at a time.
- Open [[Projects-Index]] to see what's listed, and [[Index]] for the master map.
- Done with this guide? Delete it. The installer won't put it back.
