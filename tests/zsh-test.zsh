#!/usr/bin/env zsh
# tests/zsh-test.zsh - start interactive zsh sessions on top of the shared
# config in throwaway HOME directories (every shell runs under `env -i`, so your
# real HOME is never read or written). Run from anywhere:
#   zsh tests/zsh-test.zsh
# On macOS the ~/.zshrc include block is written by install.sh itself (run with
# the system /bin/bash); elsewhere the test writes the same block by hand.
# Set OMZ_SRC to an Oh My Zsh checkout to also test against the real framework.

REPO=${0:A:h:h}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
BEGIN="# >>> dotfiles (managed by install.sh) >>>"
END="# <<< dotfiles (managed by install.sh) <<<"
TEST_PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
FUNCS=(up mkcd gb fh ovim dothelp cdf vimf extract)
fails=0

pass() { print -r -- "ok   - $1"; }
fail() { print -r -- "FAIL - $1"; (( fails++ )); }
check() { # check <description> <command...>
  local desc=$1; shift
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}
same() { [[ "$1" == "$2" ]] || { print -r -- "       got: $1"; return 1; }; }

# Kill a hung shell (e.g. a recursing rc file) instead of hanging the test;
# macOS has no `timeout`, so there it just runs.
TIMEOUT=()
(( $+commands[timeout] )) && TIMEOUT=(timeout -s KILL 20)
clean_env() { local h=$1; shift; env -i HOME=$h PATH=$TEST_PATH TERM=dumb USER=${USER:-test} "$@"; }
# interactive <home> <commands> - stdout of an interactive zsh fed <commands>
interactive() { print -r -- "$2" | clean_env $1 $TIMEOUT zsh -i 2>/dev/null; }
# startup_errors <home> - anything an interactive zsh prints on stderr while
# loading its rc files, minus zsh's own complaint about having no terminal.
startup_errors() {
  clean_env $1 $TIMEOUT zsh -ic true 2>&1 >/dev/null | grep -v "not interactive and can't open terminal"
}

# new_home <name> [fake|real|none] - a temp HOME whose ~/.zshrc has the include
# block, plus a stand-in Oh My Zsh (default), the real one, or none.
new_home() {
  local h=$WORK/$1
  mkdir -p $h
  # Debian/Ubuntu's global /etc/zsh/zshrc runs compinit for every interactive
  # zsh; on the CI runner it finds group-writable dirs, can't ask about them
  # without a terminal, and prints "compinit: initialization aborted". That's
  # the system's rc, not ours: skip it the documented way.
  print 'skip_global_compinit=1' > $h/.zshenv
  case ${2:-fake} in
    fake)
      mkdir -p $h/.oh-my-zsh
      # Like the real one: defines `omz` and aliases that clash with ours.
      cat > $h/.oh-my-zsh/oh-my-zsh.sh <<'EOF'
function omz { :; }
alias gb='git branch'
alias ll='ls -l'
alias up='cd ..'
FAKE_OMZ_LOADS=$(( ${FAKE_OMZ_LOADS:-0} + 1 ))
EOF
      ;;
    real) ln -s $OMZ_SRC $h/.oh-my-zsh ;;
  esac
  if [[ $OSTYPE == darwin* ]]; then
    clean_env $h /bin/bash $REPO/install.sh --link >$h/install.log 2>&1
  else
    printf '%s\nexport DOTFILES="%s"\nif [ -r "%s/zsh/zshrc" ]; then . "%s/zsh/zshrc"; fi\n%s\n' \
      $BEGIN $REPO $REPO $REPO $END > $h/.zshrc
  fi
  print -r -- $h
}

all_functions() {
  local out
  out=$(interactive $1 'for f in '"$FUNCS"'; do (( $+functions[$f] )) && print -r -- "$f=function" || print -r -- "$f=missing"; done')
  [[ -n $out && $out != *=missing* ]] || { print -r -- "       got: ${out//$'\n'/ }"; return 1; }
}
ours_ll() {
  [[ $1 == "ll='eza --icons -lah"* || $1 == "ll='ls -lah"* ]] || { print -r -- "       got: $1"; return 1; }
}

