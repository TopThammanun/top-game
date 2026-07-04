# Map Scripts

Map-specific scripts live here.

Keep runtime art behind `AssetRegistry`.

- Whole-sheet choices use shortcuts such as `map.default_tilesheet` and `map.fog_of_war`.
- Unit visuals use role shortcuts such as `unit.tank_idle` or `unit.enemy_grunt_idle`.
- Map cells use names from `data/maps/tile_names.json`; avoid raw `[col,row]` pairs in scripts and map plans.
- Use `asset_sliced/` only as an offline reference for choosing tile names, never as a runtime path.
