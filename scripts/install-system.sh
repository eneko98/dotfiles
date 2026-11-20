#!/bin/sh
# Install the files under system/ into the real system. Needs root.
#
# They are copied, not symlinked: root must not depend on the user's home
# (which is 0700). Run with --dry-run to see what would be installed.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
src=$repo/system
[ -d "$src" ] || { echo "no system/ directory" >&2; exit 1; }

if [ "${1:-}" = "--dry-run" ]; then
	find "$src" -type f | while read -r f; do
		rel=${f#"$src"/}
		case "$rel" in
		*/pacman-activity) mode=0755 ;;
		*) mode=0644 ;;
		esac
		echo "install -m $mode $f /$rel"
	done
	exit 0
fi

find "$src" -type f | while read -r f; do
	rel=${f#"$src"/}
	dir=$(dirname "/$rel")
	install -d -m 0755 "$dir"
	case "$rel" in
	*/pacman-activity) mode=0755 ;;
	*) mode=0644 ;;
	esac
	install -m "$mode" "$f" "/$rel"
	echo "installed /$rel"
done