# --- Fresh HOME with a framework that defines clashing aliases ---------------
h=$(new_home fresh)
if [[ $OSTYPE == darwin* ]]; then
  check "macOS install: no warnings"            grep -q 'Done\.' $h/install.log
  check "macOS install: ~/.zsh_aliases linked"  [ "$(readlink $h/.zsh_aliases)" = "$REPO/shell/aliases.sh" ]
  clean_env $h /bin/bash $REPO/install.sh --link >$h/install2.log 2>&1
  check "macOS install: re-run changes nothing" grep -q 'Already configured' $h/install2.log
fi
check "first prompt sees a success status" same "$(interactive $h 'print -r -- "status=$?"')" "status=0"
check "startup prints no errors"           same "$(startup_errors $h)" ""
check "every shared function is defined"   all_functions $h
check "no stray cd function"               same "$(interactive $h '(( $+functions[cd] )) && print yes || print no')" "no"
check "gb is our function, not OMZ's alias" same "$(interactive $h 'whence -w gb')" "gb: function"
check "ll is ours, not the framework's"    ours_ll "$(interactive $h 'alias ll')"
check "ls stays the real ls"               same "$(interactive $h 'alias ls' | cut -c1-8)" "ls='ls -"
# `unalias up` gets a line of its own: zsh expands aliases while parsing a whole
# line, before any of it runs, so on one line `up 1` would still be the
# framework's alias.
check "up changes directory, keeps PATH" \
  same "$(interactive $h $'unalias up\nbefore=$PATH; cd /tmp && up 1; print -r -- "$PWD $(( ${#PATH} == ${#before} ))"')" "/ 1"
check "framework loads once, also on reload" \
  same "$(interactive $h '. ~/.zshrc; print -r -- "loads=$FAKE_OMZ_LOADS status=$?"')" "loads=1 status=0"
check "dothelp runs and cleans up helpers" \
  same "$(interactive $h 'dothelp >/dev/null && print ok; (( $+functions[_dothelp_row] )) || print gone')" $'ok\ngone'
print 'export EDITOR=nano' > $h/.shell.local
check "EDITOR from ~/.shell.local wins"    same "$(interactive $h 'print -r -- $EDITOR')" "nano"
rm -f $h/.shell.local

# --- DOTFILES_NO_FRAMEWORK=1 above the block skips the framework -------------
h=$(new_home no-framework)
{ print 'DOTFILES_NO_FRAMEWORK=1'; cat $h/.zshrc } > $h/.zshrc.new && mv $h/.zshrc.new $h/.zshrc
check "DOTFILES_NO_FRAMEWORK=1 skips the framework" \
  same "$(interactive $h 'print -r -- "loads=${FAKE_OMZ_LOADS:-0}"')" "loads=0"

# --- ~/.zshrc symlinked to zsh/zshrc with the block appended: must not recurse
copy=$WORK/repo-copy
mkdir -p $copy && cp -R $REPO/. $copy/
h=$WORK/symlinked; mkdir -p $h
printf '%s\nexport DOTFILES="%s"\nif [ -r "%s/zsh/zshrc" ]; then . "%s/zsh/zshrc"; fi\n%s\n' \
  $BEGIN $copy $copy $copy $END >> $copy/zsh/zshrc
ln -s $copy/zsh/zshrc $h/.zshrc
check "self-including rc still starts a shell" same "$(interactive $h 'print started')" "started"

# --- The real Oh My Zsh ------------------------------------------------------
if [[ -n ${OMZ_SRC:-} && -r $OMZ_SRC/oh-my-zsh.sh ]]; then
  h=$(new_home real-omz real)
  # The CI checkout (and runner dirs on fpath) are group-writable, so Oh My
  # Zsh's compaudit would print an "insecure directories" warning into every
  # session. That's about the runner, not this config; use OMZ's own switch.
  { print 'ZSH_DISABLE_COMPFIX=true'; cat $h/.zshrc } > $h/.zshrc.new && mv $h/.zshrc.new $h/.zshrc
  check "real OMZ: first prompt sees a success status" same "$(interactive $h 'print -r -- "status=$?"')" "status=0"
  check "real OMZ: every shared function is defined"   all_functions $h
  check "real OMZ: gb is our function"                 same "$(interactive $h 'whence -w gb')" "gb: function"
  check "real OMZ: ll is ours"                         ours_ll "$(interactive $h 'alias ll')"
else
  print "skip - real Oh My Zsh checks (set OMZ_SRC to an ohmyzsh checkout)"
fi

print
if (( fails )); then print "$fails check(s) failed"; exit 1; fi
print "all checks passed"
