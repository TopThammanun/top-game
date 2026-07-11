# Design: Roguelike card-draft pivot (Vampire-Survivors-style progression on the auto-battler)

- **Date:** 2026-07-12
- **Status:** Approved design
- **Branch:** `feat/auto-battler-combat-pivot`
- **Builds on:** `docs/superpowers/specs/2026-07-05-auto-battler-combat-pivot-design.md`
  (the real-time side-scroll auto-battler + `scripts/combat/*` core). This pivot **adds a
  roguelike progression layer on top of that scene** — it does not replace the combat.
- **Setting:** Unchanged — TBH: Task Bar Hero / Whisker Realm / Purralia, cat clans, Franuka art.

## 1. Goal & scope

Turn the fixed-party auto-battler into a **run-based roguelike** in the spirit of Vampire
Survivors, **while keeping the existing side-scroll auto-battle** (game-form decision: evolve, do
not rebuild top-down):

- The player **picks ONE starter cat before the run**; the party starts at size 1.
- Enemies grant **XP**; on **level-up the battle pauses** and the player **drafts 1 of 3 cards**.
- Cards are of four kinds: **recruit** a new party cat (up to 5), **+stat** upgrade, **+skill**
  upgrade, or a party-wide **passive**.
- Two run shapes share one draft loop: **Campaign** (finite waves → boss → win) and **Endless**
  (escalating waves, boss every N, play for score).
- **Light meta-progression** between runs: a run yields currency; the player unlocks cats and
  buys small permanent boosts. Existing gacha/idle meta screens are set aside (not deleted).
- **Reuse the existing art** (`asset/`, `asset_sliced/`) via `AssetRegistry` shortcuts — no new art.

### Non-goals (this spec)
- No top-down / twin-stick movement (explicitly rejected — see §12 game-form decision).
- No new combat math — the `scripts/combat/*` core (StatSystem/DamageCalculator/CombatSkill/
  SkillEffect/CharacterFactory) is consumed unchanged.
- Evolutions, reroll/skip/banish, and full meta UI are **later slices** (§10), not the first slice.

## 2. Architecture: module map & boundaries

Strict one-way dependency: **scene layer depends on pure-logic roguelike layer; the logic never
depends on the scene.** Same discipline as the combat core. `battle_view.gd` is already large
(2636 lines) — this pivot deliberately puts new logic/UI in **new focused files** and keeps the
edits inside `battle_view.gd` thin (accrue XP, detect level-up, open the draft, apply a pick).

### New — pure-logic roguelike core (`scripts/roguelike/`, all `RefCounted`, headless-testable)
| File | Responsibility |
|---|---|
| `card_data.gd` | one card definition: `id, type, rarity, title, desc, target, effect` (parsed from JSON) |
| `card_system.gd` | owns the card pool; `draw(n)`, rarity + recruit↔upgrade weighting, "no dead card" filtering, `describe(card)` deltas; `resolve(card)` → a plain result descriptor the scene applies |
| `run_state.gd` | run-scoped state: `mode`, party ids, per-unit `xp/level`, `total_level`, rerolls/banish counts, run meta bonuses; XP curve + `add_xp()` → returns how many level-ups to process |

### New — scene/UI layer
| File | Responsibility |
|---|---|
| `scripts/ui/draft_view.gd` | the level-up overlay: its own `CanvasLayer`, full-rect dim, 3 card `Button`s built from UI shortcuts; emits `card_chosen(card)` / `rerolled()` |

### Changed — existing files (thin, surgical)
| File | Change |
|---|---|
| `scripts/combat/battle_view.gd` | ~5 hooks (§7): XP on kill, level-up detect+pause, open `DraftView`, apply the chosen card (permanent modifier / skill mutate / recruit), resume |
| `scripts/runtime/game_state.gd` | pre-run `chosen_starter`, relax the party-size assert, `end_run(result, reward)`, meta persist (schema v2) |
| `scripts/runtime/wave_state.gd` | procedural scaling for endless (stat × wave index, boss every N) beyond the authored catalog |
| `data/units/clans.json` | add per-clan `sprite_shortcut` (fixes the archetype sprite collision) + 2 new cats |
| `data/combat/skills.json`, `data/asset_shortcuts.json` | 2 new skills + `unit.bomber_*` + card-UI shortcuts |

