---
id: separate-hard-and-soft-currency
type: skill
title: Separate hard (paid) and soft (earned) currencies — no cross-buying premium
domain: monetization
status: proposed
source: ai
enforcement: advise
tags: [currency, gacha, economy, f2p, monetization]
---

Two currencies, two purposes, no bridge that lets soft-currency-rich players
short-circuit the premium loop:

- **Hard currency (Gems / "Purrs")** — bought with real money OR earned
  slowly from milestone rewards / battle pass. Spent on gacha pulls,
  cosmetics, QoL slots.
- **Soft currency (Yarn)** — earned constantly from combat, dailies, AFK
  chests. Spent on level-up, gear enhance, base upgrades.

The two must never cross-buy premium tiers. Yarn should not be exchangeable
for pulls in bulk; if it were, either (a) whales trivialise it, or (b) F2P
players correctly perceive Gems as a scam. Both are bad. Setting doc §5's
"friendly monetization" pillar depends on this separation.

**Do:**

- Grant Gems for milestones and daily-login streaks so F2P players
  accumulate a slow but honest stream — enough for a pull every 3–7 days.
- Show earned vs paid Gem balances **separately** on the wallet UI
  (transparency = trust). Prefer earned when spending.
- Cap Yarn → Gem conversions at a small daily quota so it's a QoL vent,
  not an economy backdoor.
- Sanity-check the model with a simulation: is a Day-30 F2P player able to
  afford one pity? If yes, the ratio is roughly right.

**Avoid:**

- Selling Yarn packs. It signals "Yarn is the real economy" and undermines Gems.
- Third and fourth currencies for each event. Players tune out; the wallet
  becomes noise. Reskin Yarn/Gem for events, don't add new ledgers.
- Time-limited "premium event currency" that expires. Textbook FOMO dark
  pattern; see `no-dark-patterns-checklist`.
