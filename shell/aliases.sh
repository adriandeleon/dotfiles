# shell/aliases.sh - aliases shared by bash and zsh
# POSIX-compatible: must work in both shells.

# Only take effect when shell/common.sh loads this file, which it does after
# the functions, the framework and the tool integrations. Debian's stock
# ~/.bashrc also sources ~/.bash_aliases (which install.sh links here) much
# earlier, and aliases that exist when a function is defined get baked into it
# (e.g. `mkdir -p -p` inside SDKMAN). To reload aliases, use `reload`.
if [ -z "${_DOTFILES_LOADING_ALIASES:-}" ]; then return 0; fi

# --- Listing -----------------------------------------------------------------
# `ls` stays the real ls (with colour), so its usual flags (-ltr, -S...) keep
# working; eza has different options. eza (with icons) backs ll/la/lt instead.
# macOS ls uses -G for colour; GNU ls uses --color=auto. `command` makes the
# probe use the real ls binary, never an alias; `-d /` keeps it from listing
# the current directory (slow in huge or network directories).
if command ls --color=auto -d / >/dev/null 2>&1; then
  alias ls='ls --color=auto'
else
  alias ls='ls -G'
fi
if command -v eza >/dev/null 2>&1; then
  alias eza='eza --icons'
  alias ll='eza --icons -lah --group-directories-first --git'
  alias la='eza --icons -a --group-directories-first'
  alias lt='eza --icons --tree --level=2'
else
  alias ll='ls -lah'
  alias la='ls -A'
  command -v tree >/dev/null 2>&1 && alias lt='tree -L 2'
fi

# --- Distro binary-name differences -----------------------------------------
# Debian ships fd as `fdfind` and bat as `batcat`; alias to the common names so
# `fd`/`bat` work everywhere (native on macOS, mapped on Debian).
command -v fd  >/dev/null 2>&1 || { command -v fdfind >/dev/null 2>&1 && alias fd='fdfind'; }
command -v bat >/dev/null 2>&1 || { command -v batcat >/dev/null 2>&1 && alias bat='batcat'; }

# --- Editors -----------------------------------------------------------------
# Only redirect vi/vim when neovim is actually installed (the --minimal
# package sets don't include it).
if command -v nvim >/dev/null 2>&1; then
  alias vi='nvim'
  alias vim='nvim'
fi
# `ovim` (a real Vim, bypassing these aliases) is a function in functions.sh.
alias ec='emacsclient'

# editora: personal editor wrapper and its variants.
alias edi='editora --single-window'
alias edis='editora --simple --single-window'
alias ediz='editora --zen --single-window'
alias edie='editora --expert --single-window'
alias edif='editoraf'
alias edifs='editorafs'
alias edifz='editorafz'
alias edife='editorafe'

# --- fzf helpers -------------------------------------------------------------
# (`fh`, fuzzy history search, is a function in functions.sh.)
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
