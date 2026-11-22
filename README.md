# dotfiles

Personal shell configuration shared between **bash on Debian** and **zsh on
macOS**, plus a one-shot installer that sets up the same CLI tools on both
(Homebrew on macOS, apt on Debian).

The idea: aliases, environment variables, and functions live once in
`shell/` as scripts that run in both bash and zsh (POSIX sh apart from `local`
and the `function` keyword in `functions.sh`). Both `bash/bashrc` and
`zsh/zshrc` source them, so the day-to-day experience is identical regardless
of the shell. Each of those keeps only the genuinely shell-specific bits (the
Oh My Bash/Zsh framework + agnoster theme). The installer **appends** them to
your existing `~/.bashrc` / `~/.zshrc` rather than replacing those files.

> Already set up? Run **`dothelp`** in any bash or zsh session for a cheat-sheet
> of the aliases, functions, fzf helpers, and tools this config adds, and
> **`dotdoctor`** when something seems off.

## What you get

- **Shared shell config** for bash (Debian) and zsh (macOS) — the same aliases,
  environment, and functions in both, from shared scripts under `shell/`.
- **Oh My Bash / Oh My Zsh** with the **agnoster** theme and the **JetBrains
  Mono Nerd Font** for the prompt glyphs.
- **[jkit](https://github.com/adriandeleon/jkit)** for installing and switching
  JDKs, Maven and Gradle (`jkit install jdk@21`, `jkit use jdk@21 --global`).
  On Debian it comes from the **[Vitrina](https://vitrina-project.dev)** apt
  repository, which the installer adds, so `apt upgrade` keeps it current.
- A curated **CLI toolset**, installed via apt or Homebrew:
  - *search & files:* ripgrep (`rg`), fd, bat, fzf, eza, tree, mc, ncdu, duf
  - *system:* htop, btop, fastfetch, tmux
  - *network:* nmap, ncat
  - *editors:* neovim, emacs, jed
  - *other:* git, jq, zoxide (`z`), plus build/archive basics
- Handy **aliases, functions, and fzf helpers**, discoverable any time with
  **`dothelp`**.
- A **doctor**, `dotdoctor`, that checks the setup and says how to fix what's
  off, and a **version** (`dothelp --version`) so you know which config a
  machine is running.

Tested on **Debian 13 (trixie)** and **macOS**. A leaner subset is available via
`./install.sh --minimal` (see [Install](#install)).

## Layout

```text
.
├── install.sh            # bootstrap: install packages + configure shells
├── VERSION               # the dotfiles version (see Versioning)
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
│   └── functions.sh      #   functions (mkcd, extract, fzf helpers, dothelp, dotdoctor…)
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

1. Prints its version and detects the OS (macOS vs Debian).
2. Installs the packages from `packages/brew.txt` or `packages/apt.txt`
   (installing Homebrew first on macOS if needed; on Debian it uses `sudo`
   unless you're already root — run the installer itself as yourself, not with
   `sudo`). If one package isn't available, it retries one package at a time
   so the rest still install, and lists the ones that failed. On Debian it
   then adds the [Vitrina](https://vitrina-project.dev) apt repository
   (`/etc/apt/sources.list.d/vitrina.sources`, with its signing key checked
   against a pinned SHA-256), unless a Vitrina source is already configured.
3. Installs [jkit](https://github.com/adriandeleon/jkit) (JDK / Maven / Gradle
   manager). On Debian it comes from Vitrina, so `apt upgrade` keeps it
   current. If Vitrina couldn't be added or its jkit is older than the pinned
   version (`JKIT_VERSION` in `install.sh`), and on macOS, it's downloaded from
   the GitHub release instead, checked against the release's SHA-256 sums: the
   `.deb` on Debian, or the binary into `~/.local/bin` on macOS (macOS 15+).
   It's skipped if the pinned version or a newer one is already installed, and
   an older one is upgraded. Its shell hook is loaded for both shells in
   `shell/common.sh`.
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
   the jkit hook *above* the block, they aren't loaded a second time. On
   Debian it also comments out the stock `HISTSIZE=1000` / `HISTFILESIZE=2000` lines:
   bash truncates your history file as soon as `HISTFILESIZE` is set, so with
   them in place the larger limits here could never take effect. It won't add
   the block to an rc file that is a symlink into this repo (it would load
   itself); if the rc file isn't writable, it prints the lines to add instead.
7. **Links your aliases file to the conventional name** — `~/.bash_aliases` on
   Debian or `~/.zsh_aliases` on macOS — pointing at `shell/aliases.sh`, so you
   can edit the aliases at that path or in the repo (it's the same file). If you
   already have your own file there, it's **kept**: `shell/common.sh` loads it
   right after the repo's aliases, so yours take precedence. Either way the
   aliases load after Oh My Bash/Zsh, so they win over the framework's.
8. **Prints a summary** of exactly what it changed (and where it put backups),
   and ends with a warning count if any step failed. It also points out lines
   *after* the block that change `PATH` or `PROMPT_COMMAND` or load the jkit
   hook, nvm or cargo (later installers often append those): tools they add
   aren't seen by the alias checks, and a `PROMPT_COMMAND=` assignment drops
   zoxide's hook. Move such lines above the block. `dotdoctor` checks for the
   same lines (and more) any time later.

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
./install.sh --version    # print the dotfiles version
./install.sh --doctor     # check the setup and say how to fix problems
./install.sh --help
```

Options can be combined — e.g. `./install.sh --minimal --packages` installs only
the minimal package set.

`--minimal` installs just the core CLI tools from `packages/{apt,brew}-minimal.txt`
(git, curl, fzf, ripgrep, bat, eza, htop, btop, duf, nmap, ncat, tmux, jed, plus
zip, unzip and bash-completion on Debian) and still wires up your
aliases/functions, but **skips** the Vitrina apt repository, jkit, the Oh My
Bash/Zsh framework, and the Nerd Font. Good for servers or throwaway boxes
where you just want the essentials.

It is safe to re-run; the include block is added only once and backups are
timestamped. If you move the checkout, re-run `./install.sh --link` from the new
location and the include block is updated in place to point there. If the
block's marker lines have been edited or deleted, the installer leaves the rc
file alone and asks you to fix it by hand. The checkout path can't contain
`"`, `$`, backtick or backslash characters (it's written into your rc file).

## Updating and removing

**Update:** pull, re-run the installer, and reload:

```sh
cd ~/.dotfiles && git pull && ./install.sh
exec "$SHELL" -l
dotdoctor           # optional: confirm everything loaded
```

Re-running is idempotent (see above); `./install.sh --link` is enough when only
the shell config changed. On Debian, `sudo apt upgrade` updates jkit (and any
other Vitrina packages) between runs.

**Remove:** there's no uninstaller, since nothing here replaces your files.
To undo it by hand:

1. Delete the lines from `# >>> dotfiles (managed by install.sh) >>>` to
   `# <<< dotfiles (managed by install.sh) <<<` in `~/.bashrc` / `~/.zshrc`
   (or restore one of the `.backup.<timestamp>` copies next to it).
2. Remove `~/.bash_aliases` / `~/.zsh_aliases` if it's the link to
   `shell/aliases.sh` (`ls -l` shows the target); a file of your own was never
   touched.
3. Optionally remove what the full install added: `~/.oh-my-bash` /
   `~/.oh-my-zsh`, `~/.local/share/fonts/JetBrainsMonoNerdFont`, jkit
   (`sudo apt remove jkit`, or `~/.local/bin/jkit` on macOS), and the Vitrina
   source (`/etc/apt/sources.list.d/vitrina.sources` and
   `/etc/apt/keyrings/vitrina.asc`).

## Cheat-sheet

Once installed, run **`dothelp`** in any bash or zsh session to print a grouped
summary of the aliases, functions, fzf helpers, and tools this setup adds —
handy when you forget what's available. It only lists what's actually
installed, so after `--minimal` it hides the fd-, zoxide- and jkit-based
helpers. `dothelp --version` prints just the version.

## Doctor

When something seems off, run **`dotdoctor`** in your shell (or
`./install.sh --doctor`, which runs it in a fresh one). It checks the setup and
prints one line per check — `ok`, `info`, `warn` or `fail` — with a `fix:` line
under anything that needs one, then a summary, in the same format as
`jkit doctor`:

```console
$ dotdoctor
ok    dotfiles 1.0.0 (4df2b00), in /home/me/.dotfiles
ok    /home/me/.bashrc loads this checkout
warn  lines after the include block in /home/me/.bashrc change PATH or PROMPT_COMMAND, or load tools
      fix: move these above the block:
        eval "$(jkit hook bash)"
ok    Oh My Bash loaded (theme agnoster)
ok    shared functions defined
ok    zoxide hook active
ok    jkit 0.2.2, shell hook loaded
1 warning, 0 problems
```

It looks at the include block (exactly one, pointing at this checkout), lines
after it that change `PATH`/`PROMPT_COMMAND` or load tools, Debian's stock
history limits, the aliases file, the framework, the shared functions and
aliases, core and optional tools, zoxide's hook, jkit (hook loaded, not older
than `JKIT_VERSION`), the Vitrina apt source, and the Nerd Font. It changes
nothing, uses no network, and exits 1 when a check fails.

## Versioning

The version lives in [`VERSION`](VERSION) ([semver](https://semver.org)).
`./install.sh --version` and `dothelp --version` print it with the git commit
(marked `-dirty` with uncommitted changes), e.g. `dotfiles 1.0.0 (4df2b00)`;
the installer also prints it as its first line, and `dothelp` in its header.
To release, bump `VERSION` in the pull request, then tag the merge commit
`vX.Y.Z`.

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
  `EDITOR`, `LESS` and `LANG` are only set if your rc file hasn't set them
  already; `VISUAL` is never set, so `EDITOR` decides.
- **Machine-specific or secret settings:** put them in `~/.shell.local`. It's
  sourced at the end of `shell/common.sh` (so it can override anything) and is
  not tracked by git. Add to `PROMPT_COMMAND` there rather than replacing it.
- **Use a different prompt framework** (starship, bash-it, prezto,
  powerlevel10k…): put `DOTFILES_NO_FRAMEWORK=1` in your rc file *above* the
  include block, and Oh My Bash/Zsh won't be loaded.
- **Don't symlink `~/.bashrc` / `~/.zshrc` to the files in this repo** (e.g.
  with GNU stow): the include block is what loads them.
- **Bump a pinned download:** downloads are checked against values pinned at
  the top of each step in `install.sh`. Change them together:
  `JKIT_VERSION` (checked against the release's own `SHA256SUMS`),
  `NERD_FONT_VERSION` + `NERD_FONT_SHA256` (from that release's
  `SHA-256.txt`), and `VITRINA_KEY_SHA256` if the Vitrina key is ever
  re-issued.

### Package name differences

A few tools have different names per platform; the shared aliases paper over
the binary-name differences:

| Tool | Homebrew             | apt       | Binary on Debian | Alias            |
|------|----------------------|-----------|------------------|------------------|
| fd   | `fd`                 | `fd-find` | `fdfind`         | `fd` → `fdfind`  |
| bat  | `bat`                | `bat`     | `batcat`         | `bat` → `batcat` |
| mc   | `midnight-commander` | `mc`      | `mc`             | —                |
| ncat | (bundled with `nmap`)| `ncat`    | `ncat`           | —                |

Some packages aren't available on older releases (for example `eza` or
`fastfetch` on Debian 12 or Ubuntu 24.04). One missing package makes a combined
`apt-get install` install nothing, so the installer then retries one package at
a time and lists what it couldn't install. `ls` is always the real `ls` (with
colour); `ll`/`la`/`lt` use eza when it's installed and fall back to `ls` (and
`lt` to `tree`) otherwise, so missing it isn't fatal to day-to-day use.

## Tests

`./tests/bash-test.sh` runs `install.sh --link` in throwaway home directories
(fresh install, re-run, moved checkout, damaged markers, your own aliases file,
a symlinked / read-only / dangling rc file) and checks interactive bash
sessions on top of the stock `~/.bashrc`, with a stand-in framework that defines
clashing aliases, plus the version output and `dotdoctor` (a healthy install
passes; a damaged rc file fails). `zsh tests/zsh-test.zsh` does the same for
zsh (on macOS it runs `install.sh` under the system `/bin/bash`). Both run
every shell under `env -i` with a temp `HOME`, so they never install packages
or touch your real home directory. Point `OMB_SRC` / `OMZ_SRC` at an Oh My Bash
/ Oh My Zsh checkout to also test against the real frameworks.

Before a pull request, the same lint CI runs:

```sh
shellcheck --severity=warning install.sh shell/*.sh bash/bashrc tests/bash-test.sh
```

No zsh on the machine? `podman run --rm -v "$PWD":/d:ro,Z docker.io/zshusers/zsh:5.9 zsh /d/tests/zsh-test.zsh`
runs the zsh tests in a container (`docker` works the same).

CI runs both test suites on Linux and the zsh/install test on macOS, plus
shellcheck and syntax checks, on every pull request.
