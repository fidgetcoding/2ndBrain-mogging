# Migration

This is the short, high-level migration guide. The full step-by-step runbook with commands, rollback points, and validation queries lives in [`docs/MIGRATION.md`](docs/MIGRATION.md).

## When to migrate

Migrate to `2ndBrain-mogging` if:

- You already have an Obsidian vault with more than a few dozen notes
- You've been using another Claude Code second-brain skill pack and want to upgrade to four-regime awareness
- You have live sync pipelines (Morgen, n8n, GitHub Issues, calendar) touching the vault and need a pack that won't trample them
- You've outgrown a pure-Karpathy setup and want tier 2 thinking tools

Do not migrate if:

- You're starting from zero and just want the simplest thing that works — use NulightJens or the Karpathy gist directly
- You want a turnkey vector-search RAG system — this pack deliberately doesn't ship one
- You need tier 3 bi-temporal memory — it isn't built yet

## What you lose without it

If you stay on a pure Karpathy / Jens / eugeniughelbur setup:

- **No regime awareness.** A compile pass or an ingest skill can silently rewrite a sync-mirrored file, which will round-trip as a duplicate on the next n8n tick.
- **No alias classifier.** Every `/save` prompts you for the destination or guesses wrong.
- **No `[bot:*]` commit prefix.** Sync pipelines re-fire on every plugin write, doubling your task load in Morgen within a day.
- **No tether audit.** Project indexes drift, MOCs get orphaned, sub-projects stop linking back to parents. Your graph view rots one edge at a time.
- **No thinking tools under the same schema.** You can bolt on `/challenge` or `/emerge` from eugeniughelbur but they won't understand your project structure.

## What you keep

This pack is additive, not replacing. You keep:

- Your folder structure. The pack uses your numbering (`00-Inbox/`, `01-Fleeting/`, etc.) but `aliases.yaml` lets you remap if yours differs.
- Your frontmatter conventions. We read and emit the same YAML keys you already use.
- Your existing skills. If you've installed another second-brain pack, you can run them side-by-side — just pin the slash-command names in `plugin.json` if there's a collision.
- Your sync pipelines. n8n workflows, Morgen task mirroring, calendar pins — the pack reads them, respects them, and commit-prefixes everything `[bot:*]` so your filters keep working.
- Your Obsidian plugins. Tasks, Dataview, Canvas, Periodic Notes — all untouched. The pack writes Obsidian-Tasks-compatible syntax natively.

## Six-step short version

1. **Back up the vault.** Either `git commit -am "pre-mogging"` or `cp -R 2ndBrain 2ndBrain.bak`. Both are cheap. Do both.

2. **Install the plugin.** `/plugin marketplace add lorecraft-io/2ndBrain-mogging` then `/plugin install 2ndbrain-mogging@lorecraft-io`. Restart Claude Code.

3. **Run `/aliases init`.** This walks your `07-Projects/` tree and proposes an `aliases.yaml` seed with one entry per project. Review and edit before `y`. This file becomes the classifier dictionary for every future `/save`.

4. **Run `/tether --dry-run`.** This audits project-index bidirectional links, MOC membership, and hub wiring. It reports orphans without fixing anything. Eyeball the report. If it looks sane, re-run without `--dry-run` to apply the fixes. If it looks wrong, check your `aliases.yaml` — it's usually a classification bug.

5. **Run `/backfill --last-30-days`.** This walks recent Claude Code transcripts and routes them into the vault as if `/save` had run at the time. Preview-heavy — nothing writes without your `y`. Step 1 rollback: `git reset --hard HEAD~N` where N is the number of backfilled commits.

6. **Enable scheduled agents.** `cp scheduled/launchd/*.plist ~/Library/LaunchAgents/` and `launchctl load` each one. Four plists: morning, nightly, weekly, health. Delete any you don't want.

After step 6 the pack is live. You're running tier 2 thinking tools over your existing vault, with regime awareness, alias classification, and `[bot:*]` filter-safe writes.

## Rollback

Every step is reversible. See [`docs/MIGRATION.md`](docs/MIGRATION.md) for per-step rollback commands. Short version: `git reset --hard <pre-mogging-sha>` puts you back where you started, the plist files are symlinks you can remove, and `aliases.yaml` is a single file you can delete.

## Detailed runbook

The long-form runbook with command examples, validation queries, and every edge case I've hit in my own migration is at [`docs/MIGRATION.md`](docs/MIGRATION.md). Read it before Step 5 if you've never run a `/backfill` before.
