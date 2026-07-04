# assets - asset pipeline & catalog contract

Rules for how source art lives on disk, how the catalog is generated, how sheet
assets are sliced at runtime, and how the shortcut/aliases layer is curated.

## Entries

- [rules.md](rules.md) - the standing rules
- [decisions/catalog-generator-schema.md](decisions/catalog-generator-schema.md) - the entry shape `tools/generate_asset_catalog.ps1` produces (proposed - advise)
- [decisions/id-naming-scheme.md](decisions/id-naming-scheme.md) - the `{category}_{scale}_{kind}_{slug}` id convention (proposed - block)
- [decisions/regenerate-after-asset-change.md](decisions/regenerate-after-asset-change.md) - always re-run the generator after touching `asset/` (proposed - block)
- [decisions/slice-sheets-at-registry-boundary.md](decisions/slice-sheets-at-registry-boundary.md) - sprite/tile sheets are sliced through `AssetRegistry`, not scenes or hand-cropped files (proposed - block)
- [decisions/shortcuts-are-the-swap-layer.md](decisions/shortcuts-are-the-swap-layer.md) - new gameplay roles go in `data/asset_shortcuts.json`, not in code (proposed - advise)
- [decisions/reference-slicing-and-catalog-semantics.md](decisions/reference-slicing-and-catalog-semantics.md) - semantic catalog fields (`is_atlas`/`description`/`usage`/`prompt`) + the offline `asset_sliced/` reference layer, distinct from runtime slicing (proposed - advise)
- [decisions/named-map-tiles-swap-layer.md](decisions/named-map-tiles-swap-layer.md) - reference map tiles by name via `data/maps/tile_names.json` + `AssetRegistry.load_map_tile`, not raw `[col,row]` (proposed - advise)
- [decisions/map-object-stamps-use-named-top-left.md](decisions/map-object-stamps-use-named-top-left.md) - place multi-tile map objects from a named top-left tile + `AssetRegistry.load_map_tile_offset` (proposed - advise)

## Comprehension docs

- [docs/ASSET_GUIDE.md](../../../docs/ASSET_GUIDE.md) - plain-language guide: what every asset is, atlas-vs-isolated, the tilesheet tile-role map, UI groups, prompt shape.
- `tools/slice_sheets.ps1` - generates the `asset_sliced/` reference cut-outs under `asset_sliced/`.
