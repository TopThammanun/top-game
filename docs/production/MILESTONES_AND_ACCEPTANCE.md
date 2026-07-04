# Milestones And Acceptance

Implements steps 91-100 of `docs/TBH_GAME_SPEC_1_TO_100.md`.

## Prototype: 0-3 Months

Required:

- Emberhearth region
- party of four
- 10-wave MVP combat
- 1 boss
- AFK reward chest
- basic taskbar UI
- 6 clan samples, at least one per clan
- asset-backed UI from catalog

Acceptance:

- First session reaches a reward in 5 minutes.
- The taskbar can trigger at least one skill command.
- The player can claim an AFK chest.
- A boss clear produces reward feedback.

## Vertical Slice: 3-6 Months

Required:

- friendly gacha
- pity
- equipment
- cosmetics
- offline cap
- adaptive audio prototype
- 2 playable regions

Preferred region pair:

- Emberhearth
- Silkspiredale or Tuna Coast

Acceptance:

- Gacha rates are visible.
- A duplicate converts into fair shard/exchange value.
- Audio layers respond to at least idle, combat, boss, and reward states.

## Soft Launch: 6-10 Months

Required:

- 3 playable regions
- daily/weekly loop
- guild or social-lite system
- battle pass
- event loop

Acceptance:

- Day-1 retention target: >40%.
- Day-7 retention target: >20%.
- DAU/MAU aspiration: >30%.
- Monetization feedback should not identify pressure or paywalling as dominant complaints.

## Thresholds

If Day-2 retention is below 20%, fix core loop and reward cadence before monetization.

If players complain about progression walls, reduce exponential scaling and add visible upgrade alternatives.

If monetization feedback turns negative, reduce pop-ups, increase gacha generosity, and move value into cosmetics.

## Pre-Production Definition Of Done

Pre-production is done when the repo has:

- playable Godot prototype
- updated world bible
- asset workflow through catalog
- combat loop for 1 region
- taskbar UI
- sound prototype
- issue plan ready for implementation
