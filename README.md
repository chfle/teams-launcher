# teams-launcher

Microsoft Teams as an isolated Chromium app window on Linux.

## The problem

Teams for Linux is an Electron app in maintenance mode: it ships its own Chromium
plus an Electron runtime, eats memory, and lags behind the web client. Opening
Teams in your normal browser instead means a tab you keep losing, plus Microsoft
cookies and telemetry sitting in your everyday profile.

`teams-launcher` opens `teams.microsoft.com/v2/` in a dedicated Chromium profile
as a frameless app window — real launcher entry, real icon, one instance, and by
default nothing written to disk.

## Requirements

- Linux, Bash 4+, coreutils
- `chromium` or `chromium-browser` on `PATH` (`sudo apt install chromium`)

Optional: `xdotool`, `wmctrl` or `qdbus` to raise an already-running window;
`xprop` for the KDE taskbar icon; `shellcheck` and `desktop-file-validate` for
`make lint`.

## Install

```bash
git clone https://github.com/chfle/teams-launcher.git
cd teams-launcher
bash install.sh    # or: make install
```

Installs to `~/.local/bin`, plus a `.desktop` entry and icon under
`~/.local/share`. Remove with `bash uninstall.sh`.

## Usage

```bash
teams-launcher                      # ephemeral (default)
teams-launcher --mode=persistent    # keep login across launches
teams-launcher --dry-run            # print profile + command, don't launch
teams-launcher --help
```

`TEAMS_MODE` sets the mode, `CHROMIUM` overrides binary detection.
Launching while an instance runs raises the existing window instead of opening a
second one.

## Ephemeral vs persistent

| | Ephemeral (default) | Persistent |
|---|---|---|
| Profile | `$XDG_RUNTIME_DIR/teams-launcher-XXXX` (tmpfs) | `~/.local/share/teams-launcher/profile` |
| On exit | deleted | kept |
| Login / MFA | every launch | once |

Both modes are fully isolated from your main browser profile. If
`XDG_RUNTIME_DIR` is unset, ephemeral falls back to `/tmp` — still deleted on
exit, but it touches disk on the way.

## Development

```bash
make test    # headless, uses a Chromium stub — no browser needed
make lint    # shellcheck
```

## License

MIT — see [LICENSE](LICENSE).
