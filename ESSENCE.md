# 2ndBrain-mogging: the essence

**What it is.** A kit that turns an Obsidian vault into a second brain Claude Code can read, write and keep tidy. You get four numbered folders, 13 skills, four scheduled agents, importers for your old notes and chats, and three opt-in tiers: self-learning, a guard and a memory tier.

**Who it's for.** People who want a second brain without a taxonomy degree. It's also for people who already have a messy vault, because it was built on a running one and it won't wreck yours. Everything previews first, and a migration script moves an older layout over with a dry run and a backup.

**Why it exists.** I wanted a second brain, so I built one. The first version was a lightly modded copy of someone else's system. Then I stared at it for six months and realized half the folders were doing nothing. So I tried four more systems and merged the best of all five.

**What's different.**

- **Mogging is synthesis plus subtraction.** Maxxing is accumulation: install everything. Mogging takes the best of five, cuts the rest, and says why. There's a `why-not-*.md` file for each of the five, for when theirs is the better fit.
- **Four folders, numbered 01 to 04.** `01-Projects`, `02-Library` (people, tools, ideas, sources), `03-Index` and `04-Tasks`. `00-Inbox`, `01-Fleeting`, `05-Templates` and `06-Assets` got killed early, because the inbox was where good notes went to die. In November 2026 `02-Sources` and `03-Concepts` merged into the Library too.
- **A fresh install stays small.** A new vault gets `01-Projects/VAULT/`, the four empty Library folders, two index notes, the task hub, `CLAUDE.md`, `AGENTS.md`, `SOUL.md`, and a layout guide you read and then delete. The catch-all project, the vault log and the reports folder show up the first time something needs them.
- **Built for a vault that already has a life.** Every skill checks what's there and previews its write. Your notes marked `owner: human` don't get rewritten. Sync-owned files don't get touched. The installer keeps the memory, settings, skills and launchers it finds, and uninstall leaves your later settings and every backup in place.
- **The rules that matter exist as code.** The skills are instructions to a model, and a model can forget. Task ID, scope and retired-folder rules also live in `bin/`, with tests, and `--with-guard` runs them as a hook that blocks a bad edit before it lands.
- **A small memory tier that says what it can't do.** `--with-memory` tracks when each idea note was last known to be true, using only frontmatter. Decay is a date rule and promotion is a link count. It can tell you how long it's been since anyone said a claim was right, and it can't tell you the claim is wrong.
- **No vector index.** Notes get compiled from sources, and the folder is the data model.

**The five, credited:** Andrej Karpathy, Jens Heitmann, eugeniu, AgriciDaniel and NicholasSpisak. What came from whom is in `docs/CREDITS.md`.

**How to try it.** Needs Claude Code, `jq`, Obsidian (the installer handles it on macOS) and a vault folder in your home directory.

```bash
git clone https://github.com/fidgetcoding/2ndBrain-mogging.git
cd 2ndBrain-mogging
./install.sh --vault ~/MyVault          # dry run, writes nothing
./install.sh --vault ~/MyVault --apply  # the real thing
```

Then open Claude Code in the vault and run `/save` at the end of a conversation. Already on the older layout? `bash scripts/migrate-to-library.sh --vault ~/MyVault` shows the move, and `--apply` does it. The full steps are in the [README](README.md).

**What works today.**

- 14 of 14 test files pass in CI on Ubuntu and macOS at `5988cfa`, run strict, so a skipped test fails the build. That's 546 shell assertions plus 62 Python tests: 38 for data safety and 24 for helper concurrency.
- The migration script has 97 of those checks to itself, including a vault whose task folder is a git submodule.
- A memory scan over 3,000 dependency files dropped from a 2.12-second median to 0.18 seconds with identical output, after the November 4 fixes.
- My own vault runs on it every day, on the same 01 to 04 layout.
- Dry-run installs, a doctor command, an updater, and an uninstaller that edits your current settings instead of restoring an old snapshot.
