#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ ! -x ".build/release/CodexTopGuageMac" ]]; then
  swift build -c release
fi

open -gj ".build/release/CodexTopGuageMac"
