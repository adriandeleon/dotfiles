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
# Our own aliases load after this file, but Oh My Bash/Zsh and your own rc file
# or aliases file can define some before it (e.g. Oh My Bash's
# `alias cd=_omb_directories_cd`), so bodies use `builtin cd` /
# `command mkdir` etc. to get the plain commands.

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
# Debian ships fd/bat as fdfind/batcat; macOS/Homebrew as fd/bat. The helpers
# don't use the fd/bat aliases (aliases.sh loads after this file); they look
# the real name up each time they run, so installing one later just works.
function _dotfiles_bin { # _dotfiles_bin fd|bat - print the installed binary's name
  case "$1" in
    fd)  if command -v fdfind >/dev/null 2>&1; then echo fdfind; else echo fd; fi ;;
    bat) if command -v batcat >/dev/null 2>&1; then echo batcat; else echo bat; fi ;;
    *)   echo "$1" ;;
  esac
}

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
  dir="$("$(_dotfiles_bin fd)" -t d | fzf)" && [ -n "$dir" ] && builtin cd "$dir" || return
}

# Open an fzf-picked file in $EDITOR (nvim if unset). EDITOR may include
# arguments (`code --wait`, `emacsclient -t`), so run it through sh like git
# does.
function vimf {
  local file
  file="$(fzf)" && [ -n "$file" ] && sh -c "${EDITOR:-nvim} \"\$1\"" sh "$file"
}

# editora + fzf: pick a file, open it in the various editora modes.
function editoraf  { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window; }
function editorafs { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --simple --single-window; }
function editorafz { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window --zen; }
function editorafe { local file; file="$(fzf)" && [ -n "$file" ] && editora "$file" --single-window --expert; }
# Find a file with a bat-powered preview pane.
function fd-fp {
  "$(_dotfiles_bin fd)" -t f | fzf --preview "$(_dotfiles_bin bat) --style=numbers --color=always {}"
}
function find-fp {
  command find . -type f | fzf --preview "$(_dotfiles_bin bat) --style=numbers --color=always {}"
}

# --- Version -----------------------------------------------------------------
# _dotfiles_version - "dotfiles 1.0.0 (4df2b00)": the VERSION file, plus the
# commit (marked -dirty with uncommitted changes) when $DOTFILES is a git
# checkout. Same output as dotfiles_version in install.sh; keep them in sync.
function _dotfiles_version {
  local v c
  v="$(command sed -n '1s/[[:space:]]*$//p' "$DOTFILES/VERSION" 2>/dev/null)"
  c="$(command git -C "$DOTFILES" rev-parse --short HEAD 2>/dev/null)"
  if [ -n "$c" ] && ! command git -C "$DOTFILES" diff --quiet HEAD -- 2>/dev/null; then
    c="$c-dirty"
  fi
  printf 'dotfiles %s%s\n' "${v:-unknown}" "${c:+ ($c)}"
}

# --- Help --------------------------------------------------------------------
# dothelp - a cheat-sheet of what this dotfiles setup adds to your shell.
# Run `dothelp` (works the same in bash and zsh) to print it any time. Rows for
# tools that aren't installed (e.g. after `install.sh --minimal`) are hidden.

