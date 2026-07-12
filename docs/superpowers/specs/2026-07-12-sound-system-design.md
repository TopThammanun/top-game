# Sound System — Architecture Design Spec

**Project:** TBH: Task Bar Hero (Whisker Realm / Purralia)
**Date:** 2026-07-12
**Status:** Approved design · ready for implementation plan
**Scope:** Full system (not a prototype slice)
**Source of truth:** `project_main_setting.md` §4 (Sound Direction) + `agents/sage/audio/` skills
**Deliverable of this doc:** the buildable Godot architecture; a `writing-plans` implementation
plan follows.

---

## 1. Context & goals

Sound Design is one of the two stated **pillars** of the game (`project_main_setting.md`
§0, §4) — alongside cuteness. The setting doc and five Sage skills already define the
*direction* (cozy medieval instruments, adaptive layering, tight/tactile SFX, purr
signature, Animalese cat voice). What is missing is the **system**: no runtime exists.

**What exists today**

- `data/audio/music_layers.json` — style, 6 instruments, 5 layers, 5 states (data only).
- `data/audio/sound_cues.json` — 8 cues with category/priority/mood/variants_min.
- Sage knowledge: `audio-bus-layout`, `adaptive-music-vertical-layering`,
  `variation-pool-for-frequent-sfx`, `dedicated-purr-ambient-bed`, `animalese-syllable-voice`.
- A partial **signal seam** in combat (see §12) — `GameState` (autoload) already emits
  wave/currency/run-end events audio can use; per-hit/defeat/skill combat events are resolved
  inline in `battle_view.gd` and need emit points added.

**What this design adds**

Two autoloads (`AudioRegistry`, `AudioDirector`), a 5-bus mixer, four JSON manifests, and
the eight runtime subsystems that realize the pillar: SFX pools, a reward chime ladder,
adaptive layered music with a state machine, the purr ambient bed, an Animalese cat-voice
sequencer, offline/AFK reward audio, sidechain ducking, and player-facing volume sliders.

**Design principles (inherited from the repo)**

1. **Data-driven, never hard-code `res://` paths** (CLAUDE.md) — cues live in JSON, resolved
   through a registry, exactly like `AssetRegistry`.
2. **Graceful degradation** — a missing `.wav` is a `push_warning` + skip, never a crash
   (mirrors `AssetRegistry.load_texture`).
3. **Controllable mix from day one** — every player is routed to a named bus at authoring
   time (`audio-bus-layout` skill); no orphan `Master` players.
4. **Decoupled** — audio listens to game signals; game code does not know audio exists.

---

## 2. Non-goals

- Authoring actual `.wav`/music assets. The system ships with **placeholder tones**
  (procedural `AudioStreamGenerator` beeps or silent stubs) and degrades gracefully; real
  Foley/music slots in later without code change.
- A full options/settings *scene*. This spec defines the volume-slider **API + persistence**;
  the actual settings panel UI is a thin consumer, specced only at the seam level.
- Music *composition*. We define the stem/state contract; the stems themselves are content.

---

## 3. Chosen approach — A: JSON manifest + two autoloads

Selected over (B) `.tres` Resource-first and (C) one monolithic `AudioManager`.

| Concern | Why A wins |
|---|---|
| Consistency | Mirrors `AssetRegistry` (JSON catalog + autoload + `push_warning` fallback) exactly. |
| Designer edits | Sound designers edit JSON, never `.gd`. |
| Gotcha avoidance | Defs are **plain `Dictionary`** (like `AssetRegistry.entries`), so the
  `class_name`-inside-autoload-preload failure (`agents/sage/godot-runtime/decisions/
  class-name-fails-inside-autoload-preloads.md`) is a non-issue — we never preload a
  self-referencing `class_name` Resource into the autoload chain. |
| Testability | Registry (data) is separable from Director (engine); both headless-testable. |
| Diff-friendliness | JSON diffs cleanly in git; `.tres` binaries do not. |

