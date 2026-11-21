#!/usr/bin/env python3
"""Fetch synchronized lyrics from LRCLIB and cache them locally.

    lyrics.py <artist> <title> <album> <duration_seconds>

Prints {"lines": [[t_seconds, "text"], ...]}; an empty list means "no lyrics"
(no match, instrumental, offline). A miss is cached too, so a song that LRCLIB
does not know is not asked again on every play.

LRCLIB is free and keyless. It does receive what you are listening to (artist,
title, album, duration), which is the privacy cost of the feature; the cache
means it is asked once per track, not once per play.
"""

import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 5
USER_AGENT = "dotfiles-lyrics (personal desktop shell)"


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
    path = os.path.join(base, "dotfiles", "lyrics")
    os.makedirs(path, exist_ok=True)
    return path


def parse_lrc(synced):
    """LRC to [[seconds, text], ...], sorted. Lines without a stamp are
    dropped: they would have no time to show at."""
    lines = []
    for raw in (synced or "").splitlines():
        stamps = re.findall(r"\[(\d+):(\d+(?:\.\d+)?)\]", raw)
        if not stamps:
            continue
        text = re.sub(r"\[[^\]]*\]", "", raw).strip()
        for minutes, seconds in stamps:
            lines.append([int(minutes) * 60 + float(seconds), text])
    lines.sort(key=lambda line: line[0])
    return lines


def main():
    if len(sys.argv) != 5:
        print(json.dumps({"lines": [], "error": "usage"}))
        return

    artist, title, album, duration = sys.argv[1:5]
    try:
        seconds = round(float(duration))
    except ValueError:
        seconds = 0

    key = hashlib.sha1(
        f"{artist}\0{title}\0{album}\0{seconds}".encode("utf-8")
    ).hexdigest()
    path = os.path.join(cache_dir(), key + ".json")

    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            print(handle.read())
        return

    query = urllib.parse.urlencode({
        "artist_name": artist,
        "track_name": title,
        "album_name": album,
        "duration": seconds,
    })
    request = urllib.request.Request(
        "https://lrclib.net/api/get?" + query,
        headers={"User-Agent": USER_AGENT},
    )

    lines = []
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            data = json.load(response)
        lines = parse_lrc(data.get("syncedLyrics"))
    except (urllib.error.URLError, urllib.error.HTTPError, ValueError, OSError):
        # 404 or offline: cache the miss and stay quiet, the island just has
        # no line to show.
        pass

    out = json.dumps({"lines": lines})
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(out)
    print(out)


if __name__ == "__main__":
    main()