function dothelp {
  local h k d z t c fd bat tools=""
  # `dothelp --version` prints just the version line.
  if [ "${1:-}" = --version ]; then _dotfiles_version; return; fi
  fd="$(_dotfiles_bin fd)"; bat="$(_dotfiles_bin bat)"

  # Helpers, removed again at the end. _dothelp_row pads the (plain) key to a
  # fixed width, then wraps it with colour *outside* the field so the escape
  # bytes don't throw off column alignment.
  function _dothelp_row { printf '  %s%-19s%s %s\n' "$k" "$1" "$z" "$2"; }
  function _dothelp_has { command -v "$1" >/dev/null 2>&1; }

  # Colours, but only when writing to a terminal.
  if [ -t 1 ]; then
    h=$(printf '\033[1;36m'); k=$(printf '\033[1;32m')
    d=$(printf '\033[0;90m'); z=$(printf '\033[0m')
  else
    h=; k=; d=; z=
  fi

  printf '%s\n' "${h}$(_dotfiles_version) — shell cheat-sheet${z} ${d}(run 'dothelp' anytime)${z}"
  printf '%s\n\n' "${d}shared config in \$DOTFILES (${DOTFILES})${z}"

  printf '%s\n' "${h}Listing${z}"
  _dothelp_row "ls" "the real ls, with colour"
  if _dothelp_has eza; then
    _dothelp_row "ll la lt" "eza with icons (long / all / tree)"
  else
    _dothelp_row "ll la" "ls -lah / ls -A"
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
  _dothelp_row "dotdoctor"     "check this setup and say how to fix problems"
  _dothelp_row "dothelp --version" "print the dotfiles version"

  if _dothelp_has fzf; then
    printf '\n%s\n' "${h}fzf helpers${z}"
    _dothelp_row "fh"   "fuzzy-search shell history"
    _dothelp_row "ff"   "fuzzy-pick a file (find)"
    _dothelp_row "vimf" "fuzzy-pick a file, open in \$EDITOR"
    if _dothelp_has "$fd"; then
      _dothelp_row "fdf"  "fuzzy-pick a file (fd)"
      _dothelp_row "cdf"  "fuzzy-pick a directory and cd"
    fi
    if _dothelp_has "$bat"; then
      _dothelp_row "find-fp" "fuzzy-pick a file with a bat preview"
      _dothelp_has "$fd" && _dothelp_row "fd-fp" "...same, listing with fd"
    fi
  fi

  if _dothelp_has jkit; then
    printf '\n%s\n' "${h}Java (jkit)${z}"
    _dothelp_row "jkit install jdk@21" "install a JDK (also maven@…, gradle@…)"
    _dothelp_row "jkit use jdk@21"     "switch this shell (--global for every shell)"
    _dothelp_row "jkit list"           "show installed versions"
  fi

  for t in rg fd bat fzf jq tree htop btop ncdu duf mc nmap ncat tmux nvim emacs jed zoxide fastfetch jkit; do
    case "$t" in
      fd)  c="$fd" ;;
      bat) c="$bat" ;;
      *)   c="$t" ;;
    esac
    _dothelp_has "$c" && tools="$tools $t"
  done
  if [ -n "$tools" ]; then
    printf '\n%s\n' "${h}Tools available${z}"
    printf '  %s\n' "${d}${tools# }${z}"
  fi

  printf '\n%s\n' "${d}Add your own machine-only tweaks in ~/.shell.local${z}"
  unset -f _dothelp_row _dothelp_has
}

