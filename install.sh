#!/usr/bin/env bash
# User-scope installer for teams-launcher (no root required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
BIN_SRC="${SCRIPT_DIR}/bin/teams-launcher"
BIN_DEST="${BIN_DIR}/teams-launcher"
DESKTOP_TEMPLATE="${SCRIPT_DIR}/share/teams-launcher.desktop.in"
DESKTOP_DEST="${APP_DIR}/teams-launcher.desktop"

echo "Installing teams-launcher to ${BIN_DEST} ..."

mkdir -p "${BIN_DIR}" "${APP_DIR}"

install -m 0755 "${BIN_SRC}" "${BIN_DEST}"

# Substitute @BINPATH@ with the absolute installed path (no ~ in Exec=).
sed "s|@BINPATH@|${BIN_DEST}|g" "${DESKTOP_TEMPLATE}" > "${DESKTOP_DEST}"

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "${APP_DIR}"
fi

echo "Installed successfully."

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    printf 'WARNING: %s is not on your PATH.\n' "${BIN_DIR}" >&2
    printf '         Add to ~/.bashrc or ~/.profile:\n' >&2
    printf '         export PATH="${HOME}/.local/bin:${PATH}"\n' >&2
    ;;
esac
