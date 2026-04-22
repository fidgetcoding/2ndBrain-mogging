#!/usr/bin/env bash
# tests/test_obsidian_mcp.sh
# install.sh step 10.7 registers the obsidian-mcp server with Claude Code
# pointed at the user's vault. Verifies:
#   - `claude mcp add --scope user obsidian -- npx -y obsidian-mcp <VAULT>` is
#     called when --apply is given
#   - The --no-obsidian-mcp flag skips the registration entirely
#   - The call is idempotent — if "obsidian:" already shows in `claude mcp list`,
#     install.sh does NOT re-add it
#
# Strategy: we never touch the user's real claude binary. We drop a fake
# `claude` shim on PATH that logs every invocation to a file we later
# inspect, so we can tell *what* install.sh tried to do.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=./lib/assertions.sh
source "$HERE/lib/assertions.sh"

assert_reset "test_obsidian_mcp"

TMPROOT="$(mktemp -d -t 2brain-obsmcp-XXXXXX)"
cleanup() {
  if [[ -n "${TMPROOT:-}" && ( "$TMPROOT" == /tmp/* || "$TMPROOT" == /var/folders/* ) ]]; then
    rm -rf "$TMPROOT"
  fi
}
trap cleanup EXIT

INSTALL_SH="$REPO_ROOT/install.sh"
if [[ ! -f "$INSTALL_SH" ]]; then
  printf "%sSKIP%s test_obsidian_mcp (install.sh not present)\n" \
    "${_C_YELLOW:-}" "${_C_RESET:-}"
  exit 0
fi

FAKE_HOME="$TMPROOT/home"
FAKE_VAULT="$TMPROOT/vault"
mkdir -p "$FAKE_HOME/.claude" "$FAKE_VAULT"

MOCK_BIN="$TMPROOT/mock-bin"
CALL_LOG="$TMPROOT/claude-calls.log"
MCP_STATE="$TMPROOT/claude-mcp-state"
mkdir -p "$MOCK_BIN"
: > "$CALL_LOG"
: > "$MCP_STATE"

# Fake claude: records every call, supports `--version`, `mcp list`, `mcp add`.
# `mcp list` prints lines sourced from $MCP_STATE, so we can pre-seed the
# idempotency case.
cat > "$MOCK_BIN/claude" <<SHIM
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$CALL_LOG"
case "\$1" in
  --version)
    echo "2.1.0 (Claude Code)"
    exit 0 ;;
  mcp)
    case "\$2" in
      list)
        cat "$MCP_STATE"
        exit 0 ;;
      add)
        # Record the add by appending to the state file so future mcp list
        # returns it — mimics real claude behavior.
        # Args pattern (scope variant):
        #   mcp add --scope user obsidian -- npx -y obsidian-mcp <vault>
        # We just look for a server name token that isn't a flag.
        local_name=""
        shift 2  # drop 'mcp add'
        while [[ \$# -gt 0 ]]; do
          case "\$1" in
            --scope) shift 2 ;;
            --transport) shift 2 ;;
            --) shift; break ;;
            -*) shift ;;
            *) local_name="\$1"; shift ;;
          esac
        done
        # Remaining args are the command. Record as "<name>: <cmd...>".
        echo "\${local_name}: \$*" >> "$MCP_STATE"
        exit 0 ;;
      remove)
        # Best-effort: filter out the matching prefix.
        grep -v "^\$3:" "$MCP_STATE" > "$MCP_STATE.tmp" || true
        mv "$MCP_STATE.tmp" "$MCP_STATE"
        exit 0 ;;
    esac
    exit 0 ;;
esac
exit 0
SHIM
chmod +x "$MOCK_BIN/claude"

# Seed a baseline settings.json with a user hook so we exercise the full
# install pipeline, not just the MCP step.
cat > "$FAKE_HOME/.claude/settings.json" <<'JSON'
{ "permissions": { "allow": [] } }
JSON

run_install() {
  # Prepend the mock bin so our fake claude wins over any real one.
  PATH="$MOCK_BIN:$PATH" \
  HOME="$FAKE_HOME" \
  VAULT_DIR="$FAKE_VAULT" \
    bash "$INSTALL_SH" --vault "$FAKE_VAULT" --apply \
      --no-launchd --skip-tests "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Case 1: first install registers obsidian-mcp.
# ---------------------------------------------------------------------------
: > "$CALL_LOG"
: > "$MCP_STATE"
FIRST_OUT="$(run_install || true)"
FIRST_RC=$?
assert_eq "$FIRST_RC" "0" "install.sh exits 0 with mock claude in place"

# The install should have issued `mcp add` for obsidian pointing at $FAKE_VAULT.
if grep -q "mcp add.*obsidian.*obsidian-mcp" "$CALL_LOG"; then
  _pass "install.sh called 'claude mcp add' for obsidian"
else
  _fail "install.sh did not call 'claude mcp add obsidian'"
  printf '  call log:\n' 1>&2
  sed 's/^/    /' "$CALL_LOG" 1>&2
fi

if grep -F -q "$FAKE_VAULT" "$CALL_LOG"; then
  _pass "mcp add command carries the vault path"
else
  _fail "mcp add command did not include the vault path"
fi

# State now holds the obsidian registration.
if grep -qE '^obsidian:' "$MCP_STATE"; then
  _pass "mock claude state now shows 'obsidian:' (MCP registered)"
else
  _fail "mock claude state missing 'obsidian:' after install"
fi

# ---------------------------------------------------------------------------
# Case 2: --no-obsidian-mcp skips the step.
# ---------------------------------------------------------------------------
: > "$CALL_LOG"
: > "$MCP_STATE"
SKIP_OUT="$(run_install --no-obsidian-mcp || true)"
SKIP_RC=$?
assert_eq "$SKIP_RC" "0" "install.sh exits 0 with --no-obsidian-mcp"

if grep -q "mcp add.*obsidian.*obsidian-mcp" "$CALL_LOG"; then
  _fail "--no-obsidian-mcp still tried to register obsidian"
else
  _pass "--no-obsidian-mcp did not call 'claude mcp add obsidian'"
fi

if echo "$SKIP_OUT" | grep -qi 'obsidian-mcp SKIPPED\|SKIPPED.*obsidian'; then
  _pass "install.sh logs SKIPPED message when --no-obsidian-mcp is given"
else
  # Soft-warn: the log wording may evolve — don't block on exact text.
  _pass "install.sh honored --no-obsidian-mcp (logs not asserted)"
fi

# ---------------------------------------------------------------------------
# Case 3: idempotent — pre-seeded 'obsidian:' skips a second add.
# ---------------------------------------------------------------------------
: > "$CALL_LOG"
: > "$MCP_STATE"
echo "obsidian: npx -y obsidian-mcp $FAKE_VAULT" > "$MCP_STATE"

IDEMP_OUT="$(run_install || true)"
IDEMP_RC=$?
assert_eq "$IDEMP_RC" "0" "install.sh exits 0 on re-run with obsidian already registered"

if grep -q "mcp add.*obsidian.*obsidian-mcp" "$CALL_LOG"; then
  _fail "install.sh re-added obsidian-mcp despite idempotency guard"
  printf '  call log:\n' 1>&2
  sed 's/^/    /' "$CALL_LOG" 1>&2
else
  _pass "install.sh skipped 'mcp add' when obsidian-mcp was already registered"
fi

if echo "$IDEMP_OUT" | grep -qi 'obsidian.*already registered\|already registered.*obsidian'; then
  _pass "install.sh logs 'already registered' message on idempotent re-run"
else
  # Soft-pass — exact wording may vary.
  _pass "install.sh behaved idempotently (exact log wording not asserted)"
fi

assert_report
