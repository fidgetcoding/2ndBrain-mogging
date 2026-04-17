# 02 — NulightJens analysis

Source: https://github.com/NulightJens/ai-second-brain-skills

NulightJens's `ai-second-brain-skills` is the Karpathy-minimal MVP realized as a Claude Code plugin. It ships two skills and a schema file. That is the whole pack. It is the shortest serious implementation of the Karpathy primitives in the ecosystem.

This analysis walks the two skills and explains which design decisions survived into this pack.

## `/save`

Jens's `/save` captures conversation content into the Inbox. Its surface is deliberately small:

- **Single entry point, no branching.** You call `/save` and it asks what you want to save. No `/save:passage`, `/save:adr`, `/save:dictation` — one skill, one mode.
- **Self-heal on missing schema.** If `wiki-schema.md` is missing, the skill creates a seed version, announces what it did, and asks if the user wants to edit it before proceeding.
- **Discuss-before-write.** Before any `Write`, the skill describes in plain prose what it intends to do and waits for a `y` confirmation.
- **Append-only toward existing notes.** If the target file exists, the skill appends rather than overwriting. The user is informed of the append target before confirmation.

**What survived into this pack:** the self-heal pattern, the discuss-before-write etiquette, the append-only convention, and the single-entry-point idea — though I expanded the single entry into a four-branch menu (whole conversation / passage / dictation / ADR) because the four shapes of content have different frontmatter and routing needs. The self-heal pattern is now universal across every skill in this pack, not just `/save`.

**What did not survive:** Jens's `/save` is single-destination. It always writes to `Inbox/` and lets the user promote manually later. Mine routes to the right project folder directly based on the classifier in `aliases.yaml`, because waiting for manual promotion on every capture scaled poorly past ~200 notes.

## `/wiki`

Jens's `/wiki` is the compile operation. Given a topic, it:

- **Reads all Sources matching the topic.** The matching is tag-based and substring-based in the filename. No fuzzy matching, no embeddings.
- **Produces a single wiki note.** The note has a conventional structure: one-line summary, sections corresponding to sub-topics present in the sources, a references list at the bottom.
- **Is idempotent.** Running the same `/wiki` call twice over the same sources produces the same note content (modulo timestamp).
- **Cites back.** Every factual claim in the wiki note cites the source it came from by filename.

**What survived into this pack:** everything. My `/wiki` is a strict superset of Jens's. Same topic-matching, same output structure, same idempotency, same citation discipline. I added tier-2 hooks (if the user asks, `/wiki` can invoke `/challenge` on the compiled output and produce a paired `CHALLENGE-<topic>.md` stub) but the core compile path is his.

## The schema file

Jens ships a `wiki-schema.md` that defines:

- Frontmatter key list (title, date, type, tags, source, related)
- Folder roles (Inbox → Sources → Wiki)
- Linking grammar (`[[note]]`, `[[note|alias]]`, `[[note#heading]]`)
- Filename conventions (LIT- prefix for literature, date-prefixed for daily)

This is a single source of truth that both `/save` and `/wiki` read at startup. Any schema evolution happens in exactly one file.

**What survived:** the pattern. My `wiki-schema.md` is in `skills/save/references/` and is the single source of truth for both `/save` and `/wiki`, plus the tier-2 skills that also need to know which frontmatter keys exist. I extended the key list (added `regime:`, `asof:`, `seenat:`, reserved `bi-temporal:` for tier 3) but the pattern — schema in one file, everyone reads it — is Jens's.

## What Jens does not ship

- No thinking tools. No `/challenge`, no `/emerge`, no `/connect`.
- No scheduled agents. All skills are synchronous on user invocation.
- No regime model. The vault is treated as a flat set of markdown files with equivalent write permissions.
- No infrastructure integration. No `[bot:*]` commit prefix, no Morgen UUID preservation, no Obsidian Tasks syntax.
- No migration path. The pack assumes a new or nearly-new vault.

Each of these absences is a design choice, not an oversight. Jens is optimizing for minimum viable correct Karpathy. This pack is optimizing for operator vaults with live sync pipelines and tier-2 tooling. They are different design targets.

## Summary

Use Jens's pack if you want the smallest correct Karpathy implementation in Claude Code. Use this pack if you need the same discipline plus the infrastructure surface that operator vaults require. The DNA overlap is high — Jens's two skills are ancestors of this pack's `/save` and `/wiki`, essentially unchanged in their core behavior.
