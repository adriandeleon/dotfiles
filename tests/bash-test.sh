#!/usr/bin/env bash
# tests/bash-test.sh - exercise install.sh --link and the bash config in
# throwaway HOME directories. Never installs packages; never touches your real
# HOME (every shell runs under `env -i`). Linux only. Run from anywhere:
#   ./tests/bash-test.sh
# Set OMB_SRC to an Oh My Bash checkout to also test against the real framework.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BEGIN="# >>> dotfiles (managed by install.sh) >>>"
END="# <<< dotfiles (managed by install.sh) <<<"
SKEL=/etc/skel/.bashrc
TEST_PATH="/usr/local/bin:/usr/bin:/bin"
FUNCS="up mkcd gb fh ovim dothelp cdf vimf extract"
FAILS=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILS=$((FAILS + 1)); }
check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}

# new_home <name> - a fresh HOME with Debian's stock ~/.bashrc (if present).
new_home() {
  local h="$WORK/$1"
  mkdir -p "$h"
  if [ -r "$SKEL" ]; then cp "$SKEL" "$h/.bashrc"; else : > "$h/.bashrc"; fi
  echo "$h"
}
# fake_omb <home> - a stand-in for Oh My Bash that, like the real one, defines
# aliases clashing with ours (and a cd alias that would leak into functions).
fake_omb() {
  mkdir -p "$1/.oh-my-bash"
  cat > "$1/.oh-my-bash/oh-my-bash.sh" <<'EOF'
OMB_VERSION=fake
FAKE_OMB_LOADS=$(( ${FAKE_OMB_LOADS:-0} + 1 ))
alias ll='ls -lh'
alias la='ls -lhA'
alias cd='echo fake-cd'
# Defined at framework load time, like Oh My Bash's own functions: if our
# aliases were already active here, `mkdir` would be baked in as `mkdir -p`.
function fake_omb_fn { mkdir "$1"; }
EOF
}
clean_env() { env -i HOME="$1" PATH="$TEST_PATH" TERM=dumb USER="${USER:-test}" "${@:2}"; }
link() { clean_env "$1" "${2:-$REPO}/install.sh" --link >"$1/install.log" 2>&1; }
count() { grep -cxF "$2" "$1" || true; }
# interactive <home> <commands> - stdout of an interactive bash fed <commands>
# on stdin, the way a terminal would (the prompt goes to stderr).
interactive() { printf '%s\n' "$2" | clean_env "$1" timeout -s KILL 20 bash -i 2>/dev/null; }
# startup_errors <home> - anything an interactive bash prints on stderr while
# loading its rc files, minus the "no job control" noise of having no tty.
startup_errors() {
  clean_env "$1" timeout -s KILL 20 bash -ic true 2>&1 >/dev/null \
    | grep -vE 'cannot set terminal process group|no job control in this shell' || true
}
# all_functions <home> - every name in $FUNCS is defined as a shell function
# (declare -F, not type -t: an alias of the same name would hide the function
# from type -t, though the function is still defined).
all_functions() {
  local out missing
  # shellcheck disable=SC2016  # expanded by the shell under test
  out="$(interactive "$1" 'for f in '"$FUNCS"'; do if declare -F "$f" >/dev/null; then echo "$f=function"; else echo "$f=missing"; fi; done')"
  missing="$(grep -v '=function$' <<<"$out")"
  [ -n "$out" ] && [ -z "$missing" ] || { printf '       not functions: %s\n' "$missing"; return 1; }
}
absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
ours_ll() { grep -Eq "^alias ll='(eza --icons -lah|ls -lah)" <<<"$1"; }
no_output() { [ -z "$1" ] || { printf '       got: %s\n' "$1"; return 1; }; }

