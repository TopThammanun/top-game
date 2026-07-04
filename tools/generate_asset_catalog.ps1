param(
    [string]$AssetRoot = "asset",
    [string]$OutputJson = "data/asset_catalog.json",
    [string]$OutputMarkdown = "docs/ASSET_INDEX.generated.md"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Semantic lore used to write per-asset descriptions and image-gen prompts.
# The overworld "units" are the Whisker Realm cat clans (plus their ships and
# siege engines). Keep this table in sync with data/units/clans.json.
# ---------------------------------------------------------------------------
$script:UnitLore = @{
    "Acolyte"       = "a hooded acolyte cat mage in a wide-brimmed hat, holding a glowing staff"
    "Archer"        = "a lithe archer cat with a longbow and a quiver of arrows"
    "Soldier"       = "a sworn soldier cat in a blue cloak and hat, holding a spear"
    "Vanguard"      = "a heavily-armoured vanguard cat, a frontline tank with a big shield"
    "Scout"         = "a light, quick scout cat in a traveller's cloak"
    "Healer"        = "a gentle healer cat in white-and-green robes tending a remedy"
    "Villager"      = "a plain villager cat in simple peasant clothes, a civilian worker"
    "Sapper"        = "a sapper cat carrying explosives and digging tools"
    "BeastRider"    = "a cat warrior mounted on a tamed beast"
    "Beast"         = "a wild fantasy beast creature, used as a mount or monster"
    "Elemental"     = "a conjured magical elemental made of raw energy"
    "Ram"           = "a wheeled battering-ram siege engine"
    "Siege"         = "a wheeled catapult / siege engine"
    "Battleship"    = "a heavy armed battleship, a large sailing warship"
    "Frigate"       = "a mid-size armed frigate sailing ship"
    "FishingBoat"   = "a small civilian fishing boat"
    "TransportShip" = "a broad transport ship for carrying troops or cargo"
}

$script:BiomeLore = @{
    "temperate" = "lush green grassland"
    "desert"    = "arid orange desert with oasis water"
    "snow"      = "frosted snow-and-ice"
}

# Returns @{ is_atlas; description; usage; prompt; sliced_reference } for an entry.
function Get-AssetSemantics {
    param([System.Collections.Specialized.OrderedDictionary]$Entry)

    $kind  = [string]$Entry.kind
    $name  = [string]$Entry.name
    $scale = [string]$Entry.scale
    $group = [string]$Entry.group
    $id    = [string]$Entry.id
    $style = "pixel art, top-down fantasy RPG, warm palette, transparent background, Franuka overworld/UI style"

    switch ($kind) {
        "unit_sprite" {
            $cls = [string]$Entry.unit_class
            $anim = [string]$Entry.animation
            $cols = [int]$Entry.grid_columns; $rows = [int]$Entry.grid_rows
            $cw = [int]$Entry.grid_cell_width; $frames = [int]$Entry.frame_count
            $lore = if ($script:UnitLore.ContainsKey($cls)) { $script:UnitLore[$cls] } else { "a $cls unit" }
            return @{
                is_atlas = $true
                description = "$cls unit ($anim animation), variant $($Entry.variant). Top-down overworld spritesheet: ${cols}x${rows} grid of ${cw}px frames = $frames frames. Each row is one animation track (a facing/pose), each column a frame; row 0 faces the camera (down)."
                usage = "ATLAS - never draw the whole sheet. Slice one pose with AssetRegistry.load_sprite_frame('$id', col, row); grab a whole track with AssetRegistry.load_sprite_frames('$id', row). Cut-out reference frames: asset_sliced/units/$scale/$name/."
                prompt = "$lore, $anim pose, single character sprite sheet, ${cw}px tiles, 4 animation frames per row, $style, Whisker Realm cat clans."
                sliced_reference = "asset_sliced/units/$scale/$name/"
            }
        }
        "tilesheet" {
            $biome = [string]$Entry.biome
            $hasWater = [bool]$Entry.includes_water
            $bl = if ($script:BiomeLore.ContainsKey($biome)) { $script:BiomeLore[$biome] } else { $biome }
            $waterSlug = if ($hasWater) { "water" } else { "no_water" }
            $waterTxt = if ($hasWater) { "includes shallow + deep water autotiles" } else { "NO water layer (shallow/deep water tiles omitted - composite your own water underneath)" }
            $waterTerrain = if ($hasWater) { ", shallow + deep water" } else { "" }
            $tw = [int]$Entry.tile_width; $tc = [int]$Entry.tile_columns; $tr = [int]$Entry.tile_rows
            $slicedRef = "asset_sliced/tiles/${biome}_${waterSlug}/$scale/"
            return @{
                is_atlas = $true
                description = "$biome overworld tilesheet ($waterTxt). $($Entry.width)x$($Entry.height) atlas on a ${tw}px grid (${tc}x${tr} tiles). Packs terrain autotiles (grass/ground, sand/beach, cliffs, paths$waterTerrain), colored-roof buildings, and props (barrels, sacks, potions, crates, tents, banners, map markers, number glyphs). Building + prop tiles are identical across all three biomes; only the terrain colours differ."
                usage = "ATLAS - compose maps tile-by-tile with AssetRegistry.load_grid_cell('$id', col, row). See docs/ASSET_GUIDE.md for the tile-role map (which tile rows are terrain vs buildings vs props). Cut-out reference pieces + index.json: $slicedRef."
                prompt = "top-down tactical RPG $bl tileset, seamless ${tw}px terrain autotiles, cute fantasy houses with colourful roofs, small props (barrels, potions, tents, flags), $style."
                sliced_reference = $slicedRef
            }
        }
        "fog_of_war" {
            $tw = [int]$Entry.tile_width; $tc = [int]$Entry.tile_columns; $tr = [int]$Entry.tile_rows
            return @{
                is_atlas = $true
                description = "Fog-of-war overlay tiles: ${tc}x${tr} grid of ${tw}px cloudy tiles used to hide unexplored map areas. Meant to be driven as an 8-way autotile / overlay layer."
                usage = "ATLAS overlay - draw above the terrain layer and slice with AssetRegistry.load_grid_cell('$id', col, row). Reference: asset_sliced/tiles/fog_of_war/$scale/."
                prompt = "soft grey cloud fog-of-war tiles, autotile edge pieces, semi-transparent, $style."
                sliced_reference = "asset_sliced/tiles/fog_of_war/$scale/"
            }
        }
        "background_box" {
            return @{ is_atlas = $false
                description = "Nine-slice UI panel / background box ($name) for windows, menus, tooltips and the taskbar shell."
                usage = "Ready to use. Best as a Godot NinePatchRect so the ornate border keeps its corners while the centre stretches. Shortcut roles: ui.taskbar_panel / ui.panel_dark."
                prompt = "fantasy RPG UI panel, ornate carved wooden + parchment frame, nine-slice border, $style." }
        }
        "button" {
            $st = [string]$Entry.state
            return @{ is_atlas = $false
                description = "UI button ($name)$(if($st){", $st state"}). Buttons come as Normal / Pressed / Selected triplets."
                usage = "Ready to use. Swap the three states on interaction; wire via shortcuts ui.button_normal/_pressed/_selected. TextureButton in Godot."
                prompt = "fantasy RPG UI button$(if($st){", $st state"}), beveled stone/wood key, $style." }
        }
        "checkbox" {
            $st = [string]$Entry.state
            return @{ is_atlas = $false
                description = "UI checkbox / toggle ($name)$(if($st){", $st state"}). Comes as On / Off (and sometimes Bullet) states."
                usage = "Ready to use. Toggle between On/Off textures for boolean settings. CheckBox/TextureButton in Godot."
                prompt = "fantasy RPG UI checkbox$(if($st){", $st state"}), small framed toggle, $style." }
        }
        "cursor" {
            return @{ is_atlas = $false
                description = "Mouse / selection cursor ($name)."
                usage = "Ready to use. Set with Input.set_custom_mouse_cursor(), or draw as a selection marker on the map grid."
                prompt = "fantasy RPG mouse cursor / pointer, small pixel icon, $style." }
        }
        "divider" {
            return @{ is_atlas = $false
                description = "Decorative horizontal divider / separator line ($name) for splitting menu sections."
                usage = "Ready to use. Place between UI groups; centre-stretch horizontally if wider than the source."
                prompt = "fantasy RPG UI divider line, ornate filigree separator, $style." }
        }
        "item_slot" {
            return @{ is_atlas = $false
                description = "Inventory item slot ($name). Some slots show a faint ghost icon (weapon/potion/glove/etc.) hinting the slot type."
                usage = "Ready to use as an inventory/equipment cell; overlay the actual item icon on top. Shortcut roles: ui.slot_empty/_weapon/_potion."
                prompt = "fantasy RPG inventory slot, square framed socket$(if($name -match 'empty'){', empty'}else{''}), $style." }
        }
        "mini_icon" {
            $st = [string]$Entry.state
            return @{ is_atlas = $false
                description = "Small UI mini-icon ($name)$(if($st){", $st state"}) for stats, resources, actions and taskbar commands."
                usage = "Ready to use at small sizes. Many have a plain + a Selected variant; shortcut role ui.icon_primary."
                prompt = "tiny fantasy RPG UI icon$(if($st){", $st state"}), single symbol on a small badge, $style." }
        }
        "resource_orb" {
            return @{ is_atlas = $false
                description = "Resource orb ($name) - HP / MP / Energy gem for status readouts."
                usage = "Ready to use. Pair with a fill/bar to show current vs max. Shortcut roles: ui.hp_orb/_mp_orb/_energy_orb."
                prompt = "fantasy RPG resource orb, glossy coloured gem (health/mana/energy), $style." }
        }
        "slider_bar" {
            return @{ is_atlas = $false
                description = "Slider / progress-bar piece ($name) for volume, HP/XP bars and settings."
                usage = "Ready to use. Nine-slice or tile the fill horizontally; combine track + fill + handle pieces."
                prompt = "fantasy RPG UI slider and progress bar parts, track fill and handle, $style." }
        }
        "spellbook_tab" {
            return @{ is_atlas = $false
                description = "Spellbook page / tab-menu element ($name) for book-style menus and category tabs."
                usage = "Ready to use. Assemble into a tabbed book UI; the pack ships open/close + page-turn animation frames."
                prompt = "fantasy RPG spellbook page and menu tab, aged paper and ribbon bookmark, $style." }
        }
        "title_banner" {
            return @{ is_atlas = $false
                description = "Title banner / header ribbon ($name) for screen and menu titles."
                usage = "Ready to use. Place a title label on top; centre-stretch if the title is longer than the banner."
                prompt = "fantasy RPG title banner ribbon, ornate header plaque, $style." }
        }
        "bitmap_font" {
            return @{ is_atlas = $true
                description = "Bitmap font glyph reference sheet ($name) - a laid-out character set. For actual text, use the .ttf fonts, not this sheet."
                usage = "Reference only. Render text with the ui_font_* TTF fonts; this sheet just shows the glyph set."
                prompt = "pixel bitmap font glyph sheet, full character set, $style." }
        }
        "font" {
            $isTitle = $name -match "title|Title"
            return @{ is_atlas = $false
                description = "Pixel TTF font ($name). $(if($isTitle){'FantasyRPGtitle - use at multiples of 11px.'}else{'FantasyRPGtext - use at multiples of 8px.'})"
                usage = "Load as a Godot FontFile. Keep sizes at integer multiples ($(if($isTitle){'11'}else{'8'})px) so the pixels stay crisp. Shortcut roles: ui.font_title / ui.font_text."
                prompt = "pixel-art fantasy RPG $(if($isTitle){'title'}else{'body text'}) font, blocky readable glyphs." }
        }
        "spritesheet" {
            return @{ is_atlas = $true
                description = "Combined UI atlas ($name) - every UI piece packed into one sheet. The same pieces also exist pre-split under asset/ui/Individual files/, which are easier to use."
                usage = "Prefer the Individual files. If using this atlas, slice regions with AssetRegistry.load_texture_region('$id', Rect2i(...))."
                prompt = "fantasy RPG UI atlas, panels buttons icons orbs packed together, $style." }
        }
        "reference" {
            return @{ is_atlas = $true
                description = "Reference sheet ($name) showing every asset in the pack laid out for humans. Not a runtime asset."
                usage = "Human reference only - open it to see what the pack contains; do not load it in game."
                prompt = "asset pack reference sheet contact-sheet layout." }
        }
        "example" {
            return @{ is_atlas = $false
                description = "Animated example / preview ($name) demonstrating the pack in motion. Not a game asset."
                usage = "Documentation only - do not use in game."
                prompt = "animated preview gif of the asset pack." }
        }
        "banner" {
            return @{ is_atlas = $false
                description = "Marketing banner ($name) for the asset pack. Not a game asset."
                usage = "Documentation only - do not use in game."
                prompt = "asset pack marketing banner." }
        }
        "license" {
            return @{ is_atlas = $false
                description = "License & attribution text for the $($Entry.pack) pack (by Franuka). Commercial + non-commercial use allowed with attribution."
                usage = "Keep next to the pack. Credit Franuka (itch.io / Twitter) in the game. Do not delete."
                prompt = "" }
        }
        default {
            return @{ is_atlas = $false
                description = "$kind asset ($name) in group '$group'."
                usage = "Inspect the source file; add a shortcut in data/asset_shortcuts.json if used at runtime."
                prompt = "pixel-art game asset, $style." }
        }
    }
}

function Convert-ToSlug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace '\(no water layer\)', 'no_water'
    $slug = $slug -replace '\(size ([0-9]+)\)', 'size_$1'
    $slug = $slug -replace '[^a-z0-9]+', '_'
    $slug = $slug -replace '_+', '_'
    return $slug.Trim('_')
}

