# Wallpaper credits

This repository is public, so every image committed here has to be one we are allowed
to redistribute. That rules out most wallpaper sites: their uploads are usually
reposted artwork with no licence record. Everything below is CC0 or public domain,
with the source and the licence recorded next to it.

## hong-kong-night.png

| | |
| --- | --- |
| Title | Hong Kong in night (noise version) |
| Photographer | Wilfredor |
| Original | 3538x2318, taken 2013-06-16 on Stewart Road, Wan Chai, Hong Kong |
| Source | https://commons.wikimedia.org/wiki/File:Hong_Kong_in_night_(noise_version).jpg |
| Licence | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) — public domain dedication, no attribution required |

The file here is a derivative, not the original:

- centre-cropped from 3538x2318 to 16:9 (3538x1990),
- downscaled to 1920x1080, which is this panel's native resolution, so `fit_mode = cover`
  never has to scale or crop it,
- darkened to a mean luminance of ~33, because it sits behind tiled windows and
  hyprpaper cannot dim a wallpaper — the darkening has to be baked in.

PNG rather than JPEG: the image is mostly near-black, and JPEG banding is very visible
there. It costs about 3 MB in the repo.

**To regenerate from the source** (after changing the crop or the dimming):

```bash
curl -LO 'https://upload.wikimedia.org/wikipedia/commons/4/4e/Hong_Kong_in_night_%28noise_version%29.jpg'
python3 - <<'EOF'
from PIL import Image, ImageEnhance
im = Image.open("Hong_Kong_in_night_(noise_version).jpg").convert("RGB")
w, h = im.size
nh = int(w / (16 / 9))
im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
lum = sum(i * n for i, n in enumerate(im.convert("L").histogram())) / (im.width * im.height)
im = ImageEnhance.Brightness(im).enhance(33 / lum)
im = ImageEnhance.Color(im).enhance(0.92)
im = ImageEnhance.Contrast(im).enhance(1.05)
im.resize((1920, 1080), Image.LANCZOS).save("hong-kong-night.png", optimize=True)
EOF
```

## hong-kong-night-lock.png

The lock screen's background, derived from `hong-kong-night.png` above (same source,
same photographer, same CC0 licence). Blurred and dimmed so large light text reads over
it, and small enough to keep the repo honest:

```bash
convert images/wallpapers/hong-kong-night.png -blur 0x18 -modulate 55,95,100 \
    images/wallpapers/hong-kong-night-lock.png
```

The blur is baked in because the lock surface cannot blur a live screenshot without a
shader (or the background-effect protocol) and the pre-blurred file is one less moving
part at the most fragile moment of the session.
