# Stat icon artwork

The icon shapes are from [Revamped Icons](https://steamcommunity.com/sharedfiles/filedetails/?id=3003721761) by **mono / monoSDE**. The maintainer confirmed the author's permission to include and adapt this artwork on 2026-11-21. The artwork remains attributed to its original author; no broader upstream license is claimed.

- `source/approved-icons/`: the approved redrawn 128×128 transparent PNG set.
- `build_icons.sh`: copies the approved PNGs unchanged and builds the preview with ImageMagick.
- `preview.png`: the resulting set on a dark background.
- Runtime output: `mods-unpacked/aimuzov-InsightToolkit/art/icons/`.

Run from the repository root:

```sh
./art/build_icons.sh
```

Requires ImageMagick (`magick`). The approved PNGs retain their dimensions, colors and alpha channel during the build.
