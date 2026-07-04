---
id: string-ids-not-english-source
type: skill
title: Reference strings by opaque id, not by English literal
domain: localization
status: proposed
source: ai
enforcement: advise
tags: [i18n, ids, strings, refactor]
---

A common failure mode of Godot localisation: `tr("Play")` scattered
everywhere. It "works" for two locales, then someone renames a button
and every locale silently falls back to the raw source. Solve it by using
**opaque, hierarchical ids** as translation keys:

- `MENU_PLAY`, `MENU_SETTINGS`, `MENU_QUIT`
- `BATTLE_WIN_TITLE`, `BATTLE_WIN_XP_FMT`, `BATTLE_LOSE_TITLE`
- `CLAN_MAINCOON_NAME`, `CLAN_MAINCOON_DESC`

The English source becomes just another translation, not the id. Rename the
button copy without breaking every locale. Search for "who uses this id" and
get a clean answer. Fits the design corpus which is Thai-first — English is
never authoritative.

**Do:**

- Enforce via CI: grep for `tr\("[a-z ]+"\)` and fail on any hit. The regex
  catches "lowercase or spaced source text" — a clear sign someone typed the
  English rather than an id.
- Group ids by domain prefix (`MENU_`, `BATTLE_`, `CLAN_`, `ITEM_`) so tab-
  completion in the translation CSV is fast.
- For format strings, put the placeholder count in the id: `WIN_XP_FMT_1_D`
  = "1 argument, decimal". Catches locale drift when the format changes.

**Avoid:**

- English source as key. `tr("You win!")` breaks when copy is rewritten.
- Reusing an id in two places with slightly different meaning. Split it.
  Localisers translate by context; ambiguous ids produce bad translations.
- Manual translation files edited outside the CSV/PO pipeline. Round-trip
  through the shared source or your translations will drift.
