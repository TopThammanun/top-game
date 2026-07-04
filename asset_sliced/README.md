# asset_sliced/ — generated reference cut-outs (NOT the runtime source)

This folder is **generated** by [`tools/slice_sheets.ps1`](../tools/slice_sheets.ps1).
It cuts the combined sheets in `asset/map/` into individual pieces so humans and AI
agents can **see and pick each frame / tile**.

**It is a reference / preview layer only.**

- The running game does **not** load from here. At runtime, sheets are sliced
  through `AssetRegistry` (`load_sprite_frame`, `load_grid_cell`) per the repo rule
  [`slice-sheets-at-registry-boundary`](../agents/sage/assets/decisions/slice-sheets-at-registry-boundary.md).
- Original art in `asset/` is never modified.
- This folder is **disposable** — delete it and regenerate anytime.

## Layout

```
units/<scale>/<Sprite>/frame_r<row>_c<col>.png   # 16 frames per sprite sheet
                      /row<row>_strip.png          # one animation track (4 frames)
tiles/<biome>_<water>/<scale>/<role>_<n>_c<col>_r<row>.png
                            /index.json            # role + tile pos + pixel box per piece
tiles/fog_of_war/<scale>/...
```

`<role>` matches the tile-role map in [`docs/ASSET_GUIDE.md`](../docs/ASSET_GUIDE.md#31-character-sprites)
(§3.2) — e.g. `buildings_block_1`, `water_autotile_shallow`, `props_objects`.

## Regenerate

```powershell
# 1x, everything (units + tilesheets + fog)
powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1

# a specific scale / subset
powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1 -Scale 3x -What tiles
powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1 -Scale 1x -What units
```

Full per-asset descriptions, usage and prompts: `data/asset_catalog.json`
(`description` / `usage` / `prompt` / `is_atlas` / `sliced_reference`) and
`docs/ASSET_GUIDE.md`.
