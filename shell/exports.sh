# shell/exports.sh - environment variables shared by bash and zsh
# POSIX-compatible: must work in both shells.

# Preferred editor - only if you haven't set one earlier in your rc file.
if [ -z "${EDITOR:-}" ]; then
  for _editor in nvim vim vi; do
    if command -v "$_editor" >/dev/null 2>&1; then
      EDITOR="$_editor"
      break
    fi
  done
  unset _editor
fi
: "${VISUAL:=${EDITOR:-}}"
export EDITOR VISUAL

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

# History: large, shared format between shells. These deliberately override
# the small defaults from Debian's stock ~/.bashrc (1000/2000), which runs
# before this file.
export HISTSIZE=100000
export HISTFILESIZE=200000
export SAVEHIST=100000

# Homebrew (macOS) - set up PATH/vars if present
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Personal bin directories on PATH (only if they exist)
for dir in "$HOME/.local/bin" "$HOME/bin"; do
  case ":$PATH:" in
    *":$dir:"*) : ;;                      # already present
    *) [ -d "$dir" ] && PATH="$dir:$PATH" ;;
  esac
done
unset dir
export PATH