### New — data
| File | Responsibility |
|---|---|
| `data/roguelike/cards.json` | the full card pool (recruit/stat/skill/passive, rarity, effect params) |
| `data/roguelike/run_config.json` | xp curve constants, draft size, mode params (campaign length, endless boss cadence + scaling) |

## 3. RunState (`scripts/roguelike/run_state.gd`)

The single owner of run-scoped numbers. Pure `RefCounted`.

- **Fields:** `mode: String` (`"campaign"|"endless"`), `party_ids: Array[String]`, per-unit
  progression `unit_xp: Dictionary` (unit key → `{xp, level}`), `total_level: int`,
  `rerolls: int`, `banishes: int`, `meta: Dictionary` (permanent bonuses read from GameState),
  `pending_levelups: int`.
- **XP curve (spec §4 research):** `xp_to_next(level) = 10 + 6*(level-1) + floor(level*level*0.4)`.
  Constants live in `run_config.json` so tuning is data, not code.
- **`add_xp(amount) -> int`:** adds to the run's shared level pool, returns the number of new
  level-ups crossed (usually 0 or 1; a boss chunk may cross several). The scene drains
  `pending_levelups` one draft at a time.
- **Level model (decision):** the run has a **single shared level** that drives the XP curve and
  the draft cadence (VS-style — the player levels, not individual cats). Per-cat `level` exists
  only for **recruit arrival scaling** (§6) and cosmetic display; it is derived, not the XP owner.
- **`starting_party()`:** returns the one chosen starter id (from GameState) as the initial
  `party_ids`.

## 4. CardSystem (`scripts/roguelike/card_system.gd`)

Pure `RefCounted`. Loads `cards.json` once; every draft calls `draw(3)`.

### 4.1 Card taxonomy (`type`)
| type | effect | how the scene applies it (via combat core) |
|---|---|---|
| `recruit` | add a roster cat to the party (party < 5 only) | append `UnitState` to `GameState.party`; cat arrives next wave at scaled level (§6) |
| `stat` | permanent +stat to one cat or whole party | `stats.add_modifier(StatModifier.new(key, FLAT\|PERCENT, value, "draft:<id>", 0.0))` — duration 0 ⇒ permanent (`stat_modifier.gd:24`) |
| `skill` | improve a cat's active skill | mutate `u["skill"]` (`CombatSkill`): lower `.cooldown`, raise `.skill_ratio`, raise `.max_targets` |
| `passive` | party-wide run aura (+XP, +gold, +crit, lifesteal, back-row ATK, …) | set a flag in `RunState.meta` and/or add a party-wide permanent modifier to every current+future ally |

### 4.2 Draw rules
- **3 cards per level-up** (boss draft = 4 — later slice). Never two identical cards in one draw.
- **Rarity weights:** common 60 / rare 28 / epic 10 / legendary 2, plus **pity**: each draft with
  no epic+ raises epic/legendary weight by +2% (reset on hit). Bosses guarantee ≥1 epic (later).
- **recruit↔upgrade weighting (the key curve):**
  `recruit_weight = clamp(0.45 - 0.06 * party_size, 0.0, 0.45)`.
  Party 1 → ~40% recruits; party 3 → ~25%; party 5 → 0. Freed weight flows to stat/skill/passive.
- **"No dead card" filtering (resolve in order):**
  1. Filter the pool to only *applicable* cards before drawing (no recruit for a cat already in the
     party; no skill card for a role not present; party full ⇒ no recruit at all).
  2. If party is full, a would-be recruit slot becomes a **Reinforcement** card (+1 level to the
     lowest cat, or a party-wide +stat).
  3. **Guarantee ≥1 upgrade card** every draw, so a draft is never all-recruit (all-dead at cap).
