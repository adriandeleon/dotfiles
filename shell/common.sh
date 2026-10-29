# shell/common.sh - entry point for shared shell configuration.
# Sourced by both ~/.bashrc (Debian/bash) and ~/.zshrc (macOS/zsh).
# Keep everything here POSIX-compatible so it works in both shells.

# Resolve the directory of the dotfiles shell config. DOTFILES is exported by
# the shell rc file before sourcing; fall back to the conventional location.
: "${DOTFILES:=$HOME/.dotfiles}"
DOTFILES_SHELL="$DOTFILES/shell"

for part in exports functions; do
  [ -r "$DOTFILES_SHELL/$part.sh" ] && . "$DOTFILES_SHELL/$part.sh"
done
unset part

# Aliases live in their own file, linked to the conventional name by
# install.sh: ~/.bash_aliases (bash) and ~/.zsh_aliases (zsh), both pointing at
# shell/aliases.sh. Load it here in both shells. Debian's stock ~/.bashrc has
# already sourced ~/.bash_aliases, but that happens *before* Oh My Bash, which
# then redefines ll/la - so ours are re-applied last. Falls back to the repo
# copy if the link isn't there.
if [ -n "${ZSH_VERSION:-}" ]; then
  _dotfiles_aliases="$HOME/.zsh_aliases"
else
  _dotfiles_aliases="$HOME/.bash_aliases"
fi
[ -r "$_dotfiles_aliases" ] || _dotfiles_aliases="$DOTFILES_SHELL/aliases.sh"
[ -r "$_dotfiles_aliases" ] && . "$_dotfiles_aliases"
unset _dotfiles_aliases

# --- Shared interactive tooling ---------------------------------------------
# Detect current shell name for tools that need shell-specific init.
_dotfiles_shell="${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}"
[ -z "$_dotfiles_shell" ] && _dotfiles_shell="sh"

# zoxide - smarter cd (`z foo`)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init "$_dotfiles_shell")"
fi

# fzf - fuzzy finder key bindings and completion
if command -v fzf >/dev/null 2>&1; then
  # fzf >= 0.48 can print its own integration script (run it only once).
  if _fzf_init="$(fzf --"$_dotfiles_shell" 2>/dev/null)" && [ -n "$_fzf_init" ]; then
    eval "$_fzf_init"
  else
    # Fall back to files installed by the distro/Homebrew package.
    # HOMEBREW_PREFIX is set by `brew shellenv` in exports.sh.
    for f in \
      "/usr/share/doc/fzf/examples/key-bindings.$_dotfiles_shell" \
      "/usr/share/fzf/key-bindings.$_dotfiles_shell" \
      "${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.$_dotfiles_shell}"; do
      [ -r "$f" ] && . "$f"
    done
    unset f
  fi
  unset _fzf_init
fi

unset _dotfiles_shell

# SDKMAN - JVM SDK manager (java, gradle, maven...). Its init script supports
# both bash and zsh; source it if installed.
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

# --- Local, machine-specific overrides --------------------------------------
# Not tracked in git - put secrets / per-host tweaks here.
[ -r "$HOME/.shell.local" ] && . "$HOME/.shell.local"
