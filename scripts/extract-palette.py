#!/usr/bin/env python3
"""Derive the palette from a wallpaper.

The wallpaper supplies the mood; the roles are the design. This script does not
dump the image's clusters into the theme: it picks a dark base, a light text,
one accent and one neon from the image's chroma families, keeps red as the
reserved "something is wrong" colour, and raises lightness until every role
passes a contrast floor against the new background.

PURE since the color-system v2: it prints the palette.lua contents to stdout
and never writes anything. gen-theme.py is the only writer (it applies the
palette to every copy AND to palette.lua, atomically and last), so no manual
run can leave the system half-themed -- which happened (measured: palette.lua
17 s newer than its copies). Use scripts/theme:

    scripts/theme preview IMG    palette + derived roles, no writes
    scripts/theme apply IMG      derive, regenerate, refresh what reloads live
    scripts/theme reset          back to the committed default
    scripts/theme check          palette vs copies, exit 1 if stale

The --print flag still exists and is the default; --reset only deletes the
state palette (a delete cannot leave a half-state).

Lessons baked in, from the first hand-made palette:

  * ranking clusters by raw saturation returns invisible colours (#000002 has
    saturation 1.00), so candidates are filtered by luminance first;
  * the dark base is a *near black tinted by the image*, not the image's average
    (a bright photo would otherwise turn the desktop light and unreadable);
  * the terminal's 16 ANSI colours are not extracted. A terminal needs hues that
    stay distinguishable (git, ls, yazi), and most photos carry one or two
    families, so only the three semantic slots (yellow/accent, cyan/neon,
    red/alarm) follow the palette; the rest are fixed hues checked for contrast;
  * the neon is always a *second* hue. With one chroma family it used to fall
    back to a fixed teal, which made eight unrelated wallpapers share one cyan;
    now it is a rotation of the accent, and a hard separation keeps it away from
    the accent, from the alarm red and from the fixed ANSI green/blue (the neon
    *is* ANSI cyan: a cyan that looks green or blue breaks the terminal's
    colours, measured on four wallpapers that landed 1-4 degrees off).
"""

from __future__ import annotations

import argparse
import colorsys
import os
import re
import subprocess
import sys
from pathlib import Path

STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "dotfiles"
OUT = STATE / "palette.lua"

# The alarm is not derived from the image: it has to read as "something is
# wrong" in every theme. Its hue is fixed; only its lightness is checked.
ALARM_HUE = 10 / 360

# The neon's two rules, both about the second colour being a *second* colour:
# when the photo has one hue family, or when the extracted one sits on top of
# the accent, the neon is rotated away by this much instead of being copied.
NEON_ROTATION = 0.18      # ~65 degrees: a consonant neighbour, not a twin
NEON_SEPARATION = 0.11    # ~40 degrees: below this, one colour is a failure

# The ANSI table keeps these hues fixed; the neon becomes ANSI *cyan*, so a
# rotation that lands on the fixed green (or blue) would make `ls` read as one
# colour. Rotations are scored against them.
ANSI_GREEN_HUE = 100 / 360
ANSI_BLUE_HUE = 205 / 360


def to_hex(r: float, g: float, b: float) -> str:
    return "#%02x%02x%02x" % tuple(round(c * 255) for c in (r, g, b))


def rgb(hex6: str) -> tuple[int, int, int]:
    return int(hex6[1:3], 16), int(hex6[3:5], 16), int(hex6[5:7], 16)


def oklch(hex6: str) -> tuple[float, float, float]:
    """(L, C, H) in OKLab terms -- used for the family chroma only."""
    h = hex6.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    lin = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
                for c in (r, g, b))
    l = 0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2]
    m = 0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2]
    s = 0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2]
    l_, m_, s_ = (max(v, 1e-9) ** (1 / 3) for v in (l, m, s))
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    A = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    B = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    import math
    return L, (A * A + B * B) ** 0.5, math.degrees(math.atan2(B, A)) % 360


def hsl(h: float, s: float, l: float) -> str:
    return to_hex(*colorsys.hls_to_rgb(h % 1.0, l, s))


