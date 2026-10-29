#!/usr/bin/env bash
# install.sh — bootstrap dotfiles on macOS (zsh/brew) or Debian (bash/apt).
#
#   1. Detects the OS.
#   2. Installs the CLI packages listed in packages/{brew,apt}.txt, plus SDKMAN,
#      the platform's shell framework (Oh My Bash on Debian, Oh My Zsh on
#      macOS), and the JetBrains Mono Nerd Font.
#   3. Adds the shell config to the native rc file (~/.bashrc on Debian,
#      ~/.zshrc on macOS) by backing it up and appending an include block (your
#      file is NOT replaced).
#   4. Links ~/.bash_aliases / ~/.zsh_aliases to shell/aliases.sh, unless you
#      already have your own (that one is kept and still loaded).
#   5. Links ~/.config/emacs to emacs/, unless you already have an Emacs config
#      (~/.emacs, ~/.emacs.d or ~/.config/emacs), which is left alone.
#
# Safe to re-run: the include block is added only once (and updated in place if
# the checkout moved); backups are timestamped.
#
# Usage:
#   ./install.sh            # install packages + configure shell
#   ./install.sh --minimal  # lean subset (packages/*-minimal.txt) + shell config;
#                           # skips SDKMAN, the shell framework, and the font
#   ./install.sh --link     # only configure the shell rc files, skip packages
#   ./install.sh --packages # only install packages, skip shell config
#
# Options can be combined, e.g. `--minimal --packages`.

set -euo pipefail

DO_PACKAGES=1
DO_LINK=1
MINIMAL=0
for arg in "$@"; do
  case "$arg" in
    --minimal)  MINIMAL=1 ;;
    --link)     DO_PACKAGES=0 ;;
    --packages) DO_LINK=0 ;;
    # Print only the header comment block (stops at the first non-comment line).
    --help|-h)  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done
if [ "$DO_PACKAGES" -eq 0 ] && [ "$DO_LINK" -eq 0 ]; then
  echo "--link and --packages can't be combined (try --help)" >&2
  exit 1
fi

# --- Resolve paths -----------------------------------------------------------
# pwd -P: the physical path, so reaching the checkout through a symlink doesn't
# make every run think the repo has moved.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export DOTFILES="$DOTFILES_DIR"

# The path is written into your rc file inside double quotes, so refuse
# characters that would break out of them (or run code at every shell start).
case "$DOTFILES_DIR" in
  *[\"\$\`\\]*)
    echo "install.sh: the checkout path can't contain \" \$ \` or \\ characters:" >&2
    echo "  $DOTFILES_DIR" >&2
    exit 1 ;;
esac

# Every warning is counted, so the run can't end with a plain "done" when a step
# actually failed.
WARNINGS=0
info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }

# --- Detect OS ---------------------------------------------------------------
# /etc/debian_version covers Debian and its derivatives (Ubuntu, Mint...); a
# bare `apt` command also exists on unrelated apt-rpm distros.
OS="unknown"
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)
    if [ -f /etc/debian_version ] && command -v apt-get >/dev/null 2>&1; then
      OS="debian"
    else
      OS="linux"
    fi
    ;;
esac
info "Detected OS: $OS"

# --- Choose the package set (full vs --minimal) ------------------------------
if [ "$MINIMAL" -eq 1 ]; then
  info "Minimal install: core packages only, skipping SDKMAN / framework / font."
  APT_LIST="$DOTFILES_DIR/packages/apt-minimal.txt"
  BREW_LIST="$DOTFILES_DIR/packages/brew-minimal.txt"
else
  APT_LIST="$DOTFILES_DIR/packages/apt.txt"
  BREW_LIST="$DOTFILES_DIR/packages/brew.txt"
fi

# --- Read a package list, stripping comments and blank lines -----------------
read_packages() {
  # $1 = path to package list. Prints one package name per line (nothing if the
  # file is missing; callers check for an empty result).
  [ -r "$1" ] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^[[:space:]]*$' || true
}

# --- Install packages --------------------------------------------------------
# Homebrew may be installed but not on PATH yet (e.g. a fresh terminal on Apple
# Silicon), so check its standard locations too.
find_brew() {
  if command -v brew >/dev/null 2>&1; then command -v brew; return 0; fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then echo "$b"; return 0; fi
  done
  return 1
}

