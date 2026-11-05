---
title: "log"
type: index
owner: wiki
last_confirmed: 2026-04-20
---

# log

The vault's append-only log. It lives in `01-Projects/VAULT/` so the vault root holds only `CLAUDE.md`, `AGENTS.md` and `SOUL.md`. Agents may append dated entries; they must not rewrite history.

Format each entry as:

```
## YYYY-MM-DD
- what happened, one line
```