def to_hls(hex6: str) -> tuple[float, float, float]:
    r, g, b = (c / 255 for c in rgb(hex6))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, l, s


def _channel(c: int) -> float:
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hex6: str) -> float:
    r, g, b = rgb(hex6)
    return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b)


def contrast(a: str, b: str) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def mix(a: str, b: str, t: float) -> str:
    ra, ga, ba = rgb(a)
    rb, gb, bb = rgb(b)
    return to_hex(*(x + (y - x) * t for x, y in ((ra, rb), (ga, gb), (ba, bb))))


def rotate_from(accent_h: float) -> float:
    """The neon of a one-hue photo: rotate the accent both ways and keep the
    side that stays furthest from the alarm and from the fixed ANSI hues."""
    best_h, best_score = None, -1.0
    for delta in (NEON_ROTATION, -NEON_ROTATION):
        h = (accent_h + delta) % 1.0
        score = min(hue_distance(h, ALARM_HUE),
                    hue_distance(h, ANSI_GREEN_HUE),
                    hue_distance(h, ANSI_BLUE_HUE))
        if score > best_score:
            best_h, best_score = h, score
    return best_h


def separate_neon(neon_h: float, accent_h: float) -> float:
    """Move the neon the smallest step that satisfies all four distances.

    It has to stay away from the accent (or the theme has one colour pretending
    to be two), from the alarm (or "alive" reads as "broken") and from the two
    fixed ANSI hues it would otherwise duplicate: the neon *is* ANSI cyan, and
    a cyan that is green or blue makes `ls` read as one colour. Measured on the
    wallpapers: four extracted blues sat 1-4 degrees from the fixed ANSI blue.
    """
    def acceptable(h: float) -> bool:
        return (hue_distance(h, accent_h) >= NEON_SEPARATION
                and hue_distance(h, ALARM_HUE) >= 0.055
                and hue_distance(h, ANSI_GREEN_HUE) >= 0.10
                and hue_distance(h, ANSI_BLUE_HUE) >= 0.10)

    if acceptable(neon_h):
        return neon_h
    for step in range(1, 21):
        for h in ((neon_h + step / 100) % 1.0,
                  (neon_h - step / 100) % 1.0):
            if acceptable(h):
                return h
    return neon_h


def raise_to(h: float, s: float, bg: str, target: float, start: float, cap: float) -> str:
    """The darkest colour of this hue/saturation that meets the contrast target."""
    l = start
    while l <= cap:
        colour = hsl(h, s, l)
        if contrast(colour, bg) >= target:
            return colour
        l += 0.005
    return hsl(h, s, cap)


def lighten(hex6: str, amount: float) -> str:
    h, l, s = to_hls(hex6)
    return hsl(h, s, min(l + amount, 0.95))


def hue_distance(a: float, b: float) -> float:
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)


def region_stats(path: Path, family_hex: str) -> dict[str, float]:
    """How bright the wallpaper is where each kind of surface floats.

    The wallpaper AS DISPLAYED: hyprpaper fills the monitor, so the image is
    squashed to 16:9 (96x54 with a bang). A box downscale approximates the
    compositor's blur; the statistic is the 90th percentile of the WCAG
    luminance -- not the mean, because a bright neon right under a pill is
    what breaks contrast, and p90 catches it.

    family_chroma is the OKLCH chroma of the dominant family cluster, before
    the base is darkened: the v2 surfaces tint themselves with a fraction of
    it (gen-theme), so it travels in the palette.
    """
    out = subprocess.run(
        ["magick", str(path), "-resize", "96x54!", "-depth", "8", "rgb:-"],
        capture_output=True, check=True,
    ).stdout

    def pct(values: list[float], frac: float) -> float:
        values = sorted(values)
        return values[min(len(values) - 1, int(len(values) * frac))]

    rows: list[list[float]] = []
    for y in range(54):
        row = []
        for x in range(96):
            base = (y * 96 + x) * 3
            r, g, b = (out[base] / 255, out[base + 1] / 255, out[base + 2] / 255)
            lin = tuple(
                c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
                for c in (r, g, b))
            row.append(0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2])
        rows.append(row)

    flat = [v for row in rows for v in row]
    return {
        # The bar strip: exclusiveZone 38 plus its shadow air.
        "region_bar": pct([v for row in rows[:3] for v in row], 0.90),
        # Panels hang from the top half of the screen.
        "region_panel": pct([v for row in rows[:25] for v in row], 0.90),
        # Widgets can be dragged anywhere.
        "region_desk": pct(flat, 0.90),
        "family_chroma": oklch(family_hex)[1],
    }


