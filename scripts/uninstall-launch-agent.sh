#!/usr/bin/env bash
set -euo pipefail

LABEL="com.kenneth2y.codextopguage.mac"
TARGET_PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

launchctl bootout "${GUI_DOMAIN}" "${TARGET_PLIST}" >/dev/null 2>&1 || true
rm -f "${TARGET_PLIST}"

echo "Uninstalled ${LABEL}"
