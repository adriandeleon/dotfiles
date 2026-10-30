# shell/exports.sh - environment variables shared by bash and zsh
# POSIX-compatible: must work in both shells.

# --- PATH first, so the checks below see every installed tool ----------------
# Homebrew (macOS) - set up PATH/vars if present. zsh/zshrc already does this
# before Oh My Zsh loads (for completions), so skip it when it has run.
if [ -z "${HOMEBREW_PREFIX:-}" ]; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Personal bin directories on PATH (only if they exist)
for _dotfiles_dir in "$HOME/.local/bin" "$HOME/bin"; do
  case ":$PATH:" in
    *":$_dotfiles_dir:"*) : ;;            # already present
    *) [ -d "$_dotfiles_dir" ] && PATH="$_dotfiles_dir:$PATH" ;;
  esac
done
unset _dotfiles_dir
export PATH

# Preferred editor - only if you haven't set one earlier in your rc file.
# VISUAL is left alone: programs (git, less...) fall back to EDITOR when it's
# unset, so setting EDITOR in ~/.shell.local (loaded later) still takes effect.
if [ -z "${EDITOR:-}" ]; then
  for _editor in nvim vim vi; do
    if command -v "$_editor" >/dev/null 2>&1; then
      export EDITOR="$_editor"
      break
    fi
  done
  unset _editor
fi

# less: -R shows colours. If LESS isn't set yet, also use -F (quit if one
# screen) and -X (leave output on screen) - git only applies its own LESS=FRX
# default when LESS is unset, so a bare -R would make short `git log` output
# open a pager that hides it on exit.
export PAGER="less"
: "${LESS:=-FRX}"
export LESS

# Make `less` friendly for non-text input files
if [ -x /usr/bin/lesspipe ]; then eval "$(SHELL=/bin/sh lesspipe 2>/dev/null)"; fi

# Language / locale, if not already set. en_US.UTF-8 always exists on macOS,
# but often isn't generated on minimal Linux hosts and containers (programs
# then warn on every run); C.UTF-8 is always there on modern glibc.
if [ -z "${LANG:-}" ]; then
  case "${OSTYPE:-}" in
    darwin*) LANG="en_US.UTF-8" ;;
    *)       LANG="C.UTF-8" ;;
  esac
  export LANG
fi

# History: large, shared format between shells.
# - Oh My Bash already makes bash history effectively unlimited; don't lower it.
# - bash truncates the history file the moment HISTFILESIZE is assigned, so the
#   HISTSIZE=1000 / HISTFILESIZE=2000 lines in Debian's stock ~/.bashrc (which
#   run before this file) would already have cut it to 2000 lines. install.sh
#   comments those two lines out for that reason.
if [ -z "${OMB_VERSION:-}" ]; then
  export HISTSIZE=100000
  export HISTFILESIZE=200000
fi
export SAVEHIST=100000
