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
scripts/gen-theme.py           # rewrite the generated copies
scripts/gen-theme.py --check   # fail if those copies are stale
```

One palette, not four: edit `theme.lua`, run the script, and kitty, the shell
prompt, fuzzel, yazi, mako, GTK, Qt and Firefox all follow, and the lock screen reads
`Theme.qml` directly. The
prompt is ours as well — `config/zsh/prompt.zsh`, with `ZSH_THEME=""` in
`.zshrc` so oh-my-zsh contributes its plugins and completion but not its looks.

Firefox is the one tree that is not linked into `~/.config`: its profile lives
under `~/.config/mozilla/firefox/<id>/` and that id is machine state.
`scripts/install.sh` reads the default profile from `profiles.ini` and links
`config/firefox/user.js` and `chrome/*.css` into it (`palette.css` is generated;
the rules are `userChrome.css` and `userContent.css`). Firefox only reads them
when `toolkit.legacyUserProfileCustomizations.stylesheets` is on, which
`user.js` sets, so **restart Firefox once** after the first install.

The cursor and icons are ready-made rather than generated: `simp1e-amber` (a gold
cursor, in both hyprcursor and xcursor) and `Adwaita-yellow` (Adwaita with the
folders and places recoloured to the accent). Both are AUR packages — see
`packages.txt`.

Wallpapers live in `images/wallpapers/`, each one with its source and licence in
the `CREDITS.md` beside it: everything committed there is CC0 or public domain,
because this repository is public.

## Keys

Most things are `SUPER` plus one key; the laptop's own volume, brightness and
Wi-Fi keys work too. This is the whole set so far — it grows with each
component.

| Key | What it does |
| --- | --- |
| `SUPER + Q` | new terminal (kitty) |
| `SUPER + Space` | application launcher (Quickshell) |
| `SUPER + E` | file manager (yazi) |
| `SUPER + L` | lock the screen (Quickshell) |
| volume keys | up / down in 5% steps, mute |
| brightness keys | up / down in 5% steps |
| media keys | play / pause, next, previous (playerctl) |
| `SUPER + N` | toggle Wi-Fi (the laptop's own Wi-Fi key also works) |
| `SUPER + V` | clipboard history (fuzzel over cliphist) |
| `SUPER + Escape` | session menu: lock, log out, suspend, reboot, power off |
| `SUPER + 1..0` | switch to workspace 1-10 |
| `SUPER + Shift + 1..0` | move the focused window to workspace 1-10 |
| `SUPER + scroll` | previous / next existing workspace |
| `Print` | screenshot the whole screen |
| `SUPER + Shift + A` | screenshot an area you drag over |
| `SUPER + Shift + W` | screenshot the focused window |
| `SUPER + C` | close the focused window |
| `SUPER + M` | end the session and return to the TTY |

Screenshots are saved to `~/Pictures/Screenshots` and copied to the clipboard, so
they can be pasted straight into a chat.

The launcher is our own Quickshell panel (`config/quickshell/Launcher.qml`): it
searches `DesktopEntries` by name, generic name, comment and keywords, with
keyboard selection. `fuzzel` stays installed and is still the dmenu behind the
clipboard history and the session menu.

**Calendar events.** The control centre's month grid computes Spain's national
holidays (the fixed dates plus Good Friday) and marks any day listed in
`~/.local/share/calendar/events.json`, a date → text map you maintain:

```json
{ "2026-12-24": "Nochebuena", "2026-12-25": "Comida en casa" }
```

It is user data and stays untracked; regional and local holidays belong there
too. When today has an event, the notification centre sends one "Today" toast at
startup and on the first check of a new day.

## Lock screen

`SUPER + L`, `hypridle` and the session menu all run
`config/hypr/scripts/lock`, which starts a **separate** Quickshell process
(`quickshell -p ~/.config/quickshell/lock.qml`). Separate is deliberate: a bar
reload would destroy the session lock, and the compositor then keeps the session
hidden behind a solid colour by design. The screen shows the wallpaper blurred and
dimmed, the serif clock, the seal and a PAM password field
(`config/quickshell/pam/password.conf`, `auth required pam_unix.so`); `flock`
makes a second invocation a no-op. The entrance and the unlock fade are in
`LockSurface.qml` / `LockContext.qml`.

`hyprlock` stays installed with its config and generated theme as a fallback: run
`hyprlock` by hand if the Quickshell lock ever breaks.

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

**The idle daemon is a systemd user service too.** `hypridle` locks the session
after a period of inactivity and locks it again before the machine sleeps; the
Quickshell lock (`config/hypr/scripts/lock`) is what it launches. Same one-time
enable as hyprpaper:

```bash
systemctl --user enable --now hypridle.service
```

**Notifications.** The Quickshell shell owns `org.freedesktop.Notifications` now
(`NotificationServer` in `config/quickshell/`): toasts top right, a history
behind the bell in the bar, and do-not-disturb in that history. Two daemons
cannot share the bus name, so mako's unit has to be **stopped and disabled**
while the bar runs. mako stays installed, with its generated theme and unit in
the repo, as the fallback if the centre is ever turned off:

```bash
systemctl --user stop mako.service
systemctl --user disable mako.service
```

**Privilege prompts need an agent.** `polkitd` runs as a system service, but
nothing can actually ask you for a password without a per-session agent.
`polkit-gnome` ships no unit either, so this repo carries one:

```bash
systemctl --user enable --now polkit-gnome.service
```

The portals (`xdg-desktop-portal` and its backends) need no enabling: D-Bus
starts them on demand, and which backend serves an interface is decided by
`UseIn` in `/usr/share/xdg-desktop-portal/portals/`.

**The cursor and icon theme reach the portal through GSettings**, and that is
dconf state (a binary file), so it is set once here rather than symlinked:

```bash
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita-yellow'
gsettings set org.gnome.desktop.interface cursor-theme 'simp1e-amber'
gsettings set org.gnome.desktop.interface cursor-size 24
```

GTK and Qt get the same values from their tracked config files
(`gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `qt6ct/qt6ct.conf`), and Hyprland
from `hyprland.lua`.

**The bar is a systemd user service too.** Quickshell draws it from
`config/quickshell/` (QML), and like mako and hypridle it ships no unit, so this
repo carries one:

```bash
systemctl --user enable --now quickshell.service
```

**Night light is `hyprsunset`.** Its package ships the user unit (unlike
quickshell or mako), so it only needs enabling once. The control centre toggles
it through `hyprctl hyprsunset temperature` / `identity`:

```bash
systemctl --user enable --now hyprsunset.service
```

**Bluetooth is a system service.** `bluez` provides the daemon, and this laptop
had the adapter present but soft-blocked. Enable it once, and clear the block if
it is still set:

```bash
sudo systemctl enable --now bluetooth.service
sudo rfkill unblock bluetooth
```

**The home directories are created once**, so `~/Documents`, `~/Downloads` and
the rest exist and every program agrees on where they are:

```bash
xdg-user-dirs-update
```

The `~/.config/user-dirs.dirs` it writes is deliberately **not** in this repo:
the tool rewrites that file in place, and through a symlink it would write into
the repository itself.

**paru is the AUR helper, built once by hand.** It cannot come from pacman, so
it is the one tool this repo cannot list in `packages.txt`:

```bash
git clone https://aur.archlinux.org/paru.git
cd paru && makepkg -si
```

`paru-bin` is deliberately not used: its prebuilt binary links against
`libalpm.so.15` while this system ships `.16` (pacman 7.1), so it exits with
`cannot open shared object file`. `config/paru/paru.conf` includes
`/etc/paru.conf` first — paru reads one file, it does not merge them — and then
enables `RemoveMake`, so a build's toolchain does not stay installed.

Work in progress.
