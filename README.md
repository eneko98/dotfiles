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

The script only creates symlinks and regenerates the palette's copies. It does not
install packages, and it never overwrites a real file — `~/.config` stays a normal
directory, with only the files that live in this repo (and the generated palette
copies) linked into it.

## The theme

The colours follow the wallpaper: pick one with **SUPER + W** and the palette is
re-derived from it, so the desktop and the image behind it agree.

`config/hypr/theme.lua` is the committed default: nine named roles plus the
sixteen ANSI colours a terminal needs. Hyprland reads it directly — `hyprland.lua`
requires it for the borders and the background — and, when a wallpaper has
generated one, the file returns `$XDG_STATE_HOME/dotfiles/palette.lua` instead of
its own values.

Nothing else reads Lua, so every other copy is generated:

```bash
scripts/extract-palette.py <wallpaper>   # derive a palette from an image
scripts/extract-palette.py --reset       # back to the committed default
scripts/gen-theme.py                     # rewrite the generated copies
scripts/gen-theme.py --check             # fail if those copies are stale
```

The copies live under `$XDG_STATE_HOME/dotfiles/theme/`, not in the repository,
because the palette is machine state: trying a wallpaper must not dirty the repo.
`scripts/install.sh` generates them and links each one to the fixed path its
program expects (kitty's `theme.conf`, `Theme.qml`, the GTK CSS and settings, the
Qt palette and config, the icon theme, the Firefox palette, …), so those programs
keep reading the paths they already know.

Hyprland and kitty reload live, and the bar reloads itself when `Theme.qml`
changes; GTK, Qt, Firefox, yazi, fuzzel and hyprlock read their theme at startup
(the icon variant included), so they pick it up when they next start. A full GUI
restart is the honest "apply everything".

After an `extract-palette.py --reset`, run `gen-theme.py` and then
`gsettings set org.gnome.desktop.interface icon-theme "$(cat
~/.local/state/dotfiles/theme/icon-theme)"` (or run
`config/hypr/scripts/wallpaper restore`, which does it) so the icons return to the
default's variant too.

`gold` and `teal` are role slots, not promises: their hues come from the
wallpaper. Red stays the reserved "something is wrong" colour, and the ANSI hues a
terminal needs stay fixed and contrast-checked — see `scripts/extract-palette.py`.
The prompt is ours as well — `config/zsh/prompt.zsh`, with `ZSH_THEME=""` in
`.zshrc` so oh-my-zsh contributes its plugins and completion but not its looks.

Firefox is the one tree that is not linked into `~/.config`: its profile lives
under `~/.config/mozilla/firefox/<id>/` and that id is machine state.
`scripts/install.sh` reads the default profile from `profiles.ini` and links
`config/firefox/user.js` and the two hand-written rules (`userChrome.css`,
`userContent.css`) into it, plus the generated `palette.css` from the state
dir. Firefox only reads them when
`toolkit.legacyUserProfileCustomizations.stylesheets` is on, which
`user.js` sets, so **restart Firefox once** after the first install.

The cursor is ready-made rather than generated: `Bibata-Modern-Ice`, a white
rounded pointer from the Bibata set. The package ships both hyprcursor and
xcursor; the hyprcursor build renders Ice in amber, so `cursor.enable_hyprcursor`
is false and the white xcursor copy is used. It is neutral on purpose: it has to
read on any palette the wallpaper generates.
`XCURSOR_THEME` also goes to the systemd user session
(`config/environment.d/cursor.conf`), because the bar and the idle daemon are
services and would otherwise fall back to Adwaita.

The icons do follow the accent: `gen-theme.py` maps the accent's hue to one of
the `Adwaita-*` variants from `adwaita-colors-icon-theme` (teal for the default
blue), writes it into the GTK settings, `qt6ct.conf` and fuzzel's include, and
writes `theme/icon-theme`; `install.sh` and the wallpaper script set the GSettings
value that the portal reads. App icons are their own, so this is the folder/place
colour, not a recolour of Firefox. Both cursor and icon packages are AUR — see
`packages.txt`.

There is one committed wallpaper, `images/wallpapers/default.png`: generated for
this repository from the palette, CC0, with the exact command in the `CREDITS.md`
beside it. Your own images live in `~/Pictures/Wallpapers` and stay untracked;
the picker lists both.

## Keys

Most things are `SUPER` plus one key; the laptop's own volume, brightness and
Wi-Fi keys work too. This is the whole set so far — it grows with each
component.

| Key | What it does |
| --- | --- |
| `SUPER + Q` | new terminal (kitty) |
| `SUPER + Space` | application launcher (Quickshell) |
| `SUPER + E` | file manager (yazi) |
| `SUPER + W` | wallpaper picker |
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
(`quickshell -p ~/.config/quickshell/lock.qml`) in its own transient systemd
unit (`quickshell-lock`). Both parts are deliberate: a bar reload would destroy
the session lock, and a lock left as a child of hypridle dies when hypridle is
restarted — either way the compositor keeps the session hidden behind a solid
colour by design. The screen shows the current wallpaper
blurred and dimmed (regenerated when you pick one), the clock and a PAM
password field
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

**The picker is `SUPER + W`.** Changing the wallpaper does not need a restart:
it lists the committed images in `images/wallpapers/` plus anything you drop in
`~/Pictures/Wallpapers/`, and applies the choice with hyprpaper and re-derives the palette from it (see
**The theme**). The path is remembered under `~/.local/state/dotfiles/`, so it
survives a reboot — the tracked `hyprpaper.conf` only provides the initial
default. The lock screen's blurred background is regenerated from whichever image
you pick.

The remembered choice is re-applied at login by a one-shot unit:

```bash
systemctl --user enable wallpaper-restore.service
```

The images in `images/wallpapers/` each have their source and licence recorded in
`CREDITS.md` beside them, because everything committed there is CC0 or public
domain. `~/Pictures/Wallpapers` is yours and stays out of the repository. By hand,
the same thing is `hyprctl hyprpaper wallpaper ', <path>'` followed by
`hyprctl hyprpaper listactive` to confirm.

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
dconf state (a binary file). The icon value is generated from the accent and set
by `install.sh` and by the wallpaper script; the cursor is fixed. The manual
commands are the fallback:

```bash
gsettings set org.gnome.desktop.interface icon-theme "$(cat ~/.local/state/dotfiles/theme/icon-theme)"
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24
```

GTK and Qt get the same values from their generated config files
(`gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `qt6ct/qt6ct.conf`, linked by
`install.sh`), and Hyprland from `hyprland.lua`.

**The bar is a systemd user service too.** Quickshell draws it from
`config/quickshell/` (QML), and like mako and hypridle it ships no unit, so this
repo carries one:

```bash
systemctl --user enable --now quickshell.service
```

**Night light is `hyprsunset`.** Its package ships the user unit (unlike
quickshell or mako), so it only needs enabling once. It starts with `--identity`
(a drop-in under `config/systemd/user/`), because its built-in default is a
6000 K warm filter; the control centre turns the filter on through
`hyprctl hyprsunset temperature` / `identity`:

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
