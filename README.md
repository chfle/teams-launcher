# teams-launcher

Launches Microsoft Teams as an isolated Chromium PWA-style app. The native Electron-based Teams for Linux client has been in maintenance mode and carries the overhead of a bundled Chromium plus Electron runtime; this project skips the wrapper entirely and opens the Teams web app (`teams.microsoft.com/v2/`) directly in a dedicated Chromium profile, giving you a lightweight, native app-window experience with full control over browser isolation and data retention.

## Requirements

- Linux with Bash ≥ 5 (Debian 13 / Trixie or equivalent)
- `chromium` or `chromium-browser` on PATH

```bash
sudo apt install chromium
```

- Optional (for `make lint`): `shellcheck`, `desktop-file-validate`

## Install

```bash
git clone https://github.com/your-user/teams-launcher.git
cd teams-launcher
bash install.sh
```

Copies `bin/teams-launcher` to `~/.local/bin/` and installs a `.desktop` entry to `~/.local/share/applications/` so Teams appears in your application launcher.

## Uninstall

```bash
bash uninstall.sh
```

## Usage

```bash
# Ephemeral mode (default — no state written to disk):
teams-launcher

# Persistent mode (login and MFA survive across launches):
teams-launcher --mode=persistent

# Switch via environment variable:
TEAMS_MODE=persistent teams-launcher

# Print resolved command and profile path without launching:
teams-launcher --dry-run

# Help:
teams-launcher --help
```

## Ephemeral vs Persistent

| | Ephemeral (default) | Persistent |
|---|---|---|
| Profile location | `$XDG_RUNTIME_DIR/teams-launcher-XXXX` | `~/.local/share/teams-launcher/profile` |
| On exit | Profile **deleted** by `trap … EXIT` | Profile kept |
| Login / MFA | Required every launch | Required once, then cached |
| Data on disk | **None** | Session cookies, cache, settings |
| Best for | Security-sensitive use, shared machines | Daily-driver convenience |

**Ephemeral** is the default. It leaves nothing on disk: every Teams session starts completely fresh with no saved login state. The tmpfs guarantee relies on `XDG_RUNTIME_DIR` being set by your PAM/logind session (standard on all modern desktop Linux). If `XDG_RUNTIME_DIR` is unset, the script falls back to `/tmp` — the profile is still deleted on exit by the `trap` handler, but it transiently exists on disk rather than in RAM.

**Persistent** stores state in an isolated Chromium profile that is entirely separate from your main browser's cookies and data. You authenticate once; login and MFA tokens survive across launches. No Teams data enters your default browser profile.

## Tests

```bash
make test
```

Tests run headless with no display and no real Chromium — a tiny shell stub stands in for the browser. The harness verifies: argument parsing, ephemeral profile lifecycle (created on launch, deleted on normal exit), SIGTERM cleanup, persistent mode isolation, the missing-Chromium error path, and unknown-flag exit codes. It also runs `shellcheck` and `desktop-file-validate` when available.

## Lint

```bash
make lint
```

Runs `shellcheck` on all shell scripts.

## License

MIT — see [LICENSE](LICENSE).