function Convert-ToRepoPath {
    param([string]$Path)

    $root = [System.IO.Path]::GetFullPath((Get-Location).Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $fullPath.Substring($root.Length).TrimStart('\', '/')
    }
    else {
        $relative = $fullPath
    }
    return ($relative -replace '\\', '/')
}

function Get-ScaleFromSegments {
    param([string[]]$Segments, [string]$FileName)

    foreach ($segment in $Segments) {
        if ($segment -match '^[123]x$') {
            return $segment
        }
    }

    if ($FileName -match '\(([123]x)\)') {
        return $Matches[1]
    }

    return $null
}

function Get-ImageSize {
    param([System.IO.FileInfo]$File)

    if ($File.Extension.ToLowerInvariant() -notin @(".png", ".gif")) {
        return @{ width = $null; height = $null }
    }

    try {
        $image = [System.Drawing.Image]::FromFile($File.FullName)
        try {
            return @{ width = $image.Width; height = $image.Height }
        }
        finally {
            $image.Dispose()
        }
    }
    catch {
        return @{ width = $null; height = $null }
    }
}

function Get-MapGridSize {
    param([string]$Scale)

    switch ($Scale) {
        "1x" { return 16 }
        "2x" { return 32 }
        "3x" { return 48 }
        default { return $null }
    }
}

function New-Entry {
    param(
        [System.IO.FileInfo]$File,
        [string]$Id,
        [string]$Category,
        [string]$Pack,
        [string]$Kind,
        [string]$Group,
        [string]$Scale,
        [hashtable]$Extra = @{}
    )

    $sourcePath = Convert-ToRepoPath $File.FullName
    $size = Get-ImageSize $File
    $tags = New-Object System.Collections.Generic.List[string]

    foreach ($tag in @($Category, $Pack, $Kind, $Group, $Scale)) {
        if (-not [string]::IsNullOrWhiteSpace($tag)) {
            $tags.Add((Convert-ToSlug $tag))
        }
    }

    foreach ($key in $Extra.Keys) {
        $value = $Extra[$key]
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            $tags.Add((Convert-ToSlug ([string]$value)))
        }
    }

    $entry = [ordered]@{
        id = $Id
        category = $Category
        pack = $Pack
        kind = $Kind
        group = $Group
        scale = $Scale
        name = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
        extension = $File.Extension.ToLowerInvariant()
        source_path = $sourcePath
        godot_path = "res://$sourcePath"
        file_size = $File.Length
        width = $size.width
        height = $size.height
        tags = @($tags | Select-Object -Unique)
    }

    foreach ($key in $Extra.Keys) {
        $entry[$key] = $Extra[$key]
    }

    $gridSize = Get-MapGridSize $Scale
    if ($Category -eq "map" -and $null -ne $gridSize -and $size.width -and $size.height) {
        if ($Kind -eq "unit_sprite") {
            $entry["grid_cell_width"] = $gridSize
            $entry["grid_cell_height"] = $gridSize
            if (($size.width % $gridSize) -eq 0) {
                $entry["grid_columns"] = [int]($size.width / $gridSize)
            }
            if (($size.height % $gridSize) -eq 0) {
                $entry["grid_rows"] = [int]($size.height / $gridSize)
            }
            if ($entry.Contains("grid_columns") -and $entry.Contains("grid_rows")) {
                $entry["frame_count"] = [int]($entry["grid_columns"] * $entry["grid_rows"])
            }
        }
        elseif ($Kind -in @("tilesheet", "fog_of_war")) {
            $entry["tile_width"] = $gridSize
            $entry["tile_height"] = $gridSize
            if (($size.width % $gridSize) -eq 0) {
                $entry["tile_columns"] = [int]($size.width / $gridSize)
            }
            if (($size.height % $gridSize) -eq 0) {
                $entry["tile_rows"] = [int]($size.height / $gridSize)
            }
        }
    }

    $semantics = Get-AssetSemantics $entry
    $entry["is_atlas"] = [bool]$semantics.is_atlas
    $entry["description"] = [string]$semantics.description
    $entry["usage"] = [string]$semantics.usage
    $entry["prompt"] = [string]$semantics.prompt
    if ($semantics.ContainsKey("sliced_reference") -and $semantics.sliced_reference) {
        $entry["sliced_reference"] = [string]$semantics.sliced_reference
    }

    return [pscustomobject]$entry
}

