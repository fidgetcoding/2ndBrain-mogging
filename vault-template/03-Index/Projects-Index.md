---
title: "Projects-Index"
date: 2026-04-20
type: index
tags: [index, projects]
---

# Projects-Index

The map of active projects in this vault. Every project folder in `01-Projects/` should be listed here — if it's not in this index, it's orphaned from the main graph.

## Active projects

- _none yet — add a line for each project you create_

## Vault

- [[VAULT]] — work about the vault itself: its log and the agents' reports

The catch-all project (`01-Projects/MISC/` unless `Claude-Memory/aliases.yaml` names another) doesn't exist yet. `/save` makes it, and adds its line here, the first time a chat belongs to no single project.

## How to add a new project

1. Make a new folder under `01-Projects/` whose name is the project's canonical handle, in ALL CAPS (e.g. `MY-PROJECT/`).
2. Inside that folder, create `MY-PROJECT.md` — the filename MUST match the folder name exactly (so `[[MY-PROJECT]]` resolves from anywhere in the vault).
3. Add a line under **Active projects** above: `- [[MY-PROJECT]] — one-sentence description`.
4. Link back from the project's `Related:` section to this index (`[[Projects-Index]]`).

`/vault-coach` does all four for you. See `CLAUDE.md` for the full project-index rules.
