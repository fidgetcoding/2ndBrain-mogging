# Credits

`2ndBrain-mogging` is an amalgamation. Every major design decision in this pack traces back to specific upstream work. This file credits each source with a GitHub link, the license it ships under, and the exact lines of inheritance into this pack.

## Primary sources (five)

### Andrej Karpathy — LLM Wiki gist

- **Source:** https://gist.github.com/karpathy/3d3797cfe72b4fd78dab7a5c35caf0f9
- **License:** not formally stated; public gist, treated as reference / fair use. I do not copy verbatim code from the gist into this pack.
- **What I took:**
  - The compilation-over-retrieval thesis (core rationale in `PHILOSOPHY.md`)
  - The Inbox → Sources → Wiki three-folder primitive (mapped to `00-Inbox/` → `02-Literature/` → `03-Permanent/` in this pack)
  - The source-first frontmatter convention (required `url`/`source` on every literature note)
  - The "lose-the-wiki is recoverable from Sources" invariant (enforced in `/wiki` and `/autoresearch`)
  - The thesis quotation used verbatim in `PHILOSOPHY.md` and `docs/foundations/01-karpathy-canonical.md`
- **What I did not take:** the gist does not ship executable code, so there is nothing to copy at the implementation level. The ideas are the contribution.

### NulightJens — ai-second-brain-skills

- **Source:** https://github.com/NulightJens/ai-second-brain-skills
- **License:** MIT (check repository for current status). No code is copied verbatim.
- **What I took:**
  - The minimal-MVP discipline (only ship what is structurally necessary)
  - The self-heal-on-missing-schema pattern (now universal across this pack's skills)
  - The discuss-before-write etiquette (seed of the mandatory dry-run preview)
  - The two-skill architecture (`/save` + `/wiki`) as the irreducible core — my ten skills are strictly additions on top of these two
  - The `wiki-schema.md` single-source-of-truth pattern

### eugeniughelbur — obsidian-second-brain

- **Source:** https://github.com/eugeniughelbur/obsidian-second-brain
- **License:** check repository. No code is copied verbatim.
- **What I took:**
  - The four-thinking-tool pattern (`/challenge`, `/emerge`, `/connect`, and originally `/bridge` — which I dropped)
  - The scheduled-agent cadence (morning / nightly / weekly / health)
  - The opinionated-stance design principle (ship opinions explicitly, do not abstract them away)
- **What I deliberately diverged from:**
  - The unfenced-ingest behavior that rewrites project indexes on classification ambiguity — replaced with dry-run preview + stub breadcrumbs
  - Plain-checkbox task syntax — replaced with Obsidian-Tasks-plugin-compatible syntax
  - No external-system UUID preservation — replaced with a preserve-all-trailing-IDs invariant

### AgriciDaniel — claude-obsidian

- **Source:** https://github.com/AgriciDaniel/claude-obsidian
- **License:** check repository. No code is copied verbatim.
- **What I took:**
  - The hot-cache pattern (session-lifetime cache of sources with mtime-based invalidation)
  - The `/autoresearch` three-round deepening loop (shallow sweep → gap identification → synthesis) — close port of the loop structure
  - The plugin marketplace repo layout (`.claude-plugin/`, `skills/`, `commands/`, `hooks/`, `scheduled/`, `vault-template/`, `docs/`, `tests/`, `bin/`, `references/`)
  - `/canvas` (Obsidian Canvas scratchpad pre-wired to a set of notes)

### NicholasSpisak — second-brain

- **Source:** https://github.com/NicholasSpisak/second-brain
- **License:** check repository. No code is copied verbatim.
- **What I took:**
  - The source-page template for `02-Literature/` entries
  - The discuss-before-write etiquette (reinforces the Jens version)
  - The factual-content-in-Sources-only rule
  - The prefer-update-over-create rule
  - The bash test harness pattern (my `tests/` folder follows this shape)
  - The `wiki-schema.md` as single source of truth (same pattern, same file location)

## Secondary influences (three)

### rohitg00 — LLM-Wiki-v2

- **Source:** https://github.com/rohitg00/LLM-Wiki-v2
- **License:** check repository.
- **What I took:** the template-per-output-type idea, applied narrowly to literature notes in `02-Literature/`. The broader template catalog was not adopted.

### huytieu — COG (Chain-of-Going)

- **Source:** https://github.com/huytieu/COG
- **License:** check repository.
- **What I took:** the visible-trajectory pattern — the LLM commits to its next steps explicitly before executing them. Used in `/autoresearch` round transitions. The open-ended chain format was not adopted; my research loop is bounded to three rounds.

## Tooling and platform

### Anthropic — Claude Code

- **Source:** https://docs.claude.com/claude-code
- **What I took:** the entire plugin platform (skills, slash commands, hooks, scheduled agents, marketplace). This pack is not portable to other LLM harnesses without significant rework.

### Obsidian — Tasks plugin (Clare Macrae)

- **Source:** https://publish.obsidian.md/tasks/
- **What I took:** the task syntax (`- [ ] text ⏫ 📅 <date> 🆔 <id>`), the priority emoji conventions, the date-marker conventions. Every task line emitted by this pack is Tasks-plugin-compatible by default.

### Obsidian — platform conventions

- **What I took:** the wikilink grammar (`[[note]]`, `[[note|alias]]`, `[[note#heading]]`), the Canvas file format, the frontmatter YAML convention, the vault-as-folder-of-markdown model. These are Obsidian inventions and the pack would not make sense without them.

## What is original to this pack

- The four-regime model (HUMAN, PROJECT, SYNC, LLM-COMPILED)
- The `aliases.yaml` classifier schema and scoring logic
- The `[bot:*]` commit-prefix convention for sync-filter safety
- The 50/50 stub-breadcrumb rule for ambiguous classification
- The `/tether` graph-audit skill
- The `/backfill` historical-transcript migration skill
- The integration rules between Morgen UUIDs, n8n W1 pipeline, and vault writes
- The reserved frontmatter slots for tier-3 bi-temporal facts (`asof:`, `seenat:`, `bi-temporal:`)
- The migration runbook in `docs/MIGRATION.md`

These are the load-bearing additions that justify shipping a new pack rather than configuring one of the upstream sources. Everything else in this pack is a credited borrow.

## License notes

This pack is MIT-licensed. All upstream sources listed above are credited. Where a license could be verified at the time of writing, it is noted. Where a license is not clearly stated in the upstream repo, I have not copied code verbatim — only re-implemented ideas and patterns. If any upstream maintainer believes content in this pack exceeds fair-use attribution and requires explicit re-licensing, open an issue and I will adjust.

If you are a maintainer of one of the cited upstream projects and would like a more specific credit format, a deeper per-commit acknowledgement, or removal of a particular reference — open an issue on this repo and I will act on it promptly.
