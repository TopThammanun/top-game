---
id: resource-save-with-json-mirror
type: skill
title: Save as a Resource (.res) and mirror to JSON for support
domain: persistence
status: proposed
source: ai
enforcement: advise
tags: [save, resource, json, support, portability]
---

Godot's `ResourceSaver.save(save_data, "user://save.res")` is the fastest
and safest way to persist a typed Resource: types round-trip, references
resolve, engine handles versioning of primitive fields. Do that for the
primary save. Then also write a **read-only JSON mirror** (`user://save.json`)
containing the same state as plain data — invaluable for:

- **Support**: "please paste your `save.json` in the ticket" — much easier
  than reproducing a `.res`.
- **Migration**: when you break the save schema in a big way, the JSON
  mirror is a rescue path.
- **Anti-tamper**: sign the `.res`, and use the JSON mirror only as read-only
  diagnostic — the game trusts the `.res`, not the JSON.

The JSON mirror is regenerated on every save; it's a projection, not a
source of truth.

**Do:**

- Define a `PlayerSave extends Resource` with typed `@export` fields for
  every persisted value. Save via `ResourceSaver.save`.
- Write the JSON mirror in the same transaction: `save.res` first, JSON
  second; if either fails, roll back.
- Include a HMAC over the `.res` bytes if you want tamper detection (the
  moderate-effort, high-value option — server-side leaderboards check it).
- Store the last N saves as a ring buffer (`save.res`, `save.1.res`,
  `save.2.res`) so a corrupt save is recoverable.

**Avoid:**

- JSON as the primary save. It's slower to author, prone to type drift, and
  its "readability" is a footgun — players edit it.
- One giant save file that mixes preferences, gameplay state, and cache.
  Split them: `settings.res`, `save.res`, `cache.res`. Each has different
  cadence and durability needs.
- Trusting `user://` paths on mobile without testing the sandbox behaviour;
  Godot's `user://` maps to per-platform storage that has quirks.
