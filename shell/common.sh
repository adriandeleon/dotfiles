# shell/common.sh - entry point for shared shell configuration.
# Sourced by both ~/.bashrc (Debian/bash) and ~/.zshrc (macOS/zsh).
# Keep everything here POSIX-compatible so it works in both shells.
#
# Optional files are loaded with `if [ -r … ]; then …; fi` rather than
# `[ -r … ] && …`: the latter leaves a failure status behind when the file is
# missing, and if it's the last thing the rc file runs, the first prompt shows
# that as an error (agnoster's red ✘).

# Resolve the directory of the dotfiles shell config. DOTFILES is exported by
# the shell rc file before sourcing; fall back to the conventional location.
: "${DOTFILES:=$HOME/.dotfiles}"
DOTFILES_SHELL="$DOTFILES/shell"

for part in exports functions; do
  if [ -r "$DOTFILES_SHELL/$part.sh" ]; then . "$DOTFILES_SHELL/$part.sh"; fi
done
unset part

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
      if [ -r "$f" ]; then . "$f"; fi
    done
    unset f
  fi
  unset _fzf_init
fi

unset _dotfiles_shell

# SDKMAN - JVM SDK manager (java, gradle, maven...). Its init script supports
# both bash and zsh. Skip it if your own rc file already loaded it (`sdk`
# exists), so it isn't initialised twice.
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
if command -v sdk >/dev/null 2>&1; then
  :
elif [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
  . "$SDKMAN_DIR/bin/sdkman-init.sh"
fi

# --- Aliases -----------------------------------------------------------------
# Loaded after everything above, so our aliases (ls -> eza, du -> du -h...)
# can't be baked into the functions that zoxide, fzf and SDKMAN define. They
# also come after Oh My Bash/Zsh, so they win over the framework's.
#
# Then your personal aliases file, if you have one: ~/.bash_aliases (bash) or
# ~/.zsh_aliases (zsh). install.sh links that name to shell/aliases.sh only when
# it doesn't exist yet; if it's your own file, it's loaded here after ours so
# your aliases take precedence. (In bash, Debian's stock ~/.bashrc has already
# sourced ~/.bash_aliases once, before Oh My Bash - this re-applies it.)
if [ -r "$DOTFILES_SHELL/aliases.sh" ]; then . "$DOTFILES_SHELL/aliases.sh"; fi
if [ -n "${ZSH_VERSION:-}" ]; then
  _dotfiles_aliases="$HOME/.zsh_aliases"
else
  _dotfiles_aliases="$HOME/.bash_aliases"
fi
if [ -r "$_dotfiles_aliases" ] && [ ! "$_dotfiles_aliases" -ef "$DOTFILES_SHELL/aliases.sh" ]; then
  . "$_dotfiles_aliases"
fi
unset _dotfiles_aliases DOTFILES_SHELL

# --- Local, machine-specific overrides --------------------------------------
# Not tracked in git - put secrets / per-host tweaks here.
if [ -r "$HOME/.shell.local" ]; then . "$HOME/.shell.local"; fi
