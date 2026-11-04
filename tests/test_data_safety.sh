#!/usr/bin/env bash
# Disposable-vault regressions; no installed tools, network or live data.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 "$HERE/data_safety.py"
