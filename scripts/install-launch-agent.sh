#!/usr/bin/env bash
set -euo pipefail

LABEL="com.kenneth2y.codextopguage.mac"
PLIST_NAME="${LABEL}.plist"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PLIST="${REPO_ROOT}/launchd/${PLIST_NAME}"
TARGET_DIR="${HOME}/Library/LaunchAgents"
TARGET_PLIST="${TARGET_DIR}/${PLIST_NAME}"
GUI_DOMAIN="gui/$(id -u)"

if [[ ! -x "${REPO_ROOT}/.build/release/CodexTopGuageMac" ]]; then
  swift build -c release
fi

codesign --force --sign - "${REPO_ROOT}/.build/release/CodexTopGuageMac" >/dev/null

mkdir -p "${TARGET_DIR}"
cp "${SOURCE_PLIST}" "${TARGET_PLIST}"

launchctl bootout "${GUI_DOMAIN}" "${TARGET_PLIST}" >/dev/null 2>&1 || true
launchctl bootstrap "${GUI_DOMAIN}" "${TARGET_PLIST}"
launchctl kickstart -k "${GUI_DOMAIN}/${LABEL}"

echo "Installed and started ${LABEL}"
