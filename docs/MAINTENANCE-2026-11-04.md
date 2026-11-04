# Maintenance pass — 2026-11-04

I audited the installer, uninstaller, updater, command gates, importers, scheduled templates, and helper entrypoints against disposable vaults. This pass preserves the existing layout and skill workflow.

## Data preservation

- Installation preserves existing memory before linking it. Two populated memory stores remain separate for manual reconciliation; unrelated skills and launchers are retained.
- Uninstall removes owned hooks from current settings, including individual hooks inside mixed user/mogging groups. It retains settings added after installation and keeps all recovery backups. Copied skill packs need an ownership marker before uninstall moves them to a backup.
- Backup names are unique even within one second. Vault archives are published only after successful compression; a backup destination inside its source is refused.
- Wiki creation uses exclusive publication, escapes YAML metadata, and reports filesystem failures. Alias proposals retain earlier pending review content. Missing CLI values exit with a usage error.
- Memory changes update frontmatter atomically while retaining the body’s exact bytes and existing permissions. Confirmation clears review flags; invalid calendar dates are refused. Scans prune dependency, VCS, staging, generated graph, and backup trees as appropriate.
- JSON helper writes publish a complete temporary file by rename. Corrupt existing state raises an error instead of being silently replaced with an empty store.

## Installation and runtime

- Stop and guard commands quote checkout paths. Plist values use XML escaping; scheduled prompts point at the repository’s agent files. The plugin manifest references the actual plist filenames.
- Settings must contain exactly one JSON object. Empty files, multiple JSON roots, and malformed hook containers are refused before install/uninstall side effects. Each settings mutation validates its input and complete output; unrelated settings and mixed command/prompt/agent hooks are retained. Unbalanced contract markers and symlinked `CLAUDE.md` files are preserved instead of being blindly rewritten.
- The updater keeps a full repository checkout, checks its origin/branch/local changes, and propagates failed downloads or installation.
- Import staging rejects path traversal, absolute paths, symlinks, special files, and duplicate archive names before extracting. It checks available space and cleans up partial failures. Python 3 is required for this importer.
- Hook handling reads `tool_input`, loads only the helpers needed by an event, and reports routing rules without fabricated measurements. Imported JavaScript helpers do not execute their CLI branches. Global intelligence hooks skip projects without installed helpers.
- Installer onboarding tests disable optional network installs. All new regressions use isolated fixture homes, vaults, and mocked external commands.

## Recovery

Settings and migrated directories are retained under `$CLAUDE_HOME/.backups/`; note snapshots are retained under `Claude-Memory/backups/`. Use the logged backup path to inspect and recover a specific original. Installation is a sequence of individually checked steps, not a transaction across the filesystem, launchd, and third-party installers. A later integration failure can leave earlier completed steps in place; preserve the backups and rerun after fixing the cause.

Legacy copied packs without an ownership marker remain installed. Existing foreign skills, conflicting memory stores, and foreign launchers require manual reconciliation. This avoids guessing which version should win.

## Validation boundaries

The shell suite runs on disposable vaults, with Python standard-library integration regressions. Bash syntax, ShellCheck, JavaScript syntax, Python syntax, JSON, and plist parsing are checked. No production vault, installed skill, real scheduled job, n8n sync, paid API, deployment, or remote push was used for validation.

The helper concurrency follow-up coordinates repository writers with bounded locks and adds recoverable consolidation transactions. See [helper state coordination and recovery](HELPER-STATE.md) for participating writers, pending-log retention, recovery steps and the external-writer boundary. The optional third-party memory bridge and external installers require a separate live integration check on a disposable machine. No Linux runtime was available in this session; the existing CI matrix remains the cross-platform check.

## Initial maintenance results

- `bash tests/run_all.sh --strict`: 12/12 suites passed, zero skips or failures, 157.407 seconds. This includes all 357 existing assertions and 35 new integration tests; the new tests took 32.741 seconds.
- Bash parsing and warning-level ShellCheck passed for 34 shell files, including extensionless commands and the sourced pattern configuration. JavaScript, Python, JSON and plist syntax checks passed. `git diff --check` passed.
- A `memory promote` dry-run benchmark used one concept plus 3,000 dependency Markdown files (13.5 MB). Three alternating before/after runs produced identical output. Baseline times: 2.1216, 2.0515, 2.1582 seconds. Updated times: 0.1447, 0.2160, 0.1812 seconds. Median: 2.1216 → 0.1812 seconds, an 11.71× improvement for this fixture. This measures the benefit of pruning dependency trees; it is not a whole-product speed claim.

The source baseline was `1d1a4202228409ddfdfa1d67d0bdb2693ef86f92`. The fixes remain on the local `optimize/20261104-2ndbrain-mogging` branch for review.

## Settings validation review follow-up

The initial object check used jq stream semantics, so multiple roots could pass and displace a merge overlay. Both scripts now share a slurping validator that requires one object and the hook container shapes they traverse. Uninstall also preserves pre-existing empty hook groups. Regression fixtures cover 22 invalid forms for each script and valid mixed user hooks. The results above describe the earlier maintenance pass. The follow-up reproduction against a preserved pre-fix snapshot produced 31 failed assertions. After the fix, all 44 invalid-input scenarios refused changes and preserved the fixture filesystem (bytes, permissions, directories and symlinks); valid mixed user settings and command/prompt/agent hooks survived the round trip.

Follow-up checks ran sequentially through the corrected shared two-job gate: targeted tests passed in 5.851 seconds; the strict suite passed 12/12 with zero skips/failures in 135.631 seconds, including 38 data-safety integration tests (30.000 seconds). Static checks passed, now covering 35 shell files plus Python/JavaScript/JSON/plist parsing. `git diff --check` passed. No live configuration, vault, installed hooks or scheduler was used. The earlier benchmark was not rerun because this change only affects settings validation.

## Helper concurrency review follow-up

Shared mutation locking now covers memory/session/intelligence and the auto-memory JSON backend. Pending appenders use a separate short lock so arrivals continue during consolidation. Pending JSONL bytes are retained; a checkpoint is committed with exact store/cache/snapshot outputs in a replayable transaction. Ten synchronized behavioral regressions failed against the preserved pre-fix source and then passed after the fix. Expanded verification passed: 24 helper tests in 38.439 seconds. The full strict suite passed 13/13 suites with zero skips/failures in 347.653 seconds: the original 357 assertions, 38 data-safety tests (73.077 seconds), and 24 helper tests (35.916 seconds). Static checks passed across 36 shell files plus Python/JavaScript/JSON/plist parsing. The same queued shared-gate job ran all checks sequentially; no duplicate verification was started. Before/after hashes matched for all ten follow-up files, and the closed settings code/tests were unchanged. Only verification documentation was updated afterward. Settings-validation work remains closed and preserved; the helper result is ready for hub review.

See [HELPER-STATE.md](HELPER-STATE.md) for the cooperative-writer boundary, bounded lock refusal/recovery, append-only history growth and replay behavior. Real optional integrations and Linux execution were not exercised. The earlier memory-scan benchmark remains historical evidence; this helper integrity change adds durable I/O and makes no performance-speedup claim.
