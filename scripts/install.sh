#!/usr/bin/env bash
#
# Symlink this repo's config/ tree into ~/.config, one file at a time.
#
#   scripts/install.sh --dry-run   show what would change
#   scripts/install.sh             create the symlinks
#
# Only the files committed here are linked, so ~/.config stays a normal directory
# and programs can still write their own state next to our symlinks. Real files
# are never overwritten -- anything in the way is reported and left alone.
#
# The palette's copies are the exception: they are *generated* from the active
# palette (the chosen wallpaper's, or the committed default) and live under
# XDG_STATE_HOME, because the palette is machine state. This script runs
# scripts/gen-theme.py and links each generated file to the fixed path its
# program expects.

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="$repo_dir/config"
dst_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_theme="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme"

# Every path scripts/gen-theme.py writes, relative to both ~/.config and the
# state theme dir. Firefox is handled with its profile, below.
generated=(
	kitty/theme.conf
	zsh/theme.zsh
	fuzzel/colors.ini
	yazi/theme.toml
	hypr/hyprlock-theme.conf
	mako/theme
	gtk-3.0/palette.css
	gtk-4.0/palette.css
	gtk-3.0/settings.ini
	gtk-4.0/settings.ini
	qt6ct/colors/theme.conf
	qt6ct/qt6ct.conf
	quickshell/Theme.qml
)

dry_run=0
case "${1:-}" in
	--dry-run | -n) dry_run=1 ;;
	-h | --help)
		sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	"") ;;
	*)
		printf 'unknown argument: %s\n' "$1" >&2
		exit 2
		;;
esac

if [[ ! -d "$src_dir" ]]; then
	printf 'nothing to link yet: %s does not exist\n' "$src_dir"
	exit 0
fi

changed=0
skipped=0

link_one() {
	local src="$1" dst="$2"

	if [[ -L "$dst" ]]; then
		if [[ "$(readlink -- "$dst")" == "$src" ]]; then
			return 0
		fi
		printf 'relink  %s\n' "$dst"
	elif [[ -e "$dst" ]]; then
		printf 'SKIP    %s exists and is not a symlink -- move it aside\n' "$dst" >&2
		skipped=$((skipped + 1))
		return 0
	else
		printf 'link    %s -> %s\n' "$dst" "$src"
	fi

	if ((!dry_run)); then
		mkdir -p -- "$(dirname -- "$dst")"
		ln -sfn -- "$src" "$dst"
	fi
	changed=$((changed + 1))
}

while IFS= read -r -d '' src; do
	rel="${src#"$src_dir"/}"
	link_one "$src" "$dst_dir/$rel"
done < <(find "$src_dir" -type f -not -path "$src_dir/firefox/*" -print0 | sort -z)

# Regenerate the palette's copies from the active palette, then link them where
# the programs look. A retheme writes the same files under the state dir; the
# links survive it.
if ((dry_run)); then
	printf 'note    the palette copies under %s would be regenerated and linked\n' "$state_theme"
else
	theme_out="$("$repo_dir/scripts/gen-theme.py")"
	for rel in "${generated[@]}"; do
		link_one "$state_theme/$rel" "$dst_dir/$rel"
	done

	# The icon theme reaches GTK/fuzzel through the portal, so gsettings has to
	# carry the generated value too; the GTK and Qt files already have it.
	if [[ -f "$state_theme/icon-theme" ]] && command -v gsettings >/dev/null 2>&1; then
		gsettings set org.gnome.desktop.interface icon-theme \
			"$(cat "$state_theme/icon-theme")" >/dev/null 2>&1 || true
	fi

	# Seed/sync the login greeter's system copy (QML + generated theme + the
	# regreet fallback's css and png). Only if the greeter is set up at all.
	if [[ -d /etc/greetd ]]; then
		"$repo_dir/config/hypr/scripts/wallpaper" sync-greeter >/dev/null 2>&1 || true
	fi

	# If the palette copies were (re)written, Theme.qml may be a new inode, and
	# Quickshell watches the inode it loaded. Restarting the bar is cheaper than
	# leaving it on the previous palette when install.sh runs mid-session.
	if [[ "$theme_out" != "up to date" ]] \
		&& systemctl --user is-active --quiet quickshell.service 2>/dev/null; then
		printf 'reload  quickshell.service (regenerated palette)\n'
		systemctl --user restart quickshell.service || true
	fi
fi

# Firefox is the one tree that is not a 1:1 mirror: its profile lives under
# ~/.config/mozilla/firefox/<machine-specific-id>/, so the theme files are linked
# into whichever profile profiles.ini calls default. Only files Firefox never
# writes are linked; prefs.js and the rest of the profile stay untouched.
firefox_theme="$repo_dir/config/firefox"
firefox_ini="$dst_dir/mozilla/firefox/profiles.ini"
if [[ -f "$firefox_ini" ]]; then
	firefox_profile="$(awk -F= '/^\[Install/{i=1;next} /^\[/{i=0} i && $1=="Default"{print $2; exit}' "$firefox_ini")"
	if [[ -z "$firefox_profile" ]]; then
		firefox_profile="$(cd "$dst_dir/mozilla/firefox" && ls -d *.default-release 2>/dev/null | head -n1 || true)"
	fi
	firefox_profile_dir="$dst_dir/mozilla/firefox/$firefox_profile"
	if [[ -n "${firefox_profile:-}" && -d "$firefox_profile_dir" ]]; then
		while IFS= read -r -d '' src; do
			rel="${src#"$firefox_theme"/}"
			link_one "$src" "$firefox_profile_dir/$rel"
		done < <(find "$firefox_theme" -type f -print0 | sort -z)

		# The palette is generated, so it comes from the state dir.
		link_one "$state_theme/firefox/chrome/palette.css" \
			"$firefox_profile_dir/chrome/palette.css"
	fi
fi

if ((changed == 0 && skipped == 0)); then
	printf 'already up to date\n'
elif ((dry_run)); then
	printf '\n%s change(s) would be made (dry run)\n' "$changed"
fi

if ((skipped > 0)); then
	printf '%s file(s) skipped -- resolve them and re-run\n' "$skipped" >&2
	exit 1
fi
