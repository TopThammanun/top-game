---
id: no-dark-patterns-checklist
type: skill
title: Anti-dark-pattern checklist for the storefront and pop-ups
domain: monetization
status: proposed
source: ai
enforcement: advise
tags: [dark-patterns, ethics, ux, storefront, monetization]
---

Setting doc §5.2 makes "avoid dark patterns" a design principle. A
checklist to apply against every monetization surface (store, pop-up,
banner, subscription page). Fail any item → redesign the surface.

- [ ] **No fake countdown timers.** If "24h left" is real (a genuine banner
  end), fine. If it resets each session, it's a lie — remove it.
- [ ] **Subscription cancel is one screen deep** from the buy screen.
  "Where do I unsubscribe?" is not a design puzzle.
- [ ] **Pop-ups on session start ≤ 3.** After three, queue the rest behind a
  badge. Setting doc §2.4 pins this.
- [ ] **No confusable buttons.** "Skip" and "Buy" have different colours and
  sit in different positions across every screen. Never swap them per-page.
- [ ] **Rate/pity screen is one tap** from any pull button. If it isn't, the
  storefront is hiding the maths — see `publish-gacha-rates-and-hard-pity`.
- [ ] **No first-purchase-only "special deal" that's actually the standard
  bundle.** If the bundle is good, offer it later too.
- [ ] **No progress-gated purchase prompts.** ("Buy X to unlock the next
  chapter" — F2P must be able to reach the ending; setting doc §5.2.)
- [ ] **No forced ads.** Ads must be player-initiated (Neko Atsume model).
- [ ] **No hidden auto-renewal.** Auto-renew subs must show the next charge
  date on the confirm screen.
- [ ] **No sunk-cost prompts.** "You spent X so far, spend Y more!" — never.

Apply this before every store change ships; add it to the PR template.

**Do:** ship every storefront change with this checklist attached to the PR.

**Avoid:** delegating this to trend-chasing UX audits after launch —
retrofit is 10× the cost, and by then reviews have already landed.
