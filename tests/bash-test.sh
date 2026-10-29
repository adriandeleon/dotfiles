#!/usr/bin/env bash
# tests/bash-test.sh - exercise install.sh --link and the bash config in
# throwaway HOME directories. Never installs packages; never touches your real
# HOME. Run from anywhere: ./tests/bash-test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BEGIN="# >>> dotfiles (managed by install.sh) >>>"
SKEL=/etc/skel/.bashrc
FAILS=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILS=$((FAILS + 1)); }
check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}

new_home() { # new_home <name> - a fresh HOME with Debian's stock ~/.bashrc
  local h="$WORK/$1"
  mkdir -p "$h"
  if [ -r "$SKEL" ]; then cp "$SKEL" "$h/.bashrc"; else : > "$h/.bashrc"; fi
  echo "$h"
}
# XDG_CONFIG_HOME is cleared so the Emacs link lands in the temp HOME too.
link() { HOME="$1" XDG_CONFIG_HOME="" "$REPO/install.sh" --link >"$1/install.log" 2>&1; }
count() { grep -cxF "$2" "$1" || true; }
absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
# Run commands in an interactive bash fed on stdin, the way a terminal would.
interactive() { printf '%s\n' "$2" | HOME="$1" bash -i 2>/dev/null; }

# --- Fresh install, then a re-run -------------------------------------------
h="$(new_home fresh)"
link "$h"
check "fresh: block appended once"           [ "$(count "$h/.bashrc" "$BEGIN")" = 1 ]
check "fresh: ~/.bash_aliases links to repo" [ "$(readlink "$h/.bash_aliases")" = "$REPO/shell/aliases.sh" ]
check "fresh: ~/.config/emacs links to repo" [ "$(readlink "$h/.config/emacs")" = "$REPO/emacs" ]
check "fresh: the linked config has init.el" [ -f "$h/.config/emacs/init.el" ]
backups_before="$(find "$h" -name '*.backup.*' | wc -l)"
link "$h"
check "re-run: still one block"              [ "$(count "$h/.bashrc" "$BEGIN")" = 1 ]
check "re-run: no new backup"                [ "$(find "$h" -name '*.backup.*' | wc -l)" = "$backups_before" ]
check "re-run: reports no warnings"          grep -q 'Done\.' "$h/install.log"

# --- Interactive bash on top of the stock ~/.bashrc --------------------------
out="$(interactive "$h" 'echo "status=$?"')"
check "first prompt sees a success status"   grep -q 'status=0' <<<"$out"
out="$(interactive "$h" 'type -t up mkcd gb fh ovim dothelp | sort -u')"
check "shared functions are defined"         [ "$out" = "function" ]
out="$(interactive "$h" 'type mkcd')"
check "mkcd body uses plain mkdir/cd"        grep -q 'command mkdir -p -- "\$1" && builtin cd' <<<"$out"
out="$(interactive "$h" 'alias ll')"
check "ll comes from shell/aliases.sh"       grep -Eq "ll='(eza|ls) " <<<"$out"
out="$(interactive "$h" 'dothelp >/dev/null && echo dothelp-ok')"
check "dothelp runs"                         grep -q dothelp-ok <<<"$out"

# --- An alias that shares a function's name must not break functions.sh ------
h="$(new_home collide)"
printf "alias extract='echo x'\nalias up='cd ..'\n" >> "$h/.bashrc"
link "$h"
out="$(interactive "$h" 'type -t gb dothelp | sort -u')"
check "functions load despite clashing aliases" [ "$out" = "function" ]

# --- Old-style block from a moved checkout is updated in place ---------------
h="$(new_home moved)"
cat >> "$h/.bashrc" <<EOF
$BEGIN
export DOTFILES="/old/place"
[ -r "/old/place/bash/bashrc" ] && . "/old/place/bash/bashrc"
# <<< dotfiles (managed by install.sh) <<<
export AFTER_BLOCK=1
EOF
link "$h"
check "moved: block points at this checkout" grep -qxF "export DOTFILES=\"$REPO\"" "$h/.bashrc"
check "moved: old path gone"                 [ "$(grep -c /old/place "$h/.bashrc")" = 0 ]
check "moved: still one block"               [ "$(count "$h/.bashrc" "$BEGIN")" = 1 ]
check "moved: lines after the block stay after it" \
  [ "$(tail -n 1 "$h/.bashrc")" = "export AFTER_BLOCK=1" ]

# --- Damaged markers: leave the file alone -----------------------------------
h="$(new_home damaged)"
printf '%s\nexport DOTFILES="/old"\nexport KEEP_ME=1\n' "$BEGIN" >> "$h/.bashrc"
cp "$h/.bashrc" "$WORK/damaged.orig"
link "$h"
check "damaged: rc file unchanged"           cmp -s "$h/.bashrc" "$WORK/damaged.orig"
check "damaged: run reports a warning"       grep -q 'warning(s)' "$h/install.log"

# --- An existing personal aliases file is kept and still loaded --------------
h="$(new_home own-aliases)"
echo "alias myalias='echo mine'" > "$h/.bash_aliases"
link "$h"
check "own aliases: file kept as-is"         [ ! -L "$h/.bash_aliases" ]
out="$(interactive "$h" 'alias myalias')"
check "own aliases: still loaded"            grep -q "echo mine" <<<"$out"

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

# --- Unsafe checkout paths are refused ---------------------------------------
bad="$WORK/bad\$dir"
mkdir -p "$bad" && cp -R "$REPO/." "$bad/"
h="$(new_home badpath)"
if HOME="$h" "$bad/install.sh" --link >/dev/null 2>&1; then
  fail "checkout path with \$ is refused"
else
  pass "checkout path with \$ is refused"
fi
check "badpath: rc file untouched"           [ "$(count "$h/.bashrc" "$BEGIN")" = 0 ]

echo
if [ "$FAILS" -gt 0 ]; then echo "$FAILS check(s) failed"; exit 1; fi
echo "all checks passed"
