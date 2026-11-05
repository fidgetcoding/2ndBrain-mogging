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

- Your folder structure. The pack uses the Library v2 numbering (`01-Projects/` with each project's `conversations/` and `notes/`, `02-Library/`, `03-Index/`, `04-Tasks/`, `Claude-Memory/`) but `aliases.yaml` lets you remap if yours differs. Coming from the earlier mogged layout (`02-Sources/`, `03-Concepts/`, `04-Index/`, `05-Tasks/`)? See [Moving to Library v2](#moving-to-library-v2-2026-11-05) below. If you're migrating from a pre-mogging 9-folder layout, see [`docs/MIGRATION.md`](docs/MIGRATION.md) for the rename + drain commands.
- Your frontmatter conventions. We read and emit the same YAML keys you already use.
- Your existing skills. If you've installed another second-brain pack, you can run them side-by-side — just pin the slash-command names in `plugin.json` if there's a collision.
- Your sync pipelines. n8n workflows, Morgen task mirroring, calendar pins — the pack reads them, respects them, and commit-prefixes everything `[bot:*]` so your filters keep working.
- Your Obsidian plugins. Tasks, Dataview, Canvas, Periodic Notes — all untouched. The pack writes Obsidian-Tasks-compatible syntax natively.

## Six-step short version

1. **Back up the vault.** Either `git commit -am "pre-mogging"` or `cp -R 2ndBrain 2ndBrain.bak`. Both are cheap. Do both.

2. **Install the plugin.** `/plugin marketplace add fidgetcoding/2ndBrain-mogging` then `/plugin install 2ndbrain-mogging@fidgetcoding`. Restart Claude Code.

3. **Run `/aliases init`.** This walks your `01-Projects/` tree and proposes an `aliases.yaml` seed with one entry per project. Review and edit before `y`. This file becomes the classifier dictionary for every future `/save`.

4. **Run `/tether --dry-run`.** This audits project-index bidirectional links, MOC membership, and hub wiring. It reports orphans without fixing anything. Eyeball the report. If it looks sane, re-run without `--dry-run` to apply the fixes. If it looks wrong, check your `aliases.yaml` — it's usually a classification bug.

5. **Run `/backfill --last-30-days`.** This walks recent Claude Code transcripts and routes them into the vault as if `/save` had run at the time. Preview-heavy — nothing writes without your `y`. Step 1 rollback: `git reset --hard HEAD~N` where N is the number of backfilled commits.

6. **Enable scheduled agents.** `cp scheduled/launchd/*.plist ~/Library/LaunchAgents/` and `launchctl load` each one. Four plists: morning, nightly, weekly, health. Delete any you don't want.

After step 6 the pack is live. You're running tier 2 thinking tools over your existing vault, with regime awareness, alias classification, and `[bot:*]` filter-safe writes.

## Moving to Library v2 (2026-11-05)

Library v2 merges `02-Sources/` and `03-Concepts/` into `02-Library/` and renumbers the rest so the folders run 01 to 04 with no gaps:

| Before | After |
|---|---|
| `02-Sources/*` | `02-Library/sources/` (a source tied to one project can move on to that project's `notes/` later) |
| `03-Concepts/*` | `02-Library/ideas/` (sort people and tools into `people/` and `tools/` later, by hand or with `/wiki heal`) |
| `04-Index/` | `03-Index/` |
| `05-Tasks/` | `04-Tasks/` |

`scripts/migrate-to-library.sh` does all of it. It changes nothing until you pass `--apply`:

```bash
bash scripts/migrate-to-library.sh --vault ~/MyVault            # dry run: every move, rename and query edit
bash scripts/migrate-to-library.sh --vault ~/MyVault --apply    # back up, then do it
bash scripts/migrate-to-library.sh --vault ~/MyVault --apply --remove-empty   # also remove the emptied 02-Sources/ and 03-Concepts/
```

What it does:

- Backs up first, to `~/WORK/<vault>-BACKUPS/<vault>-backup-library-migration-<timestamp>.tar.gz`: the folders it touches plus the notes whose task queries it edits. `--full-backup` tarballs the whole vault with `bin/backup-vault.sh` instead. Never `~/Desktop`. A failed backup changes nothing.
- Refuses, and changes nothing, if a destination name already exists or one of the folders is a symlink. A destination folder holding only `.gitkeep` counts as empty.
- In a git vault, moves tracked paths with `git mv`, so history follows and a `05-Tasks/` submodule keeps working (`.gitmodules` is updated).
- Rewrites `path includes 05-Tasks` to `path includes 04-Tasks` (and `04-Index` to `03-Index`) only inside ```` ```tasks ```` query blocks. Task lines and their 🆔 tokens are never touched. If `04-Tasks/` is a submodule, commit those query edits inside it as well.
- Never rewrites a wikilink. `[[note-name]]` links resolve by name and keep working; the dry run lists any path-style links (`[[02-Sources/...]]`) that will break.

After `--apply`, by hand:

1. **Update anything outside the vault that names `05-Tasks/` by path.** Task sync daemons, launchd plists, cron jobs, shell scripts and n8n path filters stop syncing until they point at `04-Tasks/`. The script prints a loud warning and lists the LaunchAgents it can see that still name the old path.
2. **Refresh the vault's `CLAUDE.md`.** Re-run `install.sh --apply` (or `update.sh`) to rewrite the plugin's marker block. Everything outside the markers is yours, so fix any old folder names there by hand. The installer won't seed `03-Index/` or `04-Tasks/` while `04-Index/` or `05-Tasks/` still exist.
3. **Commit** with a bot prefix so the sync skips it, e.g. `[bot:mogging-migrate] move the vault onto the Library v2 layout`.

To undo it, the backup tarball holds every folder and note as it was before the move.

The vault root now holds only `CLAUDE.md`, `AGENTS.md` and `SOUL.md`. The installer stops creating `CRITICAL_FACTS.md`, `index.md` and `log.md`, and nothing deletes or moves yours. When you're ready, move `log.md` to `01-Projects/VAULT/log.md` (where `/wiki` now appends), fold `CRITICAL_FACTS.md` into a **Critical facts** section of `SOUL.md`, and use `03-Index/Index.md` as the master index instead of a root `index.md`.

## Rollback

Every step is reversible. See [`docs/MIGRATION.md`](docs/MIGRATION.md) for per-step rollback commands. Short version: `git reset --hard <pre-mogging-sha>` puts you back where you started, the plist files are symlinks you can remove, and `aliases.yaml` is a single file you can delete.

## Detailed runbook

The long-form runbook with command examples, validation queries, and every edge case I've hit in my own migration is at [`docs/MIGRATION.md`](docs/MIGRATION.md). Read it before Step 5 if you've never run a `/backfill` before.
