---
id: variation-pool-for-frequent-sfx
type: skill
title: Author 3–5 variations for any SFX that plays >10x per session
domain: audio
status: proposed
source: ai
enforcement: advise
tags: [sfx, variation, cozy, fatigue]
---

Repeated identical SFX is the fastest path to "please mute this game".
Footsteps, UI clicks, unit `mya`, chest-open ticks — any sound that fires
more than ten times in a session needs a pool of 3–5 authored variations
that Godot picks between at random (ideally with light per-play pitch/vol
jitter on top). Setting doc §4.2 calls this out explicitly.

For cozy games the effect compounds: the ear stops noticing individual
sounds and instead reads them as "world texture". That's the aesthetic; a
single take breaks it.

**Do:**

- Ship 3–5 `.wav` takes per common event; store as an `Array[AudioStream]`
  on a `SfxDef` Resource; play a random pick.
- Layer `randfn(0, 1) * 0.05` on `pitch_scale` and `randfn(0, 1) * 1.5 db`
  on `volume_db` for a subtle "human take" feel.
- Route variations through the same bus so their mix stays coherent.
- Author variations **during** original SFX creation — variation added later
  never sounds like it came from the same session.

**Avoid:**

- One take + heavy pitch jitter as a substitute. It sounds broken, not varied.
- Randomizing pitch on tuned musical hits (level-up chime, chest-open jingle) —
  those *should* feel identical every time; save variation for texture sounds.
- Storing variations by hard-coded string ids in game code — put them on a
  `Resource` where designers can add takes without a code change.