Explicit consequence: **we do not introduce custom `class_name` Resource types**
(`SfxDef`, `VoiceProfile`, `MusicZone`) as `.gd` classes loaded by the autoloads. They are
JSON **dictionary schemas** resolved by `AudioRegistry`. Cached `AudioStream`s are fine —
`AudioStream` is a built-in, no `class_name` registration involved.

---

## 4. High-level architecture

```
project.godot [autoload]  (order matters — see §7)
  AssetRegistry   (existing) ── resolves wav paths shared with art, if any
  GameState       (existing) ── emits gameplay signals
  AudioRegistry   (new)      ── loads JSON manifests, resolves cue id → AudioStream(s)
  AudioDirector   (new)      ── owns buses + player pools + music FSM; the ONLY play API

           game code / combat signals
                     │  (GameState signals + new battle_view emit points)
                     ▼
              ┌──────────────┐        get_cue()/streams_for()      ┌──────────────┐
              │ AudioDirector │ ───────────────────────────────▶  │ AudioRegistry │
              │  (engine/mix) │ ◀───────────────────────────────  │  (catalog)    │
              └──────┬───────┘        Dictionary + AudioStream[]   └──────┬───────┘
                     │                                                    │
        AudioStreamPlayer pools                              data/audio/*.json
        routed to 5 buses                                    (+ AssetRegistry for paths)
                     │
                     ▼
        default_bus_layout.tres  (Master → Music/SFX/Ambient/Voice/UI + Compressors)
```

Two layers, one seam: **`AudioRegistry` = what/where a sound is; `AudioDirector` = play it &
mix it.** Only `AudioDirector` is called by game code.

---

## 5. Bus layout — `default_bus_layout.tres`

Five children of `Master`, per the `audio-bus-layout` skill:

| Bus | Content | Effects |
|---|---|---|
| **Master** | root | limiter (optional) |
| **Music** | adaptive layered stems | `Compressor` (sidechain = SFX) → ducks on reward |
| **SFX** | combat hits, UI clicks, reward jingles | — |
| **Ambient** | purr bed, hearth crackle, wind | `Compressor` (sidechain = SFX) → dips on combat |
| **Voice** | Animalese cat syllables | — |
| **UI** | menu-only clicks that must stay audible when others duck | — |

Rules:
- Every `AudioStreamPlayer` sets `.bus` at creation — **never left as `Master`**.
- Volume is driven through `AudioServer.set_bus_volume_db(idx, linear_to_db(value))`, never
  per-player `volume_db` for category level (per-play jitter is the only per-player use).
- `Compressor.sidechain` on Music and Ambient is set to the `SFX` bus so reward/hit sounds
  produce the "everything politely quiets" duck (see §11.7).

---

## 6. New / changed files (manifest)

**New**
- `scripts/autoload/audio_registry.gd` — catalog autoload.
- `scripts/autoload/audio_director.gd` — engine autoload + public API.
- `default_bus_layout.tres` — 5-bus mixer (+ referenced from Project Settings › Audio).
- `data/audio/audio_shortcuts.json` — role → wav id/path (mirrors `asset_shortcuts.json`).
- `data/audio/music_zones.json` — per-zone stems + state→stem-volume matrix (supersedes the
  data currently in `music_layers.json`).
- `data/audio/voice_profiles.json` — per-clan Animalese profiles.
- `tests/audio_system_test.gd` (+ `.tscn`) — headless test (see §14).

**Changed**
- `data/audio/sound_cues.json` — extend schema (add `bus`, `variants`, `pitch_jitter`,
  `vol_jitter`, `tuned`, `duck`, `throttle_ms`).
- `data/audio/music_layers.json` — kept as human-readable reference; runtime reads
  `music_zones.json`. (Or fold into `music_zones.json`; decided in the plan.)
- `project.godot` — register `AudioRegistry` + `AudioDirector` autoloads (§7).
- `scripts/combat/battle_view.gd` — **add combat-event emit points** for audio (hit,
  unit-defeated, skill-cast, boss-wave, level-up) at the inline combat-resolution points;
  the live path has no per-hit/defeat signal today (§12). `BattleEngine` is **not** involved.