install_macos_packages() {
  if ! brew_bin="$(find_brew)"; then
    info "Installing Homebrew..."
    # Download first: piping a failed download into bash would "succeed".
    if ! brew_script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      warn "Couldn't download the Homebrew installer; skipping packages."
      return
    fi
    if ! /bin/bash -c "$brew_script"; then
      warn "Homebrew install failed; skipping packages."
      return
    fi
    if ! brew_bin="$(find_brew)"; then
      warn "Homebrew installed but brew wasn't found; skipping packages."
      return
    fi
  fi
  eval "$("$brew_bin" shellenv)"

  pkgs="$(read_packages "$BREW_LIST")"
  if [ -z "$pkgs" ]; then
    warn "Package list $BREW_LIST is missing or empty; skipping packages."
    return
  fi
  info "Installing Homebrew packages..."
  # `brew install` with the full list is fine; brew skips already-installed.
  # shellcheck disable=SC2086  # split the package list into arguments
  brew install $pkgs || warn "Some brew packages failed; continuing."
}

install_debian_packages() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    warn "Not running as root and sudo isn't installed; skipping apt packages."
    return
  fi

  pkgs="$(read_packages "$APT_LIST")"
  if [ -z "$pkgs" ]; then
    warn "Package list $APT_LIST is missing or empty; skipping packages."
    return
  fi

  info "Updating apt package index${SUDO:+ (sudo)}..."
  # Don't abort the whole install if `apt-get update` reports an error — a
  # single broken third-party repo (bad signature, EOL suite, etc.) shouldn't
  # stop us from installing packages, since the working repos still refreshed.
  # apt-get rather than apt: apt's CLI isn't stable for scripts.
  $SUDO apt-get update || warn "apt-get update reported errors (likely an unrelated repo); continuing."
  info "Installing apt packages..."
  # A single apt install for the whole list. If a package is unavailable on
  # this release (e.g. eza/btop/fastfetch on older Debian) apt installs none of
  # them — drop it from the package list or upgrade the release.
  # shellcheck disable=SC2086  # split the package list into arguments
  $SUDO apt-get install -y --no-install-recommends $pkgs \
    || warn "Some apt packages failed to install; continuing."
}

# --- SDKMAN (JVM SDK manager) ------------------------------------------------
# Installed via its own script (not apt/brew); same on macOS and Debian.
# rcupdate=false stops it appending its own init lines to ~/.bashrc/~/.zshrc:
# shell/common.sh already sources sdkman-init.sh.
install_sdkman() {
  if [ -d "$HOME/.sdkman" ]; then
    info "SDKMAN already installed."
    return
  fi
  info "Installing SDKMAN..."
  curl -fsSL "https://get.sdkman.io?rcupdate=false" | bash || warn "SDKMAN install failed; skipping."
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
  # One framework per platform: Oh My Bash on Debian, Oh My Zsh on macOS.
  case "$OS" in
    macos)  clone_repo "https://github.com/ohmyzsh/ohmyzsh.git"     "$HOME/.oh-my-zsh"  "Oh My Zsh" ;;
    debian) clone_repo "https://github.com/ohmybash/oh-my-bash.git" "$HOME/.oh-my-bash" "Oh My Bash" ;;
    *) warn "No shell framework configured for OS '$OS'; skipping." ;;
  esac
}

# --- JetBrains Mono Nerd Font ------------------------------------------------
# The agnoster theme needs a Nerd/Powerline font for its glyphs. macOS uses a
# Homebrew cask; Debian downloads the font archive from the Nerd Fonts release.
NERD_FONT_VERSION="v3.5.1"
# SHA-256 of JetBrainsMono.zip, from that release's SHA-256.txt. Update both
# together when bumping the version.
NERD_FONT_SHA256="fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e"

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
      && printf '%s  %s\n' "$NERD_FONT_SHA256" "$tmp/JetBrainsMono.zip" | sha256sum -c --quiet - \
      && mkdir -p "$dest" \
      && unzip -oq "$tmp/JetBrainsMono.zip" -d "$dest"; then
    # Under set -e a failing fc-cache here would abort the whole install.
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 \
      || warn "fc-cache failed; the font may not show up until you log in again."
    info "Font installed to $dest"
  else
    warn "Font download/verify/extract failed; skipping."
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
  # The full install adds SDKMAN, the shell framework, and the Nerd Font.
  # --minimal skips all three.
  if [ "$MINIMAL" -eq 0 ]; then
    install_sdkman
    install_shell_frameworks
    install_font
  fi
else
  info "Skipping package installation (--link)."
fi

# --- Include helper ----------------------------------------------------------
# Rather than replacing your rc files, we back them up and append a small block
# that sources the matching file from this repo. Re-running is idempotent: the
# block is added only once (detected by the markers), and your original content
# is preserved around it. If the block's contents are out of date (e.g. the
# repo has moved), they are rewritten in place, keeping the block where it is.
# If the markers look damaged (missing, repeated or out of order), the file is
# left alone and you're asked to fix it by hand.
BLOCK_BEGIN="# >>> dotfiles (managed by install.sh) >>>"
BLOCK_END="# <<< dotfiles (managed by install.sh) <<<"

