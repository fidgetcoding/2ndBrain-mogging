# 2ndBrain-mogging: the essence

**What it is.** A kit that turns an Obsidian vault into a second brain Claude Code can read, write and maintain: a simple folder layout, 13 skills, four scheduled agents, importers for your old notes and chats, plus opt-in self-learning, guard and memory tiers.

**Who it's for.** People who want a second brain and don't want a taxonomy degree. It's also for people who already have a messy vault, because it was built on a running one and it won't wreck yours: everything previews first.

**Why it exists.** I wanted a second brain, so I built one. The first version was a lightly modded copy of someone else's system. Then I stared at it for six months and realized half the folders were doing nothing. So I tried four more systems and merged the best of all five.

**What's different.**

- **Mogging, not maxxing.** Maxxing is accumulation: install everything. Mogging is synthesis plus subtraction: take the best of five, cut the rest, and say why. There's a `why-not-*.md` file for each of the five, for when theirs is the better fit.
- **It killed folders.** `00-Inbox`, `01-Fleeting`, `05-Templates` and `06-Assets` are gone. The inbox was where good notes went to die.
- **Built for a vault that already has a life.** Every skill checks what's there and previews its write. Your notes marked `owner: human` don't get rewritten. Sync-owned files don't get touched.
- **The rules that matter exist as code.** The skills are instructions to a model, and a model can forget. Task ID and scope rules also live in `bin/`, with tests, and `--with-guard` runs them as a hook that blocks a bad edit before it lands.
- **A small, honest memory tier.** `--with-memory` tracks when each concept note was last known to be true, using only frontmatter. Decay is a date rule and promotion is a link count. It can tell you how long it's been since anyone said a claim was right, and it can't tell you the claim is wrong.
- **No vector index.** Notes get compiled from sources, and the folder is the data model.

**The five, credited:** Andrej Karpathy, Jens Heitmann, eugeniu, AgriciDaniel and NicholasSpisak. What came from whom is in `docs/CREDITS.md`.

**How to try it.** Needs Claude Code, Obsidian (the installer handles it on macOS) and a vault folder in your home directory.

```bash
git clone https://github.com/fidgetcoding/2ndBrain-mogging.git
cd 2ndBrain-mogging
./install.sh --vault ~/MyVault          # dry run, writes nothing
./install.sh --vault ~/MyVault --apply  # the real thing
```

Then open Claude Code in the vault and run `/save` at the end of a conversation.

**What works today.**

- 11 of 11 test files pass with 357 assertions, and CI runs them strict, so a skipped test fails the build.
- My own vault runs on it every day.
- Dry-run installs, a doctor command, and an updater.
