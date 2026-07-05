# SDD Progress — Plan A: Auto-Battler Combat Core

Plan: docs/superpowers/plans/2026-07-05-auto-battler-combat-core.md
Branch: feat/auto-battler-combat-pivot
Godot test cmd: "./Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless res://tests/combat_core_test.tscn

Base before Task 1: 6b04244

- Task 1: complete (commits 6b04244..2030c64, review clean; 1 fix applied — modifier lifecycle)
  Base before Task 2: 8afad60
- Task 2: complete (DamageCalculator; reverted implementer load() workaround, typed test PASS)
  Base before Task 3: a8e17f8
- Task 3: complete (CombatSkill; converted module to preload consts to fix headless new-class registration; both suites PASS)
  Base before Task 4: 2262a3c
- Task 4: complete (SkillEffect damage/heal/buff/stun; sonnet, clean; PASS)
  Base before Task 5: 0134b9e
- Task 5: complete (archetypes/skills data + CharacterFactory; both suites PASS)
  Base before Task 6: 9018dd1
- Task 6: complete (full suite green; COMBAT_SYSTEM.md updated)

Final whole-branch review (opus): 1 major fixed (buff modifier type), minors by-design/cosmetic. All suites green.
