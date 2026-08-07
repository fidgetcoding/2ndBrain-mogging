<a id="top"></a>

<div align="center">

![2ndBrain-mogging](https://raw.githubusercontent.com/fidgetcoding/2ndBrain-mogging/main/2ndbrainmogging.png)

# 2ndBrain-mogging

**The best of five second-brain systems, sanded down, self-learning, and actually usable by a normal human.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

[![Follow on X](https://img.shields.io/badge/FOLLOW%20%40fidgetcoding-000000?style=for-the-badge&logo=x&logoColor=white)](https://x.com/fidgetcoding) [![LinkedIn](https://img.shields.io/badge/LINKEDIN-CONNECT-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white&labelColor=555555)](https://www.linkedin.com/in/nate-davidovich/) [![YouTube](https://img.shields.io/badge/YOUTUBE-SUBSCRIBE-FF0000?style=for-the-badge&logo=youtube&logoColor=white&labelColor=555555)](https://youtube.com/@fidgetcoding) [![Instagram](https://img.shields.io/badge/INSTAGRAM-FOLLOW-E4405F?style=for-the-badge&logo=instagram&logoColor=white&labelColor=555555)](https://instagram.com/fidgetcoding)

</div>

---

## Quick Navigation

| Link | Section | What it does | Time |
|---|---|---|---|
| [Why this exists](#why-this-exists) | Origin | The maxxing → mogging story | ~2 min |
| [What you get](#what-you-get) | Overview | TL;DR of the kit | ~1 min |
| [Install Obsidian (auto)](#install-obsidian-first) | Setup | Auto-installed by the installer; manual download is the fallback | ~1 min |
| [Install the mogging pack](#install-the-mogging-pack) | Setup | Clone, dry-run, apply | ~2 min |
| [The 13 skills](#the-13-skills) | Reference | Every slash command in plain English | ~3 min |
| [Vault structure](#vault-structure) | Reference | The 6-folder layout, with example projects | ~2 min |
| [Self-learning tier](#self-learning-tier-opt-in) | Optional | Turns the pack into a pattern-graph that gets smarter as you go | ~1 min |
| [Bring your existing stuff in](#bring-your-existing-stuff-in-optional) | Optional | Import Claude / ChatGPT conversations + Apple Notes / OneNote / Notion / Evernote | ~3 min |
| [Credits](#credits) | Meta | The 5 originals I mogged | — |
| [License](#license) | Meta | MIT | — |

---

## Why this exists

I wanted a second brain. So I built one.

The first version was called **2ndBrain-maxxing** — a lightly modded replica of the second-brain system [**Jens Heitmann**](https://www.instagram.com/jens.heitmann/) had put out. It worked. For a while. Then I stared at it for six months and realized half the folders were doing nothing, the taxonomy had jargon I was learning on the fly, and every capture required thinking about three other captures first. That's when I went shopping.

I tried **Karpathy's** Wiki-style LLM-powered second brain. I tried **AgriciDaniel's** [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian). I tried [**eugeniu's system**](https://github.com/eugeniughelbur/obsidian-second-brain). I tried [**NicholasSpisak's second-brain**](https://github.com/NicholasSpisak/second-brain). And I kept going back to [**Jens Heitmann's ai-second-brain-skills**](https://github.com/NulightJens/ai-second-brain-skills) — not because it was the best, but because it was the one I already knew. Each of those had one thing the others didn't. None of them had everything.

So I merged them. I took what earned its keep from each of the five, threw out what didn't, and killed `00-Inbox/` (it's where good notes went to die). I killed `01-Fleeting/` (fleeting notes are just concepts you haven't written yet). I killed `05-Templates/` (templates belong in the plugin layer, not in your graph). I killed `06-Assets/` (Obsidian already handles attachments in place).

What was left was six folders, thirteen skills, and a vault that doesn't require a taxonomy degree to use. Built for a layman. No complicated language. No complicated anything.

The last piece — a **self-learning tier**. A couple of the originals had one, but bootstrapping them was heavy. This pack's is opt-in (`--with-intelligence`), ships clean, and fills itself in as you use the vault. Ignore it forever and the pack still works; turn it on and it stops feeling like a filing cabinet and starts feeling like… well, a second brain.

So: we went from maxxing to absolutely **mogging** everybody.

---

## What you get

- **The 6-folder vault-mogging layout** — the contract you install against, pre-wired to the skills below.
- **13 Claude Code skills** (10 core + 2 optional importers + a `/vault-coach` onboarding guide) that read + write against that layout with a shared alias dictionary + dry-run previews.
- **Four scheduled agents** (morning / nightly / weekly / health) that audit the vault in the background so you don't have to.
- **An opt-in self-learning tier** from **[FidgetFlo](https://github.com/fidgetcoding/fidgetflo)** (my MIT-licensed fork of [ruvnet's `ruflo@v3.5.80`](https://github.com/ruvnet/ruflo/tree/v3.5.80), made better) — a pattern-graph that makes routing smarter the longer you use the vault.
- **Import tools** for bringing in every Claude.ai / ChatGPT conversation you've ever had, plus Apple Notes / OneNote / Notion / Evernote / raw docs — so you don't start from empty.

---

## Install Obsidian first

**TL;DR — you can skip this whole section on macOS.** The installer auto-installs Obsidian.app via `brew install --cask obsidian` if it's missing, and auto-creates the vault directory if you point `--vault` at a folder that doesn't exist yet. Pass `--no-obsidian-app` to opt out of the auto-install if you'd rather grab Obsidian yourself.

The pack installs the Obsidian *configuration* on top of the Obsidian app. If the auto-install runs, you're done with this step — jump to [Install the mogging pack](#install-the-mogging-pack). Otherwise (Linux / Windows / no Homebrew / `--no-obsidian-app`), do it manually:

1. Go to **[obsidian.md](https://obsidian.md/download)** and download the installer for your OS.
2. Run the installer. It takes about 30 seconds.
3. Open Obsidian. It'll ask where your vault should live.
4. **Strong recommendation:** put it at `~/BRAIN2/`. That's `/Users/<you>/BRAIN2/` on macOS — directly in your home folder, **not** under `~/Desktop`. Reasons:
   - **Do NOT use `~/Desktop`, `~/Documents`, or `~/Downloads`.** On modern macOS those directories are permission-protected (TCC / Full Disk Access). The terminal gets "Operation not permitted" there, and git + the installer fail. Keep the vault in your home dir (`~/BRAIN2`, or `~/<vault-name>`).
   - Short path — easier to type in scripts and your shell.
   - You'll have a lot of subfolders. A shallow root path keeps them navigable.
   - The import + sync scripts auto-detect vaults at `~/BRAIN/` or `~/BRAIN2/` without needing a `VAULT_PATH=…` prefix.
5. Accept the "Create new vault" prompt. Obsidian makes the folder.
6. **Done — close Obsidian.** The next step runs from the terminal and wants the vault folder empty-ish.

> If you hit any install weirdness, the fix is almost always "use the official installer, not a script." That's why the auto-install path is `brew install --cask obsidian` (Homebrew's cask uses the official installer under the hood) and why we don't curl-pipe-shell the Obsidian binary ourselves.

---

## Prerequisites

Before running the installer you need two things on your machine. Takes about 5 minutes if you don't have them yet.

**1. Claude Code** — the CLI that runs all the skills.

```bash
# Fastest way — this one-liner handles everything (Homebrew, Node, claude, aliases)
bash <(curl -fsSL https://raw.githubusercontent.com/fidgetcoding/cli-maxxing/main/step-1/step-1-install.sh)
```

Already have it? Run `claude --version` to confirm. If that prints a version number, you're good.

**2. `jq`** — a command-line JSON tool the installer uses to merge your settings file safely.

```bash
# macOS
brew install jq

# Already have Homebrew? That's all you need. No Homebrew yet? The cli-maxxing Step 1 above installs it.
```

Already have it? Run `jq --version` to confirm.

> **Coming from cli-maxxing?** If you've already run cli-maxxing Step 1 + Step 3, you have both. Skip straight to [Install the mogging pack](#install-the-mogging-pack).

---

## Install the mogging pack

Once Obsidian is installed and you have a vault folder (e.g. `~/BRAIN2/`), the pack's installer takes over.

> **Vault location matters.** Keep your vault in your home dir (`~/BRAIN2`, `~/<vault-name>`). Do **not** put it under `~/Desktop`, `~/Documents`, or `~/Downloads` — modern macOS permission-protects those folders, so the terminal gets "Operation not permitted" and git + the installer fail.

```bash
git clone https://github.com/fidgetcoding/2ndBrain-mogging.git
cd 2ndBrain-mogging

# Dry-run first (default) — shows every change without touching disk
./install.sh --vault ~/BRAIN2

# Then apply for real
./install.sh --vault ~/BRAIN2 --apply
```

**The useful flags:**

| Flag | Default | What it does |
|---|---|---|
| `--vault PATH` | — | Absolute path to your Obsidian vault. Required with `--apply`. |
| `--dry-run` | on | Simulate only — print every change, write nothing. |
| `--apply` | off | Execute the changes on disk and in `~/.claude/settings.json`. |
| `--no-launchd` | off | Skip the 4 scheduled-agent launchd jobs (morning / nightly / weekly / health). |
| `--no-obsidian-mcp` | off | Skip registering the `obsidian-mcp` server with Claude Code (`claude mcp add obsidian … $VAULT`). |
| `--no-statusline-brain` | off | Skip writing `~/.claude/.mogging-vault` — the vault-path marker [cli-maxxing](https://github.com/fidgetcoding/cli-maxxing)'s ⚡ fidgetflo statusline reads to light up the 🧠 Brain² indicator. |
| `--no-obsidian-app` | off | Skip auto-installing the Obsidian.app desktop client (macOS; default runs `brew install --cask obsidian` when the app is missing). |
| `--no-shell-shortcuts` | off | Skip writing the `cbrain` / `cbraintg` launchers to `~/.local/bin`. |
| `--no-skill-packs` | off | Skip the 5 third-party vault skill packs from `kepano/obsidian-skills` (and the `defuddle` npm CLI they need). See [Vault skill packs](#vault-skill-packs) below. |
| `--skip-tests` | off | Skip the onboarding test suite at the end. |
| `--merge-stop` | off | Replace the existing Stop hook instead of jq-merging onto it. |
| `--no-seed-vault` | off | Skip seeding the 6-folder vault layout from `vault-template/`. By default the installer copies in any of `01-Projects/<PROJECT>/conversations/`, `02-Sources/`, `03-Concepts/`, `04-Index/Projects-Index.md`, `01-Projects/{example-project-1, example-project-2, example-project-3, INCUBATOR}/`, `05-Tasks/`, `Claude-Memory/`, `CLAUDE.md`, `AGENTS.md` that are missing. Existing files are never overwritten. |
| `--with-intelligence` | off | Install the self-learning tier. See [Self-learning tier](#self-learning-tier-opt-in) below. |
| `--symlink` | off | With `--with-intelligence`: symlink helpers instead of hardlinking. |

On `--apply`, the installer, in order: validates the vault path, **seeds the 6-folder vault layout from `vault-template/` (any folder/file already in your vault is left untouched)**, backs up `~/.claude/settings.json`, jq-merges the Stop hook (never overwrites), symlinks skills + commands + agents into `~/.claude/`, symlinks `$VAULT/Claude-Memory/` to Claude Code's per-project memory dir, patches the canonical post-mogging contract block into your vault's `CLAUDE.md` (backs up the old one to `$VAULT/Claude-Memory/backups/<timestamp>/` first — idempotent marker block, never duplicates), installs the launchd plists (unless `--no-launchd`), installs the self-learning tier if `--with-intelligence` was passed, **registers the `obsidian-mcp` server with Claude Code pointed at your vault** (unless `--no-obsidian-mcp`), **installs the 5 third-party vault skill packs at a pinned upstream commit** (unless `--no-skill-packs`), **writes `~/.claude/.mogging-vault` so cli-maxxing's statusline can light up the 🧠 Brain² indicator** (unless `--no-statusline-brain`), runs the onboarding tests (unless `--skip-tests`), and finally runs `bin/doctor.sh` to sanity-check the install.

### Vault skill packs

Five skills from [`kepano/obsidian-skills`](https://github.com/kepano/obsidian-skills) (MIT, by Obsidian's founder) install into `~/.claude/skills/` at a **pinned commit** — the same rug-pull defense [creativity-maxxing](https://github.com/fidgetcoding/creativity-maxxing) uses for its third-party packs. They are fetched at install time, not vendored, so upstream fixes arrive on a deliberate version bump instead of a fork.

| Skill | What it does | Why the vault pack needs it |
|---|---|---|
| `obsidian-markdown` | Wikilinks, embeds, callouts, properties | Every note in `02-Sources/`, `03-Concepts/`, `04-Index/` is written in Obsidian Flavored Markdown. Without this an agent emits plain CommonMark and the graph quietly loses edges. |
| `obsidian-bases` | `.base` files — views, filters, formulas | Base files are code, not prose; guessing the schema corrupts them. |
| `json-canvas` | `.canvas` files — nodes, edges, groups | `04-Index/Map.canvas` is one. |
| `obsidian-cli` | Live vault operations | Needs the **Obsidian 1.12.7+** installer. On older Obsidian it installs but stays inert — that is expected, not a failed install. |
| `defuddle` | Web page → clean markdown | The capture front door for `/wiki add` and `/save --source`. |

**Why `defuddle` matters enough to be a default:** `WebFetch` runs a page through a small model and hands back a lossy summary — a 12,500-word source comes back as roughly 20 lines, and the prompt is not honored. That is exactly the failure the `02-Sources/` contract exists to prevent, since a source note is supposed to be the source of truth for what a page actually said. Defuddle strips nav/ads/clutter and returns the full body.

The skill shells out to a `defuddle` binary, so the installer also runs `npm install -g defuddle`. If npm is missing or the install fails you get a warning and a manual command, not a hard failure. On uninstall the five skill directories are removed, but the `defuddle` CLI is **left in place** — it is a shared global binary you may use outside the vault, and the uninstaller tells you the command to remove it yourself.

To update the pin: bump `SKILLPACK_COMMIT` in `install.sh`.

### Obsidian MCP

The installer runs `claude mcp add --scope user obsidian -- npx -y obsidian-mcp "$VAULT"` so Claude Code can read and write vault notes directly. Upstream: [`obsidian-mcp`](https://github.com/StevenStavrakis/obsidian-mcp) on npm. Idempotent — skips if already registered. Opt out with `--no-obsidian-mcp`. To re-wire later against a different vault: `claude mcp remove obsidian && claude mcp add --scope user obsidian -- npx -y obsidian-mcp <new-path>`.

### Statusline (redirect to cli-maxxing)

Mogging does **not** ship a statusline of its own. If you want the live `⚡ fidgetflo` status line — model name, context %, duration, swarm/hive/mini activity, plus a 🧠 Brain² indicator that lights up when you're working inside the vault — install [`cli-maxxing`](https://github.com/fidgetcoding/cli-maxxing). Cli-maxxing writes `~/.claude/statusline.sh` and wires it into `~/.claude/settings.json`.

The *only* thing mogging contributes is a one-line marker file: `~/.claude/.mogging-vault` contains your vault's absolute path. Cli-maxxing's statusline reads that file and lights up 🧠 when `$CWD` matches. No cli-maxxing installed? The marker is a harmless ~100-byte no-op. No mogging installed? Cli-maxxing's statusline still works — the 🧠 indicator just never shows.

Rewire later against a different vault:

```bash
echo "/absolute/path/to/new/vault" > ~/.claude/.mogging-vault
```

Opt out with `--no-statusline-brain` and the marker won't be written.

---

## After install: setup + maintenance

[`docs/MAINTAINING-YOUR-BRAIN.md`](docs/MAINTAINING-YOUR-BRAIN.md) is the post-install setup and maintenance guide — what to do first, how to add a folder or project without orphaning it, and how to keep the graph healthy over time. Read it once after you install.

You don't have to read it cold, though. The `/vault-coach` skill carries the same guidance and walks you through it interactively. It auto-loads on your first session in a freshly installed vault, and again whenever you add a folder or a new project — it forces an index note on the new folder, registers it in `Projects-Index`, and wires the bidirectional links so nothing ends up orphaned. The doc is the human reference; `/vault-coach` is the hands-on version.

---

## The 13 skills

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
| `/vault-coach` | Coach you through setting up and maintaining your vault — auto-loads after install and whenever you add a folder or project. Forces an index note on every new folder, registers it in Projects-Index, keeps the graph healthy. Pairs with `docs/MAINTAINING-YOUR-BRAIN.md`. **New.** |

All thirteen are auto-namespaced under the `2ndbrain-mogging` plugin. Both `/save` and `/2ndbrain-mogging:save` resolve to the same skill — use whichever form you like inside Claude Code.

---

## Vault structure

The post-mogging 6-folder layout. This is what the installer creates (and what every skill is hard-wired to target):

```
BRAIN/
├── 01-Projects/         # Active work. One folder per project. /save output now lives in `<PROJECT>/conversations/` (post-2026-05-08 restructure absorbed the old top-level `01-Conversations/`).
├── 02-Sources/          # External inputs — articles, videos, podcasts, book notes, cross-cutting LIT conversation mirrors
├── 03-Concepts/         # Atomic concepts — one idea per note, densely linked. The graph lives here.
├── 04-Index/            # Maps of Content — navigation hubs + audits
├── 05-Tasks/            # Obsidian Tasks plugin area files. Optional 2-way Morgen sync via task-maxxing (Notion dropped 2026-05-04).
└── Claude-Memory/       # Symlink to ~/.claude/projects/<vault>/memory — aliases.yaml + auto-memory shards
```

### `01-Projects/` in detail — example layout

Each project gets its own folder. The folder name **equals** the index filename exactly (no `-Index` suffix), so `[[example-project-1]]` resolves from anywhere in the vault.

```
01-Projects/
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

Deep rationale for each skill is in [`PHILOSOPHY.md`](PHILOSOPHY.md).

---

## Self-learning tier (opt-in)

Pass `--with-intelligence` to the installer and the pack wires in a pattern-graph from **[FidgetFlo](https://github.com/fidgetcoding/fidgetflo)** that plugs into `/save` and `/wiki` so routing gets progressively smarter as the vault grows, without rewriting a single one of your notes. 11 helper scripts get hardlinked into `$VAULT/.claude/helpers/` and 5 additional hook types (PreToolUse / PostToolUse / UserPromptSubmit / SessionStart / SessionEnd) get jq-merged into `~/.claude/settings.json` — your existing hooks are preserved. (FidgetFlo is my MIT-licensed fork of [ruvnet's `ruflo@v3.5.80`](https://github.com/ruvnet/ruflo/tree/v3.5.80); upstream copyright is preserved in FidgetFlo's `LICENSE`.)

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
3. **Inside Claude Code, run `/import-claude`** — scan first, dry-run, then apply. Each conversation becomes a full-fidelity capture in `01-Projects/<PROJECT>/conversations/` (post-2026-05-08; the old top-level `01-Conversations/` was retired), a factual LIT-mirror in `02-Sources/`, and (where ideas repeat) a concept stub in `03-Concepts/`.

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
- **Karpathy** ([`LLM Wiki` gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)-era second brain) — the wiki-style synthesis pattern that became `/wiki` and `/emerge`.
- **NicholasSpisak** ([`second-brain`](https://github.com/NicholasSpisak/second-brain)) — the Canvas-scratchpad pattern that became `/canvas`.

Each of them is worth a look even if you install this pack instead. They're the people who did the hard work; I just picked the best of five.

---

## License

MIT — see [`LICENSE`](LICENSE).

[⤴ back to top](#top)

## Security: gitleaks pre-commit hook

This repo ships with a `.gitleaks.toml` config and a one-liner installer for a local
pre-commit hook that scans staged content for secrets (GitHub tokens, API keys, JWTs,
etc.) before every commit.

```bash
bash scripts/install-pre-commit-hook.sh
```

The hook runs `gitleaks protect --staged` and blocks commits that contain secrets.
For emergencies you can bypass with `git commit --no-verify` — but DO NOT bypass for
real secrets. Use env vars or a secret manager instead.

If gitleaks isn't installed yet:
- macOS: `brew install gitleaks`
- Linux: https://github.com/gitleaks/gitleaks/releases
