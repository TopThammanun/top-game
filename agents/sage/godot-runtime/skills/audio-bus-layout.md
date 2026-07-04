---
id: audio-bus-layout
type: skill
title: Set up a five-bus audio layout early
domain: godot-runtime
status: proposed
source: ai
enforcement: advise
tags: [audio, buses, mix, godot, sound-design]
---

Sound Design is a stated pillar (`project_main_setting.md` §4). That only
holds up if the mix is controllable from day one — retrofitting bus routing
after 200 `AudioStreamPlayer` nodes are already `bus = "Master"` is painful.
Configure `default_bus_layout.tres` up front with five children of Master:

- **Music** — adaptive layered stems (see `adaptive-music-vertical-layering`).
- **SFX** — combat hits, UI clicks, reward jingles.
- **Ambient** — the purr bed, wind, hearth crackle (see `dedicated-purr-ambient-bed`).
- **Voice** — cat "Animalese"-style syllable synth.
- **UI** — menu-only sounds that must stay audible even when Music/SFX ducked.

Then expose each as an in-game slider. Players who want the purr but not the
combat SFX (or vice versa) can dial it themselves; that's a cozy-audience UX,
not a nice-to-have.

**Do:**

- Set the `bus` property on every `AudioStreamPlayer` at authoring time —
  never leave it as `Master`.
- Wire volumes through `AudioServer.set_bus_volume_db(idx, db)`; convert
  0.0–1.0 slider values with `linear_to_db(value)`.
- Add a `SideChain`/`Compressor` on Music that ducks when the reward jingle
  fires on SFX — this is the "chest opens, everything else politely quiets" moment.

**Avoid:**

- One master bus for everything. You lose the ability to duck, mix, or offer
  per-category volume.
- Volume changes via `AudioStreamPlayer.volume_db` on individual players — the
  mix goes fractal, hard to reason about, impossible for QA to reproduce.
- Adding new buses on every feature. Five is the target; expand only when a
  category genuinely needs independent processing.
