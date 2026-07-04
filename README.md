# TBH: Task Bar Hero

Starter Godot project for prototyping **TBH: Task Bar Hero**, an idle + turn-based RPG set in **Whisker Realm** on the world of **Purralia**.

## Canonical identity

- Production title: **TBH: Task Bar Hero**
- Fantasy title: **Whisker Realm**
- Primary world: **Purralia**
- Setting source: `project_main_setting.md`
- Machine-readable identity: `data/project_identity.json`

## What is set up

- `project.godot` opens as a Godot 4 project.
- `scenes/main/main.tscn` is the current boot scene.
- `scripts/autoload/asset_registry.gd` loads the generated asset catalog at runtime.
- `data/asset_catalog.json` is generated from every asset file.
- `data/asset_shortcuts.json` maps stable gameplay roles to asset ids.
- `data/project_identity.json` records the canonical project/world names.
- `data/design_sources.json` records source-of-truth and folder contracts.
- `data/world/regions.json` records the first five campaign regions.
- `data/units/clans.json` records the six playable cat clans.
- `data/units/starter_party.json` records the first four party roles.
- `data/combat/mvp_waves.json` records the first 10-wave combat plan.
- `data/economy/monetization_policy.json` records the friendly monetization rules.
- `docs/ASSET_MAP.md` explains how AI agents should find and use assets.
- `docs/DESIGN_SOURCE_OF_TRUTH.md` explains which docs win when sources disagree.
- `docs/world/WORLD_BIBLE.md` defines the playable world foundation.
- `docs/world/STORY_AND_REGIONS.md` defines the campaign spine through act 5.
- `docs/world/TONE_GUIDE.md` defines the cozy fantasy tone rules.

## Regenerate the asset catalog

Run this whenever assets are added, removed, or renamed:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_asset_catalog.ps1
```

The generator writes:

- `data/asset_catalog.json`
- `docs/ASSET_INDEX.generated.md`

## Run the game

If a `Godot*.exe` file, or an extracted `Godot*.exe/` folder, is placed in the project root, the run scripts use it automatically.

Run from PowerShell:

```powershell
.\run_game.ps1
```

Open the Godot editor for this project:

```powershell
.\run_game.ps1 -Editor
```

If Godot is not in PATH, pass the executable once:

```powershell
.\run_game.ps1 -GodotPath "C:\Path\To\Godot_v4.x-stable_win64.exe"
```

Or set it for the current PowerShell session:

```powershell
$env:GODOT_EXE = "C:\Path\To\Godot_v4.x-stable_win64.exe"
.\run_game.ps1
```

From Command Prompt or by double-clicking:

```bat
run_game.bat
```

## Play the current prototype

The boot scene now opens the Emberhearth combat loop instead of an asset
preview. The party auto-fights Tangleborn monsters while the taskbar gives the
player short commands:

- `Skill 1`: Wildstripe burst, doubling party basic attacks for a short window.
- `Skill 2`: Cloudfur heal, restoring living party members.
- `AFK Chest`: claims locally accrued idle Pawcoins.
- `Upgrade`: spends Pawcoins on the `Reweave` level, increasing party ATK and HP.
- `Replay`: restarts the 10-wave run with current upgrades.

The current build includes presenter-only game-feel feedback: idle unit bobbing,
attack lunges, hit/heal floating numbers, skill pulses, boss warning flashes,
reward bursts, header/feed pulses, and taskbar press/cooldown/ready feedback.
These effects do not change combat results; `GameState` and `BattleEngine` still
own the actual run state.

Map presentation is now a compact battle strip: the Emberhearth tile map is the
combat surface, with party and monsters placed directly on the lane instead of
in separate dashboard rows.

Progress saves locally to `user://save.json` with `schema_version: 1`. The save
currently persists Pawcoins, best wave, Reweave level, and the AFK chest clock.

From Git Bash:

```bash
./run_game.sh
```

Open the editor from Git Bash:

```bash
./run_game.sh --editor
```

If Godot is not in PATH:

```bash
winget install -e --id GodotEngine.GodotEngine
```

Then open a new Git Bash and run:

```bash
./run_game.sh
```

If you already have Godot downloaded somewhere:

```bash
./run_game.sh --godot-path "/c/Path/To/Godot_v4.x-stable_win64.exe"
```

Or set it for the current Git Bash session:

```bash
export GODOT_EXE="/c/Path/To/Godot_v4.x-stable_win64.exe"
./run_game.sh
```

## Runtime smoke check

Capture a real game-window screenshot and close Godot automatically:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\capture_runtime_screenshot.ps1
```

The screenshot is written to `godot_runtime_screenshot.png`.

## Godot usage

Open this folder in Godot. The first editor launch will create `.godot/` import metadata locally.

Important runtime shortcuts:

- `AssetRegistry.get_asset_path("map.default_tilesheet")`
- `AssetRegistry.load_texture("unit.player_idle")`
- `AssetRegistry.find_assets({"category": "ui", "group": "Item slots", "scale": "1x"})`

## Design docs

Read these first when continuing design or implementation:

- `project_main_setting.md`
- `docs/TBH_GAME_SPEC_1_TO_100.md`
- `docs/DESIGN_SOURCE_OF_TRUTH.md`
- `docs/PROJECT_IDENTITY.md`
- `docs/world/WORLD_BIBLE.md`
- `docs/world/STORY_AND_REGIONS.md`
- `docs/world/TONE_GUIDE.md`
- `docs/world/PEOPLES_AND_CLANS.md`
- `docs/systems/CORE_LOOP.md`
- `docs/systems/COMBAT_SYSTEM.md`
- `docs/systems/MAP_AND_TASKBAR.md`
- `docs/systems/PROGRESSION_AND_ECONOMY.md`
- `docs/systems/MONETIZATION_POLICY.md`
- `docs/audio/SOUND_AND_FEEL.md`
- `docs/production/MILESTONES_AND_ACCEPTANCE.md`
- `docs/production/PLAYABLE_GAME_BUILD_PLAN.md`
- `docs/production/ISSUE_PLAN.md`
- `docs/ASSET_MAP.md`

## Asset credit

The included map and UI packs are by Franuka. The bundled license files allow commercial and non-commercial use, with a request to credit/link Franuka's itch page or social links. Keep the original license files in `asset/map/License and details.txt` and `asset/ui/License and details.txt`.