include_config() {
  # include_config <source-in-repo> <target-rc>
  # Records what happened in CFG_RC / CFG_BACKUP / CFG_STATUS for the summary.
  src="$1"; dst="$2"
  CFG_RC="$dst"; CFG_BACKUP=""; CFG_STATUS="appended"
  # `if … fi` rather than `[ -r … ] && …`, so a missing file doesn't leave a
  # failure status as the rc file's last command (agnoster shows it as ✘).
  block_body="$(printf 'export DOTFILES="%s"\nif [ -r "%s" ]; then . "%s"; fi' \
    "$DOTFILES_DIR" "$src" "$src")"

  [ -e "$dst" ] || { touch "$dst"; info "Created $dst"; }

  if grep -qF -e "$BLOCK_BEGIN" -e "$BLOCK_END" "$dst"; then
    # Exactly one begin marker, followed by exactly one end marker.
    if ! awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
        $0 == b { if (seen) bad = 1; seen = 1; open = 1; next }
        $0 == e { if (!open) bad = 1; open = 0 }
        END { exit (bad || open || !seen) }' "$dst"; then
      warn "The dotfiles block markers in $dst are damaged (missing, repeated or out of order); left it unchanged."
      warn "Fix or remove the block by hand, then re-run ./install.sh --link."
      CFG_STATUS="damaged"
      return
    fi
    current="$(awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" \
      '$0 == e { open = 0 } open { print } $0 == b { open = 1 }' "$dst")"
    if [ "$current" = "$block_body" ]; then
      info "Already configured: $dst"
      CFG_STATUS="already"
      return
    fi
    CFG_STATUS="updated"
  fi

  # Back up the original (a copy — the file stays in place) before changing it.
  backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
  cp "$dst" "$backup"
  CFG_BACKUP="$backup"
  info "Backed up $dst -> $backup"

  if [ "$CFG_STATUS" = "updated" ]; then
    # Replace just the lines between the markers. Writing into $dst (rather
    # than moving a new file over it) keeps its inode and permissions.
    BODY="$block_body" awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
      $0 == b { print; print ENVIRON["BODY"]; skip = 1; next }
      $0 == e { skip = 0 }
      !skip { print }' "$backup" > "$dst"
    info "Updated the dotfiles include block in $dst"
  else
    printf '\n%s\n%s\n%s\n' "$BLOCK_BEGIN" "$block_body" "$BLOCK_END" >> "$dst"
    info "Appended dotfiles include to $dst"
  fi
}

# --- Aliases file ------------------------------------------------------------
# Expose shell/aliases.sh at the conventional per-shell filename so the aliases
# live in their own editable file: ~/.bash_aliases or ~/.zsh_aliases. If you
# already have your own file there, it is left alone: shell/common.sh loads it
# after the repo's aliases, so yours take precedence.
# Records ALIAS_LINK / ALIAS_STATUS for the summary.
link_aliases() {
  src="$DOTFILES_DIR/shell/aliases.sh"
  case "$OS" in
    macos) dst="$HOME/.zsh_aliases" ;;
    *)     dst="$HOME/.bash_aliases" ;;
  esac
  ALIAS_LINK="$dst"; ALIAS_STATUS="linked"

  if [ -L "$dst" ]; then
    target="$(readlink "$dst")"
    if [ "$target" = "$src" ]; then
      info "Aliases already linked: $dst"
      ALIAS_STATUS="already"
      return
    fi
    case "$target" in
      */shell/aliases.sh)
        # Our link from an old checkout location: point it at this one.
        ln -sfn "$src" "$dst"
        info "Re-linked $dst -> $src (was $target)"
        ALIAS_STATUS="relinked"
        return ;;
    esac
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    info "Kept your existing $dst (loaded after the repo aliases)."
    ALIAS_STATUS="kept"
    return
  fi
  ln -s "$src" "$dst"
  info "Linked $dst -> $src"
}

