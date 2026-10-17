# dotfiles

My Arch Linux desktop, built from a bare install — one component per commit.

Hyprland (Wayland) · kitty · zsh + oh-my-zsh · yazi

## Layout

| Path | Purpose |
| --- | --- |
| `config/` | 1:1 mirror of `~/.config` — one folder per program |
| `scripts/` | installer, and later automation / animations |
| `images/` | wallpapers and other assets |

## Install

```bash
git clone https://github.com/eneko98/dotfiles ~/repos/dotfiles

~/repos/dotfiles/scripts/install.sh --dry-run   # preview what changes
~/repos/dotfiles/scripts/install.sh             # symlink config/ into ~/.config
```

The script only ever creates symlinks. It does not install packages, and it never
overwrites a real file — `~/.config` stays a normal directory, with only the files
that live in this repo linked into it.

Work in progress.
