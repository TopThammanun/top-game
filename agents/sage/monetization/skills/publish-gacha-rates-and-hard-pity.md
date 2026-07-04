---
id: publish-gacha-rates-and-hard-pity
type: skill
title: Publish gacha rates in-game and guarantee a rare by pull N
domain: monetization
status: proposed
source: ai
enforcement: advise
tags: [gacha, rates, pity, regulation, trust]
---

Setting doc §5.2 makes this a design principle, and it's also legally
required in a growing list of jurisdictions (Belgium and the Netherlands
ban loot boxes outright; Japan/Korea/China require rate disclosure; the EU
consumer-protection direction is clearly moving toward disclosure). Bake
it in from day one:

- **Rates visible in the pull screen**, not buried in a Terms link.
- **Hard pity**: guarantee a rare by pull N (industry norms are 60–90 for a
  high-rarity banner).
- **Soft pity**: increase the rate after pull M (e.g. 75% of hard-pity
  distance) so the pity curve is felt, not just a cliff.
- **Pity carries across banners of the same rarity tier**, not per-banner
  reset — the latter is one of the most-hated dark patterns in the genre.

The Cookie Run: Kingdom precedent cited in the setting doc — high published
rates + non-payer able to collect rares through exchange + no ads = ARPPU
that beats FGO's on a fraction of the pull count.

**Do:**

- Show the exact percentage per rarity tier on the pull screen (e.g.
  "Ancient 1.2%, Legendary 4.5%, Epic 12%, Rare 32%, Common 50.3%").
- Display a pity counter: "Ancient guaranteed in 43 pulls".
- Log every pull with seed and result for support parity — if a player
  disputes a pity count, you can prove it.
- Do a one-time client-side rate-fair sanity check in dev builds: 100,000
  simulated pulls, assert observed rates within 0.5% of published.

**Avoid:**

- Per-banner pity reset. The player learns fast; trust collapses.
- Hidden softpity that only kicks in for certain accounts. The moment any
  regulator or analyst finds it, the entire economy loses credibility.
- Rates written in a Terms-of-Service PDF, not in-app. If you can't put the
  number on the pull button, don't ship the pull button.
