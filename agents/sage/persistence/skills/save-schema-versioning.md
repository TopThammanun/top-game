---
id: save-schema-versioning
type: skill
title: Every save carries a schema_version; migrations run on load
domain: persistence
status: proposed
source: ai
enforcement: advise
tags: [save, migration, versioning, upgrade]
---

Live games break save schemas — new fields, renamed fields, restructured
subtrees. The moment you ship, the game must be able to load *any past
save* and migrate it forward. The cheapest way: every save has a
`schema_version: int` field, and load runs `MIGRATIONS[n → n+1]` in
sequence until it reaches the current version.

Write migrations as pure functions on the parsed JSON mirror (or on the
Resource fields via a `_load` hook). Test each migration on a captured
save from a previous version — keep a `tests/fixtures/save_v1.res`,
`save_v2.res` set that grows every schema bump.

**Do:**

- Add `schema_version` from day one (start at `1`) — even before any breaking
  change is planned. Retrofitting the field later is worse than starting with it.
- Write one migration function per version bump: `func migrate_v3_to_v4(data)`.
  Never skip versions.
- Assert `data.schema_version <= CURRENT_VERSION` on load. Newer saves on
  older client = show a "please update" screen, don't crash.
- Fixture-test every migration end-to-end: load an old save, walk it forward,
  compare to a hand-authored expected result.

**Avoid:**

- "It'll never break" saves without a version field. Every live game breaks
  its schema; the timeline is measured in weeks, not years.
- Big-bang migrations that skip 4 versions at once. Small stepped migrations
  compose; giant ones don't test.
- Silent field drops. If a migration removes data, log it — support tickets
  will ask "where did my costume go?" and you'll want an answer.