# --- Fresh install, then a re-run -------------------------------------------
h="$(new_home fresh)"
seq 5000 > "$h/.bash_history"
link "$h"
check "fresh: block appended once"           [ "$(count "$h/.bashrc" "$BEGIN")" = 1 ]
check "fresh: ~/.bash_aliases links to repo" [ "$(readlink "$h/.bash_aliases")" = "$REPO/shell/aliases.sh" ]
check "fresh: ~/.config/emacs links to repo" [ "$(readlink "$h/.config/emacs")" = "$REPO/emacs" ]
check "fresh: the linked config has init.el" [ -f "$h/.config/emacs/init.el" ]
if [ -r "$SKEL" ] && grep -qx 'HISTFILESIZE=2000' "$SKEL"; then
  check "fresh: stock HISTFILESIZE=2000 commented out" [ "$(count "$h/.bashrc" 'HISTFILESIZE=2000')" = 0 ]
fi
backups_before="$(find "$h" -name '*.backup.*' | wc -l)"
link "$h"
check "re-run: still one block"              [ "$(count "$h/.bashrc" "$BEGIN")" = 1 ]
check "re-run: no new backup"                [ "$(find "$h" -name '*.backup.*' | wc -l)" = "$backups_before" ]
check "re-run: reports no warnings"          grep -q 'Done\.' "$h/install.log"

# --- Interactive bash on top of the stock ~/.bashrc --------------------------
out="$(interactive "$h" 'echo "status=$?"')"
check "first prompt sees a success status"   grep -qx 'status=0' <<<"$out"
check "history file kept all 5000 lines"     [ "$(head -n 5000 "$h/.bash_history" | wc -l)" = 5000 ]
check "startup prints no errors"             no_output "$(startup_errors "$h")"
check "every shared function is defined"     all_functions "$h"
out="$(interactive "$h" 'type mkcd')"
check "mkcd body uses plain mkdir/cd"        grep -q 'command mkdir -p -- "\$1" && builtin cd' <<<"$out"
check "ll comes from shell/aliases.sh"       ours_ll "$(interactive "$h" 'alias ll')"
out="$(interactive "$h" 'alias ls')"
check "ls stays the real ls (not eza)"       grep -q "^alias ls='ls " <<<"$out"
out="$(interactive "$h" 'dothelp >/dev/null && echo dothelp-ok; type -t _dothelp_row || echo helpers-gone')"
check "dothelp runs and cleans up helpers"   [ "$out" = "$(printf 'dothelp-ok\nhelpers-gone')" ]
echo 'export EDITOR=nano' > "$h/.shell.local"
# git ignores VISUAL when TERM is dumb (the default in these sessions).
out="$(interactive "$h" 'TERM=xterm git var GIT_EDITOR')"
check "EDITOR from ~/.shell.local reaches git" [ "$out" = nano ]
rm -f "$h/.shell.local"
out="$(interactive "$h" '. ~/.bashrc; echo "reloaded status=$?"')"
check "re-sourcing ~/.bashrc works"          grep -qx 'reloaded status=0' <<<"$out"

# --- Under a framework that defines clashing aliases -------------------------
h="$(new_home fake-omb)"
fake_omb "$h"
link "$h"
check "fake OMB: ll is ours, not the framework's" ours_ll "$(interactive "$h" 'alias ll')"
out="$(interactive "$h" 'type mkcd cdf up')"
check "fake OMB: its cd alias isn't baked into functions" [ "$(grep -c fake-cd <<<"$out")" = 0 ]
out="$(interactive "$h" 'type fake_omb_fn')"
check "fake OMB: our aliases don't leak into its functions" grep -q '^ *mkdir "\$1"' <<<"$out"
out="$(interactive "$h" 'echo "loads=$FAKE_OMB_LOADS plugins=${plugins+set}"')"
check "fake OMB: loaded once, generic arrays unset" [ "$out" = "loads=1 plugins=" ]
echo 'DOTFILES_NO_FRAMEWORK=1' > "$h/.bashrc.tmp"
cat "$h/.bashrc" >> "$h/.bashrc.tmp" && mv "$h/.bashrc.tmp" "$h/.bashrc"
out="$(interactive "$h" 'echo "loads=${FAKE_OMB_LOADS:-0}"')"
check "DOTFILES_NO_FRAMEWORK=1 skips the framework" [ "$out" = "loads=0" ]