- **Anti-rot:** after a given stat has been picked ~4×, down-weight further copies 50%.

### 4.3 API
- `load_all()` — read `cards.json` + `run_config.json`.
- `draw(run_state) -> Array[CardData]` — returns 3 valid, weighted, de-duplicated cards.
- `resolve(card, run_state) -> Dictionary` — a plain descriptor the scene applies, e.g.
  `{ kind:"stat", scope:"party"|"unit", unit_key, stat, mod_type, value }`,
  `{ kind:"recruit", clan_id, arrival_level }`,
  `{ kind:"skill", unit_key, field, value }`,
  `{ kind:"passive", passive_id, params }`.
  Keeping `resolve` scene-free keeps CardSystem headless-testable; the scene owns the mutation.
- `describe(card, run_state) -> String` — the delta text shown on the card ("+18% party ATK",
  "unlocks AoE", "recruit Quillwhisker — ranged"). **Required** (§12 auto-battler pitfall: the
  draft is the entire skill expression, so choices must be legible).

## 5. Card data schema (`data/roguelike/cards.json`)

Flat array; one object per card. Example shapes:

```json
[
  { "id": "atk_party_s", "type": "stat", "rarity": "common", "title": "Sharpened Claws",
    "target": "party", "effect": { "stat": "atk", "mod": "percent", "value": 0.08 } },
  { "id": "hp_unit_m", "type": "stat", "rarity": "rare", "title": "Thick Fur",
    "target": "unit", "effect": { "stat": "hp", "mod": "percent", "value": 0.20 } },
  { "id": "recruit_quillwhisker", "type": "recruit", "rarity": "rare", "title": "Quillwhisker joins",
    "effect": { "clan_id": "abyssian_quillwhisker" } },
  { "id": "skill_cdr_wildstripe", "type": "skill", "rarity": "epic", "title": "Faster Thornslash",
    "target": "unit", "effect": { "field": "cooldown", "op": "mul", "value": 0.75 } },
  { "id": "passive_bloodpurr", "type": "passive", "rarity": "epic", "title": "Bloodpurr",
    "effect": { "passive_id": "lifesteal", "value": 0.10 } }
]
```

`target: "unit"` cards are expanded per eligible party member at draw time (so "Thick Fur" can
appear as "Thick Fur — Ironmane"). `recruit` cards are gated on the cat not already in the party.

## 6. Roster & recruit (`data/units/clans.json`)

Six existing clans + two new, each with an explicit **`sprite_shortcut`** (fixes the collision
where `front_charge`/`ambush` and `mid_magic`/`bomber` currently share a sprite via the archetype):

| Cat (clan id) | archetype | lane | sprite_shortcut → sheet | skill |
|---|---|---|---|---|
| `maincoon_ironmane` | front_defense | front | `unit.tank_idle` → Vanguard_02 | `ironmane_bulwark` |
| `shorthold_emberpaw` | front_charge | front_mid | `unit.player_idle` → Soldier_01 | `emberpaw_dash` |
| `bengalis_wildstripe` | ambush | middle | `unit.striker_idle` → Scout_04 | `wildstripe_burst` |
| `siamheart_voicecasters` | mid_magic | middle | `unit.mage_idle` → Acolyte_01 | `voicecaster_chord` |
| `persephone_silkpaw` | support | rear | `unit.support_idle` → Acolyte_04 | `silkpaw_ward` |
| `ragdollan_cloudfur` | healer | rear | `unit.healer_idle` → Healer_03 | `cloudfur_mend` |
| **new** `abyssian_quillwhisker` | ranged | rear | `unit.ranged_idle` → Archer_01 | **new** `quillwhisker_volley` |
| **new** `devonrex_tinkertail` | bomber | middle | **new** `unit.bomber_idle` → Sapper_01 | **new** `tinkertail_flask` |

