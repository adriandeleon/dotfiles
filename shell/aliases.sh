# shell/aliases.sh — aliases shared by bash and zsh
# POSIX-compatible: must work in both shells.

# --- Listing -----------------------------------------------------------------
# Prefer eza (with icons) if installed, otherwise fall back to coloured ls.
if command -v eza >/dev/null 2>&1; then
  alias eza='eza --icons'
  alias ls='eza --icons --group-directories-first'
  alias ll='eza --icons -lah --group-directories-first --git'
  alias la='eza --icons -a --group-directories-first'
  alias lt='eza --icons --tree --level=2'
else
  # macOS ls uses -G for colour; GNU ls uses --color=auto
  if ls --color=auto >/dev/null 2>&1; then
    alias ls='ls --color=auto'
  else
    alias ls='ls -G'
  fi
  alias ll='ls -lah'
  alias la='ls -A'
fi

# --- Distro binary-name differences -----------------------------------------
# Debian ships fd as `fdfind` and bat as `batcat`; alias to the common names so
# `fd`/`bat` work everywhere (native on macOS, mapped on Debian).
command -v fdfind  >/dev/null 2>&1 && ! command -v fd  >/dev/null 2>&1 && alias fd='fdfind'
command -v batcat  >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && alias bat='batcat'

# --- Editors -----------------------------------------------------------------
alias vi='nvim'
alias vim='nvim'
alias ovim='/usr/bin/vim'          # the original vim, bypassing the nvim alias
alias ec='emacsclient'

# editora — personal editor wrapper and its variants.
alias edi='editora --single-window'
alias edis='editora --simple-ui --single-window'
alias ediz='editora --zen --single-window'
alias edif='editoraf'
alias edifs='editorafs'
alias edifz='editorafz'

# --- fzf helpers -------------------------------------------------------------
alias fh='history | fzf'           # fuzzy-search shell history
alias ff='find . -type f | fzf'    # fuzzy-pick a file under the cwd
alias fdf='fd -t f | fzf'          # same, using fd (faster, respects .gitignore)

# --- Grep --------------------------------------------------------------------
alias grep='grep --color=auto'

# --- Navigation --------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- Git ---------------------------------------------------------------------
alias g='git'
alias gs='git status'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate -20'

# --- Misc --------------------------------------------------------------------
alias df='df -h'
alias du='du -h'
alias mkdir='mkdir -p'
alias reload='exec "$SHELL" -l'