# --- Emacs config ------------------------------------------------------------
# Link ~/.config/emacs (or $XDG_CONFIG_HOME/emacs) to emacs/ in this repo.
# Emacs loads ~/.emacs or ~/.emacs.d in preference to ~/.config/emacs, so if
# either exists the link would be ignored: then, or when ~/.config/emacs is
# already your own, nothing is changed.
# Records EMACS_LINK / EMACS_STATUS for the summary.
link_emacs() {
  src="$DOTFILES_DIR/emacs"
  dst="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"
  EMACS_LINK="$dst"; EMACS_STATUS="linked"

  for old in "$HOME/.emacs" "$HOME/.emacs.el" "$HOME/.emacs.d"; do
    if [ -e "$old" ] || [ -L "$old" ]; then
      info "Kept your existing $old; Emacs loads it instead of $dst."
      EMACS_LINK="$old"; EMACS_STATUS="shadowed"
      return
    fi
  done

  if [ -L "$dst" ]; then
    target="$(readlink "$dst")"
    if [ "$target" = "$src" ]; then
      info "Emacs config already linked: $dst"
      EMACS_STATUS="already"
      return
    fi
    # Our link from an old checkout location (since moved, or another checkout
    # of this repo): point it at this one.
    case "$target" in
      */emacs)
        if [ ! -e "$target" ] || [ -f "$target/../install.sh" ]; then
          ln -sfn "$src" "$dst"
          info "Re-linked $dst -> $src (was $target)"
          EMACS_STATUS="relinked"
          return
        fi ;;
    esac
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    info "Kept your existing $dst."
    EMACS_STATUS="kept"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  info "Linked $dst -> $src"
}

# --- Wire up the shell configuration -----------------------------------------
if [ "$DO_LINK" -eq 1 ]; then
  info "Configuring shell startup files (existing files are backed up, not replaced)..."

  # Configure the native shell for this platform: bash on Debian, zsh on macOS.
  case "$OS" in
    macos)  include_config "$DOTFILES_DIR/zsh/zshrc"   "$HOME/.zshrc" ;;
    *)      include_config "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc" ;;
  esac

  # Put the aliases in their own conventional file.
  link_aliases

  link_emacs

  # --- Summary of what changed ---
  printf '\n'
  info "What changed in your shell config:"
  case "$CFG_STATUS" in
    already) printf '  • %s already had the dotfiles include block — no change.\n' "$CFG_RC" ;;
    damaged) printf '  • %s was NOT changed: its dotfiles block markers are damaged.\n' "$CFG_RC" ;;
    updated|appended)
      if [ "$CFG_STATUS" = "updated" ]; then
        printf '  • Updated the outdated include block in %s (in place)\n' "$CFG_RC"
      else
        printf '  • Appended a marked include block to %s\n' "$CFG_RC"
      fi
      printf '    that sources functions, exports and the agnoster theme from this\n'
      printf '    repo (%s).\n' "$DOTFILES_DIR"
      printf '  • Backed up the previous %s to %s\n' "$CFG_RC" "$CFG_BACKUP"
      printf '  • The rest of %s is unchanged (only the marked block was touched).\n' "$CFG_RC"
      ;;
  esac
  case "$ALIAS_STATUS" in
    already)  printf '  • Your aliases file %s already links to the repo — no change.\n' "$ALIAS_LINK" ;;
    kept)     printf '  • Kept your own aliases file %s; it loads after the repo aliases.\n' "$ALIAS_LINK" ;;
    relinked) printf '  • Re-pointed %s at %s\n' "$ALIAS_LINK" "$DOTFILES_DIR/shell/aliases.sh" ;;
    linked)   printf '  • Linked your aliases file %s -> %s\n' "$ALIAS_LINK" "$DOTFILES_DIR/shell/aliases.sh" ;;
  esac
  case "$EMACS_STATUS" in
    already)  printf '  • %s already links to the repo Emacs config — no change.\n' "$EMACS_LINK" ;;
    kept)     printf '  • Kept your own Emacs config in %s.\n' "$EMACS_LINK" ;;
    shadowed)
      printf '  • Did not link the Emacs config: Emacs would load your %s instead.\n' "$EMACS_LINK"
      printf '    Move it aside and re-run ./install.sh --link to use %s.\n' "$DOTFILES_DIR/emacs"
      ;;
    relinked) printf '  • Re-pointed %s at %s\n' "$EMACS_LINK" "$DOTFILES_DIR/emacs" ;;
    linked)   printf '  • Linked your Emacs config %s -> %s\n' "$EMACS_LINK" "$DOTFILES_DIR/emacs" ;;
  esac
  printf '\n'
  info "Reload your shell to see the changes:  exec \"\$SHELL\" -l   (or open a new terminal)"
else
  info "Skipping shell configuration (--packages)."
fi

if [ "$WARNINGS" -gt 0 ]; then
  printf '\n\033[1;33m[!]\033[0m Finished with %d warning(s); see the [!] lines above.\n' "$WARNINGS" >&2
else
  info "Done."
fi
