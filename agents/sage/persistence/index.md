# persistence - save / load / migration

Rules, skills, and decisions for save files: format, migration, and
supportability.

## Skills

- [skills/resource-save-with-json-mirror.md](skills/resource-save-with-json-mirror.md) - save as `.res` for engine parity, mirror to JSON for support (proposed - advise)
- [skills/save-schema-versioning.md](skills/save-schema-versioning.md) - every save has a `schema_version`; migrations run on load (proposed - advise)

## Decisions

- [decisions/game-state-owns-prototype-json-save.md](decisions/game-state-owns-prototype-json-save.md) - `GameState` owns the prototype JSON save boundary (proposed - advise)
