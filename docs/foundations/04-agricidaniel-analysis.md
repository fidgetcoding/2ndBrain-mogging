# 04 — AgriciDaniel analysis

Source: https://github.com/AgriciDaniel/claude-obsidian

AgriciDaniel's `claude-obsidian` is the architecturally-cleanest pack in the ecosystem. It ships fewer commands than eugeniughelbur's, more than Jens's, and its internal structure — hot cache, three-round research loop, plugin marketplace layout — is the best piece of engineering in the upstream set.

This analysis covers the four commands most relevant to this pack (`/wiki`, `/save`, `/autoresearch`, `/canvas`) and the supporting infrastructure.

## `/wiki`

AgriciDaniel's `/wiki` is a strict compile operation along Karpathy lines. What is novel is how it uses the hot cache:

- **Sources are read once per session and cached in memory** for the duration of the Claude Code session. Re-running `/wiki` on a related topic in the same session does not re-read the same source files.
- **Cache invalidation is modified-time based.** If a source file's mtime advances between two `/wiki` calls, the cache entry for that file is dropped.
- **Output is diffed, not overwritten.** If the target wiki note already exists, the skill computes a diff against the proposed new content and presents it for user review before writing.

**What I kept:** the cache, the mtime-based invalidation, and the diff-before-write behavior. All three are load-bearing when running a sequence of `/wiki` calls in the same session. My `/wiki` uses the same cache format.

## `/save`

This is the command I rewrote most. AgriciDaniel's `/save` is roughly a transcript-dump into Inbox — a single destination, minimal classification, no routing to project folders. For a new vault this is fine; for my operator vault it was insufficient.

**What I rebuilt:**

- **Classification pipeline.** Load `aliases.yaml`, score every alias against incoming content, present the top candidates with confidence scores in a dry-run preview table, route to the primary destination.
- **Ambiguity handling.** If the top two candidates are within 10% of each other, write to the primary AND leave a stub breadcrumb at the runner-up so the operator can flip the decision without re-running the capture.
- **Four entry branches.** Whole conversation / specific passage / dictated note / ADR. Each has different frontmatter, different routing, and different prompts.
- **Regime check.** Refuses to write to SYNC regime files. Prompts before writing to HUMAN files. Diff-previews writes to PROJECT files.
- **`[bot:save]` commit prefix.** Every write is prefixed so n8n W1 sync filters skip the commit.

**What survived from his version:** the discuss-before-write etiquette, the idea that `/save` is the single capture entry point rather than a family of variant commands, and the hot-cache integration.

## `/autoresearch`

This is AgriciDaniel's most distinctive contribution and I ported it essentially verbatim. The structure:

**Round 1 — shallow sweep.** Given a research question, produce a first-draft answer based on whatever is already in the vault and whatever the LLM knows from its training cutoff. Output is a rough wiki note with `draft: true` frontmatter.

**Round 2 — gap identification.** Read the round-1 draft, identify claims that are weak, undercited, contradicted by other sources, or simply missing. Produce a list of follow-up research queries.

**Round 3 — synthesis.** Execute the follow-up queries (read more sources, fetch new URLs, run additional compiles). Produce a final wiki note with `draft: false` that integrates round 1 and round 2 findings.

**Why this matters:** a single-pass compile produces a wiki note that reflects only what was already in the vault. The three-round loop produces a note that has actively deepened — the LLM has gone back to fetch what was missing. For topics where the operator wants an actually thorough output rather than a summary of what they already have, `/autoresearch` is the right tool.

**What I kept:** the entire three-round structure, the prompt scaffolding between rounds, the `draft:` frontmatter convention, and the hot-cache integration that makes the three rounds feasible to run in sequence. My `/autoresearch` is a close port. I added regime-awareness (the final output regime defaults to LLM-COMPILED, so the operator can re-run it without prompt fatigue) but the core loop is his.

## `/canvas`

An Obsidian Canvas scratchpad pre-wired to a set of notes you name. You invoke `/canvas topic-x` and the skill produces a `.canvas` file in `06-Assets/canvases/` (or your equivalent) with cards for each note matching the topic, arranged in a sensible default layout, with edges drawn between cards that already link.

**Why it is useful:** Obsidian Canvas is a thinking-out-loud surface. Seeing the relevant notes laid out spatially with the LLM in the loop changes the shape of the conversation you can have about them. The skill exists to remove the friction of setting up the canvas manually.

**What I kept:** essentially everything. `/canvas` is the one skill in this pack I have not meaningfully modified from AgriciDaniel's version. The canvas file format is defined by Obsidian, not by the skill, so there is little room for adaptation.

## The plugin marketplace layout

AgriciDaniel's repo layout is the clean version of how a Claude Code plugin should be organized:

```
.claude-plugin/
  plugin.json           # the manifest
  marketplace.json      # for /plugin marketplace installs
skills/
  <skill>/SKILL.md      # one skill per folder
  <skill>/references/   # per-skill reference docs
commands/
  <cmd>.md              # slash-command wrappers
hooks/
  <hook>.sh             # event hooks
scheduled/
  launchd/*.plist       # macOS scheduled jobs
vault-template/         # scaffold for new vaults
docs/                   # user-facing documentation
tests/                  # bash test harness
```

I mirrored this exactly. The folder layout of `2ndBrain-mogging` is AgriciDaniel's layout, reused by design. Discoverability is better when packs share structure.

## What AgriciDaniel does not ship

- Tier-2 thinking tools beyond `/autoresearch`. No `/challenge`, no `/emerge`, no `/connect`.
- Regime awareness. The vault is treated as flat.
- Infrastructure integration. No `[bot:*]` commit prefix, no Morgen preservation, no Obsidian Tasks syntax.
- Migration tooling. `/backfill`, `/tether`, `/aliases` are all net-new in this pack.

## Summary

AgriciDaniel's pack is the closest architectural match to what I wanted. This pack's `/wiki`, `/autoresearch`, and `/canvas` are close ports; `/save` was rebuilt around a classifier; and tier-2 thinking tools, migration tooling, and regime awareness are additive. If you want the core compilation + research primitive done well and do not have operator-vault concerns, his pack is smaller and cleaner.
