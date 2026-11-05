---
title: "VAULT"
date: 2026-11-05
type: project
tags: [vault, meta]
status: active
related: [[Projects-Index]]
---

# VAULT

Work about the vault itself. Skills and agents write their logs and reports here, never at the vault root.

## What lives here

- `log.md` — the append-only vault log. `/wiki` starts it on its first run and adds one line per run after that. Anything may append a dated entry; nothing rewrites one. If your log already lives in a subfolder here (say `VAULT/MISC/log.md`), `/wiki` keeps using that one.
- `!!conversations/` — text chats about the vault (architecture sessions, graph repairs). Chats only. `/save` makes it the first time it saves one.
- `REPORTS/` — daily, audit, weekly and health reports from the scheduled agents and `/wiki audit`. The first report makes the folder. Never in `03-Index/` or `!!conversations/`.

## Related

- Parent index: [[Projects-Index]]
