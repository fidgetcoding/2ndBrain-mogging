# Changelog

All notable changes to `2ndBrain-mogging` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- `tether` — audit and repair bidirectional linking rules in `05-Projects/`
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
- Post-mogging 7-folder layout: `01-Conversations/`, `02-Sources/`, `03-Concepts/`, `04-Index/`, `05-Projects/`, `06-Tasks/`, `Claude-Memory/` (symlink).
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
