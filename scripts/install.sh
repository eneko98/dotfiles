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

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="$repo_dir/config"
dst_dir="${XDG_CONFIG_HOME:-$HOME/.config}"

dry_run=0
case "${1:-}" in
	--dry-run | -n) dry_run=1 ;;
	-h | --help)
		sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
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

while IFS= read -r -d '' src; do
	rel="${src#"$src_dir"/}"
	dst="$dst_dir/$rel"

	if [[ -L "$dst" ]]; then
		if [[ "$(readlink -f -- "$dst")" == "$(readlink -f -- "$src")" ]]; then
			continue
		fi
		printf 'relink  %s\n' "$dst"
	elif [[ -e "$dst" ]]; then
		printf 'SKIP    %s exists and is not a symlink -- move it aside\n' "$dst" >&2
		skipped=$((skipped + 1))
		continue
	else
		printf 'link    %s -> %s\n' "$dst" "$src"
	fi

	if ((!dry_run)); then
		mkdir -p -- "$(dirname -- "$dst")"
		ln -sfn -- "$src" "$dst"
	fi
	changed=$((changed + 1))
done < <(find "$src_dir" -type f -print0 | sort -z)

if ((changed == 0 && skipped == 0)); then
	printf 'already up to date\n'
elif ((dry_run)); then
	printf '\n%s change(s) would be made (dry run)\n' "$changed"
fi

if ((skipped > 0)); then
	printf '%s file(s) skipped -- resolve them and re-run\n' "$skipped" >&2
	exit 1
fi
