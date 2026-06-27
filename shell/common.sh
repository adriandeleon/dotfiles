# shell/common.sh — entry point for shared shell configuration.
# Sourced by both ~/.bashrc (Debian/bash) and ~/.zshrc (macOS/zsh).
# Keep everything here POSIX-compatible so it works in both shells.

# Resolve the directory of the dotfiles shell config. DOTFILES is exported by
# the shell rc file before sourcing; fall back to the conventional location.
: "${DOTFILES:=$HOME/.dotfiles}"
DOTFILES_SHELL="$DOTFILES/shell"

for part in exports aliases functions; do
  [ -r "$DOTFILES_SHELL/$part.sh" ] && . "$DOTFILES_SHELL/$part.sh"
done
unset part

# --- Shared interactive tooling ---------------------------------------------
# Detect current shell name for tools that need shell-specific init.
_dotfiles_shell="$(basename "${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}")"
[ -z "$_dotfiles_shell" ] && _dotfiles_shell="sh"

# zoxide — smarter cd (`z foo`)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init "$_dotfiles_shell")"
fi

# fzf — fuzzy finder key bindings and completion
if command -v fzf >/dev/null 2>&1; then
  # fzf >= 0.48 can print its own integration script
  if fzf --"$_dotfiles_shell" >/dev/null 2>&1; then
    eval "$(fzf --"$_dotfiles_shell")"
  else
    # Fall back to files installed by the distro/Homebrew package.
    for f in \
      "/usr/share/doc/fzf/examples/key-bindings.$_dotfiles_shell" \
      "/usr/share/fzf/key-bindings.$_dotfiles_shell" \
      "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.$_dotfiles_shell"; do
      [ -r "$f" ] && . "$f"
    done
    unset f
  fi
fi

unset _dotfiles_shell

# --- Local, machine-specific overrides --------------------------------------
# Not tracked in git — put secrets / per-host tweaks here.
[ -r "$HOME/.shell.local" ] && . "$HOME/.shell.local"
