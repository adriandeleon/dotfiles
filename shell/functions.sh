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
