---
id: dedicated-purr-ambient-bed
type: skill
title: Run a low-volume purr ambient bed under cozy scenes
domain: audio
status: proposed
source: ai
enforcement: advise
tags: [ambient, purr, cozy, signature, identity]
---

Setting doc §4.3 calls the purr bed an **ambient signature** — a low-volume,
slow-varying purr layer that plays under menus, base scenes, and
between-wave lulls. Two payoffs: (a) it makes silence feel warm instead of
empty; (b) it becomes an audio identity — players hear the game before they
see it. Route it through the Ambient bus so it ducks correctly when combat
SFX fire.

Author a 20–30 s loop at very low volume (-24 to -30 dB), start it on scene
enter, stop on combat enter, resume on wave-clear. Never let it play *during*
active combat; the ambient bed and the combat mix compete otherwise.

**Do:**

- Loop point crossfade must be inaudible — purr is a texture, any loop click
  will kill it.
- Dip the bed to `-40 dB` (nearly silent) during combat instead of stopping
  it; a resume-from-silence hides the transition better than an on/off.
- Vary the purr slowly — swap between 2–3 authored 20 s beds over the course
  of an hour so the ear doesn't lock onto a repeat.
- Tie the bed volume to the player's Ambient slider (see `audio-bus-layout`) —
  some players will want it up, some off; the layout gives them the choice.

**Avoid:**

- One 5 s purr loop looping forever — the loop point becomes the sound.
- Baking the purr into music stems — you lose the ability to duck it
  independently.
- Making the purr responsive to gameplay (louder when winning). Cute in a
  trailer, exhausting in an hour of play.