# --- Doctor ------------------------------------------------------------------
# dotdoctor - check this shell's dotfiles setup and say how to fix what's off.
# Changes nothing and uses no network. One line per check (ok / info / warn /
# fail), a "fix:" line under anything that needs one, then a summary; returns
# 1 when a check fails. Same format as `jkit doctor`. It runs in your shell,
# so it sees what actually loaded (aliases, functions, hooks); `install.sh
# --doctor` runs it in a fresh one.
function dotdoctor {
  local warns=0 fails=0 sh rc aliases_file n t c missing extras late have pinned
  local c_ok c_info c_warn c_fail c_off
  local marker='# >>> dotfiles (managed by install.sh) >>>'
  local end_marker='# <<< dotfiles (managed by install.sh) <<<'

  if [ -t 1 ]; then
    c_ok=$(printf '\033[32m'); c_info=$(printf '\033[90m'); c_warn=$(printf '\033[33m')
    c_fail=$(printf '\033[31m'); c_off=$(printf '\033[0m')
  else
    c_ok=; c_info=; c_warn=; c_fail=; c_off=
  fi
  # _dotdoctor_line <ok|info|warn|fail> <message> [fix]
  function _dotdoctor_line {
    local col
    case "$1" in
      ok)   col=$c_ok ;;
      warn) col=$c_warn; warns=$((warns + 1)) ;;
      fail) col=$c_fail; fails=$((fails + 1)) ;;
      *)    col=$c_info ;;
    esac
    printf '%s%-6s%s%s\n' "$col" "$1" "$c_off" "$2"
    if [ -n "${3:-}" ]; then printf '      fix: %s\n' "$3"; fi
  }
  # _dotdoctor_older <a> <b> - true if dotted version <a> is older than <b>.
  function _dotdoctor_older {
    command awk -v a="$1" -v b="$2" 'BEGIN {
      n = split(a, x, "."); m = split(b, y, "."); if (m > n) n = m
      for (i = 1; i <= n; i++) {
        if (x[i] + 0 < y[i] + 0) exit 0
        if (x[i] + 0 > y[i] + 0) exit 1
      }
      exit 1 }'
  }

  if [ -n "${ZSH_VERSION:-}" ]; then
    sh=zsh; rc="$HOME/.zshrc"; aliases_file="$HOME/.zsh_aliases"
  else
    sh=bash; rc="$HOME/.bashrc"; aliases_file="$HOME/.bash_aliases"
  fi

  # checkout: the config this shell loaded from
  if [ -r "$DOTFILES/shell/common.sh" ]; then
    _dotdoctor_line ok "$(_dotfiles_version), in $DOTFILES"
  else
    _dotdoctor_line fail "\$DOTFILES ($DOTFILES) has no shell/common.sh" \
      "run ./install.sh --link from your dotfiles checkout"
  fi

  # include block: exactly one, pointing at this checkout
  n="$(command grep -cxF "$marker" "$rc" 2>/dev/null)"
  case "${n:-0}" in
    0) _dotdoctor_line warn "$rc has no dotfiles include block" "$DOTFILES/install.sh --link" ;;
    1)
      if command grep -qxF "export DOTFILES=\"$DOTFILES\"" "$rc"; then
        _dotdoctor_line ok "$rc loads this checkout"
      else
        _dotdoctor_line warn "the include block in $rc points at another checkout" "$DOTFILES/install.sh --link"
      fi ;;
    *) _dotdoctor_line fail "$rc has $n dotfiles include blocks" \
         "delete all but one by hand, then $DOTFILES/install.sh --link" ;;
  esac

  # lines after the block that undo what it set up (same list as install.sh)
  late="$(command awk -v e="$end_marker" '
    after && /(^|[^A-Za-z_])(PATH|PROMPT_COMMAND)=|jkit hook|cargo\/env|nvm\.sh/ { print "        " $0 }
    $0 == e { after = 1 }' "$rc" 2>/dev/null)"
  if [ -n "$late" ]; then
    _dotdoctor_line warn "lines after the include block in $rc change PATH or PROMPT_COMMAND, or load tools" \
      "move these above the block:"
    printf '%s\n' "$late"
  fi

  # Debian's stock history limits (bash truncates the file to HISTFILESIZE)
  if [ "$sh" = bash ] && command grep -Eq '^(HISTSIZE=1000|HISTFILESIZE=2000)[[:space:]]*$' "$rc" 2>/dev/null; then
    _dotdoctor_line warn "$rc still sets the stock HISTFILESIZE=2000, which truncates your history" \
      "$DOTFILES/install.sh --link (comments those lines out)"
  fi

  # aliases file
  if [ -L "$aliases_file" ] && [ ! -e "$aliases_file" ]; then
    _dotdoctor_line warn "$aliases_file is a broken link" "rm '$aliases_file'; $DOTFILES/install.sh --link"
  elif [ "$aliases_file" -ef "$DOTFILES/shell/aliases.sh" ]; then
    _dotdoctor_line ok "$aliases_file links to shell/aliases.sh"
  elif [ -e "$aliases_file" ]; then
    _dotdoctor_line info "$aliases_file is your own file, loaded after the repo's aliases"
  fi

  # framework
  if [ "$sh" = bash ] && [ -n "${OMB_VERSION:-}" ]; then
    _dotdoctor_line ok "Oh My Bash loaded (theme ${OSH_THEME:-none})"
  elif [ "$sh" = zsh ] && typeset -f omz >/dev/null 2>&1; then
    _dotdoctor_line ok "Oh My Zsh loaded (theme ${ZSH_THEME:-none})"
  elif [ -n "${DOTFILES_NO_FRAMEWORK:-}" ]; then
    _dotdoctor_line info "no framework: DOTFILES_NO_FRAMEWORK is set"
  else
    if [ "$sh" = bash ]; then t="Oh My Bash"; c="$HOME/.oh-my-bash"; else t="Oh My Zsh"; c="$HOME/.oh-my-zsh"; fi
    if [ -d "$c" ]; then
      _dotdoctor_line warn "$t is installed in $c but wasn't loaded" "$sh -ic true  (look for errors as your shell starts)"
    else
      _dotdoctor_line info "$t isn't installed (./install.sh adds it; --minimal skips it)"
    fi
  fi

  # shared functions, and our aliases winning over anything loaded earlier
  missing=""
  for t in mkcd extract up ovim gb fh cdf vimf dothelp; do
    typeset -f "$t" >/dev/null 2>&1 || missing="$missing $t"
  done
  if [ -n "$missing" ]; then
    _dotdoctor_line fail "shared functions missing:$missing" "$sh -ic true  (look for errors as your shell starts)"
  else
    _dotdoctor_line ok "shared functions defined"
  fi
  case "$(alias ll 2>/dev/null)" in
    *"ll='eza --icons -lah"*|*"ll='ls -lah"*) _dotdoctor_line ok "aliases are the repo's (ll checked)" ;;
    *)
      if [ -e "$aliases_file" ] && ! [ "$aliases_file" -ef "$DOTFILES/shell/aliases.sh" ] \
          && command grep -q 'alias ll=' "$aliases_file"; then
        _dotdoctor_line info "ll comes from your $aliases_file"
      else
        _dotdoctor_line warn "ll isn't the repo's alias: something after the include block redefines it" \
          "move that alias above the block in $rc, or into $aliases_file"
      fi ;;
  esac

  # tools: the ones every install has, then the full install's extras
  missing=""
  for t in git curl fzf rg bat; do
    c="$t"; [ "$t" = bat ] && c="$(_dotfiles_bin bat)"
    command -v "$c" >/dev/null 2>&1 || missing="$missing $t"
  done
  extras=""
  for t in fd eza zoxide nvim jq tmux; do
    c="$t"; [ "$t" = fd ] && c="$(_dotfiles_bin fd)"
    command -v "$c" >/dev/null 2>&1 || extras="$extras $t"
  done
  if [ -n "$missing" ]; then
    _dotdoctor_line warn "core tools missing:$missing" "$DOTFILES/install.sh --packages  (or --minimal --packages)"
  else
    _dotdoctor_line ok "core tools installed (git curl fzf rg bat)"
  fi
  if [ -n "$extras" ]; then
    _dotdoctor_line info "not installed:$extras (./install.sh adds them; --minimal skips them)"
  fi

  # zoxide's hook: a later PROMPT_COMMAND= assignment silently drops it
  if command -v zoxide >/dev/null 2>&1; then
    if [ "$sh" = bash ]; then t=" ${PROMPT_COMMAND[*]:-} "; else t=" ${chpwd_functions[*]:-} "; fi
    case "$t" in
      *__zoxide_hook*) _dotdoctor_line ok "zoxide hook active" ;;
      *) _dotdoctor_line warn "zoxide is installed but its hook isn't active, so z stops learning directories" \
           "add to PROMPT_COMMAND rather than replacing it (e.g. in ~/.shell.local)" ;;
    esac
  fi

  # jkit: hook loaded, and not older than the version install.sh pins
  if command -v jkit >/dev/null 2>&1; then
    have="$(command jkit --version 2>/dev/null | command awk 'NR == 1 { print $NF }')"
    pinned="$(command sed -n 's/^JKIT_VERSION="\(.*\)"$/\1/p' "$DOTFILES/install.sh" 2>/dev/null)"
    if ! typeset -f jkit >/dev/null 2>&1; then
      _dotdoctor_line warn "jkit ${have:-?} is installed but its shell hook isn't loaded" \
        "open a new shell; if that doesn't help, $DOTFILES/install.sh --link"
    elif [ -n "$have" ] && [ -n "$pinned" ] && _dotdoctor_older "$have" "$pinned"; then
      _dotdoctor_line warn "jkit $have is older than $pinned (pinned in install.sh)" "$DOTFILES/install.sh --packages"
    else
      _dotdoctor_line ok "jkit ${have:-?}, shell hook loaded"
    fi
  else
    _dotdoctor_line info "jkit isn't installed (./install.sh adds it; --minimal skips it)"
  fi

  # Vitrina apt repository (Debian and derivatives)
  if [ -f /etc/debian_version ]; then
    if command grep -rqs 'vitrina-project\.dev' /etc/apt/sources.list /etc/apt/sources.list.d; then
      _dotdoctor_line ok "Vitrina apt repository configured"
    else
      _dotdoctor_line info "Vitrina apt repository not configured (./install.sh adds it; --minimal skips it)"
    fi
  fi

  # Nerd Font for the agnoster prompt (only matters with a framework loaded)
  if command -v fc-list >/dev/null 2>&1; then
    command fc-list 2>/dev/null | command grep -qi 'JetBrainsMono Nerd' && t=yes || t=no
  else
    command ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | command grep -qi 'JetBrainsMono.*Nerd' && t=yes || t=no
  fi
  if [ "$t" = yes ]; then
    _dotdoctor_line ok "JetBrains Mono Nerd Font installed (your terminal must use it)"
  elif [ -n "${OMB_VERSION:-}" ] || typeset -f omz >/dev/null 2>&1; then
    _dotdoctor_line warn "JetBrains Mono Nerd Font not found, so the prompt's glyphs won't render" \
      "$DOTFILES/install.sh --packages"
  fi

  if [ "$warns" -eq 0 ] && [ "$fails" -eq 0 ]; then
    printf '%s\n' "no problems found"
  else
    printf '%s warning%s, %s problem%s\n' "$warns" "$([ "$warns" -eq 1 ] || echo s)" \
      "$fails" "$([ "$fails" -eq 1 ] || echo s)"
  fi
  unset -f _dotdoctor_line _dotdoctor_older
  [ "$fails" -eq 0 ]
}
