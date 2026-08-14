#!/usr/bin/env bash
# firstmate-toolbox bootstrap - set up a fresh Debian/Ubuntu machine with the
# full firstmate stack: node, gh, opencode, herdr, treehouse, no-mistakes, the
# axi toolchain, the firstmate distro (skills included), and the splash opener.
#
#   curl -fsSL https://github.com/mbufkin/firstmate-toolbox/archive/refs/heads/main.tar.gz | tar -xz
#   cd firstmate-toolbox-main && ./bootstrap.sh
#
# Idempotent: safe to re-run. Steps already present are skipped.
set -euo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '\033[1;34m --\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !! %s\033[0m\n' "$*"; }

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else
    echo "error: need root (run as root or install sudo)" >&2; exit 1
  fi
fi
SUDO_EV="$SUDO -E"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

have() { command -v "$1" >/dev/null 2>&1; }

require_deb() { # install apt packages if missing
  local need=()
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 || need+=("$p")
  done
  if ((${#need[@]})); then
    log "apt: installing ${need[*]}"
    $SUDO_EV apt-get update -y
    $SUDO_EV apt-get install -y "${need[@]}"
  fi
}

# ---------------------------------------------------------------- base deps
log "base packages"
require_deb git curl ca-certificates gnupg tar jq gnome-terminal

# ------------------------------------------------------------------- node
if have node && [[ "$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)" -ge 22 ]]; then
  info "node $(node -v) already installed"
else
  log "installing Node.js LTS 22 (NodeSource)"
  curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO_EV bash -
  $SUDO_EV apt-get install -y nodejs
  info "node $(node -v), npm $(npm -v)"
fi

# --------------------------------------------------------------------- gh
if have gh; then
  info "gh $(gh --version 2>/dev/null | head -1) already installed"
else
  log "installing GitHub CLI (official apt repo)"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | $SUDO tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
  $SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  $SUDO_EV apt-get update -y
  $SUDO_EV apt-get install -y gh
fi

# ---------------------------------------------------------------- opencode
if have opencode; then
  info "opencode already installed"
else
  log "installing opencode"
  curl -fsSL https://opencode.ai/install | bash
fi

# ------------------------------------------------------------------- herdr
if have herdr; then
  info "herdr $(herdr --version 2>/dev/null | head -1) already installed"
else
  log "installing herdr (https://herdr.dev)"
  curl -fsSL https://herdr.dev/install.sh | sh
fi

# --------------------------------------------------------------------- pi
# The Pi coding-agent harness (github.com/earendil-works/pi) is the primary
# firstmate agent here; herdr manages its spawned workers as the backend.
if have pi; then
  info "pi $(pi --version 2>/dev/null | head -1) already installed"
else
  log "installing pi harness (https://pi.dev)"
  curl -fsSL https://pi.dev/install.sh | sh
fi

# ------------------------------------------------------------ toolchain
if have treehouse; then
  info "treehouse already installed"
else
  log "installing treehouse"
  curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
fi

if have no-mistakes; then
  info "no-mistakes already installed"
else
  log "installing no-mistakes"
  curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
fi

# ------------------------------------------------------------- axi family
log "axi toolchain"
$SUDO_EV npm install -g gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi
for t in gh-axi chrome-devtools-axi lavish-axi; do
  if have "$t"; then
    info "$t setup hooks"
    "$t" setup hooks || warn "$t setup hooks reported an issue (continue anyway)"
  fi
done

# ----------------------------------------------------- firstmate distro
FM_DIR="${FIRSTMATE_DIR:-$HOME/firstmate}"
if [[ -d "$FM_DIR/.git" ]]; then
  info "firstmate repo present at $FM_DIR"
else
  log "cloning firstmate (brings the bundled skills) into $FM_DIR"
  git clone https://github.com/kunchenguid/firstmate "$FM_DIR"
fi
mkdir -p "$FM_DIR/config"
if [[ ! -f "$FM_DIR/config/backend" ]]; then
  printf 'herdr\n' > "$FM_DIR/config/backend"
  info "firstmate backend set to herdr"
fi
# herdr manages pi: crewmates and scouts run the pi harness on the herdr backend.
if [[ ! -f "$FM_DIR/config/crew-harness" ]]; then
  printf 'pi\n' > "$FM_DIR/config/crew-harness"
  info "firstmate crew harness set to pi"
fi
# secondmate harness: "pi [<model>] [<effort>]"; set FIRSTMATE_PI_MODEL to pin one.
if [[ ! -f "$FM_DIR/config/secondmate-harness" ]]; then
  printf 'pi%s\n' "${FIRSTMATE_PI_MODEL:+ $FIRSTMATE_PI_MODEL}" > "$FM_DIR/config/secondmate-harness"
  info "firstmate secondmate harness set to pi${FIRSTMATE_PI_MODEL:+ ($FIRSTMATE_PI_MODEL)}"
fi

# --------------------------------------------------------- personal skills
# firstmate's skills ship inside the firstmate repo; personal skills live here
# in skills/<name>/SKILL.md and are installed to the opencode user skills dir.
if [[ -d "$SCRIPT_DIR/skills" ]]; then
  mkdir -p "$HOME/.config/opencode/skills"
  for sk in "$SCRIPT_DIR"/skills/*/; do
    [[ -e "${sk}SKILL.md" ]] || continue
    name=$(basename "$sk")
    ln -sfn "$SCRIPT_DIR/skills/$name" "$HOME/.config/opencode/skills/$name"
    info "skill: $name"
  done
fi

# --------------------------------------------------------- toolbox files
log "installing splash + launcher + herdr service"
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
for f in firstmate firstmate-splash.sh; do
  ln -sf "$SCRIPT_DIR/$f" "$HOME/.local/bin/$f"
done
ln -sf "$SCRIPT_DIR/herdr.service" "$HOME/.config/systemd/user/herdr.service"
systemctl --user daemon-reload
if ! systemctl --user is-active --quiet herdr.service; then
  systemctl --user enable --now herdr.service || true
fi

# ------------------------------------------------------------------ check
log "preflight"
if [[ -x "$FM_DIR/bin/fm-bootstrap.sh" ]]; then
  (cd "$FM_DIR" && bash bin/fm-bootstrap.sh) || true
fi
"$HOME/.local/bin/firstmate" --check || true

# ------------------------------------------------------------- api keys
if [[ -t 0 ]]; then
  log "API keys (the only manual step)"
  bash "$SCRIPT_DIR/setup-keys.sh" || true
else
  echo
  echo "Not interactive - skipping the API-keys prompt. Run it manually:"
  echo "   $SCRIPT_DIR/setup-keys.sh"
fi

echo
echo "Done. On a fresh machine finish with:"
echo "   gh auth login"
echo "then start the opener with:   firstmate"
