#!/usr/bin/env zsh
# tests/zsh-test.zsh - load the shared config in zsh and check the things that
# have broken there before. Run from the repo root: zsh tests/zsh-test.zsh

fails=0
check() { # check <description> <status>
  if [ "$2" -eq 0 ]; then print -r -- "ok   - $1"; else print -r -- "FAIL - $1"; fails=$((fails + 1)); fi
}

# Aliases that share names with our functions must not break functions.sh
# (zsh refuses to define `name() {` when name is an alias).
alias up='cd ..'
alias extract='echo x'

DOTFILES=$PWD
. shell/common.sh
check "sourcing common.sh leaves a success status" $?

(( $+functions[gb] && $+functions[fh] && $+functions[ovim] && $+functions[dothelp] ))
check "functions are defined despite clashing aliases" $?
(( ! $+functions[cd] ))
check "no stray cd function from an alias clash" $?

unalias up
before=$PATH
cd /tmp && up 1
check "up changes directory" $?
[ "$PATH" = "$before" ]
check "up leaves PATH alone (zsh ties \`path\` to it)" $?

dothelp >/dev/null
check "dothelp runs" $?

if (( fails )); then print "$fails check(s) failed"; exit 1; fi
print "all checks passed"
