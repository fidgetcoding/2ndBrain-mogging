<a id="top"></a>

<div align="center">

![2ndBrain-mogging](https://raw.githubusercontent.com/<ORG-A>/2ndBrain-mogging/main/2ndbrainmogging.png)

# 2ndBrain-mogging

**The best of five second-brain systems, sanded down, self-learning, and actually usable by a normal human.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

</div>

---

## Quick Navigation

| Link | Section | What it does | Time |
|---|---|---|---|
| [Why this exists](#why-this-exists) | Origin | The maxxing → mogging story | ~2 min |
| [What you get](#what-you-get) | Overview | TL;DR of the kit | ~1 min |
| [Install Obsidian first](#install-obsidian-first) | Setup | Manual download + folder suggestion | ~3 min |
| [Install the mogging pack](#install-the-mogging-pack) | Setup | Clone, dry-run, apply | ~2 min |
| [The 12 skills](#the-12-skills) | Reference | Every slash command in plain English | ~3 min |
| [Vault structure](#vault-structure) | Reference | The 7-folder layout, with example projects | ~2 min |
| [Self-learning tier](#self-learning-tier-opt-in) | Optional | Turns the pack into a pattern-graph that gets smarter as you go | ~1 min |
| [Bring your existing stuff in](#bring-your-existing-stuff-in-optional) | Optional | Import Claude / ChatGPT conversations + Apple Notes / OneNote / Notion / Evernote | ~3 min |
| [Credits](#credits) | Meta | The 5 originals I mogged | — |
| [License](#license) | Meta | MIT | — |

---

## Why this exists

I wanted a second brain. So I built one.

The first version was called **2ndBrain-maxxing** — a lightly modded replica of the second-brain system [**Jens Heitmann**](https://www.instagram.com/jens.heitmann/) had put out. It worked. For a while. Then I stared at it for six months and realized half the folders were doing nothing, the taxonomy had jargon I was learning on the fly, and every capture required thinking about three other captures first. That's when I went shopping.

I tried **Karpathy's** Wiki-style LLM-powered second brain. I tried **AgriciDaniel's** [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian). I tried [**eugeniu's system**](https://github.com/eugeniughelbur/obsidian-second-brain). I tried **NicholasSpisak's**. And I kept going back to [**Jens Heitmann's ai-second-brain-skills**](https://github.com/NulightJens/ai-second-brain-skills) — not because it was the best, but because it was the one I already knew. Each of those had one thing the others didn't. None of them had everything.

So I merged them. I took what earned its keep from each of the five, threw out what didn't, and killed `00-Inbox/` (it's where good notes went to die). I killed `01-Fleeting/` (fleeting notes are just concepts you haven't written yet). I killed `05-Templates/` (templates belong in the plugin layer, not in your graph). I killed `06-Assets/` (Obsidian already handles attachments in place).

What was left was seven folders, ten skills, and a vault that doesn't require a taxonomy degree to use. Built for a layman. No complicated language. No complicated anything.

The last piece — a **self-learning tier**. A couple of the originals had one, but bootstrapping them was heavy. This pack's is opt-in (`--with-intelligence`), ships clean, and fills itself in as you use the vault. Ignore it forever and the pack still works; turn it on and it stops feeling like a filing cabinet and starts feeling like… well, a second brain.

So: we went from maxxing to absolutely **mogging** everybody.

---

## What you get

- **The 7-folder mogged vault layout** — the contract you install against, pre-wired to the skills below.
- **12 Claude Code skills** (10 core + 2 optional importers) that read + write against that layout with a shared alias dictionary + dry-run previews.
- **Four scheduled agents** (morning / nightly / weekly / health) that audit the vault in the background so you don't have to.
- **An opt-in self-learning tier** (ruvnet's claude-flow / ruflo pattern-graph) that makes routing smarter the longer you use it.
- **Import tools** for bringing in every Claude.ai / ChatGPT conversation you've ever had, plus Apple Notes / OneNote / Notion / Evernote / raw docs — so you don't start from empty.

---

## Install Obsidian first

The pack installs the Obsidian *configuration* — it assumes Obsidian itself is already on your machine. The installer for the Obsidian app is a one-time thing you do manually; I don't automate it because the official installer is the only one that reliably works across macOS/Windows/Linux quirks.

1. Go to **[obsidian.md](https://obsidian.md/download)** and download the installer for your OS.
2. Run the installer. It takes about 30 seconds.
3. Open Obsidian. It'll ask where your vault should live.
4. **Strong recommendation:** put it at `~/Desktop/BRAIN/`. That's `/Users/<you>/Desktop/BRAIN/` on macOS. Reasons:
   - Short path — easier to type in scripts and your shell.
   - You'll have a lot of subfolders. A shallow root path keeps them navigable.
   - The import + sync scripts auto-detect vaults at `~/Desktop/BRAIN/` or `~/Desktop/BRAIN2/` without needing a `VAULT_PATH=…` prefix.
5. Accept the "Create new vault" prompt. Obsidian makes the folder.
6. **Done — close Obsidian.** The next step runs from the terminal and wants the vault folder empty-ish.

> If you hit any install weirdness, the fix is almost always "use the official installer, not a script." I've tried. It fights me every time.

---

## Install the mogging pack

Once Obsidian is installed and you have a vault folder (e.g. `~/Desktop/BRAIN/`), the pack's installer takes over.

```bash
git clone https://github.com/<ORG-A>/2ndBrain-mogging.git
cd 2ndBrain-mogging

# Dry-run first (default) — shows every change without touching disk
./install.sh --vault ~/Desktop/BRAIN

# Then apply for real
./install.sh --vault ~/Desktop/BRAIN --apply
```

**The useful flags:**

| Flag | Default | What it does |
|---|---|---|
| `--vault PATH` | — | Absolute path to your Obsidian vault. Required with `--apply`. |
| `--dry-run` | on | Simulate only — print every change, write nothing. |
| `--apply` | off | Execute the changes on disk and in `~/.claude/settings.json`. |
| `--no-launchd` | off | Skip the 4 scheduled-agent launchd jobs (morning / nightly / weekly / health). |
| `--skip-tests` | off | Skip the onboarding test suite at the end. |
| `--merge-stop` | off | Replace the existing Stop hook instead of jq-merging onto it. |
| `--with-intelligence` | off | Install the self-learning tier. See [Self-learning tier](#self-learning-tier-opt-in) below. |
| `--symlink` | off | With `--with-intelligence`: symlink helpers instead of hardlinking. |

On `--apply`, the installer backs up `~/.claude/settings.json`, jq-merges the Stop hook (never overwrites), symlinks skills + commands + agents into `~/.claude/`, installs the launchd plists, and runs the onboarding tests.

---

## The 12 skills

Every skill is a Claude Code slash command. You type `/<name>` inside Claude Code and the skill runs.

| Slash command | What it does |
|---|---|
| `/save` | Capture this conversation (or a passage, dictated note, ADR) into the vault. Alias-classified, dry-run-previewed, append-only. Also runs in `--backfill` mode for historical transcripts. |
| `/wiki` | Re-compile a topic note from its sources. Single source of truth is `wiki-schema.md`. |
| `/challenge` | Steel-man the opposing view of any claim in your vault. Writes a dated `CHALLENGE-<slug>.md` — receipts for arguing with yourself. |
| `/emerge` | Surface patterns across N notes you'd otherwise miss. Clusters, contradictions, half-formed arguments. |
| `/connect` | Propose new `[[wikilinks]]` between notes that share concepts but don't link yet. |
| `/tether` | Audit project-index bidirectional links, MOC membership, hub wiring. Fix orphans. |
| `/backfill` | Walk a set of historical Claude Code session JSONLs and route them into the vault as if `/save` had run at the time. |
| `/aliases` | Manage the classifier dictionary in `Claude-Memory/aliases.yaml`. Add / rename / split entities. |
| `/autoresearch` | 3-round deepening research loop — shallow sweep, follow-up pass, synthesis. |
| `/canvas` | Drop an Obsidian Canvas scratchpad pre-wired to whatever set of notes you name. |
| `/import-claude` | One-shot import your entire Claude.ai or ChatGPT data export into the vault. Full conversation history, alias-classified, spawns concept stubs where ideas repeat. **New.** |
| `/import-notes` | One-shot import your existing notes from Apple Notes, OneNote, Notion, Evernote, or any raw `.md` / `.docx` / `.pptx` / `.xlsx` / `.html` pile. Pandoc under the hood, full dry-run preview. **New.** |

All twelve are auto-namespaced under the `2ndbrain-mogging` plugin. Both `/save` and `/2ndbrain-mogging:save` resolve to the same skill — use whichever form you like inside Claude Code.

---

## Vault structure

The post-mogging 7-folder layout. This is what the installer creates (and what every skill is hard-wired to target):

```
BRAIN/
├── 01-Conversations/    # /save output — full-fidelity chat captures, mirrors 05-Projects subfolders
├── 02-Sources/          # External inputs — articles, videos, podcasts, book notes, conversation mirrors
├── 03-Concepts/         # Atomic concepts — one idea per note, densely linked. The graph lives here.
├── 04-Index/            # Maps of Content — navigation hubs + audits
├── 05-Projects/         # Active work. One folder per project. See below.
├── 06-Tasks/            # Obsidian Tasks plugin area files. Optional 3-way Notion + Morgen sync via task-maxxing.
└── Claude-Memory/       # Symlink to ~/.claude/projects/<vault>/memory — aliases.yaml + auto-memory shards
```

### `05-Projects/` in detail — example layout

Each project gets its own folder. The folder name **equals** the index filename exactly (no `-Index` suffix), so `[[example-project-1]]` resolves from anywhere in the vault.

```
05-Projects/
├── example-project-1/
│   ├── example-project-1.md    ← index note (filename = folder name)
│   ├── content/                 ← write-ups, specs, decks, session logs
│   ├── misc-building/           ← experiments, tools, plugins built for this project
│   └── GITHUB/                  ← cloned repos tied to this project
│
├── example-project-2/
│   └── example-project-2.md
│
├── example-project-3/
│   ├── example-project-3.md
│   └── <any subfolders you want>
│
└── INCUBATOR/                   ← staging lane for ideas not yet full projects
```

The subfolders inside each project are **up to you**. Use whatever makes sense — the skills don't require a specific layout below the project's index note. The `content/` + `misc-building/` + `GITHUB/` pattern is what I use personally; yours might be `research/` + `drafts/` + `deliverables/`. Whatever works.

### What the retired folders were

If you're coming from an older second-brain kit, you'll notice these are gone:

- `00-Inbox/` → retired. `/save` and `/wiki add` write directly to `02-Sources/` with a dry-run preview first. The inbox stage was a tax you paid every single capture for the luxury of triaging later, which you never did.
- `01-Fleeting/` → retired. Fleeting notes are just concepts you haven't written down yet. Inline capture plus same-day promotion beats shuffling markdown between folders.
- `05-Templates/` → retired. Templates belong in the plugin layer, not in your graph. The `2ndbrain-mogging` skills carry them now.
- `06-Assets/` → retired. Obsidian's attachment defaults handle assets in place; a centralized assets folder exists mostly to make your graph view lie to you about which notes are "connected."

Deep rationale for each kill is in [`PHILOSOPHY.md`](PHILOSOPHY.md).

---

## Self-learning tier (opt-in)

Pass `--with-intelligence` to the installer and the pack wires in a sixth upstream: ruvnet's claude-flow / ruflo pattern-graph (ADR-050). It plugs into `/save` and `/wiki` so routing gets progressively smarter as the vault grows, without rewriting a single one of your notes. 11 helper scripts (verbatim MIT-licensed copies with provenance headers) get hardlinked into `$VAULT/.claude/helpers/` and 5 additional hook types (PreToolUse / PostToolUse / UserPromptSubmit / SessionStart / SessionEnd) get jq-merged into `~/.claude/settings.json` — your existing hooks are preserved.

Off by default so the advertised pack works for people who just want the folders and the skills. Turn it on when you want the vault to start learning from your session history.

---

## Bring your existing stuff in (optional)

If you've been keeping notes somewhere else, you don't have to abandon them. The two importer skills handle the most common cases.

### Claude.ai or ChatGPT history → vault

1. **Export from the platform.**
   - Claude.ai: Settings → Privacy → **Download my data** → All time. You'll get an email with a zip.
   - ChatGPT: Settings → Data controls → **Export data**. Same email pattern.
2. **Drop the zip in `~/Downloads/`** and run the helper:
   ```bash
   bash scripts/import-claude.sh
   ```
   It unzips the export into `<vault>/.import-staging/<timestamp>-claude/` and prints the next step.
3. **Inside Claude Code, run `/import-claude`** — scan first, dry-run, then apply. Each conversation becomes a full-fidelity capture in `01-Conversations/`, a factual LIT-mirror in `02-Sources/`, and (where ideas repeat) a concept stub in `03-Concepts/`.

### Apple Notes / OneNote / Notion / Evernote / raw files → vault

Same shape. Export from your source first, then run:

```bash
bash scripts/import-notes.sh
```

Then `/import-notes --source ~/Desktop/<export-folder>` inside Claude Code.

**Supported sources:**

- **Apple Notes** via [`Exporter.app`](https://apps.apple.com/us/app/exporter/id1099120373) → Markdown
- **OneNote** via File → Export → Word `.docx`
- **Notion** via Settings → Export → Markdown & CSV
- **Evernote** via File → Export Notes → `.enex`
- **Raw pile** — any folder full of `.md` / `.txt` / `.docx` / `.pptx` / `.xlsx` / `.html` / `.rtf`

All five routes share the same rulebook in [`docs/PARSING-GUIDE.md`](docs/PARSING-GUIDE.md). Pandoc handles conversions; `/import-notes` does the classification.

### After you import anything

Run these three in order (they're all quick):

```
/tether        # audit and fix bidirectional project-note links
/connect       # propose wikilinks between notes that share concepts
/wiki audit    # write a dated audit report to 04-Index/audit-YYYY-MM-DD.md
```

That's it. Your vault is wired.

---

## A note on placeholders

This pack was extracted from a live operator's personal vault. Real names and private client-project names have been redacted and replaced with stable placeholders of the form `<PERSON-A>`, `<PROJECT-B>`, etc. The mapping isn't in this repo. See [`docs/placeholder-names.md`](docs/placeholder-names.md) for the convention.

---

## Credits

This pack is an amalgamation — not an invention. The best ideas are all borrowed; what I did was test them side-by-side and throw out what didn't earn its keep. In alphabetical order:

- **AgriciDaniel** ([`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian)) — the conversation-capture hygiene and the `owner: wiki` vs `owner: human` discipline that makes skills safe to run against live notes.
- **eugeniu** ([`obsidian-second-brain`](https://github.com/eugeniughelbur/obsidian-second-brain)) — the concept-atomization rules that keep `03-Concepts/` from becoming a dumping ground.
- **Jens Heitmann** ([`ai-second-brain-skills`](https://github.com/NulightJens/ai-second-brain-skills)) — the original folder structure I modded to death, and the taste-making starting point.
- **Karpathy** ([`LLM Wiki`](https://karpathy.ai/zero-to-hero.html)-era second brain) — the wiki-style synthesis pattern that became `/wiki` and `/emerge`.
- **NicholasSpisak** — the Canvas-scratchpad pattern that became `/canvas`.
- **ruvnet** ([`claude-flow` / `ruflo`](https://github.com/ruvnet/claude-flow)) — the pattern-graph intelligence tier (opt-in via `--with-intelligence`).

Each of them is worth a look even if you install this pack instead. They're the people who did the hard work; I just picked the best of five.

---

## License

MIT — see [`LICENSE`](LICENSE).

[⤴ back to top](#top)
