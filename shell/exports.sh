# shell/exports.sh — environment variables shared by bash and zsh
# POSIX-compatible: must work in both shells.

# Preferred editor
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
  export VISUAL="nvim"
else
  export EDITOR="vim"
  export VISUAL="vim"
fi

export PAGER="less"
export LESS="-R"

# Make `less` friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe 2>/dev/null)"

# Language / locale
export LANG="${LANG:-en_US.UTF-8}"

# History: large, shared format between shells
export HISTSIZE=100000
export HISTFILESIZE=200000
export SAVEHIST=100000

# Homebrew (macOS) — set up PATH/vars if present
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
export PATH
