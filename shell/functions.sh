# shell/functions.sh - functions shared by bash and zsh.
# Written for bash/zsh rather than strict POSIX sh: `local` keeps function
# variables out of your interactive shell, and some names are hyphenated.
#
# Every function is defined as `function name {`, not `name() {`. If an alias
# with the same name already exists (from your rc file, Oh My Bash/Zsh or a
# plugin), `name() {` gets alias-expanded and breaks this whole file; the
# `function` keyword form is never alias-expanded.
#
# Aliases that exist when a function is *defined* are expanded inside its body.
# In bash, Debian's stock ~/.bashrc and Oh My Bash define aliases before this
# file loads (e.g. `alias cd=_omb_directories_cd`, our `mkdir -p`), so bodies
# use `builtin cd` / `command mkdir` etc. to get the plain commands.

# Make a directory and cd into it.
function mkcd {
  [ -n "$1" ] || { echo "usage: mkcd <dir>" >&2; return 1; }
  command mkdir -p -- "$1" && builtin cd -- "$1" || return 1
}

# Extract most archive types with one command.
function extract {
  [ -f "$1" ] || { echo "extract: '$1' is not a file" >&2; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) command tar xjf "$1" ;;
    *.tar.gz|*.tgz)   command tar xzf "$1" ;;
    *.tar.xz)         command tar xJf "$1" ;;
    *.tar)            command tar xf  "$1" ;;
    *.bz2)            command bunzip2 "$1" ;;
    *.gz)             command gunzip  "$1" ;;
    *.zip)            command unzip   "$1" ;;
    *.Z)              command uncompress "$1" ;;
    *.7z)             command 7z x    "$1" ;;
    *) echo "extract: don't know how to extract '$1'" >&2; return 1 ;;
  esac
}

# Up N directories: `up 3` == cd ../../..
# Never name a variable `path` here: in zsh it is tied to $PATH.
function up {
  local count="${1:-1}" target="" i=0
  case "$count" in
    ''|*[!0-9]*) echo "usage: up [n]" >&2; return 1 ;;
  esac
  while [ "$i" -lt "$count" ]; do
    target="../$target"
    i=$((i + 1))
  done
  builtin cd "$target" || return 1
}

# ovim - a real Vim, bypassing the vi/vim -> nvim aliases. On Debian
# /usr/bin/vim is often just an alternatives link to nvim, so look for an
# actual Vim binary first.
function ovim {
  local v
  for v in vim.basic vim.nox vim.gtk3 vim.tiny; do
    if command -v "$v" >/dev/null 2>&1; then
      command "$v" "$@"
      return
    fi
  done
  # `command -v` reports aliases, so look vim up with the alias removed.
  v="$(unalias vim 2>/dev/null; command -v vim)"
  case "$(readlink -f "$v" 2>/dev/null || echo "$v")" in
    ''|*nvim) echo "ovim: no real Vim installed (vim is neovim here)" >&2; return 1 ;;
  esac
  command vim "$@"
}

# Git change branch with fzf support.
# -This version:
# -sorts by most recently updated branches
# -previews the commit graph
# -lists local and origin's branches
# -automatically creates a tracking branch if you pick a remote-only branch
# Oh My Zsh's git plugin defines `alias gb='git branch'`, which would win over
# this function when you type `gb`.
unalias gb 2>/dev/null
function gb {
    local branch

    git rev-parse --git-dir >/dev/null 2>&1 || { echo "gb: not a git repository" >&2; return 1; }

    # Use full refnames: %(refname:short) shortens origin/HEAD to plain
    # "origin". awk drops duplicates without losing the recency order.
    # The preview falls back to origin/<name> for remote-only branches.
    branch=$(
        git for-each-ref \
            --sort=-committerdate \
            --format='%(refname)' \
            refs/heads refs/remotes/origin |
        sed -e 's#^refs/heads/##' -e 's#^refs/remotes/origin/##' |
        command grep -vx 'HEAD' |
        awk '!seen[$0]++' |
        fzf \
            --height=50% \
            --reverse \
            --prompt='branch> ' \
            --preview='git log --graph --decorate --oneline --color=always -n 20 {} -- 2>/dev/null || git log --graph --decorate --oneline --color=always -n 20 origin/{} --'
    ) || return

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git switch "$branch"
    else
        git switch --track "origin/$branch"
    fi
}


# --- fzf helpers -------------------------------------------------------------
# Whether an alias reaches a function body depends on load order, which differs
# between bash and zsh here, so resolve the real binary names explicitly
# (Debian ships fdfind/batcat; macOS/Homebrew ship fd/bat).
command -v fdfind >/dev/null 2>&1 && _FD=fdfind || _FD=fd
command -v batcat >/dev/null 2>&1 && _BAT=batcat || _BAT=bat

# Fuzzy-search the whole shell history. zsh's plain `history` only lists the
# last 16 events (Oh My Zsh wraps it), so ask `fc` for everything there.
function fh {
  if [ -n "${ZSH_VERSION:-}" ]; then
    fc -ln 1 | fzf
  else
    history | fzf
  fi
}

# cd into a directory picked with fzf.
function cdf {
  local dir
  dir="$("$_FD" -t d | fzf)" && [ -n "$dir" ] && builtin cd "$dir" || return
}

# Open an fzf-picked file in the editor ($EDITOR is nvim; see exports.sh).
function vimf {
  local file
  file="$(fzf)" && [ -n "$file" ] && "${EDITOR:-nvim}" "$file"
}

