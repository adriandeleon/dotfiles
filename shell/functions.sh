# shell/functions.sh — functions shared by bash and zsh.
# Written for bash/zsh (the fzf helpers below use hyphenated names, which are a
# bash/zsh extension rather than strict POSIX sh).

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
up() {
  count="${1:-1}"
  path=""
  i=0
  while [ "$i" -lt "$count" ]; do
    path="../$path"
    i=$((i + 1))
  done
  cd "$path" || return 1
}

# --- fzf helpers -------------------------------------------------------------
# Aliases are NOT expanded inside function bodies, so resolve the real binary
# names here (Debian ships fdfind/batcat; macOS/Homebrew ship fd/bat).
command -v fdfind >/dev/null 2>&1 && _FD=fdfind || _FD=fd
command -v batcat >/dev/null 2>&1 && _BAT=batcat || _BAT=bat

# cd into a directory picked with fzf.
cdf() {
  dir="$("$_FD" -t d | fzf)" && [ -n "$dir" ] && cd "$dir" || return
}

# Open an fzf-picked file in the editor ($EDITOR is nvim; see exports.sh).
vimf() {
  file="$(fzf)" && [ -n "$file" ] && "${EDITOR:-nvim}" "$file"
}

# editora + fzf: pick a file, open it in the various editora modes.
editoraf()  { file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window; }
editorafs() { file="$(fzf)" && [ -n "$file" ] && editora "$file" --simple --single-window; }
editorafz() { file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window --zen; }

# Find a file with a bat-powered preview pane.
fd-fp() {
  "$_FD" -t f | fzf --preview "$_BAT --style=numbers --color=always {}"
}
find-fp() {
  find . -type f | fzf --preview "$_BAT --style=numbers --color=always {}"
}

# --- Help --------------------------------------------------------------------
# dothelp — a cheat-sheet of what this dotfiles setup adds to your shell.
# Run `dothelp` (works the same in bash and zsh) to print it any time.
dothelp() {
  # Colours, but only when writing to a terminal.
  if [ -t 1 ]; then
    h=$(printf '\033[1;36m'); k=$(printf '\033[1;32m')
    d=$(printf '\033[0;90m'); z=$(printf '\033[0m')
  else
    h=; k=; d=; z=
  fi

  # Pad the (plain) key to a fixed width, then wrap with colour *outside* the
  # field so the escape bytes don't throw off column alignment.
  row() { printf '  %s%-18s%s %s\n' "$k" "$1" "$z" "$2"; }

  printf '%s\n' "${h}dotfiles — shell cheat-sheet${z} ${d}(run 'dothelp' anytime)${z}"
  printf '%s\n\n' "${d}Oh My Bash/Zsh + agnoster · shared config in \$DOTFILES (${DOTFILES})${z}"

  printf '%s\n' "${h}Listing${z}"
  row "ls ll la lt"   "eza with icons (falls back to coloured ls)"

  printf '\n%s\n' "${h}Editors${z}"
  row "vi vim"           "→ nvim"
  row "ovim"             "→ the original /usr/bin/vim"
  row "ec"               "→ emacsclient"
  row "edi edis ediz"    "editora: normal / simple-ui / zen"
  row "edif edifs edifz" "editora + fzf file picker"

  printf '\n%s\n' "${h}Git${z}"
  row "g gs gd ga gc"  "git / status / diff / add / commit"
  row "gco gp gl glog" "checkout / push / pull / graph log"

  printf '\n%s\n' "${h}Navigation${z}"
  row ".. ... ...." "cd up 1 / 2 / 3 levels"
  row "up [n]"      "cd up n levels (default 1)"
  row "z <dir>"     "jump to a frecent dir (zoxide)"

  printf '\n%s\n' "${h}Functions${z}"
  row "mkcd <dir>"    "make a directory and cd into it"
  row "extract <file>" "extract any common archive type"

  printf '\n%s\n' "${h}fzf helpers${z}"
  row "fh"            "fuzzy-search shell history"
  row "ff fdf"        "fuzzy-pick a file (find / fd)"
  row "cdf"           "fuzzy-pick a directory and cd"
  row "vimf"          "fuzzy-pick a file, open in \$EDITOR"
  row "fd-fp find-fp" "fuzzy-pick a file with a bat preview"

  printf '\n%s\n' "${h}Tools installed${z}"
  printf '  %s\n' "${d}rg fd bat fzf jq tree htop btop ncdu duf mc${z}"
  printf '  %s\n' "${d}nmap ncat tmux neovim emacs jed zoxide tldr fastfetch sdk${z}"

  printf '\n%s\n' "${d}Add your own machine-only tweaks in ~/.shell.local${z}"
}