- **Roster size = 6 draftable + 2 meta-unlocked** (Quillwhisker & Tinkertail behind meta). Fixed,
  legible roster (auto-battler synergy must be tunable — not a wide pool).
- **Recruit arrival:** a recruited cat enters at `arrival_level = max(1, floor(avg_party_level*0.7))`
  and gets a **~2s spawn shield** so it does not instantly die.
- **Recruit timing (MVP decision):** the new `UnitState` is appended to `GameState.party` and the
  cat appears **at the start of the next wave** — `_do_wave_swap()` (`battle_view.gd:1804-1807`)
  re-reads `GameState.party` via `_spawn_wave()` (line 449), so no live re-render is needed. This
  avoids the mid-wave placement reshuffle risk (§9). "Arrive mid-wave immediately" is a **polish
  item (Slice 3)** via a new `_spawn_ally()` helper wrapping `_build_unit()` (line 495) + append to
  `_units` + `_build_skill_bar()` (line 703).

## 7. Integration seams in `battle_view.gd` (exact, from recon)

| Hook | Where | What |
|---|---|---|
| **(a) XP on kill** | at the two kill call sites `_basic_attack` **line 676** and `_cast_skill` **line 698** (attacker `u` in scope; `_kill()` at 1693 has no attacker) | `RunState.add_xp(1)` per enemy kill; wave-clear bonus (`5 + _wave`) in `_do_wave_swap`/`_check_wave_end` |
| **(b) level-up detect + pause** | in `_process` after the unit loop, near **lines 604-607** | if `RunState.pending_levelups > 0`: `Engine.time_scale = 0`, `_phase = "levelup"`, open `DraftView`. Extend `_process` guards (590-596) so `"levelup"` skips combat |
| **(c) draft overlay** | new `DraftView` on a new `CanvasLayer` (layer ~18, above `_screen_layer`=16, below `_toast_layer`=25) | copy the `_open_screen`/`_close_screen` pattern (1846/1870) **but dim the FULL rect** (not from `TOP_BAR_H`) so nav/speed can't be tapped mid-draft |
| **(d) apply pick** | `DraftView.card_chosen` handler | `CardSystem.resolve(card)` → mutate: `stats.add_modifier(...)` / `u["skill"].*` / append to `GameState.party` / set `RunState.meta`. Then `_close_draft()`: restore `Engine.time_scale = SPEED_STEPS[_speed_idx]` (mirror `_restart_run` line 1822), `_phase = "fighting"`, drain one `pending_levelups` |
| **(e) run end** | `_end()` **line 1829** (both won/lost branches) | `GameState.end_run(result, reward)` computed from `_wave`/`best_wave` (the pivot branch does NOT route through `mark_wave_cleared` — this is the only reward seam) |

**Phase ordering (critical, §9.8):** a kill can trigger both a level-up and a wave-clear on the
same frame. Rule: **resolve the level-up draft BEFORE the wave warp.** Queue the draft; if
`_check_wave_end` (line 605) wants to advance while `pending_levelups > 0`, hold the warp until the
draft closes (or open the draft, and on close re-check wave end). Never open the draft during
`"warp"`.

- **Per-unit level field (display only):** XP is owned by `RunState` as one shared run level (§3);
  each unit dict gets a **derived** `level` field (its recruit arrival level, §6) for display —
  `_hero_level(u)` (line 876) already reads `u["level"]` when present. No per-unit XP accumulation.

## 8. GameState changes (`scripts/runtime/game_state.gd`)

1. **Pre-run hero pick:** add `chosen_starter_id` (or `run_party_ids`); parameterize `_load_party()`
   (89-98) to seed `GameState.party` from the single chosen clan instead of all of
   `starter_party.json`. **Relax the `if party.size() != 4` assert** (64-65).
2. **Grow to 5:** recruit appends a `UnitState` to `party` + emits `party_changed`. All party
   iterators (`_apply_upgrade_bonus_to_party` 269-279, `reset_run` 127-134, `alive_party` 144-149)
   are already size-agnostic.