def clusters(path: Path) -> list[dict]:
    """A small weighted colour histogram: the image reduced to 24 colours."""
    result = subprocess.run(
        ["magick", str(path),
         "-resize", "240x240^", "-gravity", "center", "-extent", "240x240",
         "-depth", "8", "-colors", "24", "-format", "%c", "histogram:info:-"],
        capture_output=True, text=True, check=True,
    )

    found = []
    total = 0
    for line in result.stdout.splitlines():
        # Components may be integers or floats (Q16-HDRI prints both); the hex
        # is the stable part, so the count and the hex are all that are read.
        match = re.search(r"(\d+):\s*\([^)]*\)\s+#([0-9a-fA-F]{6})", line)
        if match is None:
            continue
        count = int(match.group(1))
        hex6 = "#" + match.group(2).lower()
        h, l, s = to_hls(hex6)
        found.append({
            "hex": hex6,
            "weight": count,
            "lum": luminance(hex6),
            "h": h,
            "l": l,
            "s": s,
        })
        total += count

    if total == 0:
        raise SystemExit(f"error: could not read colours from {path}")

    for colour in found:
        colour["weight"] /= total
    return found


def derive(colours: list[dict]) -> tuple[dict[str, str], dict[str, str], str, list[str]]:
    """Roles, ANSI and the dominant family's hex (for the v2 stats)."""
    notes: list[str] = []
    family_hex = "#000000"

    # Accent candidates: bright enough to be visible, chromatic enough to be a
    # colour. Saturation x lightness x area, after the visibility filter. The
    # weight floor is low on purpose: a neon sign is a small part of the frame
    # but exactly what the eye remembers.
    candidates = [
        c for c in colours
        if c["lum"] >= 0.10 and c["s"] >= 0.15 and c["weight"] >= 0.005
    ]
    if candidates:
        best = max(candidates, key=lambda c: c["s"] * (c["lum"] ** 0.5) * (0.3 + c["weight"]))
        accent_h = best["h"]
        accent_s = min(max(best["s"], 0.35), 0.52)
    else:
        accent_h, accent_s = 39 / 360, 0.55
        notes.append("no chromatic cluster: accent falls back to the default gold")

    # Keep the accent away from the alarm's red, or "active" and "broken" start
    # to look alike.
    if hue_distance(accent_h, ALARM_HUE) < 0.055:
        accent_h = ALARM_HUE + 0.10
        notes.append("accent hue was too close to the alarm red; shifted warm")

    # The base is a near black tinted by the image's dominant *colour family*,
    # not by the accent: a blue photo with one orange sign should still give a
    # blue-black desktop. A bright photo must not turn the desktop light.
    families = [c for c in colours if c["s"] >= 0.12 and c["weight"] >= 0.01]
    if families:
        base_source = max(families, key=lambda c: c["weight"])
        family_hex = base_source["hex"]
        base_h = base_source["h"]
        base_s = min(max(min(base_source["s"], 0.50) * 0.50, 0.15), 0.28)
    else:
        # A grayscale photo has no family to borrow; a neutral dark is better
        # than an arbitrary red tint from the hue of a gray pixel.
        base_h, base_s = 0.0, 0.03
        notes.append("no colour family: neutral base")

    bg0 = hsl(base_h, base_s, 0.030)
    bg1 = hsl(base_h, base_s * 0.75, 0.068)
    bg2 = hsl(base_h, base_s * 0.75, 0.108)

    # Text is a neutral of the same family, not a neon from the photo: a pink
    # cream over a teal accent would fight the chrome.
    text_h, text_s = base_h, 0.12
    fg0 = raise_to(text_h, text_s, bg0, 13.0, 0.55, 0.94)
    fg1 = raise_to(text_h, text_s * 0.85, bg0, 5.6, 0.20, 0.90)
    fg2 = raise_to(text_h, text_s * 0.70, bg0, 3.2, 0.15, 0.85)

    accent = raise_to(accent_h, accent_s, bg0, 8.0, 0.38, 0.72)

    # The neon is the second family: at least 60 degrees away in hue, so the two
    # accents cannot be mistaken for each other. One family only: the neon is a
    # *rotation of the accent's own hue* instead of a fixed teal -- the old
    # fallback made eight unrelated photos share the same cyan, which is what
    # made every theme look alike.
    second = [c for c in candidates if hue_distance(c["h"], accent_h) >= 1 / 6]
    if second:
        best2 = max(second, key=lambda c: c["s"] * (c["lum"] ** 0.5) * (0.3 + c["weight"]))
        neon_h, neon_s = best2["h"], min(max(best2["s"], 0.25), 0.45)
    else:
        neon_h, neon_s = rotate_from(accent_h), 0.32
        notes.append("one chroma family: neon rotated from the accent")

    # Separation is a rule, not a property of the source: Shibuya's accent was
    # cyan and the fallback teal sat 4 degrees away, so the theme had one colour
    # pretending to be two.
    neon_h = separate_neon(neon_h, accent_h)

    neon = raise_to(neon_h, neon_s, bg0, 7.0, 0.38, 0.75)
    # The alarm floor went up (4.2 -> 5.6) with the color-system v2: red is
    # also text on the v2's tinted SURFACES (a touch lighter than bg0), and
    # 4.2:1 there was under the 4.5 text floor. Measured on the default
    # palette: #dc6048, 5.6:1 on bg0, 5.1:1 on s1, 4.7:1 on s3.
    alarm = raise_to(ALARM_HUE, 0.62, bg0, 5.6, 0.38, 0.66)

    roles = {
        "bg0": bg0,
        "bg1": bg1,
        "bg2": bg2,
        "fg0": fg0,
        "fg1": fg1,
        "fg2": fg2,
        "gold": accent,
        "teal": neon,
        "red": alarm,
    }

    # The terminal's hues that the photo does not supply: fixed, muted, and only
    # their lightness is chosen so they sit above the contrast floor.
    green = raise_to(100 / 360, 0.27, bg0, 4.8, 0.30, 0.70)
    blue = raise_to(205 / 360, 0.30, bg0, 4.8, 0.30, 0.70)
    magenta = raise_to(350 / 360, 0.30, bg0, 5.0, 0.35, 0.72)

    ansi = {
        "black": hsl(base_h, 0.12, 0.14),
        "red": alarm,
        "green": green,
        "yellow": accent,
        "blue": blue,
        "magenta": magenta,
        "cyan": neon,
        "white": fg0,
        "bright_black": hsl(base_h, 0.12, 0.27),
        "bright_red": lighten(alarm, 0.12),
        "bright_green": lighten(green, 0.12),
        "bright_yellow": lighten(accent, 0.10),
        "bright_blue": lighten(blue, 0.12),
        "bright_magenta": lighten(magenta, 0.12),
        "bright_cyan": lighten(neon, 0.10),
        "bright_white": lighten(fg0, 0.06),
    }
    return roles, ansi, family_hex, notes