function Get-UiKind {
    param([string]$Group)

    switch ($Group) {
        "Background boxes" { return "background_box" }
        "Buttons" { return "button" }
        "Checkboxes" { return "checkbox" }
        "Cursors" { return "cursor" }
        "Dividers" { return "divider" }
        "Fonts" { return "bitmap_font" }
        "Item slots" { return "item_slot" }
        "Mini icons" { return "mini_icon" }
        "Resource orbs" { return "resource_orb" }
        "Sliders & Bars" { return "slider_bar" }
        "Spellbook & Tabs" { return "spellbook_tab" }
        "Title banners" { return "title_banner" }
        default { return Convert-ToSlug $Group }
    }
}

function Get-StateFromName {
    param([string]$Name)

    foreach ($state in @("Normal", "Pressed", "Selected", "On", "Off", "Bullet", "Outline")) {
        if ($Name -match "(^|_)$state$") {
            return $state.ToLowerInvariant()
        }
    }
    return $null
}

$assetRootPath = (Resolve-Path $AssetRoot).Path
Add-Type -AssemblyName System.Drawing

$files = Get-ChildItem -Path $assetRootPath -Recurse -File |
    Where-Object { $_.Extension.ToLowerInvariant() -in @(".png", ".gif", ".ttf", ".txt") } |
    Sort-Object FullName

