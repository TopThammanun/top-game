---
id: authority-order
type: team_decision
title: Authority order when design docs disagree
domain: design-docs
tags: [conflict-resolution, source-of-truth]
status: proposed
enforcement: block
applies_to: [design-docs, "docs/**", "project_main_setting.md"]
source: ai
related: []
timestamp: 2026-07-04T00:00:00Z
---

When two documents disagree, resolve them in **this order** (from
`docs/DESIGN_SOURCE_OF_TRUTH.md`, mirrored in `data/design_sources.json`):

1. `project_main_setting.md` — lore, tone, world, clans, magic, monetization
   principles, sound direction.
2. `docs/TBH_GAME_SPEC_1_TO_100.md` — implementation sequence and acceptance
   criteria.
3. `docs/PROJECT_IDENTITY.md` and `data/project_identity.json` — canonical names.
4. `docs/ASSET_MAP.md`, `data/asset_catalog.json`, and
   `data/asset_shortcuts.json` — asset usage.
5. Local scene/script `README.md` files — folder-specific intent.

**Rules for using this order:**

- Never silently reconcile — if two docs disagree, state which won and why,
  then propose an edit to the losing doc so future readers don't hit the same
  conflict.
- The order is transitive: a lower-ranked doc that contradicts a higher-ranked
  one is *wrong*, not "another view".
- Data files (`data/*.json`) tie their prose sibling in rank — treat them as
  the same authority; if they disagree with each other, fix the mismatch
  before continuing.

Why "block": conflicts get louder as the corpus grows. Every unresolved
disagreement becomes an ambush for the next agent.
