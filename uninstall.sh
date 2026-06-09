#!/usr/bin/env bash
# Removes teams-launcher installation (user scope only).
set -euo pipefail

BIN_DEST="${HOME}/.local/bin/teams-launcher"
DESKTOP_DEST="${HOME}/.local/share/applications/teams-launcher.desktop"
APP_DIR="${HOME}/.local/share/applications"

echo "Uninstalling teams-launcher ..."

removed=0

if [[ -f "${BIN_DEST}" ]]; then
  rm -f "${BIN_DEST}"
  echo "Removed ${BIN_DEST}"
  removed=1
fi

if [[ -f "${DESKTOP_DEST}" ]]; then
  rm -f "${DESKTOP_DEST}"
  echo "Removed ${DESKTOP_DEST}"
  removed=1
fi

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "${APP_DIR}"
fi

if [[ ${removed} -eq 0 ]]; then
  echo "Nothing to remove — teams-launcher was not installed."
fi

echo "Done."