---

## 7. Autoload registration & order

```ini
[autoload]
AssetRegistry="*res://scripts/autoload/asset_registry.gd"
GameState="*res://scripts/runtime/game_state.gd"
AudioRegistry="*res://scripts/autoload/audio_registry.gd"
AudioDirector="*res://scripts/autoload/audio_director.gd"
```

Order rationale: Godot initializes autoloads top-to-bottom. `AudioRegistry` must load its
manifests before `AudioDirector` builds pools; `AudioDirector` connects to `GameState`
signals in `_ready()`, so `GameState` must already exist. Placing the two audio autoloads
**after** `GameState` guarantees both. `AudioDirector` waits on `AudioRegistry.audio_ready`
(or proceeds immediately if already loaded) — same pattern as `main.gd` waiting on
`AssetRegistry.catalog_ready`.

---

## 8. `AudioRegistry` — the catalog layer

Mirrors `AssetRegistry` structure and defensiveness.

```gdscript
extends Node
signal audio_ready

const CUES_PATH      := "res://data/audio/sound_cues.json"
const SHORTCUTS_PATH := "res://data/audio/audio_shortcuts.json"
const ZONES_PATH     := "res://data/audio/music_zones.json"
const VOICES_PATH    := "res://data/audio/voice_profiles.json"

var cues: Dictionary = {}        # id -> cue Dictionary
var shortcuts: Dictionary = {}   # role -> wav id/path (or Array of them)
var zones: Dictionary = {}       # zone_id -> zone Dictionary
var voices: Dictionary = {}      # clan_id -> voice profile Dictionary
var _stream_cache: Dictionary = {}   # path -> AudioStream
var loaded := false

func _ready() -> void: load_manifests()
func load_manifests() -> void          # parse all four JSON files, tolerant of missing/malformed
func get_cue(id: String) -> Dictionary # {} if unknown (never null)
func has_cue(id: String) -> bool
func streams_for(id: String) -> Array  # Array[AudioStream]; resolves variants via shortcuts+cache
func get_zone(zone_id: String) -> Dictionary
func get_voice(clan_id: String) -> Dictionary
func load_stream(path_or_id: String) -> AudioStream   # cached; push_warning + null on miss
```

- `streams_for()` resolves a cue's `variants` (each a wav id/path or a shortcut role) to
  concrete `AudioStream`s, caching by path. Missing files → `push_warning`, omitted from the
  returned array (a cue with zero resolvable streams is a no-op at play time, not a crash).
- Path resolution order (mirrors CLAUDE.md "shortcuts, then ids, then paths"): shortcut role
  → wav path; a raw `res://…/foo.wav` is accepted as-is.

---

## 9. Data manifests (JSON schemas)

### 9.1 `sound_cues.json` (extended)

```jsonc
{
  "id": "ui_click",
  "category": "sfx",          // sfx | reward | voice | ambient
  "bus": "UI",                // Master | Music | SFX | Ambient | Voice | UI
  "variants": ["sfx.ui_click"], // wav ids / shortcut roles; 3–5 for frequent sounds
  "variants_min": 4,
  "pitch_jitter": 0.05,       // randfn(0,1)*this on pitch_scale; 0 for tuned hits
  "vol_jitter": 1.5,          // dB
  "tuned": false,             // true = musical hit, NO jitter (level_up, chest jingle)
  "duck": false,              // true = trigger Music/Ambient duck when it plays
  "throttle_ms": 0,           // min gap between plays (e.g. hit spam) ; 0 = none
  "reward_layer": 0,          // 1..5 for the reward ladder (see §11.2)
  "mood": "tight_tactile"     // authoring note only
}
```

Existing 8 cues are migrated into this schema. Reward cues (`loot_tiny_drop` …
`boss_clear`) get `tuned: true`, `duck: true`, and their `reward_layer` 1–5.

### 9.2 `audio_shortcuts.json` (new — mirrors `asset_shortcuts.json`)

