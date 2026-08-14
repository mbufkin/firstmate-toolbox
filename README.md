# firstmate-toolbox

Personal setup for running Firstmate (herdr-backed agent) with a cinematic
ASCII splash opener. One GitHub point to pull everything down onto a new
computer.

## Contents

- `firstmate` — launcher: preflight checks (herdr server, gh auth, firstmate
  repo, toolchain), plays the splash in a new terminal window, then execs
  `opencode` in `~/firstmate`.
- `firstmate-splash.sh` — tear-free ASCII animation (single write per frame,
  segment-based renderer). Stars, moon, a sloop gliding on smoothstep easing,
  and a "FIRSTMATE" title reveal over the sea.
- `herdr.service` — systemd user unit running the herdr background session
  server (`herdr server`), portable via `%h`.
- `bootstrap.sh` — full new-machine setup (below).
- `skills/` — personal opencode skills, installed by bootstrap.

## Fresh machine (easy pull-down)

```sh
curl -fsSL https://github.com/mbufkin/firstmate-toolbox/archive/refs/heads/main.tar.gz | tar -xz
cd firstmate-toolbox-main
./bootstrap.sh
```

`bootstrap.sh` installs, idempotently (existing steps are skipped):

1. Base packages: `git`, `curl`, `jq`, `gnome-terminal`.
2. Node.js LTS 22 (NodeSource).
3. GitHub CLI (official apt repo).
4. opencode (official installer).
5. herdr (https://herdr.dev) + the user service, enabled.
6. `treehouse` and `no-mistakes` (official installers).
7. The axi toolchain (`gh-axi`, `chrome-devtools-axi`, `lavish-axi`,
   `tasks-axi`, `quota-axi`) with opencode hooks.
8. The firstmate distro (`kunchenguid/firstmate`) — **this is what brings your
   skills**: firstmate's 19 skills live in `.agents/skills/` inside that repo.
9. This toolbox's splash + launcher + herdr service.
10. Any personal skills from `skills/` → `~/.config/opencode/skills/`.

Then one manual step on a fresh machine:

```sh
gh auth login
firstmate        # splash -> opencode in ~/firstmate
```

## Manual install (existing machine)

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
