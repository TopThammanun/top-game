---
id: thai-first-bilingual-from-day-one
type: skill
title: Ship Thai + English from day one — font, wrap, and TranslationServer
domain: localization
status: proposed
source: ai
enforcement: advise
tags: [i18n, thai, fonts, godot, translation]
---

The project's design source is Thai; the production title, identity
vocabulary, and folder contracts are English. Neither is optional. That
forces three engine decisions on day one:

1. **Font stack with Thai fallback.** The current default
   (`FantasyRPGtext (size 8).ttf`) is a Latin-only pixel font. Configure a
   Godot `SystemFont` or a Thai-capable `FontFile` as the fallback so
   Thai renders instead of tofu boxes.
2. **Thai line-breaking.** Thai text has no word spaces; Godot 4 supports
   ICU-style boundary detection when the `text_server_advanced` module is
   built into the export template (it is in the standard 4.x export
   templates). Verify on device — some legacy export templates omit it.
3. **`TranslationServer` + PO/CSV workflow.** Every user-facing string goes
   through `tr("STRING_ID")`; source-of-truth is a CSV or PO file exported to
   both locales. Never hard-code Thai (or English) UTF-8 in scripts.

**Do:**

- Configure two locales in the project: `en` and `th`. Ship both switchable
  from the settings screen.
- Add a `res://locale/strings.csv` with columns `id, en, th` and let the
  import handle it (Godot has native CSV translation import).
- Use `RichTextLabel` with `autowrap_mode = AUTOWRAP_WORD_SMART` for prose;
  it handles Thai boundaries correctly when `text_server_advanced` is loaded.
- Test on a real device early — desktop rendering can mask Thai combining-mark
  bugs that mobile GPUs surface.

**Avoid:**

- Hard-coded English literals in UI. `label.text = "Play"` is a bug that
  compounds every screen. Use `label.text = tr("MENU_PLAY")`.
- Assuming Thai fits in the same UI boxes as English. Thai is compact per
  character but taller per line and rarely word-breaks predictably. Author
  UI with a 1.4× width headroom.
- Baking translated text into images. Fine for the title logo, disastrous
  for anything else — costs multiply per language.