```jsonc
{
  "sfx.ui_click":   ["res://asset/audio/sfx/ui_click_a.wav", ".../ui_click_b.wav"],
  "sfx.hit":        ["res://asset/audio/sfx/hit_a.wav", ".../hit_b.wav", ".../hit_c.wav"],
  "reward.chest":   ["res://asset/audio/reward/chest_stage.wav"],
  "ambient.purr":   ["res://asset/audio/ambient/purr_a.wav", ".../purr_b.wav"],
  "voice.syl.mya":  ["res://asset/audio/voice/mya_01.wav", "..."]
}
```

Swap art/audio by editing the shortcut, never the caller (same rule as assets).

### 9.3 `music_zones.json` (new)

```jsonc
{
  "emberhearth": {
    "bpm": 84, "key": "D_dorian", "loop_len_s": 72,
    "stems": {
      "ambient_bed":    "res://asset/audio/music/ember_ambient.ogg",
      "warm_chords":    ".../ember_chords.ogg",
      "melody":         ".../ember_melody.ogg",
      "soft_percussion":".../ember_perc.ogg",
      "tension":        ".../ember_tension.ogg"
    },
    "states": {                       // state -> per-stem target volume (0..1)
      "idle":            {"ambient_bed":1.0,"warm_chords":0.7,"melody":0.5,"soft_percussion":0.0,"tension":0.0},
      "wave_pressure":   {"ambient_bed":1.0,"warm_chords":0.9,"melody":0.7,"soft_percussion":0.8,"tension":0.3},
      "boss":            {"ambient_bed":0.8,"warm_chords":1.0,"melody":0.9,"soft_percussion":1.0,"tension":1.0},
      "reward":          {"ambient_bed":1.0,"warm_chords":1.0,"melody":1.0,"soft_percussion":0.6,"tension":0.0},
      "region_restored": {"ambient_bed":1.0,"warm_chords":1.0,"melody":1.0,"soft_percussion":0.7,"tension":0.0}
    }
  }
}
```

All stems share bpm/key/loop length so a crossfade never lurches
(`adaptive-music-vertical-layering` skill).

### 9.4 `voice_profiles.json` (new)

```jsonc
{
  "siamheart":  {"pitch_semitones": 3,  "rate_cps": 22, "filter": null,       "reverb": null,   "syllables": ["mya","nya","mrr"]},
  "maincoon":   {"pitch_semitones": -3, "rate_cps": 14, "filter": null,       "reverb": null,   "syllables": ["mrr","meh","prr"]},
  "ragdollan":  {"pitch_semitones": -1, "rate_cps": 16, "filter": "lowpass",  "reverb": null,   "syllables": ["prr","mya","meh"]},
  "bengalis":   {"pitch_semitones": 1,  "rate_cps": 26, "filter": null,       "reverb": null,   "syllables": ["nya","mya","mrr"]},
  "persephone": {"pitch_semitones": 0,  "rate_cps": 18, "filter": null,       "reverb": "room", "syllables": ["mrr","prr","meh"]},
  "shorthold":  {"pitch_semitones": 0,  "rate_cps": 18, "filter": null,       "reverb": null,   "syllables": ["mya","meh","prr"]}
}
```

Per §1.4 lore: Siamese higher/faster (vocal clan), Maine Coon deeper/slower, Ragdoll soft
lowpass, Bengal fast, Persian neutral with room. `rate_cps` = syllables per second target
(≈ 1 syllable / 2–3 text chars). Registers (calm/excited/hurt/questioning) apply a small
pitch offset on top of the anchor.

---

## 10. `AudioDirector` — the engine layer (public API)

The **only** surface game code calls.

