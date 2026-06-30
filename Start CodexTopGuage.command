#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ ! -x ".build/release/CodexTopGuageMac" ]]; then
  swift build -c release
fi

nohup "${SCRIPT_DIR}/.build/release/CodexTopGuageMac" >/tmp/codextopguage.command.log 2>&1 &

osascript -e 'tell application "Terminal" to close front window' >/dev/null 2>&1 &
exit 0
