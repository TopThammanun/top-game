# combat - turn-based auto-battle patterns

Rules and skills for the `auto-battle + intervention window` combat design
described in `project_main_setting.md` section 2.

## Decisions

- [decisions/separate-enemy-archetype-and-instance-id.md](decisions/separate-enemy-archetype-and-instance-id.md) - repeated enemy archetypes need unique runtime instance ids (proposed - warn)

## Skills

- [skills/deterministic-rng-per-battle.md](skills/deterministic-rng-per-battle.md) - seed the RNG per battle so results reproduce (proposed - advise)
- [skills/priority-queue-turn-scheduler.md](skills/priority-queue-turn-scheduler.md) - schedule turns by cumulative time-to-act, not fixed round order (proposed - advise)
