#!/usr/bin/env bash
# install.sh — bootstrap dotfiles on macOS (zsh/brew) or Debian (bash/apt).
#
#   1. Detects the OS.
#   2. Installs the CLI packages listed in packages/{brew,apt}.txt.
#   3. Symlinks the shell config into place (~/.bashrc or ~/.zshrc).
#
# Safe to re-run: existing files are backed up, symlinks are refreshed.
#
# Usage:
#   ./install.sh            # install packages + link config
#   ./install.sh --link     # only (re)create symlinks, skip packages
#   ./install.sh --packages # only install packages, skip symlinks

set -euo pipefail

# --- Resolve paths -----------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES="$DOTFILES_DIR"

DO_PACKAGES=1
DO_LINK=1
case "${1:-}" in
  --link)     DO_PACKAGES=0 ;;
  --packages) DO_LINK=0 ;;
  --help|-h)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")         ;;
  *) echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
esac

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }

# --- Detect OS ---------------------------------------------------------------
OS="unknown"
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)
    if command -v apt >/dev/null 2>&1; then OS="debian"; else OS="linux"; fi
    ;;
esac
info "Detected OS: $OS"

# --- Read a package list, stripping comments and blank lines -----------------
read_packages() {
  # $1 = path to package list. Prints one package name per line.
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^[[:space:]]*$' || true
}

# --- Install packages --------------------------------------------------------
install_macos_packages() {
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$([ -x /opt/homebrew/bin/brew ] && /opt/homebrew/bin/brew shellenv || /usr/local/bin/brew shellenv)"
  fi
  info "Installing Homebrew packages..."
  # `brew install` with the full list is fine; brew skips already-installed.
  # shellcheck disable=SC2046
  brew install $(read_packages "$DOTFILES_DIR/packages/brew.txt") || \
    warn "Some brew packages failed; continuing."
}

install_debian_packages() {
  info "Updating apt package index (sudo)..."
  sudo apt update -y
  info "Installing apt packages..."
  # Install one at a time so a single unavailable package doesn't abort the run.
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if sudo apt install -y --no-install-recommends "$pkg"; then
      :
    else
      warn "Could not install '$pkg'; skipping."
    fi
  done <<EOF
$(read_packages "$DOTFILES_DIR/packages/apt.txt")
EOF
}

# --- SDKMAN (JVM SDK manager) ------------------------------------------------
# Installed via its own script (not apt/brew); same on macOS and Debian.
install_sdkman() {
  if [ -d "$HOME/.sdkman" ]; then
    info "SDKMAN already installed."
    return
  fi
  info "Installing SDKMAN..."
  curl -s "https://get.sdkman.io" | bash || warn "SDKMAN install failed; skipping."
}

if [ "$DO_PACKAGES" -eq 1 ]; then
  case "$OS" in
    macos)  install_macos_packages ;;
    debian) install_debian_packages ;;
    *) warn "No package installer for OS '$OS'; skipping packages." ;;
  esac
  install_sdkman
else
  info "Skipping package installation (--link)."
fi

# --- Symlink helper ----------------------------------------------------------
link() {
  # link <source-in-repo> <target-in-home>
  src="$1"; dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    info "Already linked: $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
    warn "Backing up existing $dst -> $backup"
    mv "$dst" "$backup"
  fi
  ln -s "$src" "$dst"
  info "Linked $dst -> $src"
}

# --- Create symlinks ---------------------------------------------------------
if [ "$DO_LINK" -eq 1 ]; then
  info "Linking shell configuration..."

  # Make the repo discoverable at the conventional path ~/.dotfiles so that
  # the rc files can locate shell/common.sh regardless of where it's cloned.
  if [ "$DOTFILES_DIR" != "$HOME/.dotfiles" ]; then
    link "$DOTFILES_DIR" "$HOME/.dotfiles"
  fi

  # Link both rc files so the same config applies whether you're in bash
  # (Debian) or zsh (macOS), and keeps working if you switch shells.
  link "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"
  link "$DOTFILES_DIR/zsh/zshrc"   "$HOME/.zshrc"

  info "Done. Restart your shell or run: exec \"\$SHELL\" -l"
else
  info "Skipping symlinks (--packages)."
fi