ROLE_COMMENTS = {
    "bg0": "base: terminal background, misc:background_color",
    "bg1": "raised surface: bar, panels, menus",
    "bg2": "selection, current workspace, current tab",
    "fg0": "primary text",
    "fg1": "secondary text, comments",
    "fg2": "dim: inactive borders, rules -- never body text",
    "gold": "accent slot (its hue follows the wallpaper)",
    "teal": "neon: cursor, focus, links",
    "red": "alarm: errors, failures",
}


def render(roles: dict[str, str], ansi: dict[str, str],
           stats: dict[str, float], source: str) -> str:
    lines = [
        f"-- Generated by scripts/extract-palette.py from {source}.",
        "-- This is the active palette. config/hypr/theme.lua loads it when it",
        "-- exists; scripts/gen-theme.py writes every other program's copy from",
        "-- it. Delete this file (or run `scripts/extract-palette.py --reset`) to",
        "-- return to the committed default in config/hypr/theme.lua.",
        "--",
        "-- `gold` and `teal` are role names, not promises: their hues come from",
        "-- the wallpaper. Red stays the reserved alarm colour.",
        "local theme = {",
    ]
    for name, value in roles.items():
        lines.append(f'    {name} = "{value}", -- {ROLE_COMMENTS[name]}')
    lines += ["}", "",
        "-- v2 stats, read by scripts/gen-theme.py (Hyprland ignores them):",
        "-- the dominant family's OKLCH chroma and the 90th percentile of the",
        "-- wallpaper's luminance where each kind of surface floats.",
        "theme.stats = {"]
    for name, value in stats.items():
        lines.append(f"    {name} = {value:.6f},")
    lines += ["}", "", "theme.ansi = {"]
    for name, value in ansi.items():
        lines.append(f'    {name} = "{value}",')
    lines += ["}", "", "return theme", ""]
    return "\n".join(lines)


