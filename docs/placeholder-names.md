# Placeholder Names

## What you're looking at

This skill pack is an **operator's personal vault tooling**. It was extracted from a live Obsidian + Claude Code second brain that has been in daily use since early 2026, and the examples, scripts, and memory shards in this repo were written against real people and real client projects.

Before this repo was made public, every real personal name and every private client-project name was redacted and replaced with a **stable placeholder**. You will see tokens like the following throughout the skills, commands, agents, tests, and sample memory:

- `<PERSON-A>`, `<PERSON-B>`, `<PERSON-C>`, ... — individual humans (collaborators, clients, cofounders, teammates, vendors)
- `<PEER-A>`, `<PEER-B>`, ... — peers in ongoing conversations where the human is not a client but is named in the transcript
- `<PROJECT-A>`, `<PROJECT-B>`, ... — private client projects, product names, or internal codenames that the operator does not want associated with their public-facing work

## The rules

1. **Stable.** The same real name always maps to the same placeholder across every file in the repo and across every commit in the history. If you see `<PERSON-D>` in `skills/save/SKILL.md` and `<PERSON-D>` in `tests/fixtures/sample-vault/Claude-Memory/aliases.yaml`, they are the same real person.
2. **One-way.** The mapping from real name to placeholder is **private** and is not included in this repository. It lives in the operator's local `Claude-Memory/aliases.yaml`, which is git-ignored in their personal vault. It is not recoverable from any file in this repo, including this one.
3. **Scrubbed from history.** `git log` has been rewritten with `git-filter-repo` so the real names are not recoverable from prior commits either. If you see a real-looking name in history, please [open an issue](https://github.com/lorecraft-io/2ndBrain-mogging/issues) — it is a bug.
4. **Present in the operator's private fork.** On the operator's own machine, the same skills resolve the placeholders back to real names at runtime via the private `aliases.yaml`. This is how the pack stays useful without exposing the substrate.

## Why the placeholders read like fiction

They're intentionally contentless. `<PERSON-A>` tells you "a human appears here in the operator's real use of this skill" without telling you anything about *which* human. This is deliberate:

- It keeps the examples legible — you can see the shape of a real `/save` classification run without needing context you don't have.
- It signals to forks and contributors that this token is a hole that the skill fills in at runtime against their own vault's alias map.
- It prevents the reverse-engineering-by-context attack, where a diligent reader triangulates an undisclosed name from surrounding details.

## If you fork this

When you install this pack into your own vault, your `Claude-Memory/aliases.yaml` defines **your** mapping from real names (or project names) to your preferred handles. The skills read from `aliases.yaml` at runtime; they do not carry the upstream operator's mapping with them. Fork freely — the placeholders are contract, not content.

## Tokens currently in use

The current public release uses the following placeholder families. New placeholders may be added as the pack grows; removed placeholders are never re-used.

- `<PERSON-A>` through `<PERSON-I>` — 9 individuals
- `<PROJECT-A>` through `<PROJECT-C>` — 3 client projects

If you see a placeholder that's not on this list, either the pack has been updated and this file is stale (please [open an issue](https://github.com/lorecraft-io/2ndBrain-mogging/issues)) or you're looking at a downstream fork.

## See also

- [`docs/CREDITS.md`](CREDITS.md) — upstream attribution
- [`docs/SECURITY.md`](SECURITY.md) — secrets-adjacent handling, the broader redaction discipline this file is part of
- `README.md` — top-level project overview
