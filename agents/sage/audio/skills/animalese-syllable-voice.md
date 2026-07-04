---
id: animalese-syllable-voice
type: skill
title: "Give cats an Animalese-style syllable voice"
domain: audio
status: proposed
source: ai
enforcement: advise
tags: [voice, animalese, cat, cozy, dialogue]
---

Setting doc §4.2 specifies a K.K. Slider / *Animal Crossing*-style syllable
voice for cat speech: a small pool of syllables (`mya`, `nya`, `mrr`, `prr`,
`meh`) played fast in sequence while a text bubble scrolls, with per-clan
pitch and rate to give voice identity — Siamese higher and faster (they're
the "vocal" clan per §1.4), Maine Coon deeper and slower, Ragdoll softer.

This is cheap to produce, distinctive, and scales to any dialogue count
without needing localised voice actors — the "voice" is procedurally the
same in Thai, English, or Japanese, because it's syllable synthesis, not
speech.

**Do:**

- Author 6–10 syllable takes per emotional register (calm / excited /
  hurt / questioning). Store as an `AudioStream` array on a `VoiceProfile`
  Resource per clan.
- Play one syllable per 2–3 text characters at a random pitch within a small
  per-clan range. Stop syllables on dialogue skip.
- Per-clan pitch profiles (Siamese +3 st, Maine Coon -3 st, Ragdoll -1 st with
  soft filter, Bengal +1 st fast, Persian neutral with room reverb).
- Bus: **Voice**, so per-player volume slider can dial it independently.

**Avoid:**

- Random syllable + random pitch on every character — the pattern reads as
  broken, not cute. Anchor the pitch per line, jitter within a small range.
- Long syllable takes. Under 200 ms each is the target; longer takes overlap
  and mud up.
- Reusing the same voice profile across clans. The voice is the character —
  and there are only six clans, so bespoke per-clan is cheap and worth it.
