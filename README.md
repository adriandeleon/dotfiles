# dotfiles

Personal shell configuration shared between **bash on Debian** and **zsh on
macOS**, plus a one-shot installer that sets up the same CLI tools on both
(Homebrew on macOS, apt on Debian).

The idea: aliases, environment variables, and functions live once in
`shell/` as POSIX-compatible scripts. Both `bash/bashrc` and `zsh/zshrc` source
them, so the day-to-day experience is identical regardless of the shell. Each
of those keeps only the genuinely shell-specific bits (the Oh My Bash/Zsh
framework + agnoster theme). The installer **appends** them to your existing
`~/.bashrc` / `~/.zshrc` rather than replacing those files.

> Already set up? Run **`dothelp`** in any bash or zsh session for a cheat-sheet
> of the aliases, functions, fzf helpers, and tools this config adds.

## What you get

- **Shared shell config** for bash (Debian) and zsh (macOS) — the same aliases,
  environment, and functions in both, from POSIX scripts under `shell/`.
- **Oh My Bash / Oh My Zsh** with the **agnoster** theme and the **JetBrains
  Mono Nerd Font** for the prompt glyphs.
- **[SDKMAN](https://sdkman.io/)** for managing JVM SDKs (`sdk install …`).
- A curated **CLI toolset**, installed via apt or Homebrew:
  - *search & files:* ripgrep (`rg`), fd, bat, fzf, eza, tree, mc, ncdu, duf
  - *system:* htop, btop, fastfetch, tmux
  - *network:* nmap, ncat
  - *editors:* neovim, emacs, jed
  - *other:* git, jq, zoxide (`z`), tldr, plus build/archive basics
- Handy **aliases, functions, and fzf helpers**, discoverable any time with
  **`dothelp`**.

Tested on **Debian 13 (trixie)** and **macOS**. A leaner subset is available via
`./install.sh --minimal` (see [Install](#install)).

## Layout

```
.
├── install.sh            # bootstrap: install packages + configure shells
├── packages/
│   ├── apt.txt           # CLI tools for Debian (apt)
│   ├── brew.txt          # the same CLI tools for macOS (Homebrew)
│   ├── apt-minimal.txt   # lean subset for `install.sh --minimal`
│   └── brew-minimal.txt  # …and its Homebrew counterpart
├── shell/                # shared, POSIX-compatible config
│   ├── common.sh         #   entry point sourced by both shells
│   ├── exports.sh        #   environment variables (EDITOR, PATH, history…)
│   ├── aliases.sh        #   aliases — linked to ~/.bash_aliases / ~/.zsh_aliases
│   └── functions.sh      #   functions (mkcd, extract, fzf helpers…)
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
   (installing Homebrew first on macOS if needed).
3. Installs [SDKMAN](https://sdkman.io/) (JVM SDK manager) via its own script
   if it isn't already present. It's wired up for both shells in
   `shell/common.sh`.
4. Clones the framework for your platform — [Oh My Bash](https://github.com/ohmybash/oh-my-bash)
   into `~/.oh-my-bash` on Debian, or [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)
   into `~/.oh-my-zsh` on macOS (the **agnoster** theme is enabled either way).
5. Installs the **JetBrains Mono Nerd Font** so the agnoster glyphs render: a
   Homebrew cask on macOS, or the Nerd Fonts release archive into
   `~/.local/share/fonts` on Debian (then refreshes the font cache).
6. **Adds the config to your existing rc file without replacing it.** For the
   platform's native shell (`~/.bashrc` on Debian, `~/.zshrc` on macOS) it backs
   up the file (timestamped copy) and appends a small managed include block that
   sources this repo's `bash/bashrc` / `zsh/zshrc`. Your original settings stay
   in place above the block.
7. **Links your aliases file to the conventional name** — `~/.bash_aliases` on
   Debian (sourced natively by the stock `~/.bashrc`) or `~/.zsh_aliases` on
   macOS — both pointing at `shell/aliases.sh`. Any existing file there is backed
   up first. Edit your aliases at that path or in the repo; it's the same file.
8. **Prints a summary** of exactly what it changed (and where it put backups).

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

`--minimal` installs just the core CLI tools from `packages/{apt,brew}-minimal.txt`
(git, curl, fzf, ripgrep, bat, eza, htop, btop, duf, nmap, ncat, tmux, jed, zip,
unzip, bash-completion) and still wires up your aliases/functions — but **skips**
SDKMAN, the Oh My Bash/Zsh framework, and the Nerd Font. Good for servers or
throwaway boxes where you just want the essentials.

It is safe to re-run; the include block is added only once and backups are
timestamped.

## Cheat-sheet

Once installed, run **`dothelp`** in any bash or zsh session to print a grouped
summary of the aliases, functions, fzf helpers, and tools this setup adds —
handy when you forget what's available.

## Customizing

- **Add a CLI tool to both platforms:** add it to `packages/apt.txt` *and*
  `packages/brew.txt` (mind the name differences — see below).
- **Add an alias:** edit `shell/aliases.sh` (a.k.a. `~/.bash_aliases` /
  `~/.zsh_aliases` — it's symlinked). Applies to both shells.
- **Add a function or export:** edit `shell/functions.sh` / `shell/exports.sh`.
  Applies to both shells automatically.
- **Machine-specific or secret settings:** put them in `~/.shell.local`. It's
  sourced at the end of `shell/common.sh` and is not tracked by git.

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
24.04. The installer runs a single `apt install` for the whole list, so on an
older release where one of these is missing apt installs **none** of them — drop
the unavailable packages from `packages/apt.txt` (or upgrade the release) and
re-run. The `ls`/`ll`/`la` aliases fall back to coloured `ls` when `eza` is
absent, so missing it isn't fatal to day-to-day use.