if [ -n "${OMB_SRC:-}" ] && [ -r "$OMB_SRC/oh-my-bash.sh" ]; then
  h="$(new_home real-omb)"
  ln -s "$OMB_SRC" "$h/.oh-my-bash"
  link "$h"
  out="$(interactive "$h" 'echo "status=$?"')"
  check "real OMB: first prompt sees a success status" grep -qx 'status=0' <<<"$out"
  check "real OMB: startup prints no errors"           no_output "$(startup_errors "$h")"
  check "real OMB: every shared function is defined"   all_functions "$h"
  check "real OMB: ll is ours"                         ours_ll "$(interactive "$h" 'alias ll')"
  out="$(interactive "$h" 'type mkcd')"
  check "real OMB: mkcd uses builtin cd"               grep -q 'builtin cd' <<<"$out"
else
  echo "skip - real Oh My Bash checks (set OMB_SRC to an oh-my-bash checkout)"
fi

# --- An alias that shares a function's name must not break functions.sh ------
h="$(new_home collide)"
printf "alias extract='echo x'\nalias up='cd ..'\nalias dothelp='echo x'\n" >> "$h/.bashrc"
link "$h"
check "functions load despite clashing aliases" all_functions "$h"

# --- Old-style block from a moved checkout is updated in place ---------------
h="$(new_home moved)"
cat >> "$h/.bashrc" <<EOF
$BEGIN
export DOTFILES="/old/place"
[ -r "/old/place/bash/bashrc" ] && . "/old/place/bash/bashrc"
$END
export AFTER_BLOCK=1
EOF
link "$h"
check "moved: block points at this checkout" grep -qxF "export DOTFILES=\"$REPO\"" "$h/.bashrc"
check "moved: old path gone"                 [ "$(grep -c /old/place "$h/.bashrc")" = 0 ]
check "moved: still one block"               [ "$(count "$h/.bashrc" "$BEGIN")" = 1 ]
check "moved: lines after the block stay after it" \
  [ "$(tail -n 1 "$h/.bashrc")" = "export AFTER_BLOCK=1" ]

# --- Lines after the block that change PATH get a hint -----------------------
h="$(new_home late)"
link "$h"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$h/.bashrc"
link "$h"
check "late PATH line after the block is pointed out" grep -q 'come after the dotfiles block' "$h/install.log"

# --- Damaged markers: leave the file alone -----------------------------------
h="$(new_home damaged)"
printf '%s\nexport DOTFILES="/old"\nexport KEEP_ME=1\n' "$BEGIN" >> "$h/.bashrc"
cp "$h/.bashrc" "$WORK/damaged.orig"
link "$h"
check "damaged: rc file unchanged"           cmp -s "$h/.bashrc" "$WORK/damaged.orig"
check "damaged: run reports a warning"       grep -q 'warning(s)' "$h/install.log"

# --- An existing personal aliases file is kept, loaded, and wins -------------
h="$(new_home own-aliases)"
printf "alias myalias='echo mine'\nalias ll='echo my-ll'\n" > "$h/.bash_aliases"
link "$h"
check "own aliases: file kept as-is"         [ ! -L "$h/.bash_aliases" ]
out="$(interactive "$h" 'alias ll myalias')"
check "own aliases: they win over the repo's" grep -q "echo my-ll" <<<"$out"
check "own aliases: still loaded"            grep -q "echo mine" <<<"$out"

# --- ~/.bashrc symlinked into the repo: refuse, and never recurse ------------
copy="$WORK/repo-copy"
mkdir -p "$copy" && cp -R "$REPO/." "$copy/"
cp "$copy/bash/bashrc" "$WORK/bashrc.orig"
h="$WORK/symlinked"; mkdir -p "$h"
ln -s "$copy/bash/bashrc" "$h/.bashrc"
link "$h" "$copy"
check "symlinked rc: repo's bash/bashrc unchanged" cmp -s "$copy/bash/bashrc" "$WORK/bashrc.orig"
check "symlinked rc: run reports a warning"        grep -q 'links into this repo' "$h/install.log"
# Even if the block ends up in there anyway, a shell must still start.
printf '%s\nexport DOTFILES="%s"\nif [ -r "%s/bash/bashrc" ]; then . "%s/bash/bashrc"; fi\n%s\n' \
  "$BEGIN" "$copy" "$copy" "$copy" "$END" >> "$copy/bash/bashrc"