3. **`end_run(result: String, reward: int)`** (mirror `mark_wipe` 169-175): `add_currency(reward)`
   + `save_game()` + `run_ended.emit(result)`. Called from `battle_view._end()` (1829).
4. **Meta persist:** extend `snapshot()` (220-227) + `load_save()` (240-267) with
   `unlocked_clans: Array`, `meta_upgrades: Dictionary`; add matching vars; **bump
   `CURRENT_SAVE_SCHEMA_VERSION` 1 → 2**. `load_save` already `.get()`-defaults missing keys, so old
   saves upgrade cleanly. `try_buy_upgrade()` (182-204) is the template for permanent-upgrade
   purchases (guard → `add_currency(-cost)` → mutate persisted var → emit → `save_game`).

## 9. Run structure & procedural waves (`scripts/runtime/wave_state.gd`)

- **Campaign:** 12-15 authored waves, boss at the end; beating the final boss ⇒ `end_run("won")`.
  Reuses the existing catalog path (`mvp_waves.json`, `WaveState.for_wave`).
- **Endless:** lift the `MAX_WAVE = 10` cap in the **three** places recon found — `advance_to_wave`
  guard (game_state.gd:116-118), the `_wave >= MAX_WAVE → _end("won")` branch
  (battle_view.gd:1779), and the best_wave load clamp (game_state.gd:262). Then make
  `WaveState.for_wave` **procedural** past the authored catalog:
  - **stat scaling** `base × 1.12^wave` applied to spawned enemies (add a `scale` param to
    `UnitState.from_enemy` or post-multiply `hp_max/atk/def` in `for_wave`);
  - **boss every N (=5)** via `wave % 5 == 0` selecting a boss row;
  - compose count/mix from the 3 existing enemies (`tangleborn_yarnling` grunt,
    `tangleborn_snarlbeast` brute, `hollowmew_captain` boss); add 1-2 mid-tier archetypes + boss
    variants later for variety.
- Both modes share the identical draft loop, XP curve, and card pool — only the wave container and
  end condition differ.

## 10. Build slices

- **Slice 1 — core in-run loop (first playable):** pre-run hero pick (start with 1) · per-unit &
  run XP · level-up pause + `DraftView` with all four card types · recruit next-wave · endless
  escalating waves · wipe/end → `end_run` reward. Headless tests for `CardSystem` + `WaveState`
  scaling. **Reroll/skip/banish, campaign, boss-every-N, meta UI, evolutions are OUT of Slice 1.**
- **Slice 2 — run shape & agency:** campaign mode + boss draft (4 cards) + boss-every-N · reroll
  (2/run, +1 per boss) · skip (+gold) · banish (1-2/run) · rarity pity.
- **Slice 3 — depth & polish:** light meta-progression (Whisker Coins, 5 upgrades §11) · card-delta
  UI polish · mid-wave immediate recruit · evolutions (skill max-stack + passive ⇒ legendary).

## 11. Light meta-progression (Slice 3)

Currency **Whisker Coins** (per-run, more for wins/depth). Cap total permanent power ≤10-15%.
Five upgrades: (1) unlock cats 5 & 6 (Quillwhisker/Tinkertail — content, not power); (2) starting
reroll +1 (max +2); (3) Party Vigor +2% HP/tier (max 5 tiers = +10%); (4) starting gold (25/50/75);
(5) unlock an epic/evolution card per cat via **achievements** (mastery-gated, not grind-gated).
Prefer unlocks (variety) over stat boosts (power). No consumables, no per-run purchasable power.

## 12. UI, assets, and the auto-battler pitfall

- **Draft card** = `NinePatchRect(ui.card_frame)` + portrait `AssetRegistry.load_sprite_frame(
  sprite_shortcut, 0, 0)` on `ui.portrait_frame` + name `ui.card_title` + rarity by `modulate` color
  on a shared ring (no per-tier art) + pick `Button` (`ui.card_pick_*`). Unit sheets are
  `is_atlas` ⇒ **`load_sprite_frame`**, never `load_texture` on the whole sheet.
