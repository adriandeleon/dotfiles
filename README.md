# dotfiles

Personal shell configuration shared between **bash on Debian** and **zsh on
macOS**, plus a one-shot installer that sets up the same CLI tools on both
(Homebrew on macOS, apt on Debian).

The idea: aliases, environment variables, and functions live once in
`shell/` as scripts that run in both bash and zsh (POSIX sh apart from
`local` and the `function` keyword in `functions.sh`). Both `bash/bashrc` and `zsh/zshrc` source
them, so the day-to-day experience is identical regardless of the shell. Each
of those keeps only the genuinely shell-specific bits (the Oh My Bash/Zsh
framework + agnoster theme). The installer **appends** them to your existing
`~/.bashrc` / `~/.zshrc` rather than replacing those files.

> Already set up? Run **`dothelp`** in any bash or zsh session for a cheat-sheet
> of the aliases, functions, fzf helpers, and tools this config adds.

## What you get

- **Shared shell config** for bash (Debian) and zsh (macOS) — the same aliases,
  environment, and functions in both, from shared scripts under `shell/`.
- **Oh My Bash / Oh My Zsh** with the **agnoster** theme and the **JetBrains
  Mono Nerd Font** for the prompt glyphs.
- **[SDKMAN](https://sdkman.io/)** for managing JVM SDKs (`sdk install …`).
- A curated **CLI toolset**, installed via apt or Homebrew:
  - *search & files:* ripgrep (`rg`), fd, bat, fzf, eza, tree, mc, ncdu, duf
  - *system:* htop, btop, fastfetch, tmux
  - *network:* nmap, ncat
  - *editors:* neovim, emacs, jed
  - *other:* git, jq, zoxide (`z`), plus build/archive basics
- Handy **aliases, functions, and fzf helpers**, discoverable any time with
  **`dothelp`**.
- An **Emacs 31 config** in `emacs/`, linked to `~/.config/emacs`: tree-sitter
  modes, Eglot, Vertico/Consult/Corfu completion and Magit (see [Emacs](#emacs)).

Tested on **Debian 13 (trixie)** and **macOS**. A leaner subset is available via
`./install.sh --minimal` (see [Install](#install)).

## Layout

```text
.
├── install.sh            # bootstrap: install packages + configure shells
├── .shellcheckrc         # lint settings (CI: .github/workflows/lint.yml)
├── packages/
│   ├── apt.txt           # CLI tools for Debian (apt)
│   ├── brew.txt          # the same CLI tools for macOS (Homebrew)
│   ├── apt-minimal.txt   # lean subset for `install.sh --minimal`
│   └── brew-minimal.txt  # …and its Homebrew counterpart
├── shell/                # shared bash/zsh config
│   ├── common.sh         #   entry point sourced by both shells
│   ├── exports.sh        #   environment variables (EDITOR, PATH, history…)
│   ├── aliases.sh        #   aliases — linked to ~/.bash_aliases / ~/.zsh_aliases
│   └── functions.sh      #   functions (mkcd, extract, fzf helpers…)
├── emacs/                # Emacs 31 config — linked to ~/.config/emacs
│   ├── early-init.el     #   runs before the first frame (UI, GC)
│   └── init.el           #   everything else
├── tests/
│   ├── bash-test.sh      # install.sh --link + interactive bash, in temp HOMEs
│   └── zsh-test.zsh      # loads the shared config in zsh
├── bash/
│   └── bashrc            # Oh My Bash (agnoster) + sources shell/common.sh
└── zsh/
    └── zshrc             # Oh My Zsh (agnoster) + sources shell/common.sh
```

## Install

```sh
git clone https://github.com/adriandeleon/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The installer:

1. Detects the OS (macOS vs Debian).
2. Installs the packages from `packages/brew.txt` or `packages/apt.txt`
   (installing Homebrew first on macOS if needed; on Debian it uses `sudo`
   unless you're already root).
3. Installs [SDKMAN](https://sdkman.io/) (JVM SDK manager) via its own script
   if it isn't already present, telling it not to edit your rc files. It's
   wired up for both shells in `shell/common.sh`.
4. Clones the framework for your platform — [Oh My Bash](https://github.com/ohmybash/oh-my-bash)
   into `~/.oh-my-bash` on Debian, or [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)
   into `~/.oh-my-zsh` on macOS (the **agnoster** theme is enabled either way).
5. Installs the **JetBrains Mono Nerd Font** so the agnoster glyphs render: a
   Homebrew cask on macOS, or the Nerd Fonts release archive into
   `~/.local/share/fonts` on Debian (checked against a pinned SHA-256, then
   the font cache is refreshed).
6. **Adds the config to your existing rc file without replacing it.** For the
   platform's native shell (`~/.bashrc` on Debian, `~/.zshrc` on macOS) it backs
   up the file (timestamped copy) and appends a small managed include block that
   sources this repo's `bash/bashrc` / `zsh/zshrc`. Your original settings stay
   in place above the block. If your rc file already loads Oh My Bash/Zsh or
   SDKMAN itself, they aren't loaded a second time.
7. **Links your aliases file to the conventional name** — `~/.bash_aliases` on
   Debian or `~/.zsh_aliases` on macOS — pointing at `shell/aliases.sh`, so you
   can edit the aliases at that path or in the repo (it's the same file). If you
   already have your own file there, it's **kept**: `shell/common.sh` loads it
   right after the repo's aliases, so yours take precedence. Either way the
   aliases load after Oh My Bash/Zsh, so they win over the framework's.
8. **Links `~/.config/emacs` to `emacs/`** (or `$XDG_CONFIG_HOME/emacs`). If
   you already have an Emacs config — `~/.emacs`, `~/.emacs.d` or your own
   `~/.config/emacs` — it's **kept** and nothing is linked (Emacs loads
   `~/.emacs` / `~/.emacs.d` first anyway; move yours aside and re-run
   `./install.sh --link` to switch).
9. **Prints a summary** of exactly what it changed (and where it put backups),
   and ends with a warning count if any step failed.

When it finishes, **reload your shell** to pick up the changes:

```sh
exec "$SHELL" -l    # or just open a new terminal
```

> **Font note:** the agnoster theme uses Powerline glyphs (arrows, branch
> symbol). The installer puts JetBrains Mono Nerd Font on the machine, but you
> still need to **select it as your terminal's font** for the glyphs to show.

Options:

```sh
./install.sh --minimal    # lean subset of packages + shell config only
./install.sh --link       # only configure the rc files, skip packages
./install.sh --packages   # only install packages, skip shell config
./install.sh --help
```

Options can be combined — e.g. `./install.sh --minimal --packages` installs only
the minimal package set.

`--minimal` installs just the core CLI tools from `packages/{apt,brew}-minimal.txt`
(git, curl, fzf, ripgrep, bat, eza, htop, btop, duf, nmap, ncat, tmux, jed, plus
zip, unzip and bash-completion on Debian) and still wires up your
aliases/functions — but **skips**
SDKMAN, the Oh My Bash/Zsh framework, and the Nerd Font. Good for servers or
throwaway boxes where you just want the essentials.

It is safe to re-run; the include block is added only once and backups are
timestamped. If you move the checkout, re-run `./install.sh --link` from the new
location and the include block is updated in place to point there. If the
block's marker lines have been edited or deleted, the installer leaves the rc
file alone and asks you to fix it by hand. The checkout path can't contain
`"`, `$`, backtick or backslash characters (it's written into your rc file).

`dothelp` only lists what's actually installed, so after `--minimal` it hides the
fd- and zoxide-based helpers.

## Cheat-sheet

Once installed, run **`dothelp`** in any bash or zsh session to print a grouped
summary of the aliases, functions, fzf helpers, and tools this setup adds —
handy when you forget what's available.

## Emacs

`emacs/` is a config for **Emacs 31.1**. It uses options that don't exist in
Emacs 30, which is what Debian 13's apt installs, so build or install 31
yourself. It works in GUI frames, terminal frames and under the daemon.

- Standard Emacs keys, the built-in **modus-vivendi** theme, and JetBrains Mono
  Nerd Font in GUI frames.
- **Vertico**, **Orderless**, **Marginalia** and **Consult** in the minibuffer;
  **Corfu** for completion at point — in terminal frames too, through Emacs
  31's TTY child frames.
- **Tree-sitter** modes for every language that has one. A missing grammar is
  built on first use, after asking (`treesit-auto-install-grammar`).
  `astro-ts-mode` handles `.astro` files and the built-in `markdown-ts-mode`
  handles `.md`.
- **Eglot** starts automatically for Java, TypeScript/JavaScript, Astro, JSON,
  YAML, Bash, Python and Dockerfiles.
- **Magit** on `C-x g`, code folding with fringe indicators, and
  `vc-auto-revert-mode` (buffers follow branch switches).

The first start downloads the packages from GNU ELPA, NonGNU ELPA and MELPA.
Everything Emacs writes at runtime (packages, grammars, history, `custom.el`,
backups) also lands in `emacs/`, and `emacs/.gitignore` keeps it out of git.

**Language servers** are installed outside Emacs: the npm ones
(`typescript-language-server`, `@astrojs/language-server`,
`vscode-langservers-extracted`, …) and **jdtls** for Java, which has to be on
your `PATH` (until it is, Eglot warns when you open a Java file). A daemon
started by systemd never reads your shell rc file, so the config itself adds
nvm's newest Node, SDKMAN's `current` candidates and `~/.local/bin` to Emacs's
`PATH`, and sets `JAVA_HOME` from SDKMAN.

**As a daemon:** a source build of Emacs installs a systemd user unit, so

```sh
systemctl --user enable --now emacs
```

then open frames with `emacsclient -c` (GUI) or `emacsclient -t` (terminal).

## Customizing

- **Add a CLI tool to both platforms:** add it to `packages/apt.txt` *and*
  `packages/brew.txt` (mind the name differences — see below).
- **Add an alias:** edit `shell/aliases.sh` (a.k.a. `~/.bash_aliases` /
  `~/.zsh_aliases` when the installer symlinked it). Applies to both shells.
  If you kept your own aliases file, add personal ones there instead.
- **Add a function:** edit `shell/functions.sh`, defining it as
  `function name { … }` (not `name() { … }`, which breaks if an alias of the
  same name exists) and using `command`/`builtin` for commands that might be
  aliased (`command mkdir`, `builtin cd`).
- **Add an export:** edit `shell/exports.sh`. Applies to both shells.
  `EDITOR`/`VISUAL`, `LESS` and `LANG` are only set if your rc file hasn't
  set them already.
- **Machine-specific or secret settings:** put them in `~/.shell.local`. It's
  sourced at the end of `shell/common.sh` and is not tracked by git.
- **Change the Emacs config:** edit `emacs/init.el`. Lisp files of your own can
  go in `emacs/user-lisp/`: Emacs 31 byte-compiles them and adds them to
  `load-path` at startup. Settings made with `M-x customize` go to
  `emacs/custom.el`, which isn't tracked.

### Package name differences

A few tools have different names per platform; the shared aliases paper over
the binary-name differences:

| Tool | Homebrew             | apt       | Binary on Debian | Alias            |
|------|----------------------|-----------|------------------|------------------|
| fd   | `fd`                 | `fd-find` | `fdfind`         | `fd` → `fdfind`  |
| bat  | `bat`                | `bat`     | `batcat`         | `bat` → `batcat` |
| mc   | `midnight-commander` | `mc`      | `mc`             | —                |
| ncat | (bundled with `nmap`)| `ncat`    | `ncat`           | —                |

`eza`, `btop`, and `fastfetch` are only packaged by apt on Debian 13+/Ubuntu
24.04. The installer runs a single `apt-get install` for the whole list, so on an
older release where one of these is missing apt installs **none** of them — drop
the unavailable packages from `packages/apt.txt` (or upgrade the release) and
re-run. The `ls`/`ll`/`la` aliases fall back to coloured `ls` (and `lt` to
`tree`) when `eza` is absent, so missing it isn't fatal to day-to-day use.

## Tests

`./tests/bash-test.sh` runs `install.sh --link` in throwaway home directories
(fresh install, re-run, moved checkout, damaged markers, your own aliases file
or Emacs config)
and checks an interactive bash on top of the stock `~/.bashrc`. It never installs
packages or touches your real home directory. `zsh tests/zsh-test.zsh` loads the
shared config in zsh. CI runs both, plus shellcheck and syntax checks, on every
pull request.