def report(roles: dict[str, str], ansi: dict[str, str], notes: list[str], source: str) -> None:
    print(f"source    {source}")
    for name in ("bg0", "bg1", "bg2", "fg0", "fg1", "fg2"):
        print(f"  {name}    {roles[name]}")
    for name in ("gold", "teal", "red"):
        print(f"  {name:<5} {roles[name]}   {contrast(roles[name], roles['bg0']):.1f}:1 on bg0")
    print("  ansi   " + " ".join(ansi[name] for name in (
        "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")))
    weakest = min(
        (contrast(value, roles["bg0"]), name) for name, value in ansi.items()
        if name not in ("black", "bright_black")
    )
    print(f"  weakest ANSI contrast: {weakest[0]:.1f}:1 ({weakest[1]})")
    for note in notes:
        print(f"  note   {note}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("wallpaper", nargs="?", help="image to derive the palette from")
    parser.add_argument("--print", dest="preview", action="store_true",
                        help="kept for compatibility: printing is the default now")
    parser.add_argument("--reset", action="store_true",
                        help="remove the generated palette (back to the committed default)")
    parser.add_argument("--stats", action="store_true",
                        help="print only the region stats of a wallpaper (for"
                             " theme reset: the committed palette over the"
                             " wallpaper that is actually on screen)")
    args = parser.parse_args()

    if args.stats:
        # Only the luminance regions, with the committed bg1 standing in for
        # the family: a reset keeps the committed palette, and its surfaces
        # carry the committed family's chroma anyway.
        path = Path(args.wallpaper).expanduser()
        if not path.is_file():
            print(f"error: {path} is not a file", file=sys.stderr)
            return 1
        for name, value in region_stats(path, "#0e0e15").items():
            if name != "family_chroma":
                print(f"{name} = {value:.6f}")
        return 0

    if args.reset:
        if OUT.exists():
            OUT.unlink()
            print(f"removed {OUT}")
        else:
            print("no generated palette to remove")
        return 0

    if not args.wallpaper:
        parser.error("a wallpaper path is required (or --reset)")

    path = Path(args.wallpaper).expanduser()
    if not path.is_file():
        print(f"error: {path} is not a file", file=sys.stderr)
        return 1

    roles, ansi, family_hex, notes = derive(clusters(path))
    try:
        stats = region_stats(path, family_hex)
    except Exception as exc:  # noqa: BLE001 - a stat failure must not stop the palette
        print(f"-- region stats unavailable: {exc}", file=sys.stderr)
        stats = {}
    print(render(roles, ansi, stats, str(path)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
