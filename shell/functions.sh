# shell/functions.sh - functions shared by bash and zsh.
# Written for bash/zsh (the fzf helpers below use hyphenated names, and `local`
# keeps function variables out of your interactive shell - both are bash/zsh
# extensions rather than strict POSIX sh).

# Make a directory and cd into it.
mkcd() {
  [ -n "$1" ] || { echo "usage: mkcd <dir>" >&2; return 1; }
  mkdir -p -- "$1" && cd -- "$1" || return 1
}

# Extract most archive types with one command.
extract() {
  [ -f "$1" ] || { echo "extract: '$1' is not a file" >&2; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar)            tar xf  "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.gz)             gunzip  "$1" ;;
    *.zip)            unzip   "$1" ;;
    *.Z)              uncompress "$1" ;;
    *.7z)             7z x    "$1" ;;
    *) echo "extract: don't know how to extract '$1'" >&2; return 1 ;;
  esac
}

# Up N directories: `up 3` == cd ../../..
# Never name a variable `path` here: in zsh it is tied to $PATH.
up() {
  local count="${1:-1}" target="" i=0
  case "$count" in
    ''|*[!0-9]*) echo "usage: up [n]" >&2; return 1 ;;
  esac
  while [ "$i" -lt "$count" ]; do
    target="../$target"
    i=$((i + 1))
  done
  cd "$target" || return 1
}

# Git change branch with fzf support.
# -This version:
# -sorts by most recently updated branches
# -previews the commit graph
# -lists local and remote branches
# -automatically creates a tracking branch if you pick a remote-only branch
unalias gb 2>/dev/null
gb() {
    local branch

    # Use full refnames: %(refname:short) shortens origin/HEAD to plain
    # "origin". awk drops duplicates without losing the recency order.
    branch=$(
        git for-each-ref \
            --sort=-committerdate \
            --format='%(refname)' \
            refs/heads refs/remotes/origin |
        sed -e 's#^refs/heads/##' -e 's#^refs/remotes/origin/##' |
        grep -vx 'HEAD' |
        awk '!seen[$0]++' |
        fzf \
            --height=50% \
            --reverse \
            --prompt='branch> ' \
            --preview='git log --graph --decorate --oneline --color=always -n 20 {}'
    ) || return

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git switch "$branch"
    else
        git switch --track "origin/$branch"
    fi
}


# --- fzf helpers -------------------------------------------------------------
# Aliases are NOT expanded inside function bodies, so resolve the real binary
# names here (Debian ships fdfind/batcat; macOS/Homebrew ship fd/bat).
command -v fdfind >/dev/null 2>&1 && _FD=fdfind || _FD=fd
command -v batcat >/dev/null 2>&1 && _BAT=batcat || _BAT=bat

# cd into a directory picked with fzf.
cdf() {
  local dir
  dir="$("$_FD" -t d | fzf)" && [ -n "$dir" ] && cd "$dir" || return
}

# Open an fzf-picked file in the editor ($EDITOR is nvim; see exports.sh).
vimf() {
  local file
  file="$(fzf)" && [ -n "$file" ] && "${EDITOR:-nvim}" "$file"
}

# editora + fzf: pick a file, open it in the various editora modes.
editoraf()  { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window; }
editorafs() { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --simple --single-window; }
editorafz() { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window --zen; }
editorafe() { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window --expert; }
# Find a file with a bat-powered preview pane.
fd-fp() {
  "$_FD" -t f | fzf --preview "$_BAT --style=numbers --color=always {}"
}
find-fp() {
  find . -type f | fzf --preview "$_BAT --style=numbers --color=always {}"
}

# --- Help --------------------------------------------------------------------
# dothelp - a cheat-sheet of what this dotfiles setup adds to your shell.
# Run `dothelp` (works the same in bash and zsh) to print it any time.

# Pad the (plain) key to a fixed width, then wrap with colour *outside* the
# field so the escape bytes don't throw off column alignment. Reads dothelp's
# local $k / $z (bash and zsh both scope locals dynamically).
# shellcheck disable=SC2154
_dothelp_row() { printf '  %s%-19s%s %s\n' "$k" "$1" "$z" "$2"; }

dothelp() {
  local h k d z
  # Colours, but only when writing to a terminal.
  if [ -t 1 ]; then
    h=$(printf '\033[1;36m'); k=$(printf '\033[1;32m')
    d=$(printf '\033[0;90m'); z=$(printf '\033[0m')
  else
    h=; k=; d=; z=
  fi

  printf '%s\n' "${h}dotfiles — shell cheat-sheet${z} ${d}(run 'dothelp' anytime)${z}"
  printf '%s\n\n' "${d}Oh My Bash/Zsh + agnoster · shared config in \$DOTFILES (${DOTFILES})${z}"

  printf '%s\n' "${h}Listing${z}"
  _dothelp_row "ls ll la lt"   "eza with icons (falls back to coloured ls)"

  printf '\n%s\n' "${h}Editors${z}"
  _dothelp_row "vi vim"           "→ nvim (when installed)"
  _dothelp_row "ovim"             "→ the original vim, bypassing the alias"
  _dothelp_row "ec"               "→ emacsclient"
  _dothelp_row "edi edis ediz edie" "editora window: normal / simple / zen / expert"

  printf '\n%s\n' "${h}editora + fzf  (function, and its alias)${z}"
  _dothelp_row "editoraf  (edif)"  "pick a file with fzf, open in editora"
  _dothelp_row "editorafs (edifs)" "...in editora's simple UI"
  _dothelp_row "editorafz (edifz)" "...in editora's zen mode"
  _dothelp_row "editorafe (edife)" "...in editora's expert mode"

  printf '\n%s\n' "${h}Git${z}"
  _dothelp_row "g gs gd ga gc"  "git / status / diff / add / commit"
  _dothelp_row "gco gp gl glog" "checkout / push / pull / graph log"
  _dothelp_row "gb"             "fzf branch switcher (recent first, tracks remotes)"

  printf '\n%s\n' "${h}Navigation${z}"
  _dothelp_row ".. ... ...." "cd up 1 / 2 / 3 levels"
  _dothelp_row "up [n]"      "cd up n levels (default 1)"
  _dothelp_row "z <dir>"     "jump to a frecent dir (zoxide)"

  printf '\n%s\n' "${h}Functions${z}"
  _dothelp_row "mkcd <dir>"    "make a directory and cd into it"
  _dothelp_row "extract <file>" "extract any common archive type"
  _dothelp_row "reload"        "restart the shell to pick up config changes"

  printf '\n%s\n' "${h}fzf helpers${z}"
  _dothelp_row "fh"            "fuzzy-search shell history"
  _dothelp_row "ff fdf"        "fuzzy-pick a file (find / fd)"
  _dothelp_row "cdf"           "fuzzy-pick a directory and cd"
  _dothelp_row "vimf"          "fuzzy-pick a file, open in \$EDITOR"
  _dothelp_row "fd-fp find-fp" "fuzzy-pick a file with a bat preview"

  printf '\n%s\n' "${h}Tools installed${z}"
  printf '  %s\n' "${d}rg fd bat fzf jq tree htop btop ncdu duf mc${z}"
  printf '  %s\n' "${d}nmap ncat tmux neovim emacs jed zoxide fastfetch sdk${z}"

  printf '\n%s\n' "${d}Add your own machine-only tweaks in ~/.shell.local${z}"
}
