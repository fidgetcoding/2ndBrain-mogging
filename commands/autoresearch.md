---
description: "Fetch a URL (or resolve a literature TODO), summarize it into 02-Library/sources, and spawn linked concept stubs in 02-Library/ideas."
---

Read the `autoresearch` skill at `skills/autoresearch/SKILL.md`, then run the workflow. Invocation is `/autoresearch "topic" [--rounds N=3] [--depth shallow|standard|deep] [--existing-check]`. The skill runs Round 0 (existing-vault check), Round 1 (broad search, 3–5 angles), Round 2 (gap fill), and optional Round 3 (synthesis check), emitting per-source `02-Library/sources/SRC-YYYY-MM-DD-{slug}.md` source notes (factual-only, Karpathy rule), per-concept updates in `02-Library/ideas/`, and a master synthesis at `02-Library/ideas/{topic-slug}.md`. Every WebFetch obeys the §"URL Safety" SSRF block list and scheme whitelist. Commit prefix `[bot:autoresearch]`.
