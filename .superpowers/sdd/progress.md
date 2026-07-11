# SDD Progress — Roguelike Draft Slice 1 (core in-run loop)

Plan: docs/superpowers/plans/2026-07-12-roguelike-draft-slice-1.md
Spec: docs/superpowers/specs/2026-07-12-roguelike-draft-pivot-design.md
Branch: feat/auto-battler-combat-pivot
Godot: "./Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" (v4.7 confirmed working)
Test cmd: <godot> --headless res://tests/<name>.tscn  (PASS = exit 0)

Base before Task 1: c8a255c

## Tasks (current plan)
- Task 1: complete (commits c8a255c..c4661b5, review clean; haiku impl / sonnet review)
- Task 2: complete (commits c4661b5..ccfb496, review clean; 1 Important fixed — CardData.effect deep-copy + proving test; header comment restored)
- Task 3: complete (commits ccfb496..8478d41, review clean; 2 Important test-rigor gaps fixed — guarantee branch now exercised over 60 seeds, skill/passive resolve shapes tested)
- Task 4: complete (commit 8478d41..1dfa60a, review clean; catalog ids verified 5/5, both suites green)
- Task 5: complete (commit 1dfa60a..62ae2f8, review clean — NO issues; catalog path proven untouched)
- Task 6: complete (commit 62ae2f8..53e36dd, review clean; all 3 suites green)
  Minor: recruit_member has no party-cap guard (callers gate via CardSystem.candidates + RunState.add_member); get_clan_row untyped return
- Task 7: complete (commit 53e36dd..11bd36e, review clean; parse-check PASS, presentation-only, index-capture correct)
  Minor: dead NinePatchRect in null-frame fallback; latent 1-frame double-render on reopen (not exercised)
  RESOLVED: pre-existing battle_view.gd WIP checkpointed as commit f356ee0 (boots exit 0). BASE for Task 8 = f356ee0.
- Task 8: complete (commits f356ee0..8cce8ba, opus review; make-or-break risks clean [:=-Variant, 5b persistence]; 1 Important fixed [_restart_run fresh run] + 2 latent guards [starter-pick index, empty-draw]. boot exit 0, 4 suites green)
  Deferred Minors (final triage): starter-pick shows "LEVEL UP" title (cosmetic); recruit_arrival_level computed but unused (no per-unit stat leveling in Slice 1 — recruits inherit party upgrades via 5b); _run.passives recorded but re-applied via _run.upgrades only
- Task 9: complete — all 4 headless suites PASS (roguelike_test, roguelike_gamestate_test, combat_core_test, bootstrap_test); added `tests/roguelike_loop_test.gd/.tscn` (real battle.tscn scene-wiring integration test, 4/4 clean runs, no `--quit-after` needed); windowed screenshot confirms the starter-pick draft overlay renders; COMBAT_SYSTEM.md + anatomy.md updated. **Slice 1 COMPLETE.**

## FINAL WHOLE-SLICE REVIEW (opus): MERGE AFTER FIXES → fixes applied → CLEAN
- 1 Important fixed (commit 5ff6b0f): base `atk_spd` added to mid_magic/ambush/bomber/support/healer so the +ATK_SPD card isn't a silent no-op (percent × 0 base = 0). Doc wording corrected (_scale_enemy runs every wave).
- All accumulated Minors triaged ACCEPTABLE (see below). Persistence invariant, clan_id threading, state machine, economy all verified solid end-to-end.
- SLICE 1 COMPLETE & VERIFIED: 9 tasks + integration test + windowed screenshot of the working starter-pick. All suites green. HEAD = 5ff6b0f.

## Minor findings (all triaged ACCEPTABLE by final review — for Slice 2 polish)
- T1 tests/roguelike_test.gd:23 — untyped `var rs = RunStateClass.new(...)` (loses static typing; inherited from brief; matches nothing to fix functionally)
- T1 run_state.gd — DEFAULTS values duplicated in inline `.get(k, default)` fallbacks (unreachable branch; keep in sync if retuned)
- T3 card_system.gd — `resolve()` skill branch omits `scope` key (stat has it); harmless since skill cards are always unit-targeted in cards.json
- T3 card_system.gd:99 — `_first_upgrade` always substitutes the first eligible upgrade (deterministic, not varied) when the guarantee fires
- T3 card_system.gd:145 — `describe()` stat branch prints empty `()` if called on an unbound unit-card (never happens today; candidates() always binds)
- T4 tests/roguelike_test.gd:203 — helper `CombatEnumsForRoster()` is PascalCase (inconsistent snake_case; inherited from brief)

---

## Archived: Plan A — Auto-Battler Combat Core (COMPLETE)

Plan: docs/superpowers/plans/2026-07-05-auto-battler-combat-core.md
- Task 1: complete (commits 6b04244..2030c64, review clean; 1 fix applied — modifier lifecycle)
- Task 2: complete (DamageCalculator; reverted implementer load() workaround, typed test PASS)
- Task 3: complete (CombatSkill; converted module to preload consts to fix headless new-class registration)
- Task 4: complete (SkillEffect damage/heal/buff/stun; sonnet, clean; PASS)
- Task 5: complete (archetypes/skills data + CharacterFactory; both suites PASS)
- Task 6: complete (full suite green; COMBAT_SYSTEM.md updated)
Final whole-branch review (opus): 1 major fixed (buff modifier type), minors by-design/cosmetic. All suites green.
