# Security Policy

This document describes how security is handled for the `2ndBrain-mogging`
public plugin. It covers disclosure, the install-time trust boundary, the
automated secret-scrub coverage, known residual risks, and the mandatory
pre-publish checks that every release must pass.

---

## 1. Reporting a vulnerability

Please **do not** open a public GitHub issue for suspected security
vulnerabilities.

- Email: `security@lorecraft.io` (placeholder — replace with the actual
  disclosure inbox before first public release)
- Expected first response: within **72 hours** on weekdays
- Please include:
  - A description of the issue and its impact
  - Reproduction steps (minimal, deterministic)
  - Affected version/commit SHA
  - Any proof-of-concept artifacts

We follow a coordinated disclosure model. We will acknowledge the report,
agree on a remediation window, and credit the reporter in the release
notes unless anonymity is requested.

---

## 2. Plugin install trust boundary

The primary install surface for this plugin is `install.sh`. Users are
effectively piping a shell script into their session, so the integrity
of that script is the single most important trust decision they make.

Our trust guarantees:

- **Signed releases.** Every tagged release publishes `install.sh` plus a
  matching [minisign](https://jedisct1.github.io/minisign/) signature
  (`install.sh.minisig`) and a SHA-256 digest (`install.sh.sha256`).
- **Published public key.** The minisign public key is published in the
  repo root as `minisign.pub` and is also pinned in the release README.
  Users should verify against the pinned value, not against whatever
  ships next to the signature.
- **Checksum-before-execute.** The recommended install command verifies
  the SHA-256 digest before piping to `bash`. The one-liner in the
  README fetches `install.sh.sha256` first and aborts on mismatch.
- **Reproducible.** `install.sh` is deterministic. Given the same repo
  contents at a given tag, the SHA-256 of the script never changes.

### Verification example

```bash
# 1. Download
curl -sSfL -o install.sh      https://example.com/releases/vX.Y.Z/install.sh
curl -sSfL -o install.sh.minisig  https://example.com/releases/vX.Y.Z/install.sh.minisig

# 2. Verify signature (public key pinned in README)
minisign -V -p minisign.pub -m install.sh

# 3. Cross-check the published digest
shasum -a 256 -c install.sh.sha256

# 4. Only after both pass, run it
bash ./install.sh
```

If any of the three checks fail, the script must not be executed.

---

## 3. Secret-scrub coverage

The repo runs two independent secret scanners and one PII sweep.

| Layer | Tool | Config | When |
| ----- | ---- | ------ | ---- |
| Commit-time | `gitleaks` | `.gitleaks.toml` | push, PR, daily cron, local pre-publish |
| Verified-only | `trufflehog` | GitHub Action + local | push, PR, daily cron, local pre-publish |
| Deny-list sweep | `grep -Ef config/nathan.pii` | `config/nathan.pii` | local pre-publish |
| Hard-block patterns | `config/secrets.patterns` | `HARDBLOCK[]` bash array | local pre-publish, any custom tooling |

**What gets blocked:**

- Anthropic keys (`sk-ant-*`, `sk-proj-*`, `sk-svcacct-*`)
- GitHub tokens (`ghp_*`, `gho_*`, `github_pat_*`)
- Notion integration tokens (`ntn_*`)
- AWS access keys (`AKIA*`)
- Slack tokens (`xox[baprs]-*`)
- Google OAuth access tokens (`ya29.*`)
- Supabase service-role keys (`sbp_*`)
- Stripe live keys (`sk_live_*`, `rk_live_*`)
- Cloudflare `v1.0-*` bearer tokens
- PEM private keys of any kind
- Morgen API keys (via custom gitleaks rule `morgen-api`)
- n8n PATs (via custom gitleaks rule `n8n-api`)
- Owner email `nate@lorecraft.io` and private collaborator first names
  (via `config/nathan.pii`)

**What gets flagged for manual review:**

- Stripe publishable live keys (`pk_live_*`)
- Generic `api_key = ...` assignments
- JWTs
- URL-embedded credentials (`scheme://user:pass@host`)

See [`config/secrets.patterns`](../config/secrets.patterns) for the
canonical lists.

---

## 4. Known residual risks

These are accepted risks that live outside the scope of automated
scanning for this repo.

- **Morgen API key rotation is out of scope.** The owner has explicitly
  declined to rotate the Morgen API key in private tooling; exposure is
  local-only and accepted. This public repo never contains that key,
  but the decision is documented here so downstream forks understand
  why no key-rotation guidance accompanies the Morgen integration.
- **Plugin side-effects.** `install.sh` writes files into the user's
  Claude Code configuration directory and Obsidian vault. Users should
  review the script contents before running, same as any install-from-
  curl workflow. The signature and checksum cover authorship and
  integrity, not behavioral review.
- **Historical commits.** Any secret that was present in git history
  before the first signed release must be considered exposed forever.
  Rotate rather than rewrite history.
- **Third-party dependencies.** Supply-chain risk in GitHub Actions
  (`gitleaks/gitleaks-action@v2`, `trufflesecurity/trufflehog@main`) is
  pinned to tags/branches rather than immutable SHAs to keep
  maintenance simple. Forks with stricter supply-chain requirements
  should pin to full commit SHAs.

---

## 5. Pre-publish checks (mandatory)

Every release **must** pass `scripts/prepublish-check.sh` locally before
the tag is pushed. CI reruns the same gitleaks + trufflehog checks, but
the PII sweep and checksum emission are local-only.

The script runs seven gates, fail-closed:

1. `gitleaks detect --config .gitleaks.toml --no-git` — exit 0 required
2. `trufflehog filesystem . --only-verified --fail` — exit 0 required
3. `grep -Ef config/nathan.pii` — no match required
4. `.gitleaks.toml` and `.github/workflows/secret-scan.yml` present
5. `.gitignore` excludes `Claude-Memory`
6. `LICENSE` file present
7. Emits `install.sh.sha256` for release attachment

There is no `--force` or `--skip` flag. If any check fails, fix the
underlying issue; never bypass the gate.

```bash
# from repo root
./scripts/prepublish-check.sh
```

If any gate fails, the release is not ready.