```gdscript
extends Node

# --- lifecycle ---
func _ready()                                 # build buses cache, player pools, load settings,
                                              # apply volumes, connect GameState signals with
                                              # the is_ready guard (§12), boot zone+purr

# --- one-shots ---
func sfx(cue_id: String, pos := Vector2.INF)  # pooled play; variation pick + jitter + throttle
func reward(layer: int)                       # 1..5 reward ladder; tuned, triggers duck
func voice(clan_id: String, text: String, register := "calm")  # Animalese sequence
func stop_voice()

# --- music ---
func play_zone(zone_id: String)               # start all stems in sync at that zone
func set_music_state(state: String)           # tween per-stem volumes to the state matrix
func stop_music(fade_s := 1.5)

# --- ambient ---
func purr(on: bool)                           # start/duck the purr bed (never hard stop mid-combat)

# --- mix / settings ---
func set_bus_volume(bus: String, value01: float)   # linear_to_db → AudioServer; persists
func get_bus_volume(bus: String) -> float
func save_settings() ; func load_settings()        # ConfigFile at user://audio_settings.cfg
```

Internal: a **player pool** per bus (N `AudioStreamPlayer`, round-robin, so overlapping
one-shots never allocate mid-frame); a `Dictionary` of active music stem players; a `Tween`
per stem for crossfades; a `VoiceSequencer` helper node; per-cue `last_played_ms` for
throttling.

---

## 11. Subsystem specs

### 11.1 SFX — variation pools (`variation-pool-for-frequent-sfx`)
`sfx(id)` → look up cue → `AudioRegistry.streams_for(id)` → pick random stream → play on a
free pooled player on `cue.bus`. If not `tuned`: apply `pitch_scale += randfn(0,1)*pitch_jitter`
and `volume_db += randfn(0,1)*vol_jitter`. `throttle_ms` suppresses replays within the window
(hit spam). 3–5 variants authored per frequent sound; the "world texture" effect depends on it.

### 11.2 Reward chime ladder
Five tuned stingers, `reward(layer)` where layer maps to a cue:
`1 loot_tiny_drop · 2 loot_rare_drop · 3 level_up · 4 afk_chest_open · 5 boss_clear`.
Tuned → **no jitter** (they must sound identical every time). `duck: true` → each fires the
Music/Ambient duck. Higher layers are richer stingers (may stack lower layers as content).
This is the dopamine loop (setting doc §4.3).

### 11.3 Music — adaptive vertical layering + state machine
`play_zone(id)` instantiates one `AudioStreamPlayer` per stem on the **Music** bus, all
`play()`-ed on the same frame with identical loop length → phase-locked. `set_music_state(s)`
reads `zones[id].states[s]` and tweens each stem's `volume_db` to `linear_to_db(target)` over
1–2 s. No track swaps — only stem crossfades (skill: cross-track cozy transitions are hard,
cross-stem are almost free). State transitions come from signals (§12):

```
        idle ──wave_changed(pressure)──▶ wave_pressure ──boss wave──▶ boss
          ▲                                   │                              │
   region_restored ◀──run_ended("won")────────┴─────wave_cleared─▶ reward ───┘
                                                       (brief pulse, returns to prior)
```

`reward` is a short accent state that auto-returns to the pre-reward state after the chime.

### 11.4 Ambient purr bed (`dedicated-purr-ambient-bed`)
2–3 authored 20–30 s loops on the **Ambient** bus at −24…−30 dB. `purr(true)` on
menu/base/between-wave; on combat enter, **dip to −40 dB** (not stop) via the sidechain +
an explicit floor; resume on wave-clear. Slowly rotate between the 2–3 loops so the ear never
locks onto a repeat. Volume tracks the Ambient slider. Never baked into music stems.

### 11.5 Cat voice — Animalese sequencer (`animalese-syllable-voice`)
`voice(clan, text, register)` → a `VoiceSequencer` plays one syllable per ≈2–3 characters of
`text` on the **Voice** bus. Pitch = clan anchor (`voice_profiles.json`) + small per-syllable
jitter (anchored, not fully random — random reads as broken). Syllable takes < 200 ms. Apply
clan `filter`/`reverb`. Stop on dialogue skip (`stop_voice()`). Register adds a pitch offset
(excited +, hurt −, questioning rising). Because it is syllable synthesis it needs no
localization — identical in Thai/EN/JP. Initial trigger point: `_on_skill_pressed` in
`battle_view.gd` (Siamese "voice casting" per lore) and any future dialogue/text-bubble system.