# editora + fzf: pick a file, open it in the various editora modes.
function editoraf  { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window; }
function editorafs { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --simple --single-window; }
function editorafz { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window --zen; }
function editorafe { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window --expert; }
# Find a file with a bat-powered preview pane.
function fd-fp {
  "$_FD" -t f | fzf --preview "$_BAT --style=numbers --color=always {}"
}
function find-fp {
  command find . -type f | fzf --preview "$_BAT --style=numbers --color=always {}"
}

# --- Help --------------------------------------------------------------------
# dothelp - a cheat-sheet of what this dotfiles setup adds to your shell.
# Run `dothelp` (works the same in bash and zsh) to print it any time. Rows for
# tools that aren't installed (e.g. after `install.sh --minimal`) are hidden.

# Pad the (plain) key to a fixed width, then wrap with colour *outside* the
# field so the escape bytes don't throw off column alignment. Reads dothelp's
# local $k / $z (bash and zsh both scope locals dynamically).
# shellcheck disable=SC2154
function _dothelp_row { printf '  %s%-19s%s %s\n' "$k" "$1" "$z" "$2"; }
function _dothelp_has { command -v "$1" >/dev/null 2>&1; }

function dothelp {
  local h k d z t c tools=""
  # Colours, but only when writing to a terminal.
  if [ -t 1 ]; then
    h=$(printf '\033[1;36m'); k=$(printf '\033[1;32m')
    d=$(printf '\033[0;90m'); z=$(printf '\033[0m')
  else
    h=; k=; d=; z=
  fi

  printf '%s\n' "${h}dotfiles — shell cheat-sheet${z} ${d}(run 'dothelp' anytime)${z}"
  printf '%s\n\n' "${d}shared config in \$DOTFILES (${DOTFILES})${z}"

  printf '%s\n' "${h}Listing${z}"
  if _dothelp_has eza; then
    _dothelp_row "ls ll la lt" "eza with icons"
  else
    _dothelp_row "ls ll la" "coloured ls"
    _dothelp_has tree && _dothelp_row "lt" "tree, 2 levels deep"
  fi

  printf '\n%s\n' "${h}Editors${z}"
  _dothelp_has nvim && _dothelp_row "vi vim" "→ nvim"
  _dothelp_row "ovim"             "a real Vim (not neovim), if one is installed"
  _dothelp_has emacsclient && _dothelp_row "ec" "→ emacsclient"
  if _dothelp_has editora; then
    _dothelp_row "edi edis ediz edie" "editora window: normal / simple / zen / expert"
  fi

  if _dothelp_has editora && _dothelp_has fzf; then
    printf '\n%s\n' "${h}editora + fzf  (function, and its alias)${z}"
    _dothelp_row "editoraf  (edif)"  "pick a file with fzf, open in editora"
    _dothelp_row "editorafs (edifs)" "...in editora's simple UI"
    _dothelp_row "editorafz (edifz)" "...in editora's zen mode"
    _dothelp_row "editorafe (edife)" "...in editora's expert mode"
  fi

  printf '\n%s\n' "${h}Git${z}"
  _dothelp_row "g gs gd ga gc"  "git / status / diff / add / commit"
  _dothelp_row "gco gp gl glog" "checkout / push / pull / graph log"
  _dothelp_has fzf && _dothelp_row "gb" "fzf branch switcher (recent first, tracks origin)"

  printf '\n%s\n' "${h}Navigation${z}"
  _dothelp_row ".. ... ...." "cd up 1 / 2 / 3 levels"
  _dothelp_row "up [n]"      "cd up n levels (default 1)"
  _dothelp_has zoxide && _dothelp_row "z <dir>" "jump to a frecent dir (zoxide)"

  printf '\n%s\n' "${h}Functions${z}"
  _dothelp_row "mkcd <dir>"    "make a directory and cd into it"
  _dothelp_row "extract <file>" "extract any common archive type"
  _dothelp_row "reload"        "restart the shell to pick up config changes"

  if _dothelp_has fzf; then
    printf '\n%s\n' "${h}fzf helpers${z}"
    _dothelp_row "fh"   "fuzzy-search shell history"
    _dothelp_row "ff"   "fuzzy-pick a file (find)"
    _dothelp_row "vimf" "fuzzy-pick a file, open in \$EDITOR"
    if _dothelp_has "$_FD"; then
      _dothelp_row "fdf"  "fuzzy-pick a file (fd)"
      _dothelp_row "cdf"  "fuzzy-pick a directory and cd"
    fi
    if _dothelp_has "$_BAT"; then
      _dothelp_row "find-fp" "fuzzy-pick a file with a bat preview"
      _dothelp_has "$_FD" && _dothelp_row "fd-fp" "...same, listing with fd"
    fi
  fi

  for t in rg fd bat fzf jq tree htop btop ncdu duf mc nmap ncat tmux nvim emacs jed zoxide fastfetch sdk; do
    case "$t" in
      fd)  c="$_FD" ;;
      bat) c="$_BAT" ;;
      *)   c="$t" ;;
    esac
    _dothelp_has "$c" && tools="$tools $t"
  done
  if [ -n "$tools" ]; then
    printf '\n%s\n' "${h}Tools available${z}"
    printf '  %s\n' "${d}${tools# }${z}"
  fi

  printf '\n%s\n' "${d}Add your own machine-only tweaks in ~/.shell.local${z}"
}
