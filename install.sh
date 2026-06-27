#!/usr/bin/env bash
# install.sh — bootstrap dotfiles on macOS (zsh/brew) or Debian (bash/apt).
#
#   1. Detects the OS.
#   2. Installs the CLI packages listed in packages/{brew,apt}.txt, plus SDKMAN,
#      the Oh My Bash / Oh My Zsh frameworks, and the JetBrains Mono Nerd Font.
#   3. Adds the shell config to your existing ~/.bashrc and ~/.zshrc by backing
#      them up and appending an include block (your files are NOT replaced).
#
# Safe to re-run: the include block is added only once; backups are timestamped.
#
# Usage:
#   ./install.sh            # install packages + configure shell
#   ./install.sh --link     # only configure the shell rc files, skip packages
#   ./install.sh --packages # only install packages, skip shell config

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

# --- Shell frameworks (Oh My Bash / Oh My Zsh) -------------------------------
# Cloned directly (not via their curl installers, which would rewrite the rc
# files). Both are plain git repos; the rc fragments enable the agnoster theme.
clone_repo() {
  # clone_repo <url> <dest> <name>
  if [ -d "$2" ]; then
    info "$3 already installed."
  else
    info "Installing $3..."
    git clone --depth=1 "$1" "$2" || warn "$3 clone failed; skipping."
  fi
}

install_shell_frameworks() {
  clone_repo "https://github.com/ohmybash/oh-my-bash.git" "$HOME/.oh-my-bash" "Oh My Bash"
  clone_repo "https://github.com/ohmyzsh/ohmyzsh.git"     "$HOME/.oh-my-zsh"  "Oh My Zsh"
}

# --- JetBrains Mono Nerd Font ------------------------------------------------
# The agnoster theme needs a Nerd/Powerline font for its glyphs. macOS uses a
# Homebrew cask; Debian downloads the font archive from the Nerd Fonts release.
NERD_FONT_VERSION="v3.2.1"

install_font_macos() {
  info "Installing JetBrains Mono Nerd Font (cask)..."
  brew install --cask font-jetbrains-mono-nerd-font \
    || warn "Font cask install failed; skipping."
}

install_font_debian() {
  dest="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if [ -d "$dest" ]; then
    info "JetBrains Mono Nerd Font already installed."
    return
  fi
  if ! command -v fc-cache >/dev/null 2>&1; then
    warn "fontconfig (fc-cache) not found; skipping font install."
    return
  fi
  info "Installing JetBrains Mono Nerd Font ($NERD_FONT_VERSION)..."
  url="https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONT_VERSION/JetBrainsMono.zip"
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/JetBrainsMono.zip" "$url" \
      && mkdir -p "$dest" \
      && unzip -oq "$tmp/JetBrainsMono.zip" -d "$dest"; then
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
    info "Font installed to $dest"
  else
    warn "Font download/extract failed; skipping."
    rm -rf "$dest"
  fi
  rm -rf "$tmp"
}

install_font() {
  case "$OS" in
    macos)  install_font_macos ;;
    debian) install_font_debian ;;
    *) warn "No font installer for OS '$OS'; skipping font." ;;
  esac
}

if [ "$DO_PACKAGES" -eq 1 ]; then
  case "$OS" in
    macos)  install_macos_packages ;;
    debian) install_debian_packages ;;
    *) warn "No package installer for OS '$OS'; skipping packages." ;;
  esac
  install_sdkman
  install_shell_frameworks
  install_font
else
  info "Skipping package installation (--link)."
fi

# --- Include helper ----------------------------------------------------------
# Rather than replacing your rc files, we back them up and append a small block
# that sources the matching file from this repo. Re-running is idempotent: the
# block is added only once (detected by the marker), and your original content
# is preserved above it.
BLOCK_BEGIN="# >>> dotfiles (managed by install.sh) >>>"
BLOCK_END="# <<< dotfiles (managed by install.sh) <<<"

include_config() {
  # include_config <source-in-repo> <target-rc>
  src="$1"; dst="$2"

  [ -e "$dst" ] || { touch "$dst"; info "Created $dst"; }

  if grep -qF "$BLOCK_BEGIN" "$dst" 2>/dev/null; then
    info "Already configured: $dst"
    return
  fi

  # Back up the original (a copy — the file stays in place) before appending.
  backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
  cp "$dst" "$backup"
  info "Backed up $dst -> $backup"

  {
    printf '\n%s\n' "$BLOCK_BEGIN"
    printf 'export DOTFILES="%s"\n' "$DOTFILES_DIR"
    printf '[ -r "%s" ] && . "%s"\n' "$src" "$src"
    printf '%s\n' "$BLOCK_END"
  } >> "$dst"
  info "Appended dotfiles include to $dst"
}

# --- Wire up the shell configuration -----------------------------------------
if [ "$DO_LINK" -eq 1 ]; then
  info "Configuring shell startup files (existing files are backed up, not replaced)..."

  # Append to both rc files so the same config applies whether you're in bash
  # (Debian) or zsh (macOS), and keeps working if you switch shells.
  include_config "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"
  include_config "$DOTFILES_DIR/zsh/zshrc"   "$HOME/.zshrc"

  info "Done. Restart your shell or run: exec \"\$SHELL\" -l"
else
  info "Skipping shell configuration (--packages)."
fi
