# Stat icon artwork

The icon shapes are from [Revamped Icons](https://steamcommunity.com/sharedfiles/filedetails/?id=3003721761) by **mono / monoSDE**. The maintainer confirmed the author's permission to include and adapt this artwork on 2026-11-21. The artwork remains attributed to its original author; no broader upstream license is claimed.

- `source/revamped-icons/`: original 96×96 transparent PNGs, retained unchanged.
- `palette.tsv`: Insight Toolkit's muted stat colors.
- `build_icons.sh`: reproducible recoloring with ImageMagick; only RGB changes, with the original dimensions and alpha preserved.
- `preview.png`: the resulting set on a dark background.
- Runtime output: `mods-unpacked/aimuzov-InsightToolkit/art/icons/`.

Run from the repository root:

```sh
./art/build_icons.sh
```

Requires ImageMagick (`magick`). The original silhouettes, negative spaces and antialiased edges are preserved.
