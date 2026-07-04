---
id: adaptive-music-vertical-layering
type: skill
title: Compose music as 3–5 stems per zone and fade by state
domain: audio
status: proposed
source: ai
enforcement: advise
tags: [music, adaptive, layering, cozy, idle]
---

Idle sessions are long. A single looping track that never changes turns into
ear fatigue by minute 30; a track that switches abruptly breaks the cozy
spell. The middle path — vertical layering — composes one piece as 3–5 stems
(ambient pad, chord bed, percussion, melody-lite, melody-full) and fades
them in and out based on game state (exploration → wave clear → boss).
Mark Sparling's five-layer approach in *A Short Hike* is the reference case
called out in the setting doc §4.1.

Every stem is the same key, tempo, and loop length. What changes is which
stems are audible. That gives you "the same song, feeling different" — the
signature of cozy-game music that stays interesting for hours.

**Do:**

- Author one loop per zone, 60–90 s, split into named stems that Godot loads
  as separate `AudioStream`s on the Music bus.
- Fade stems with 1–2 s crossfades; a hard cut on stem entry is jarring.
- Escalate audibility on late waves so the music thickens — payoff moment.
- Keep tempo 65–90 BPM in ambient stems, 110–130 for combat stems; author
  them at the same BPM so a stem swap doesn't lurch.

**Avoid:**

- Full track swaps on state change. Cross-track transitions are hard to make
  cozy; cross-stem transitions inside one track are almost free.
- Melody stems that overlap on entry — pick one melody at a time or accept
  the muddle.
- Stems authored in different keys/tempos "because they'll never overlap" —
  they will overlap during transitions, and they'll clash.
