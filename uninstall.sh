#!/usr/bin/env bash
# Removes teams-launcher installation (user scope only).
set -euo pipefail

BIN_DEST="${HOME}/.local/bin/teams-launcher"
DESKTOP_DEST="${HOME}/.local/share/applications/teams-launcher.desktop"
ICON_DEST="${HOME}/.local/share/icons/hicolor/scalable/apps/teams.svg"
EXTENSION_DEST="${HOME}/.local/share/teams-launcher/extension"
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

if [[ -f "${ICON_DEST}" ]]; then
  rm -f "${ICON_DEST}"
  echo "Removed ${ICON_DEST}"
  removed=1
fi

if [[ -d "${EXTENSION_DEST}" ]]; then
  rm -rf "${EXTENSION_DEST}"
  echo "Removed ${EXTENSION_DEST}"
  removed=1
fi

if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
fi

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "${APP_DIR}"
fi

if [[ ${removed} -eq 0 ]]; then
  echo "Nothing to remove — teams-launcher was not installed."
fi

echo "Done."
