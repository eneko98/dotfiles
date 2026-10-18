# dotfiles

My Arch Linux desktop, built from a bare install — one component per commit.

Hyprland (Wayland) under uwsm · kitty · zsh + oh-my-zsh · fuzzel · yazi

## Layout

| Path | Purpose |
| --- | --- |
| `config/` | 1:1 mirror of `~/.config` — one folder per program |
| `scripts/` | installer, and later automation / animations |
| `images/` | wallpapers and other assets |
| `packages.txt` | every package this setup adds, in install order |

## Install

Packages first:

```bash
grep -vE '^\s*(#|$)' packages.txt | sudo pacman -S --needed -
```

Then the configs:

```bash
git clone https://github.com/eneko98/dotfiles ~/repos/dotfiles

~/repos/dotfiles/scripts/install.sh --dry-run   # preview what changes
~/repos/dotfiles/scripts/install.sh             # symlink config/ into ~/.config
```

The script only ever creates symlinks. It does not install packages, and it never
overwrites a real file — `~/.config` stays a normal directory, with only the files
that live in this repo linked into it.

## The theme

The colours are taken from the wallpaper, so the desktop and the image behind it
agree with each other.

`config/hypr/theme.lua` is the palette: nine named roles plus the sixteen ANSI
colours a terminal needs. Hyprland reads it directly — `hyprland.lua` requires it
for the window borders and the background colour.

Nothing else reads Lua, so the other copies are generated instead of hand-written:

```bash
scripts/gen-theme.py           # rewrite the copies for kitty, zsh and fuzzel
scripts/gen-theme.py --check   # fail if those copies are stale
```

One palette, not four: edit `theme.lua`, run the script, and the terminal colours,
the shell prompt and the launcher all follow. The prompt is ours as well —
`config/zsh/prompt.zsh`, with `ZSH_THEME=""` in `.zshrc` so oh-my-zsh contributes
its plugins and completion but not its looks.

Wallpapers live in `images/wallpapers/`, each one with its source and licence in
the `CREDITS.md` beside it: everything committed there is CC0 or public domain,
because this repository is public.

## Keys

Everything is `SUPER` plus one key. This is the whole set so far — it grows with
each component.

| Key | What it does |
| --- | --- |
| `SUPER + Q` | new terminal (kitty) |
| `SUPER + Space` | application launcher (fuzzel) |
| `SUPER + C` | close the focused window |
| `SUPER + M` | end the session and return to the TTY |

## Setup that lives outside the repo

A few things cannot be symlinked out of `config/`, because they have to exist
before the program reads its config, or because they are not configs at all.

**zsh has to be told where its config is.** zsh looks for `~/.zshrc` before
anything in this repo can get a word in, so `ZDOTDIR` is set one file earlier,
in `/etc/zsh/zshenv`:

```bash
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
```

That single line is the only reason `config/zsh/.zshrc` is read at all. Without
it, zsh quietly falls back to `$HOME`.

**oh-my-zsh is cloned, not installed.** It defaults to `~/.oh-my-zsh`, so it is
cloned into `XDG_DATA_HOME` instead:

```bash
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.local/share/oh-my-zsh
```

**The login shell** is changed with `usermod`:

```bash
sudo usermod -s /usr/bin/zsh "$USER"
```

**tty1 logs in automatically**, so a boot lands in the desktop instead of at a
login prompt. `getty`'s `ExecStart` is replaced by a drop-in, because the unit
itself belongs to systemd:

```ini
# /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --autologin eneko98 - ${TERM}
```

The bare `ExecStart=` is required — it clears the inherited command before the
new one is added. From there the login shell starts the session: zsh reads
`config/zsh/.zprofile`, which runs `uwsm check may-start` and execs the
compositor as a systemd user session (`wayland-wm@hyprland.desktop.service`,
pulled in with `graphical-session.target`). tty2 and above keep an ordinary
login prompt on purpose: that is the way back in if a config ever breaks the
session. To get the prompt back, remove the drop-in and reload:

```bash
sudo rm -r /etc/systemd/system/getty@tty1.service.d
sudo systemctl daemon-reload
```

**The wallpaper is a systemd user service.** `hyprpaper` ships a unit, and a unit
restarts if it crashes and shuts down with the session — a bare child process of
the compositor would do neither:

```bash
systemctl --user enable --now hyprpaper.service
```

Changing the wallpaper does not need a restart:

```bash
hyprctl hyprpaper wallpaper ', ~/pictures/whatever.png'
hyprctl hyprpaper listactive
```

The images themselves live in `images/wallpapers/`, each one with its source and
licence recorded in `CREDITS.md` beside it.

Work in progress.
