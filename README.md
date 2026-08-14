# firstmate-toolbox

Personal setup for running Firstmate (herdr-backed agent) with a cinematic
ASCII splash opener.

## Contents

- `firstmate` — launcher: preflight checks (herdr server, gh auth, firstmate
  repo, toolchain), plays the splash in a new terminal window, then execs
  `opencode` in `~/firstmate`.
- `firstmate-splash.sh` — tear-free ASCII animation (single write per frame,
  segment-based renderer). Stars, moon, a sloop gliding on smoothstep easing,
  and a "FIRSTMATE" title reveal over the sea.
- `herdr.service` — systemd user unit running the herdr background session
  server (`herdr server`).

## Install

```sh
mkdir -p ~/.local/bin
cp firstmate firstmate-splash.sh ~/.local/bin/

mkdir -p ~/.config/systemd/user
cp herdr.service ~/.config/systemd/user/
systemctl --user enable --now herdr.service

# requires: gh, opencode, firstmate repo (~/firstmate), herdr on PATH
firstmate
```

## Notes

- Set `FIRSTMATE_NO_SPLASH=1` to skip the splash window.
- `firstmate-splash.sh --hold` keeps the terminal open on the final banner;
  `firstmate-splash.sh --frames N` renders N frames then exits (debug).
- Splash is pure ASCII by design (char-level transparency surgery breaks on
  multibyte chars).
