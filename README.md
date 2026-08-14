# firstmate-toolbox

Personal setup for running **Firstmate on the Pi harness with herdr managing
the workers**. One GitHub point to pull down and set up a fresh computer — the
only manual step is adding your API keys.

## Contents

- `firstmate` — launcher: preflight checks (herdr server, gh auth, firstmate
  repo, toolchain, pi + keys), plays the splash in a new terminal window, then
  starts the Pi harness in `~/firstmate`. Set `FIRSTMATE_HARNESS=opencode` to
  use the opencode fallback instead.
- `firstmate-splash.sh` — tear-free ASCII animation (single write per frame,
  segment-based renderer). Stars, moon, a sloop gliding on smoothstep easing,
  and a "FIRSTMATE" title reveal over the sea.
- `herdr.service` — systemd user unit running the herdr background session
  server (`herdr server`), portable via `%h`.
- `bootstrap.sh` — full new-machine setup (below).
- `setup-keys.sh` — the API-keys step: interactively stores your provider keys
  in Pi's credential store (`~/.pi/agent/auth.json`, mode 0600).
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
4. opencode (fallback harness).
5. herdr (https://herdr.dev) + the user service, enabled.
6. **Pi** (https://pi.dev) — the primary harness.
7. `treehouse` and `no-mistakes` (official installers).
8. The axi toolchain (`gh-axi`, `chrome-devtools-axi`, `lavish-axi`,
   `tasks-axi`, `quota-axi`) with opencode hooks.
9. The firstmate distro (`kunchenguid/firstmate`) — **this is what brings your
   skills**: firstmate's skills live in `.agents/skills/` inside that repo.
10. Firstmate config: `config/backend` = `herdr` (herdr manages the workers),
    `config/crew-harness` and `config/secondmate-harness` = `pi` (set
    `FIRSTMATE_PI_MODEL` to pin a model for secondmates, e.g. `FIRSTMATE_PI_MODEL=anthropic/claude-sonnet-4-5 ./bootstrap.sh`).
11. **Matt Pocock's pi skills** (`mattpocock/skills`) installed for every Pi
    session into `~/.pi/agent/skills/`: `wayfinder`, `to-spec`, `to-tickets`,
    `implement`, `code-review`, `tdd`, `grilling`, `grill-me`, `research`,
    `prototype`, `triage`, `wizard`, `handoff`, and 17 more.
12. The **Vercel `web-design-guidelines` skill** (UI/accessibility design review
    — the "immaculate web design" one) from `vercel-labs/agent-skills`.
12. This toolbox's splash + launcher + herdr service.
13. Any personal skills from `skills/` → `~/.config/opencode/skills/`.

At the end it launches the API-keys prompt (or tells you to run it manually):

```sh
./setup-keys.sh        # add one or more provider keys
gh auth login          # GitHub
firstmate              # splash -> pi running firstmate in ~/firstmate
```

On first `pi` launch in a clone, approve Pi's project-trust prompt once so the
tracked watcher extensions load.

## How it fits together

- **Pi** is the coding agent (the harness firstmate runs on).
- **herdr** manages the workers: with `config/backend` = `herdr`, every
  crewmate/scout firstmate spawns runs as a Pi agent in a herdr pane.
- **firstmate** is the instruction distro in `~/firstmate`.
- **API keys** are the only manual input: they live in `~/.pi/agent/auth.json`
  (0600) or Pi's `/login` subscription flow, and every spawned Pi agent reads
  them automatically.

## Manual install (existing machine)

```sh
mkdir -p ~/.local/bin
cp firstmate firstmate-splash.sh ~/.local/bin/

mkdir -p ~/.config/systemd/user
cp herdr.service ~/.config/systemd/user/
systemctl --user enable --now herdr.service

# requires: gh, herdr, pi, firstmate repo (~/firstmate), API keys
./setup-keys.sh
firstmate
```

## Notes

- Set `FIRSTMATE_NO_SPLASH=1` to skip the splash window.
- Set `FIRSTMATE_HARNESS=opencode firstmate` for the opencode fallback harness.
- `firstmate-splash.sh --hold` keeps the terminal open on the final banner;
  `firstmate-splash.sh --frames N` renders N frames then exits (debug).
- Splash is pure ASCII by design (char-level transparency surgery breaks on
  multibyte chars).