### 11.6 Offline / AFK reward audio
When the player returns with accumulated offline rewards, play `reward(4)` (afk_chest) **once**
— a single satisfying moment, not per-item spam (setting doc §2.2 "AFK chest = one dopamine
hit on return"). Trigger on the offline-reward-claim event when that system lands; until then
the hook is a no-op that degrades gracefully.

### 11.7 Ducking / sidechain
`Compressor` on Music and Ambient with `sidechain = SFX`. Reward chimes and heavy hits route
to SFX; when they fire, Music/Ambient duck ≈ −6 dB and release smoothly → "chest opens,
everything politely quiets" (skill). Purr additionally floors to −40 dB during combat.

### 11.8 Volume sliders + persistence
Six logical sliders (Master + 5 buses). `set_bus_volume(bus, 0..1)` →
`AudioServer.set_bus_volume_db(idx, linear_to_db(value))` and persists to
`user://audio_settings.cfg` (`ConfigFile`). `load_settings()` on boot applies them before
first sound. Cozy-audience UX: a player can keep the purr and mute combat, or vice-versa.

---

## 12. Integration seam (live path: `battle_view.gd` + `GameState`)

Audio **listens**; game code stays audio-agnostic. Verified against the real main scene
(`project.godot` → `run/main_scene = scenes/combat/battle.tscn` → `battle_view.gd`).

> **Correction from the first draft.** `BattleEngine`
> (`scripts/runtime/battle_engine.gd`) and its `damage_dealt` / `unit_defeated` /
> `skill_used` / `boss_telegraph` signals are used **only by the legacy `main.gd` /
> `main.tscn` prototype**, which is *not* the scene that runs. `battle_view.gd` never
> references `BattleEngine`; it resolves combat **inline**. Do **not** wire audio to
> `BattleEngine` — no combat sound would ever fire.

**`GameState` (autoload) — the live event bus.** `battle_view.gd` calls its mutators
(`advance_to_wave`, `add_currency`, `end_run`, `reset_run`, `seed_run_party`,
`recruit_member`). `AudioDirector` connects to these signals in `_ready()`:

| Signal (emitted on the live path) | Audio reaction |
|---|---|
| `wave_changed(n)` (via `advance_to_wave`) | `set_music_state("wave_pressure")`, or `"boss"` on boss waves |
| `currency_changed(v)` (via `add_currency`) | optional coin `sfx` (throttled) |
| `run_ended(status)` (via `end_run`) | won → `region_restored` + `reward(5)`; wiped → defeat sting + soften music |

**Signals that exist on `GameState` but must be confirmed/added on the live path** — the
implementation plan verifies each is actually emitted by `battle_view.gd` and adds the emit
point where missing: `wave_cleared` (→ milestone `reward()`), `loot_event` (→ loot `sfx`;
upgrade to a structured rarity signal, see §16), `progression_changed`, `party_changed`,
`state_ready`.

**Combat-event audio has NO live signal today.** Per-hit, unit-defeated, skill-cast, and
boss-telegraph do **not** exist on `battle_view.gd`'s inline resolution. This audio requires
**new emit points added to the live combat path** (new signals on `GameState`, or a small
`AudioEvents` bus, emitted from `battle_view.gd` where damage/defeat/skill/boss resolve) —
real, listed work, not a one-liner. Concrete existing hooks the plan attaches to:
`_on_skill_pressed` (skill-cast `sfx` + caster-clan `voice`), `_on_levelup_chosen` / the
level-up-draft open point (`reward(3)` — `progression_changed` is too broad to mean "level
up"), and the boss-wave branch inside `advance_to_wave` (`set_music_state("boss")`).

**`state_ready` ordering hazard (fix, don't discover it later).** Autoloads init
top-to-bottom and `GameState` is listed **before** the audio autoloads, so `GameState` may
emit `state_ready` **before** `AudioDirector._ready()` runs — a naive
`state_ready.connect()` silently misses it and music/purr never boot. Use the guard
`battle_view.gd:228` already uses:

```gdscript
if not GameState.is_ready:
    GameState.state_ready.connect(_boot_audio, CONNECT_ONE_SHOT)
else:
    _boot_audio()   # play_zone(current) + purr(true); AFK cue if rewards pending
```

Net: `GameState` is the correct seam and is partly live already; the combat-event half needs
emit points added to `battle_view.gd`. `BattleEngine` is not used.

---

## 13. Godot gotchas honored

- **`class_name`-in-autoload-preload** (`class-name-fails-inside-autoload-preloads.md`):
  avoided structurally — audio defs are plain `Dictionary`; no self-referencing `class_name`
  Resource is preloaded into `AudioRegistry`/`AudioDirector`. If a helper node
  (`VoiceSequencer`) is used, it is a child node, not a preloaded self-referencing class, and
  its factory methods carry no `-> Self` return annotations.
- **Bus index lookups** cached once in `_ready()` (`AudioServer.get_bus_index`) — not per play.
- **`config/features="4.2"`** — stick to 4.2-safe APIs (`AudioServer`, `Tween`,
  `AudioStreamPlayer`, `linear_to_db`). No 4.3+-only audio calls.
- **Headless safety**: guard any editor-only audio calls so the headless test (§14) runs.

---

## 14. Testing

Follow `tests/roguelike_loop_test.gd` precedent (headless, bounded, deterministic). Audio is
verifiable **without hearing it** by asserting engine state:

- `audio_system_test.gd` boots the autoloads and asserts: all 5 buses exist by name; every
  cue in `sound_cues.json` resolves (`has_cue`), and each is routed to a valid bus; a missing
  wav degrades to a warning, not a crash; `set_music_state()` sets the expected per-stem
  target volumes from the matrix; `set_bus_volume()` round-trips through
  `get_bus_volume()`; `voice()` on each clan produces the profile's syllable count for a
  sample string.
- Manual "verify it runs" per CLAUDE.md: `run_game.ps1` and confirm no audio errors in the
  Godot log (report actual output).

---

## 15. Build order (phased, even though scope is full)

Each phase is independently runnable and leaves the game green.

1. **Buses + skeletons** — `default_bus_layout.tres`, register autoloads, `AudioRegistry`
   loads manifests, `AudioDirector` builds pools + settings load/save + slider API.
2. **SFX pool** — variation pick + jitter + throttle; wire `ui_click`; **add a combat-hit
   emit point** in `battle_view.gd` (no live hit signal exists — §12) and play hit sfx off it.
3. **Reward ladder + ducking** — 5 layers, tuned, `Compressor` sidechain; wire `run_ended`
   and level-up (`_on_levelup_chosen` → `reward(3)`); add wave-clear / boss-defeat emit
   points where missing.
4. **Purr ambient** — bed + combat dip; boot via the `GameState.is_ready` guard (§12).
5. **Music layering + FSM** — stems, `play_zone`, `set_music_state`, tween crossfades; wire
   `wave_changed` and the boss-wave branch of `advance_to_wave`; resolve on `run_ended`.
6. **Cat voice** — `VoiceSequencer` + per-clan profiles; wire `_on_skill_pressed` (caster clan).
7. **AFK reward audio** — `reward(4)` on offline-claim (no-op until that system exists).
8. **Options sliders UI** — thin panel consuming the slider API (optional/last).
9. **Headless test** — `audio_system_test.gd` green.

**Acceptance (whole system):** cues data-driven and hot-swappable via JSON; every player on a
named bus; music thickens on late waves and resolves on region-restore; purr bed present in
lulls and dips in combat; reward chimes duck the mix; cat voice differs per clan; six working
volume sliders that persist; missing assets warn (never crash); headless test green;
`run_game.ps1` shows no audio errors.

---

## 16. Open questions (resolve during planning, non-blocking)

- Keep `music_layers.json` as a reference doc, or fold entirely into `music_zones.json`?
- Milestone→reward-layer mapping for `wave_cleared` (every N waves = which layer?).
- Whether `loot_event(msg)` should be upgraded to a structured signal (rarity, id) so audio
  can pick tiny vs rare without string-parsing the message.
