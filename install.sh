#!/usr/bin/env bash
# User-scope installer for teams-launcher (no root required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
BIN_SRC="${SCRIPT_DIR}/bin/teams-launcher"
BIN_DEST="${BIN_DIR}/teams-launcher"
DESKTOP_TEMPLATE="${SCRIPT_DIR}/share/teams-launcher.desktop.in"
DESKTOP_DEST="${APP_DIR}/teams-launcher.desktop"
ICON_SRC="${SCRIPT_DIR}/share/icons/teams.svg"
ICON_DEST="${ICON_DIR}/teams.svg"

echo "Installing teams-launcher to ${BIN_DEST} ..."

mkdir -p "${BIN_DIR}" "${APP_DIR}" "${ICON_DIR}"

install -m 0755 "${BIN_SRC}" "${BIN_DEST}"

# Substitute @BINPATH@ with the absolute installed path (no ~ in Exec=).
sed "s|@BINPATH@|${BIN_DEST}|g" "${DESKTOP_TEMPLATE}" > "${DESKTOP_DEST}"

# Install icon into the hicolor theme so Icon=teams resolves correctly.
install -m 0644 "${ICON_SRC}" "${ICON_DEST}"
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
fi

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "${APP_DIR}"
fi

echo "Installed successfully."

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    printf 'WARNING: %s is not on your PATH.\n' "${BIN_DIR}" >&2
    printf '         Add to ~/.bashrc or ~/.profile:\n' >&2
    # shellcheck disable=SC2016
    printf '         export PATH="${HOME}/.local/bin:${PATH}"\n' >&2
    ;;
esac
