# Wallpaper credits

This repository is public, so every image committed here has to be one we are
allowed to redistribute. There is one committed wallpaper and it is generated
from this project's own palette, so there are no third-party pixels in it.

## default.png

Generated for this repository with ImageMagick; released as
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

- 1920x1080: a vertical gradient from bg0 (#06060a) to a violet end (#191632),
  with two soft glows in the accent (#5eadcc) and the neon (#ab8bd2), both at low
  opacity. It is deliberately dark — it sits behind tiled windows and hyprpaper
  cannot dim a wallpaper, so the darkness is baked in.
- It is exactly this panel's resolution, so `fit_mode = cover` never scales or
  crops it.

Regenerate (the numbers match the committed file):

```bash
magick -size 1920x1080 gradient:'#05060a-#191632' /tmp/default-base.png
magick -size 1920x1080 xc:none \
  -fill 'rgba(94,173,204,0.10)' -draw 'ellipse 960,600 720,420 0,360' \
  -fill 'rgba(171,139,210,0.07)' -draw 'ellipse 1300,850 500,320 0,360' \
  -blur 0x120 /tmp/default-glow.png
magick /tmp/default-base.png /tmp/default-glow.png -compose over -composite \
  -depth 8 -strip images/wallpapers/default.png
```

PNG rather than JPEG: it is mostly near-black, where JPEG banding is very
visible. It costs about 140 KB.

## default-lock.png

The lock screen's fallback background, derived from `default.png`: blurred and
dimmed so large light text reads over it.

```bash
magick images/wallpapers/default.png -blur 0x18 -modulate 55,95,100 \
  images/wallpapers/default-lock.png
```

The blur is baked in because the lock surface cannot blur a live screenshot
without a shader (or the background-effect protocol), and the per-wallpaper lock
copy is regenerated into the state directory by `config/hypr/scripts/wallpaper`.

## Your own wallpapers

`~/Pictures/Wallpapers` is untracked: the picker lists it, but nothing there is
committed. Only images with a clear licence belong in this directory.
