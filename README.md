# dotfiles

Personal shell configuration shared between **bash on Debian** and **zsh on
macOS**, plus a one-shot installer that sets up the same CLI tools on both
(Homebrew on macOS, apt on Debian).

The idea: aliases, environment variables, and functions live once in
`shell/` as POSIX-compatible scripts. Both `~/.bashrc` and `~/.zshrc` source
them, so the day-to-day experience is identical regardless of the shell. Each
rc file only keeps the genuinely shell-specific bits (prompt, history options,
completion).

## Layout

```
.
├── install.sh            # bootstrap: install packages + symlink config
├── packages/
│   ├── apt.txt           # CLI tools for Debian (apt)
│   └── brew.txt          # the same CLI tools for macOS (Homebrew)
├── shell/                # shared, POSIX-compatible config
│   ├── common.sh         #   entry point sourced by both shells
│   ├── exports.sh        #   environment variables (EDITOR, PATH, history…)
│   ├── aliases.sh        #   aliases (ls/eza, git, navigation…)
│   └── functions.sh      #   functions (mkcd, extract, up…)
├── bash/
│   └── bashrc            # ~/.bashrc — bash-specific + sources shell/common.sh
└── zsh/
    └── zshrc             # ~/.zshrc — zsh-specific + sources shell/common.sh
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
3. Backs up any existing `~/.bashrc` / `~/.zshrc` and replaces them with
   symlinks into this repo. It also symlinks the repo to `~/.dotfiles` if you
   cloned it elsewhere.

Options:

```sh
./install.sh --link       # only (re)create symlinks, skip packages
./install.sh --packages   # only install packages, skip symlinks
./install.sh --help
```

It is safe to re-run; existing files are timestamped and backed up.

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
