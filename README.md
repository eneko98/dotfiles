# dotfiles

Arch + Hyprland (Lua) desktop, one component per commit. `config/` mirrors
`~/.config`; `scripts/install.sh` links it and regenerates the theme copies.

## Keys

| Key | Action |
| --- | --- |
| `SUPER + Q` | terminal (kitty) |
| `SUPER + Space` | launcher |
| `SUPER + E` | files (yazi) |
| `SUPER + G` | Firefox |
| `SUPER + D` | dashboard |
| `SUPER + H` | measurement HUD |
| `SUPER + W` | wallpaper picker |
| `SUPER + N` | System panel, network |
| `SUPER + Escape` | System panel, session |
| `SUPER + V` | clipboard history |
| `SUPER + Tab` | workspace carousel |
| `SUPER + 1..0` | workspace 1-10 |
| `SUPER + Shift + 1..0` | move window to workspace 1-10 |
| `SUPER + scroll` | previous / next workspace |
| `SUPER + F` | fullscreen |
| `SUPER + C` | close window |
| `SUPER + L` | lock |
| `SUPER + M` | log out |
| `Print` | screenshot: screen |
| `SUPER + Shift + A` | screenshot: area |
| `SUPER + Shift + W` | screenshot: window |
| volume keys | ±5 %, mute, mic mute |
| brightness keys | ±5 % |
| media keys | play/pause, next, previous, stop |

Three-finger horizontal swipe switches workspaces; vertical opens the carousel.
Screenshots land in `~/Pictures/Screenshots` and in the clipboard.

## Programs

| Piece | Program |
| --- | --- |
| Compositor | Hyprland, configured in Lua |
| Session | uwsm |
| Login screen | greetd + cage + our Quickshell greeter |
| Bar, panels, overview | Quickshell (our QML) |
| Terminal | kitty |
| Shell | zsh + oh-my-zsh, `lsd`, `bat` |
| Editor | neovim |
| Files | yazi (fd, ripgrep, fzf, zoxide, chafa, poppler, ffmpegthumbnailer, 7zip) |
| Browser | Firefox |
| Music | Spotify via `spotify-launcher`, with `cava` for the spectrum |
| Mixer | pavucontrol |
| dmenu | fuzzel (clipboard, session menu) |
| Clipboard | cliphist |
| Wallpaper | hyprpaper |
| Lock and idle | our Quickshell lock + hypridle |
| Night light | hyprsunset |
| Screenshots | grim + slurp + wl-clipboard |
| Notifications | our Quickshell server (mako as fallback) |
| Bluetooth | bluez + `bt-agent` |
| Battery | upower |
| Qt theme | qt6ct |
| Fonts | JetBrainsMono Nerd Font, Source Han Sans CN, Noto Color Emoji |

The full package list, with the reason for each entry, is in `packages.txt`.