$entries = foreach ($file in $files) {
    $repoPath = Convert-ToRepoPath $file.FullName
    $segments = $repoPath -split '/'
    $scale = Get-ScaleFromSegments $segments $file.Name
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $baseSlug = Convert-ToSlug $baseName

    if ($repoPath -like "asset/map/*") {
        if ($repoPath -like "asset/map/Examples/*") {
            New-Entry $file "map_example_$baseSlug" "map" "tactical_overworld" "example" "Examples" $scale
            continue
        }

        if ($file.Name -eq "License and details.txt") {
            New-Entry $file "map_license" "map" "tactical_overworld" "license" "Legal" $scale
            continue
        }

        if ($file.Name -eq "Banner.gif") {
            New-Entry $file "map_banner" "map" "tactical_overworld" "banner" "Marketing" $scale
            continue
        }

        if ($baseName -eq "FogOfWar") {
            New-Entry $file "map_${scale}_fog_of_war" "map" "tactical_overworld" "fog_of_war" "Fog of war" $scale
            continue
        }

        if ($repoPath -like "asset/map/*/Character sprites/*") {
            if ($baseName -match '^(?<unit_class>.+)_(?<variant>[0-9]+)_(?<animation>Idle|Move)$') {
                $unitClass = $Matches.unit_class
                $variant = $Matches.variant
                $animation = $Matches.animation.ToLowerInvariant()
                $unitSlug = Convert-ToSlug $unitClass
                New-Entry $file "map_${scale}_unit_${unitSlug}_${variant}_${animation}" "map" "tactical_overworld" "unit_sprite" "Character sprites" $scale @{
                    unit_class = $unitClass
                    variant = $variant
                    animation = $animation
                }
                continue
            }
        }

        if ($baseName -like "Tactical RPG Overworld Pack - *Tilesheet*") {
            $biome = "temperate"
            if ($baseName -like "*Desert*") { $biome = "desert" }
            if ($baseName -like "*Snow*") { $biome = "snow" }
            $waterMode = "water"
            $includesWater = $true
            if ($baseName -like "*NO WATER LAYER*") {
                $waterMode = "no_water"
                $includesWater = $false
            }
            New-Entry $file "map_${scale}_tilesheet_${biome}_${waterMode}" "map" "tactical_overworld" "tilesheet" "Tilesheets" $scale @{
                biome = $biome
                includes_water = $includesWater
            }
            continue
        }

        New-Entry $file "map_${scale}_$baseSlug" "map" "tactical_overworld" "unknown" "Unsorted" $scale
        continue
    }

    if ($repoPath -like "asset/ui/*") {
        if ($repoPath -like "asset/ui/Examples/*") {
            New-Entry $file "ui_example_$baseSlug" "ui" "fantasy_ui" "example" "Examples" $scale
            continue
        }

        if ($file.Name -eq "License and details.txt") {
            New-Entry $file "ui_license" "ui" "fantasy_ui" "license" "Legal" $scale
            continue
        }

        if ($repoPath -like "asset/ui/Fonts/*" -and $file.Extension.ToLowerInvariant() -eq ".ttf") {
            New-Entry $file "ui_font_$baseSlug" "ui" "fantasy_ui" "font" "Fonts" $scale
            continue
        }

        if ($baseName -like "UI assets *") {
            New-Entry $file "ui_${scale}_spritesheet" "ui" "fantasy_ui" "spritesheet" "Spritesheets" $scale
            continue
        }

        if ($baseName -eq "Reference sheet") {
            New-Entry $file "ui_reference_sheet" "ui" "fantasy_ui" "reference" "Reference" $scale
            continue
        }

        if ($repoPath -like "asset/ui/Individual files/*") {
            $group = $segments[4]
            $kind = Get-UiKind $group
            $state = Get-StateFromName $baseName
            $extra = @{}
            if ($state) { $extra.state = $state }
            New-Entry $file "ui_${scale}_${kind}_${baseSlug}" "ui" "fantasy_ui" $kind $group $scale $extra
            continue
        }

        New-Entry $file "ui_$baseSlug" "ui" "fantasy_ui" "unknown" "Unsorted" $scale
        continue
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutputJson) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $OutputMarkdown) | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$jsonText = $entries | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutputJson), $jsonText, $utf8NoBom)