out="$(interactive "$h" 'echo started')"
check "self-including rc still starts a shell"     [ "$out" = started ]

# --- rc files the installer can't write: warn, don't abort -------------------
if [ "$(id -u)" -ne 0 ]; then
  h="$(new_home readonly)"
  chmod 444 "$h/.bashrc"
  link "$h"; status=$?
  check "read-only rc: install exits 0"        [ "$status" = 0 ]
  check "read-only rc: warns with the lines to add" grep -q "isn't writable" "$h/install.log"
  check "read-only rc: aliases still linked"   [ -L "$h/.bash_aliases" ]
  chmod 644 "$h/.bashrc"
else
  echo "skip - read-only rc checks (running as root)"
fi
h="$WORK/dangling"; mkdir -p "$h"
ln -s "$WORK/does-not-exist" "$h/.bashrc"
link "$h"; status=$?
check "dangling rc symlink: install exits 0" [ "$status" = 0 ]
check "dangling rc symlink: warns"           grep -q 'broken symlink' "$h/install.log"

# --- Emacs config link -------------------------------------------------------
# An existing ~/.emacs.d takes precedence over ~/.config/emacs: don't link.
h="$(new_home own-emacs-d)"
mkdir -p "$h/.emacs.d"
link "$h"
check "own ~/.emacs.d: no ~/.config/emacs link" absent "$h/.config/emacs"
check "own ~/.emacs.d: summary says why"     grep -q 'Emacs would load your' "$h/install.log"
# An existing ~/.config/emacs of your own is kept.
h="$(new_home own-config-emacs)"
mkdir -p "$h/.config/emacs" && echo ';; mine' > "$h/.config/emacs/init.el"
link "$h"
check "own ~/.config/emacs: not replaced"    [ ! -L "$h/.config/emacs" ]
check "own ~/.config/emacs: contents kept"   grep -q mine "$h/.config/emacs/init.el"
# A link left behind by a checkout that has since moved is re-pointed.
h="$(new_home emacs-moved)"
mkdir -p "$h/.config" && ln -s "$WORK/old-checkout/emacs" "$h/.config/emacs"
link "$h"
check "moved checkout: emacs link re-pointed" [ "$(readlink "$h/.config/emacs")" = "$REPO/emacs" ]
# Anything else that ~/.config/emacs links to is somebody else's: keep it.
h="$(new_home emacs-other-link)"
mkdir -p "$h/elsewhere/emacs" "$h/.config" && ln -s "$h/elsewhere/emacs" "$h/.config/emacs"
link "$h"
check "other emacs link: kept"               [ "$(readlink "$h/.config/emacs")" = "$h/elsewhere/emacs" ]

# --- Messages ----------------------------------------------------------------
h="$(new_home minimal-link)"
clean_env "$h" "$REPO/install.sh" --minimal --link >"$h/install.log" 2>&1
check "--minimal --link doesn't claim to install packages" \
  [ "$(grep -c 'Minimal install' "$h/install.log")" = 0 ]

# --- Unsafe checkout paths are refused ---------------------------------------
bad="$WORK/bad\$dir"
mkdir -p "$bad" && cp -R "$REPO/." "$bad/"
h="$(new_home badpath)"
if link "$h" "$bad"; then
  fail "checkout path with \$ is refused"
else
  pass "checkout path with \$ is refused"
fi
check "badpath: rc file untouched"           [ "$(count "$h/.bashrc" "$BEGIN")" = 0 ]

echo
if [ "$FAILS" -gt 0 ]; then echo "$FAILS check(s) failed"; exit 1; fi
echo "all checks passed"
