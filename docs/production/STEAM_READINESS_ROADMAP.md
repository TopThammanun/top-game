# Steam Readiness Roadmap

**Written:** 2026-07-04 after the first-playable milestone.
This document maps what remains between the current playable prototype and a
Steam launch. It is intentionally conservative: no timelines shorter than the
work actually requires.

## Where the prototype is now

Verified running via `tools/gate_check.ps1` and
`tools/capture_runtime_screenshot.ps1`:

- Godot 4.7 project boots with `AssetRegistry` and `GameState` autoloads.
- Emberhearth game shell renders on `main.tscn` with header, loot feed, MapView,
  and Taskbar.
- MapView now uses a compact battle-strip layout: the tile map is the action
  surface, with party and monsters positioned directly on the lane.
- Party of 4 loads from `data/units/starter_party.json` joined with per-clan
  base stats in `data/units/clans.json`.
- Wave 1-10 monsters load from `data/combat/enemies.json` through
  `data/combat/mvp_waves.json`; repeated enemy archetypes receive unique
  runtime instance ids for targeting and effects.
- Auto-battle ticks: party attacks lowest-HP monster every 1.4s; monsters attack
  the front lane first every 1.9s.
- Two taskbar skills fire real effects: Wildstripe burst (2x damage for 3s) and
  Cloudfur heal (25% party heal).
- Combat now has visual game-feel feedback: idle bobbing, attack lunges, hit and
  heal floating numbers, skill pulses, boss warning flashes, reward bursts, and
  taskbar press/cooldown/ready animations.
- Currency, Reweave upgrades, and AFK chest rewards work through `GameState`.
- Local `user://save.json` persists Pawcoins, best wave, Reweave level, and the
  AFK chest clock with `schema_version: 1`.
- The taskbar has a Replay command so the player can restart the 10-wave run
  stronger after a wipe or win.
- A compact loot feed shows wave rewards, AFK chest claims, run start, and boss
  chest feedback.
- Wave 10 emits a visible Hushweave boss telegraph before the next enemy strike
  window.
- Wave progression advances on clear; run status `won` / `wiped` is handled.
- Bootstrap smoke test (`tests/bootstrap_test.tscn`) passes headless.

## Deliberately Deferred After The Playable MVP Pass

Still MVP-scoped, still small in code. Each is 1 focused session:

- **Skills per hero:** Ironmane taunt, Cloudfur cleanse, Wildstripe-specific
  timing, and support tempo identity.
- **Loot drops:** equipment ids from `data/economy/equipment.json`, inventory
  display, and drop rarity feedback.
- **Persistence hardening:** move shipped saves to `.res` plus JSON mirror,
  keeping the current schema-versioned JSON as the support/debug projection.
- **Reward polish:** chest opening ceremony, richer loot feed content, and audio
  cues. The current build has visual reward burst feedback, but no chest scene
  or SFX yet.
- **Sprite animation:** choose frame columns/rows over time instead of tweening a
  single idle frame.
- **Real Emberhearth TileMap:** use a `TileMapLayer`/TileMap workflow when the
  prototype needs collision, pathing, or editor-authored map layers.

## Vertical Slice (3-6 Months Of Build Work)

Per `docs/production/MILESTONES_AND_ACCEPTANCE.md`, the vertical slice still
needs:

- friendly gacha with visible pity and rate disclosure
- duplicate-to-shard exchange
- equipment affix reroll
- cosmetics inventory and shop
- adaptive music state machine (idle/combat/boss/reward)
- second playable region (Silkspiredale or Tuna Coast)

## Soft Launch (6-10 Months)

- third playable region
- daily/weekly loop
- guild or social-lite
- battle pass tracks
- first seasonal event
- KPI telemetry hooks (retention, session length)

## Steam-Only Work Not Covered By The Game Spec

These are pure launch-engineering and operations items, not gameplay:

- **Steamworks SDK integration:** achievements, cloud saves, rich presence,
  Workshop if needed.
- **Storefront assets:** capsule art, library hero, header, 6+ screenshots,
  trailer.
- **Store page:** description, supported languages, tags, pricing.
- **Localization:** Thai and English at minimum, per project identity. Translate
  every UI string, item name, enemy name, region name, and system prompt.
- **Content age rating:** ESRB (US), PEGI (EU), USK (DE), IARC self-report.
- **Third-party audits:** cheat detection strategy if a leaderboard ships.
- **Marketing:** Steam Next Fest slot, press outreach, wishlist funnel,
  community Discord.
- **Legal:** EULA, privacy policy, and gacha-rate disclosure where required.
- **Playtesting and QA:** closed beta cohort, bug triage, balance passes.
- **Audio production:** original OST, SFX library, Animalese voice pack.
- **Art production:** proper unit sprites, boss art, region tilesets, UI polish,
  particles, and cutscene panels.

## Honest Bottom Line

The current prototype is a first playable: one region, one loop, placeholder art
from the Franuka packs, local persistence, and basic boss/reward feedback. The
design docs give soft launch a 6-10 month window, and Steam release sits after
that. The gameplay code is small and correct; content, art, audio, localization,
storefront, marketing, and legal work remain person-weeks or person-months per
layer.

**Next single-session bite (recommended):** persistence hardening or reward
polish. Persistence hardening turns the prototype JSON save into the shipped
`.res` + JSON mirror shape; reward polish adds chest animation/audio so the
working loop feels better without broadening scope.