- **New shortcuts** (`data/asset_shortcuts.json`, never hardcode `res://asset/...`): `unit.bomber_idle`
  → `map_1x_unit_sapper_01_idle`, `unit.bomber_move` → `..._move`; card UI: `ui.card_frame`,
  `ui.card_title`, `ui.portrait_frame`, `ui.rarity_ring`, `ui.card_pick_normal/_pressed/_selected`
  (map to the un-shortcutted `bgbox_04a`, `bannersmall_01a`, `slot_02_empty`, `mini_icon_01_outline`,
  `button_03a_*`). Regenerate the asset catalog only if files under `asset/` change (they don't here).
- **Game-form decision (recorded):** keep the side-scroll auto-battle; do NOT rebuild as top-down
  Vampire Survivors. The VS inspiration is expressed through the **draft/level-up loop**, not
  player-piloted movement.
- **Auto-battler pitfall:** because the player does not pilot units, the **draft is the entire skill
  expression**. Mitigations baked into this design: card **delta text** (§4.3 `describe`), the
  existing **manual skill-tap** already serves as the "light control" lever, the **guaranteed
  ≥1-upgrade + reroll** anti-snowball rules, and **recruit level-scaling** so a weak start is
  recoverable by drafting rather than reflexes. Favor synergy/conditional passives over flat stats
  for epic+ cards.

## 13. Testing

- **Headless unit tests** (existing harness: `tests/*.tscn` → `extends Node`, collect `failures`,
  print PASS/FAIL, `quit(0|1)`):
  - `CardSystem`: `draw(3)` returns 3 distinct valid cards; no recruit when party full; ≥1 upgrade
    guaranteed; recruit weight falls to 0 at size 5; `resolve()` descriptors correct per type.
  - `RunState`: XP curve thresholds; `add_xp` crosses the right number of level-ups; recruit
    arrival-level math.
  - `WaveState` procedural: wave > catalog scales stats by `1.12^wave` and picks a boss on `wave%5==0`.
- **Runtime smoke** (Sage): `run_game.ps1` + `tools/capture_runtime_screenshot.ps1` — prove the
  battle launches, a level-up pauses and shows 3 cards, a pick applies and combat resumes. Report
  the actual output. (Note the Do-Not-Repeat: warnings-as-errors ⇒ never `:=` from a Variant; run
  Godot, not just gdtoolkit, before claiming a `.gd` change works.)

## 14. Risks & notes

1. **Two-driver currency:** the pivot's `battle_view._end()` never calls
   `mark_wave_cleared/mark_wipe`; rewards MUST go through the new `end_run` seam.
2. **Hardcoded party size 4** (`game_state.gd:64-65`) blocks a 1-cat start — relax it.
3. **`_units` is a flat mixed ally+enemy array**; growing the party requires appending + rebuilding
   `_build_skill_bar()` (only relevant for mid-wave recruit, deferred to Slice 3).
4. **Placement re-lays-out a whole side** (`_place_side` 471) — mid-wave recruit reshuffles allies;
   avoided in MVP by next-wave arrival.
5. **Level-up vs wave-clear ordering** (§7) — resolve the draft before the warp.
6. **`_build_unit` mutates HP in place** (line 519, `×HP_MULT`) — never re-run on a built unit;
   apply draft buffs via `stats.add_modifier`, not by rebuilding.
7. **Endless requires lifting the cap in three places** (§9) + procedural `for_wave`.
8. **Godot target 4.x**; warnings-as-errors; verify with a real Godot run.

## 15. Explicitly deferred
- Reroll / skip / banish / pity (Slice 2).
- Campaign authored curve + boss-every-N variety enemies (Slice 2).
- Full meta-progression UI + Whisker Coins economy + achievements (Slice 3).
- Mid-wave immediate recruit, evolutions, per-cat formation control (Slice 3).
