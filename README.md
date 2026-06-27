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

## Layout

```
.
├── install.sh            # bootstrap: install packages + configure shells
├── packages/
│   ├── apt.txt           # CLI tools for Debian (apt)
│   └── brew.txt          # the same CLI tools for macOS (Homebrew)
├── shell/                # shared, POSIX-compatible config
│   ├── common.sh         #   entry point sourced by both shells
│   ├── exports.sh        #   environment variables (EDITOR, PATH, history…)
│   ├── aliases.sh        #   aliases (ls/eza, git, navigation…)
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
4. Clones [Oh My Bash](https://github.com/ohmybash/oh-my-bash) and
   [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) into `~/.oh-my-bash` and
   `~/.oh-my-zsh` (the **agnoster** theme is enabled for both).
5. Installs the **JetBrains Mono Nerd Font** so the agnoster glyphs render: a
   Homebrew cask on macOS, or the Nerd Fonts release archive into
   `~/.local/share/fonts` on Debian (then refreshes the font cache).
6. **Adds the config to your existing rc files without replacing them.** It
   backs up `~/.bashrc` / `~/.zshrc` (timestamped copy) and appends a small
   managed include block that sources this repo's `bash/bashrc` / `zsh/zshrc`.
   Your original settings stay in place above the block.

> **Font note:** the agnoster theme uses Powerline glyphs (arrows, branch
> symbol). The installer puts JetBrains Mono Nerd Font on the machine, but you
> still need to **select it as your terminal's font** for the glyphs to show.

Options:

```sh
./install.sh --link       # only configure the rc files, skip packages
./install.sh --packages   # only install packages, skip shell config
./install.sh --help
```

It is safe to re-run; the include block is added only once and backups are
timestamped.

## Customizing

- **Add a CLI tool to both platforms:** add it to `packages/apt.txt` *and*
  `packages/brew.txt` (mind the name differences — see below).
- **Add an alias/function/export:** edit the relevant file in `shell/`. It
  applies to both shells automatically.
- **Machine-specific or secret settings:** put them in `~/.shell.local`. It's
  sourced at the end of `shell/common.sh` and is not tracked by git.

### Package name differences

A few tools have different names per platform; the shared aliases paper over
the binary-name differences:

| Tool | Homebrew | apt        | Binary on Debian | Alias              |
|------|----------|------------|------------------|--------------------|
| fd   | `fd`     | `fd-find`  | `fdfind`         | `fd` → `fdfind`    |
| bat  | `bat`    | `bat`      | `batcat`         | `bat` → `batcat`   |
| ls+  | `eza`    | (fallback) | —                | falls back to `ls` |

`eza` isn't packaged on all Debian releases, so it's intentionally left out of
`apt.txt`; the `ls`/`ll`/`la` aliases fall back to coloured `ls` when `eza`
isn't present.