$categorySummary = $entries | Group-Object category | Sort-Object Name
$kindSummary = $entries | Group-Object kind | Sort-Object Count -Descending
$scaleSummary = $entries | Where-Object { $_.scale } | Group-Object scale | Sort-Object Name
$groupSummary = $entries | Group-Object group | Sort-Object Count -Descending

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add("# Generated Asset Index")
$markdown.Add("")
$markdown.Add('Generated by `tools/generate_asset_catalog.ps1`.')
$markdown.Add("")
$markdown.Add('For per-asset descriptions, usage and prompts see the `description` / `usage` / `prompt` / `is_atlas` fields in `data/asset_catalog.json`, and the human guide `docs/ASSET_GUIDE.md`. Cut-out reference pieces live under `asset_sliced/` (regenerate with `tools/slice_sheets.ps1`).')
$markdown.Add("")
$markdown.Add("Total assets: $($entries.Count)")
$markdown.Add("")
$markdown.Add("## By category")
$markdown.Add("")
foreach ($item in $categorySummary) {
    $markdown.Add("- $($item.Name): $($item.Count)")
}
$markdown.Add("")
$markdown.Add("## By scale")
$markdown.Add("")
foreach ($item in $scaleSummary) {
    $markdown.Add("- $($item.Name): $($item.Count)")
}
$markdown.Add("")
$markdown.Add("## Top kinds")
$markdown.Add("")
foreach ($item in $kindSummary | Select-Object -First 20) {
    $markdown.Add("- $($item.Name): $($item.Count)")
}
$markdown.Add("")
$markdown.Add("## Top groups")
$markdown.Add("")
foreach ($item in $groupSummary | Select-Object -First 20) {
    $markdown.Add("- $($item.Name): $($item.Count)")
}
$markdown.Add("")
$markdown.Add("## TBH quick ids")
$markdown.Add("")
foreach ($id in @(
    "map_1x_tilesheet_temperate_water",
    "map_1x_tilesheet_desert_water",
    "map_1x_tilesheet_snow_water",
    "map_1x_fog_of_war",
    "map_1x_unit_soldier_01_idle",
    "map_1x_unit_villager_01_idle",
    "map_1x_unit_scout_01_idle",
    "ui_1x_background_box_bgbox_01a",
    "ui_1x_item_slot_slot_01_empty",
    "ui_1x_button_button_01a_normal",
    "ui_1x_mini_icon_icon_01",
    "ui_font_fantasyrpgtext_size_8"
)) {
    $entry = $entries | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if ($entry) {
        $markdown.Add(("- ``{0}`` -> ``{1}``" -f $entry.id, $entry.godot_path))
    }
}

$markdownText = ($markdown -join [System.Environment]::NewLine) + [System.Environment]::NewLine
[System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutputMarkdown), $markdownText, $utf8NoBom)

Write-Host "Wrote $($entries.Count) entries to $OutputJson"
Write-Host "Wrote generated index to $OutputMarkdown"
