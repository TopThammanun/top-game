<#
.SYNOPSIS
    Slice the map atlas sheets into a REFERENCE layer under asset_sliced/.

.DESCRIPTION
    This tool cuts the combined sheets in asset/map/ into individual pieces so
    humans and AI agents can *see and understand* each asset:

      * Character sprites  -> per-frame PNGs (16 frames) + one strip per row.
      * Tilesheets / Fog   -> each distinct object/tile block, extracted by
                              connected-component (alpha) labelling, snapped to
                              the 16px grid, and tagged with a terrain/building
                              role. Also writes a per-sheet index.json.

    IMPORTANT - this is a *reference / preview* artifact, NOT the runtime source.
    Originals in asset/ are never touched. At runtime the game still slices
    sheets through AssetRegistry (load_sprite_frame / load_grid_cell) per the
    repo rule `agents/sage/assets/decisions/slice-sheets-at-registry-boundary.md`.
    Regenerate anytime; asset_sliced/ can be deleted freely.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1
    powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1 -Scale 1x -What units
    powershell -ExecutionPolicy Bypass -File tools/slice_sheets.ps1 -Scale 3x -What tiles
#>
param(
    [ValidateSet("1x", "2x", "3x")]
    [string]$Scale = "1x",

    [ValidateSet("all", "units", "tiles", "fog")]
    [string]$What = "all",

    [string]$AssetRoot = "asset",
    [string]$OutRoot = "asset_sliced",

    # Ignore connected components smaller than this many opaque pixels (specks).
    [int]$MinObjectPx = 12,

    # Alpha above this counts as "opaque" when finding objects.
    [int]$AlphaThreshold = 24
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$cell = switch ($Scale) { "1x" { 16 } "2x" { 32 } "3x" { 48 } }

function New-Dir { param([string]$Path) [void][System.IO.Directory]::CreateDirectory($Path) }

function Save-Png {
    param([System.Drawing.Bitmap]$Bmp, [string]$Path)
    New-Dir ([System.IO.Path]::GetDirectoryName($Path))
    $Bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# Crop a rectangle out of a source bitmap into a fresh 32bpp bitmap.
function Get-Crop {
    param([System.Drawing.Bitmap]$Src, [int]$X, [int]$Y, [int]$W, [int]$H)
    $out = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $dst = New-Object System.Drawing.Rectangle 0, 0, $W, $H
    $g.DrawImage($Src, $dst, $X, $Y, $W, $H, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    return $out
}

# ---------------------------------------------------------------------------
# Tilesheet region-role map (in 1x tile units; y-band based, shared by biomes).
# The overworld sheet stacks content in horizontal bands; a piece's role is
# decided by the tile-row its top edge sits in (plus an x split for the cliff).
# Bands verified visually from the temperate + desert sheets (identical layout).
# ---------------------------------------------------------------------------
function Get-TileRole {
    param([int]$TileRow, [int]$TileCol)
    switch ($TileRow) {
        { $_ -le 1 }              { return "nature_canopy" }       # trees, rocks, bushes
        { $_ -ge 2  -and $_ -le 6 } {
            if ($TileCol -ge 13) { return "cliff_plateau" }         # tan elevated terrain
            return "terrain_swatch_foliage"                         # ground swatches + hedges
        }
        { $_ -ge 7  -and $_ -le 11 } { return "water_autotile_shallow" }
        { $_ -ge 12 -and $_ -le 16 } { return "sand_water_autotile" }
        { $_ -ge 17 -and $_ -le 26 } { return "path_floor_autotile" }
        { $_ -ge 27 -and $_ -le 32 } { return "deep_water_autotile" }
        { $_ -ge 33 -and $_ -le 40 } { return "buildings_block_1" }
        { $_ -ge 41 -and $_ -le 49 } { return "buildings_block_2" }
        default                      { return "props_objects" }     # barrels, potions, tents, flags, markers
    }
}

# ---------------------------------------------------------------------------
# Connected-component extraction over the alpha channel.
# Returns a list of PSCustomObjects: { X, Y, W, H, Area } in pixel units,
# with the bounding box snapped out to the $cell grid.
# ---------------------------------------------------------------------------
function Get-AlphaComponents {
    param([System.Drawing.Bitmap]$Bmp, [int]$Cell, [int]$MinPx, [int]$AlphaCut)

    $w = $Bmp.Width; $h = $Bmp.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $Bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object 'byte[]' ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $Bmp.UnlockBits($data)

    # opaque mask (byte per pixel) - BGRA so alpha is offset +3
    $opaque = New-Object 'byte[]' ($w * $h)
    for ($y = 0; $y -lt $h; $y++) {
        $row = $y * $stride
        $base = $y * $w
        for ($x = 0; $x -lt $w; $x++) {
            if ($bytes[$row + $x * 4 + 3] -gt $AlphaCut) { $opaque[$base + $x] = 1 }
        }
    }

    $visited = New-Object 'byte[]' ($w * $h)
    $stackX = New-Object 'int[]' ($w * $h)
    $stackY = New-Object 'int[]' ($w * $h)
    $components = New-Object System.Collections.Generic.List[object]

    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $idx = $y * $w + $x
            if ($opaque[$idx] -eq 0 -or $visited[$idx] -eq 1) { continue }

            $sp = 0
            $stackX[0] = $x; $stackY[0] = $y; $sp = 1
            $visited[$idx] = 1
            $minX = $x; $maxX = $x; $minY = $y; $maxY = $y; $area = 0

            while ($sp -gt 0) {
                $sp--
                $cx = $stackX[$sp]; $cy = $stackY[$sp]
                $area++
                if ($cx -lt $minX) { $minX = $cx }
                if ($cx -gt $maxX) { $maxX = $cx }
                if ($cy -lt $minY) { $minY = $cy }
                if ($cy -gt $maxY) { $maxY = $cy }

                # 8-connectivity keeps diagonally-touching sprite parts together
                for ($dy = -1; $dy -le 1; $dy++) {
                    $ny = $cy + $dy
                    if ($ny -lt 0 -or $ny -ge $h) { continue }
                    for ($dx = -1; $dx -le 1; $dx++) {
                        if ($dx -eq 0 -and $dy -eq 0) { continue }
                        $nx = $cx + $dx
                        if ($nx -lt 0 -or $nx -ge $w) { continue }
                        $nidx = $ny * $w + $nx
                        if ($opaque[$nidx] -eq 1 -and $visited[$nidx] -eq 0) {
                            $visited[$nidx] = 1
                            $stackX[$sp] = $nx; $stackY[$sp] = $ny; $sp++
                        }
                    }
                }
            }

            if ($area -lt $MinPx) { continue }

            # snap bbox out to the tile grid
            $sx = [math]::Floor($minX / $Cell) * $Cell
            $sy = [math]::Floor($minY / $Cell) * $Cell
            $ex = [math]::Ceiling(($maxX + 1) / $Cell) * $Cell
            $ey = [math]::Ceiling(($maxY + 1) / $Cell) * $Cell
            $components.Add([pscustomobject]@{
                X = [int]$sx; Y = [int]$sy; W = [int]($ex - $sx); H = [int]($ey - $sy); Area = $area
            })
        }
    }

    # top-to-bottom, left-to-right for stable numbering
    return $components | Sort-Object Y, X
}

# ===========================================================================
# UNIT SPRITES  ->  per-frame + per-row strip
# ===========================================================================
function Export-Units {
    $dir = Join-Path $AssetRoot "map/$Scale/Character sprites"
    if (-not (Test-Path $dir)) { Write-Host "  (no unit dir for $Scale)"; return 0 }
    $count = 0
    Get-ChildItem -Path $dir -Filter *.png | ForEach-Object {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $img = New-Object System.Drawing.Bitmap $_.FullName
        try {
            $cols = [int]($img.Width / $cell)
            $rows = [int]($img.Height / $cell)
            $outDir = Join-Path $OutRoot "units/$Scale/$name"
            for ($r = 0; $r -lt $rows; $r++) {
                # per-row strip (an animation track)
                $strip = New-Object System.Drawing.Bitmap ($cols * $cell), $cell, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $sg = [System.Drawing.Graphics]::FromImage($strip)
                $sg.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                for ($c = 0; $c -lt $cols; $c++) {
                    $frame = Get-Crop $img ($c * $cell) ($r * $cell) $cell $cell
                    Save-Png $frame (Join-Path $outDir ("frame_r{0}_c{1}.png" -f $r, $c))
                    $sdst = New-Object System.Drawing.Rectangle ($c * $cell), 0, $cell, $cell
                    $sg.DrawImage($frame, $sdst, 0, 0, $cell, $cell, [System.Drawing.GraphicsUnit]::Pixel)
                    $frame.Dispose()
                    $count++
                }
                $sg.Dispose()
                Save-Png $strip (Join-Path $outDir ("row{0}_strip.png" -f $r))
                $strip.Dispose()
            }
        }
        finally { $img.Dispose() }
    }
    return $count
}

# ===========================================================================
# TILESHEETS + FOG  ->  connected-component objects + index.json
# ===========================================================================
function Export-Sheet {
    param([System.IO.FileInfo]$File, [string]$OutName, [bool]$IsFog)
    $img = New-Object System.Drawing.Bitmap $File.FullName
    $count = 0
    try {
        $outDir = Join-Path $OutRoot "tiles/$OutName/$Scale"
        $comps = Get-AlphaComponents $img $cell $MinObjectPx $AlphaThreshold
        $index = New-Object System.Collections.Generic.List[object]
        $roleCounters = @{}
        foreach ($comp in $comps) {
            $tileCol = [int]($comp.X / $cell)
            $tileRow = [int]($comp.Y / $cell)
            $role = if ($IsFog) { "fog_autotile" } else { Get-TileRole $tileRow $tileCol }
            if (-not $roleCounters.ContainsKey($role)) { $roleCounters[$role] = 0 }
            $n = $roleCounters[$role]; $roleCounters[$role] = $n + 1
            $fname = ("{0}_{1:d3}_c{2}_r{3}.png" -f $role, $n, $tileCol, $tileRow)
            $crop = Get-Crop $img $comp.X $comp.Y $comp.W $comp.H
            Save-Png $crop (Join-Path $outDir $fname)
            $crop.Dispose()
            $index.Add([pscustomobject]@{
                file = $fname; role = $role
                tile_col = $tileCol; tile_row = $tileRow
                px_x = $comp.X; px_y = $comp.Y; px_w = $comp.W; px_h = $comp.H
                tiles_w = [int]($comp.W / $cell); tiles_h = [int]($comp.H / $cell)
            })
            $count++
        }
        $meta = [pscustomobject]@{
            sheet = $OutName; scale = $Scale; cell = $cell
            source = ($File.FullName -replace [regex]::Escape((Get-Location).Path + [System.IO.Path]::DirectorySeparatorChar), '' -replace '\\', '/')
            object_count = $count
            objects = $index
        }
        New-Dir $outDir
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText((Join-Path $outDir "index.json"), ($meta | ConvertTo-Json -Depth 6), $utf8)
    }
    finally { $img.Dispose() }
    return $count
}

function Export-Tiles {
    $dir = Join-Path $AssetRoot "map/$Scale"
    if (-not (Test-Path $dir)) { Write-Host "  (no map dir for $Scale)"; return 0 }
    $total = 0
    Get-ChildItem -Path $dir -Filter *.png | Where-Object { $_.Name -like "*Tilesheet*" } | ForEach-Object {
        $biome = "temperate"
        if ($_.Name -like "*Desert*") { $biome = "desert" }
        if ($_.Name -like "*Snow*") { $biome = "snow" }
        $water = if ($_.Name -like "*NO WATER LAYER*") { "no_water" } else { "water" }
        $outName = "${biome}_${water}"
        $n = Export-Sheet $_ $outName $false
        Write-Host ("  tilesheet {0,-18} -> {1} objects" -f $outName, $n)
        $total += $n
    }
    return $total
}

function Export-Fog {
    $file = Get-Item (Join-Path $AssetRoot "map/$Scale/FogOfWar.png") -ErrorAction SilentlyContinue
    if (-not $file) { Write-Host "  (no fog for $Scale)"; return 0 }
    $n = Export-Sheet $file "fog_of_war" $true
    Write-Host ("  fog_of_war         -> {0} objects" -f $n)
    return $n
}

# ===========================================================================
Write-Host "Slicing scale=$Scale what=$What (cell=${cell}px) -> $OutRoot/"
$unitFrames = 0; $tileObjs = 0; $fogObjs = 0
if ($What -in @("all", "units")) { Write-Host "Units:";      $unitFrames = Export-Units; Write-Host "  $unitFrames frames" }
if ($What -in @("all", "tiles")) { Write-Host "Tilesheets:"; $tileObjs   = Export-Tiles }
if ($What -in @("all", "fog"))   { Write-Host "Fog:";        $fogObjs    = Export-Fog }

Write-Host ""
Write-Host ("Done. unit frames=$unitFrames  tile objects=$tileObjs  fog objects=$fogObjs")
Write-Host "Output under $OutRoot/ (reference only - runtime still uses AssetRegistry)."
