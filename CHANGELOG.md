# Changelog

All notable changes to `2ndBrain-mogging` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`install.sh` step 10.75 — third-party vault skill packs.** `--apply` now installs 5 skills from [`kepano/obsidian-skills`](https://github.com/kepano/obsidian-skills) (MIT) at a pinned commit: `obsidian-markdown`, `obsidian-bases`, `obsidian-cli`, `json-canvas`, and `defuddle`. Fetched at install time rather than vendored, so upstream fixes land on a deliberate `SKILLPACK_COMMIT` bump instead of a fork — same rug-pull defense creativity-maxxing uses for `blader/humanizer`. These close a real gap in the vault contract: the note formats in `02-Sources/`, `03-Concepts/` and `04-Index/` are Obsidian Flavored Markdown (wikilinks, callouts, properties, `.base`, `.canvas`), and without the format skills an agent emits plain CommonMark and the graph silently loses edges. `defuddle` closes the capture side — `WebFetch` runs a page through a small model and returns a lossy summary (a 12,500-word source comes back as ~20 lines), which defeats the entire point of a `02-Sources/` note being the source of truth for what a page said. Opt out with `--no-skill-packs`.
- **`install.sh` — `defuddle` npm CLI.** The `defuddle` skill shells out to a binary, so the installer runs `npm install -g defuddle` when it isn't already on PATH. A missing npm or a failed install warns with the manual command rather than failing the install. Skipped entirely under `--no-skill-packs`.
- **`uninstall.sh` — `remove_vault_skill_packs`.** The skill packs are *copied* in, not symlinked, so `unlink_kind "skills"` deliberately leaves them ("not a symlink; leaving") and they would otherwise orphan in `~/.claude/skills` forever. The new remover deletes them, but only when the path is a real directory — a symlink means another tool owns it. The shared `defuddle` CLI is intentionally **left installed** (the user may rely on it outside the vault); the uninstaller just prints the command to remove it.
- **`tests/test_vault_skill_packs.sh`** — 14 assertions covering the new step: all 5 packs land as real dirs, upstream `.git` metadata is stripped, `--no-skill-packs` skips cleanly, a dead pin warns and continues instead of aborting the install, npm is only invoked when `defuddle` is genuinely absent, and uninstall removes the dirs while leaving the shared CLI. Never touches the network — `git` and `npm` are shimmed, and the test builds a closed PATH so an ambient `defuddle` on the developer's own machine can't mask the install-when-absent case.
- **`install.sh` step 1.5 — auto-install Obsidian.app on macOS (<ORG-D> install-call item 2).** When Obsidian.app is missing from `/Applications/`, the installer now runs `brew install --cask obsidian` automatically (idempotent — no-op when already present). Falls back to a download-pointer message on Linux/WSL or when Homebrew isn't on PATH. Opt out with `--no-obsidian-app`. README "Install Obsidian first" section softened to a one-line TL;DR plus a fallback manual section for non-macOS / opt-out users. Source: `project_<ORG-D>_install_bugs_2026_04_22` + <ORG-D> Apr-22 install-call transcript (3 teammates independently bailed at this wall).
- **`bin/doctor.sh` — root-owned `~/.npm` check (item 7).** New `check_npm_cache_ownership` walks `~/.npm` (top 2 levels via `find -maxdepth 2 -user root -print -quit`) and surfaces a `[doctor:FAIL]` with the literal copy/paste fix `sudo chown -R $(whoami) ~/.npm` plus the fully-literal fallback `sudo chown -R <user>:staff ~/.npm` for shells that swallow the substitution. Same check ALSO runs at the very end of `install.sh` so the fix is on-screen the moment install completes — users don't have to remember to invoke `doctor` separately.
- **`bin/doctor.sh` — filename-equals-foldername check for `01-Projects/` (item 9).** New `check_project_filename_equals_folder` walks `$VAULT/01-Projects/*/` and verifies `<folder>/<folder>.md` exists, surfacing `[doctor:FAIL]` per missing index file with the exact `mv` command that fixes it. Vault path is discovered from the `~/.claude/.mogging-vault` statusline marker (or `$VAULT` env override). Never auto-renames — project index files are owner=human per CLAUDE.md hard rule.
- **`bin/doctor.sh` — `Projects-Index.md` stale-wikilink check (item 10).** New `check_projects_index_stale_wikilinks` parses `[[X]]` tokens from `04-Index/Projects-Index.md` and verifies `01-Projects/X/X.md` exists for each. Skips known non-project hubs (Home-Index, Tech-Index, GITHUB, <ORG-A>, etc.). Flags stale wikilinks with explicit "do NOT auto-delete; flag for human review" reminder per the vault hard rule against silent removal.
- **`install.sh` step 13 — `print_install_summary` (item 11).** Final post-install banner prints an explicit `Self-learning tier: ON | OFF (opt-in via --with-intelligence)` line so users running default install don't think the install is broken when they don't see `helpers/` in the vault. Also surfaces `--no-obsidian-app` and `--no-obsidian-mcp` skip-states inline so the post-install summary matches what was actually wired up. Source: `project_<ORG-D>_install_bugs_2026_04_22` + <ORG-D> Apr-22 install-call transcript.
- README: social-links badge strip (X · LinkedIn · YouTube · Instagram, ruvnet-style for-the-badge) inserted into the centered header block beneath the project license badge.
- **`install.sh` step 10.7 — register `obsidian-mcp` with Claude Code.** `--apply` now runs `claude mcp add --scope user obsidian -- npx -y obsidian-mcp "$VAULT"` so Claude Code can read/write the vault out of the box. Idempotent (skips if already registered), opts out with `--no-obsidian-mcp`, and gracefully noops if the `claude` CLI isn't on PATH. Closes the cli-maxxing README cross-reference that previously promised this behavior before it existed (b0c38cd).
- **`install.sh` step 10.8 — `~/.claude/.mogging-vault` marker file.** Install writes a marker pointing at the vault root so cli-maxxing's statusline can detect a mogged vault and render the correct `fidgetflo` / mogging indicator. Closes the second half of the cli-maxxing cross-reference (7feeedf).
- **`install.sh` step 3.5 — vault-template seeding.** Fresh `--apply` runs now copy `vault-template/` into the target vault when the 7-folder layout is absent, including three placeholder projects (`example-project-1/2/3`) and a seed `Projects-Index.md` so `/tether` has something to audit on day one.
- **`/import-claude` and `/import-notes` skills** — brought the shipped skill count to 12. `/import-claude` routes a Claude.ai Project export (conversations + knowledge + assets) into the matching `01-Projects/<PROJECT>/` subtree; `/import-notes` handles the more general "pile of files from somewhere else" case.
- **FidgetFlo attribution in README** — the self-learning intelligence tier is sourced from FidgetFlo (a fork of ruvnet/ruflo@v3.5.80) and now credited as such.
- **NicholasSpisak repo link** — added to the origin story and Credits.

### Fixed
- **`install.sh` `validate_vault` no longer bails when `--vault` points at a missing directory (<ORG-D> install-call item 5).** Previously the script exited with code 21 + a "create it first, then re-run" message, forcing a 2-step install for every fresh teammate. Now `--apply` runs `mkdir -p "$VAULT"` (after the existing `..`-traversal guard) and lets vault-template seeding (step 3.5) populate the empty dir on the same pass. Dry-run logs `would create vault directory: <path>` instead of erroring. Source: <ORG-D> Apr-22 install transcript (Ian, Kostas, Scott all hit this).
- **`install.sh` `link_claude_memory` no longer requires a 2-pass install (<ORG-D> install-call item 8).** Previously the symlink step skipped when `~/.claude/projects/<encoded-vault>/memory/` didn't exist yet (cbrain had to run once first to mint it). Now the installer mkdir -p's that path itself before linking, so `cbrain` works on first invocation post-install. Claude Code's first-run also mkdir -p's the same path, so racing it is a no-op for Claude.
- **`install.sh` no longer references the non-existent `npm cache fix` subcommand (<ORG-D> install-call item 6).** Repo-wide grep returned zero hits at audit time (the bad string had already been stripped during prior cleanup), but the legacy fix message was preserved as a comment in `check_npm_cache_ownership` so future contributors don't reintroduce it. The actual user-facing fix string is now the literal `sudo chown -R $(whoami) ~/.npm` (with a `:staff` fallback for shells that drop the substitution).
- **launchd plist `node` PATH resolution.** The four `scheduled/launchd/*.plist` templates had a `PATH` that listed `/opt/homebrew/bin` but never sourced nvm, so scheduled agents on nvm-managed Node installs hit `sh: exec: node: not found` inside the SessionEnd hook. The plists now source `$HOME/.nvm/nvm.sh` inside `ProgramArguments`, which stays version-agnostic — no hardcoded `vN.N.N` path to maintain (04c796e).
- **`install.sh` `merge_intelligence_hooks()` jq bug.** The merge pipeline was `(.[0] * .[1]) as $m | $m | .[0]...` — after the `$m |` step, the pipeline context is the merged object, so `.[0]` threw `Cannot index object with number` and the `--with-intelligence` install aborted mid-flight. Bind `$old` / `$new` before the merge, and the hook-array concat logic goes through untouched. Verified end-to-end: `install.sh --with-intelligence` completes, `doctor` passes, all 4 launchd jobs reload with working `node` PATH, Stop hook preserved, 5 intelligence hooks appended, `settings.json` stays valid JSON (04c796e).
- **launchd plist flags.** Stale `--headless --audit` flags dropped from the agent invocations in the four `scheduled/launchd/*.plist` templates (pre-existing carry-over from pre-mogging).
- **the operator → the operator sweep.** Purged every "the operator" / "the operator" reference from shipped skill MDs, commands, README, and migration docs. Canonical is the operator / <ORG-A>.
- **Ruvnet/claude-flow/ruflo attribution.** Removed the inaccurate direct-descent claim from README in favor of the actual lineage (FidgetFlo fork).
- **15-agent audit-and-fix pass.** Full consistency sweep across `README.md`, `PHILOSOPHY.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `docs/**`, `references/wiki-schema.md`, and every `skills/*/SKILL.md` to close the residual drift between prose and shipped behavior after v0.1.4.

### Changed
- Git history rewrite: `git filter-repo` collapsed all author/committer identities into a single `the operator <operator@example.com>` identity across `main` and all release tags. All `Co-authored-by:` trailers stripped. Two stale dependabot/* branches deleted from the remote. Tag commit hashes for v0.1.0 / v0.1.1 changed; this repo has no published npm artifact, so no downstream impact.

## [0.1.4] — 2026-04-17

### Added — `install.sh` now applies the CLAUDE.md patch (closes v0.1.3 known gap)

Previously `docs/CLAUDE-MD-PATCH.md` was the canonical post-mogging contract that was supposed to be appended to every user vault's `CLAUDE.md` at install time, but the installer didn't actually consume it — the file was documentation-only. New users who ran `install.sh --apply` got skills, agents, and launchd plists wired up, but their vault's `CLAUDE.md` still described whatever layout they had before install. This closes that gap.

- **New install step: `apply_claude_md_patch` (step 9.5)** — runs between `link_claude_memory` and `install_launchd` in the main install sequence. Extracts the canonical block (between `<!-- 2ndbrain-mogging:start -->` and `<!-- 2ndbrain-mogging:end -->` markers) from `docs/CLAUDE-MD-PATCH.md` and writes it to `$VAULT/CLAUDE.md`.
- **Idempotent** — re-running `install.sh --apply` detects existing markers and replaces the block between them, never duplicating.
- **Legacy migration** — vaults that have the pre-namespaced `<!-- mogging:start -->` / `<!-- mogging:end -->` marker pair from older installs get their legacy block stripped and replaced with the new namespaced block. No manual migration required.
- **Backup-before-mutation** (non-negotiable #1 enforced) — the existing vault `CLAUDE.md` is copied to `$VAULT/Claude-Memory/backups/YYYY-MM-DD-HHMMSS/CLAUDE.md.bak` before any write.
- **Fresh vaults handled** — if the vault has no `CLAUDE.md`, a minimal header is created and the patch is appended below it.
- **Honors `--dry-run`** — logs the intended patch in dry-run mode; only writes on `--apply`.
- **New exit code 41** — reserved for patch extraction failures (missing markers in source file).

No behavior change for users who don't re-run the installer. Next `install.sh --apply` on any existing install will migrate the CLAUDE.md block to the current canonical contract.

## [0.1.3] — 2026-04-17

### Fixed — post-mogging contract sync across skills, docs, schema

15-agent /fswarmmax fix swarm addressed all known pre-mogging folder drift in skill runtime paths, README tables, migration docs, and the CLAUDE-MD-PATCH template that gets appended to user vaults at install. Before this release, the plugin documented the post-mogging 7-folder layout in prose while still carrying pre-mogging destinations (`07-Projects/`, `08-Tasks/`, `02-Literature/`, `03-Permanent/`, `00-Inbox/`, `01-Fleeting/`, `06-Assets/`) throughout skill specs — meaning `/save`, `/wiki`, `/challenge`, `/emerge`, and siblings could route writes to folders the contract had already retired.

- **`skills/{aliases,autoresearch,backfill,canvas,challenge,connect,emerge,save,wiki}/SKILL.md` + `references/wiki-schema.md`:** 31 of 49 pre-mogging folder references updated to post-mogging targets (historical prose preserved where it describes the rename itself). Every runtime destination, routing rule, and example path now resolves against `01-Projects/<PROJECT>/conversations/` (post-2026-05-08; `01-Projects/<PROJECT>/conversations/` was retired) / `02-Sources/` / `03-Concepts/` / `04-Index/` / `01-Projects/` / `05-Tasks/` / `Claude-Memory/`.
- **`docs/CLAUDE-MD-PATCH.md`:** full rewrite (147 → 192 lines). This is the file appended to user vaults' CLAUDE.md at install time — previous versions installed stale pre-mogging contract into new vaults. Marker block renamed from `<!-- mogging:* -->` to `<!-- 2ndbrain-mogging:* -->` for namespace clarity. Now carries the canonical 7-folder table, killed-folders callout, grandfathered-type mapping (literature→source, permanent→concept, moc→index, fleeting→inbox-residue), 10 skills list, 4 scheduled agents with correct times (morning 8am, nightly 10pm, weekly Fri 6pm, health Sun 9pm), 3 non-negotiables, bot-prefix commits table, and 9 hard rules.
- **`README.md`:** regime-ownership table updated (HUMAN → `03-Concepts/`, PROJECT → `01-Projects/` + `05-Tasks/`, LLM-COMPILED → `03-Concepts/wiki-*.md`). Scheduled-agents table fully rewritten to match shipped plists + agent-spec write paths (`01-Projects/VAULT/conversations/reports/*`). Backward-compat claim about killed folders inverted — `aliases.yaml` remaps entity names only, not folder structures.
- **`MIGRATION.md`:** folder-numbering callout rewritten to the post-mogging 7-folder scheme with pointer to `docs/MIGRATION.md` for pre-mogging → post-mogging migration runbook. `/aliases init` walk target corrected `07-Projects/` → `01-Projects/`.
- **`CONTRIBUTING.md`:** test harness path typo `tests/run-all.sh` → `tests/run_all.sh` (actual filename uses underscore).

### Changed — regex hardening for PII scrub

- **`.filter-repo-replacements.example.txt`:** added explicit WARNING section documenting the v0.1.1 substring-bleed regression mode. Future forks get a prominent callout: `regex:\bNAME\b` word-boundary patterns are NOT safe with all `git-filter-repo` versions — use capitalized literal rules instead. Documents the exact corruption signature (`security` → `sec<person-i>ty`, etc.) so the mistake cannot be innocently reintroduced.

### Known gaps (v0.1.3)

- `install.sh` does not currently consume `docs/CLAUDE-MD-PATCH.md` — the file is a reference template not yet wired into the live installer. Wiring the append step is tracked as a follow-up.

## [0.1.2] — 2026-04-17

### Fixed
- **Critical: reverted substring corruption from v0.1.1 PII scrub.** The `regex:\buri\b==><person-i>` rule in `.filter-repo-replacements.txt` did not honor its word-boundary `\b` anchors, so `git-filter-repo` replaced `uri` as a literal substring in 39+ English words across 19 files. `security` became `sec<person-i>ty`, `during` became `d<person-i>ng`, `heuristics` became `he<person-i>stics`, `buried` became `b<person-i>ed`, `configuring` became `config<person-i>ng`, `gesturing` became `gest<person-i>ng`. Same bug with `\balan\b` corrupted `balance` → `b<person-c>ce`. All reverted across `CHANGELOG.md`, `docs/SECURITY.md`, `references/wiki-schema.md`, `scripts/prepublish-check.sh`, `.github/workflows/secret-scan.yml`, 5 skill files, 2 vault-template files, 2 PII-config examples, and more.
- **Critical: `.github/workflows/secret-scan.yml:76` now correctly references `trufflesecurity/trufflehog@main`** (was `trufflesec<person-i>ty/trufflehog@main` → GitHub Actions failed to resolve the action on every push).
- **Prepublish gate restored.** `scripts/prepublish-check.sh` now prints `"security-gate files present"` instead of `"sec<person-i>ty-gate files present"`.
- **Placeholder preservation:** legitimate mapping rule `regex:\buri\b==><person-i>` in `.filter-repo-replacements.txt` left intact (that's the config, not the corrupted output). A future history rewrite needs a git-filter-repo version that honors regex-prefix word-boundaries, or a different replacement strategy (e.g., `--replace-message` pattern).

### Changed
- Scrubbed residual "auto-delete" / "auto-remove" / "silently delete|remove|overwrite|misfile" phrasing from `skills/wiki/SKILL.md`, `skills/save/SKILL.md`, and `references/wiki-schema.md` — replaced with "flag for human review" / "never remove without explicit human approval" language. Behavior unchanged; pure phrasing cleanup to remove alarming verbs from instruction manuals. Guardrail uses of "silent" (e.g., "never silently rewritten", "cannot be silently undone") preserved — they forbid silent behavior rather than promise it.

## [0.1.1] — 2026-04-17

### Fixed
- PII scrub: redacted all personal and private project names from skill files; replaced with stable `<PERSON-X>` / `<PROJECT-X>` placeholders (see [`docs/placeholder-names.md`](docs/placeholder-names.md)).
- `install.sh` idempotency: re-running with an existing `2ndbrain` Stop hook now skips the `jq` merge instead of appending a duplicate entry.
- `install.sh`: inline Stop-hook overlay referenced `hooks/stop-hook.sh`; corrected to `hooks/stop-save.sh` (matches the shipped filename).
- Eliminated hardcoded user-home paths from `install.sh` and the 4 `scheduled/launchd/*.plist` templates — `install.sh` now substitutes `$HOME` at install time.
- `skills/emerge/SKILL.md`: added missing `allowed-tools:` frontmatter field.
- `skills/wiki/SKILL.md`: removed stale `/cingest + /clint` reference from the skill description.
- README vault-structure diagram: updated from the legacy 9-folder layout to the post-mogging 7-folder contract.
- `docs/MIGRATION.md`: created — root `MIGRATION.md` referenced it three times but the file was missing.
- `CHANGELOG.md`: expanded v0.1.0 entry with the full feature list.

### Security
- Full git history rewrite via `git-filter-repo` to remove PII from all past commits (not just `HEAD`).

## [0.1.0] — 2026-04-16 — Initial release

### Added

**Skills (10, auto-namespaced under `2ndbrain-mogging`)**
- `save` — capture conversation content into the vault with alias-driven classification
- `wiki` — add, audit, heal, and find across the vault (unifies legacy `/cingest` + `/clint`)
- `challenge` — adversarial agent that argues against an idea using the user's own prior notes
- `emerge` — pattern-miner across recent vault activity; surfaces rising topics and killed ideas
- `backfill` — scrape historical Claude Code JSONL session transcripts into the vault
- `aliases` — bootstrap and maintain `Claude-Memory/aliases.yaml` entity→project dictionary
- `autoresearch` — three-round web research loop with gap-filling and source reconciliation
- `canvas` — generate and maintain Obsidian Canvas files from vault queries
- `tether` — audit and repair bidirectional linking rules in `01-Projects/`
- `connect` — bridge two unrelated notes via semantic overlap and candidate wikilinks

**Scheduled agents (4, audit-only by default)**
- `morning` — 8am ET
- `nightly` — 10pm ET
- `weekly` — Friday 6pm ET
- `health` — Sunday 9pm ET

**Installer tooling**
- `install.sh` — 448-line installer with `--dry-run` default, `--apply`, `--vault PATH`, `--no-launchd`, `--skip-tests`, `--merge-stop` flags. Installs skills / commands / agents via symlink, merges the Stop hook with `jq` (never overwrites `~/.claude/settings.json`), links `Claude-Memory` inside the vault, runs the test suite.
- `uninstall.sh` — clean removal path, mirrors install order.
- `bin/doctor.sh` — installation health check.
- `bin/backup-vault.sh` — tarball backup to `~/Desktop/2ndBrain-backup-*.tar.gz`.

**Vault contract**
- Post-mogging 7-folder layout: `01-Projects/<PROJECT>/conversations/` (post-2026-05-08; `01-Projects/<PROJECT>/conversations/` was retired), `02-Sources/`, `03-Concepts/`, `04-Index/`, `01-Projects/`, `05-Tasks/`, `Claude-Memory/` (symlink).
- Six root sidecars: `AGENTS.md`, `CLAUDE.md`, `CRITICAL_FACTS.md`, `SOUL.md`, `index.md`, `log.md`.
- Four-regime architecture: HUMAN / PROJECT / SYNC / LLM-COMPILED.
- `[bot:*]` commit-prefix convention to suppress n8n re-ingest on automated writes.

**Security**
- `.gitleaks.toml` with custom rules for morgen-api, n8n-api, private email, and private client names.
- `.github/workflows/secret-scan.yml` running gitleaks + trufflehog on every push.
- `config/nathan.pii` and `config/secrets.patterns` as the canonical PII/secret lists.
- `scripts/prepublish-check.sh` — fail-closed prepublish gate.

**Repository scaffold**
- `vault-template/` for fresh vault onboarding.
- `.claude-plugin/`, `skills/`, `agents/`, `commands/`, `hooks/`, `scheduled/`, `docs/`, `tests/`, `bin/`, `references/` folders.
- MIT license.
- `.gitignore` covering macOS `.DS_Store`, Node artifacts, env files, test-vault Claude memory, install-script signature files.

**Documentation**
- `CONTRIBUTING.md` — direct-push policy, skill authoring guide.
- `PHILOSOPHY.md` — tier 1/2/3 model, four-regimes rationale.
- `docs/CREDITS.md` — attribution to 5 upstream sources + 3 secondary.
- `docs/SECURITY.md` — gitleaks config, `install.sh` trust boundary (minisign + SHA-256 + pinned public key).
- `docs/foundations/01-05` — per-source analysis documents.
- `docs/placeholder-names.md` — public-facing explainer of the `<PERSON-X>` / `<PROJECT-X>` redaction convention.

**Tests**
- 7 `tests/test_*.sh` scripts plus `tests/lib/assertions.sh` — harness covering install, uninstall, skills, migration, idempotency, Stop-hook merge, and launchd plists.
