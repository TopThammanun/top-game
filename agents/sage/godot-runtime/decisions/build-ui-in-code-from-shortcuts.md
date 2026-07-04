---
id: build-ui-in-code-from-shortcuts
type: convention
title: Prototype UIs are built in code from shortcut ids
domain: godot-runtime
tags: [ui, prototype, style]
status: proposed
enforcement: advise
applies_to: [godot-runtime, "scripts/main/**", "scripts/ui/**"]
source: ai
related: [asset-registry-api]
timestamp: 2026-07-04T00:00:00Z
---

Prototype screens (currently `scripts/main/main.gd`) keep the `.tscn` file as a
thin stub that just attaches the script, then build the whole Control tree in
`_build_layout()` inside `_ready()`. Assets referenced by id lists at the top of
the script (e.g. `UNIT_PREVIEW_IDS`, `SLOT_PREVIEW_IDS`) using shortcut ids, not
raw catalog ids.

**Why the team does it this way:**

- The `.tscn` diff stays trivial when the layout changes — no scene churn.
- Every asset used by the screen is visible in one glance at the top of the file.
- Swapping art is a one-line change in `data/asset_shortcuts.json`.

**Reusable helpers to lift from `main.gd` when a second caller needs them:**

- `_make_panel(name, color) -> PanelContainer` — StyleBoxFlat with the project's
  warm border colour.
- `_make_margin(amount) -> MarginContainer` — uniform margin all sides.
- `_make_label(text, font_size) -> Label` — themed label with the parchment tint.
- `_make_texture_rect(name, min_size) -> TextureRect` — configured for pixel-art
  (`EXPAND_IGNORE_SIZE`, `STRETCH_KEEP_ASPECT_CENTERED`).

Don't extract them into `scripts/ui/` yet — they only have one caller. When a
second screen wants them, move the block to `scripts/ui/ui_builders.gd` and
have both scripts call in.
