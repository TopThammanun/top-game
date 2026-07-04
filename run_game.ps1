[CmdletBinding()]
param(
    [string]$GodotPath,
    [switch]$Editor,
    [switch]$ProjectManager,
    [switch]$PrintCommand,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-GodotExecutable {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (Test-Path -LiteralPath $ExplicitPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $ExplicitPath).Path
        }
        if (Test-Path -LiteralPath $ExplicitPath -PathType Container) {
            $nestedGodot = Get-ChildItem -LiteralPath $ExplicitPath -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notlike "*console*" } |
                Sort-Object Name -Descending |
                Select-Object -First 1
            if (-not $nestedGodot) {
                $nestedGodot = Get-ChildItem -LiteralPath $ExplicitPath -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending |
                    Select-Object -First 1
            }
            if ($nestedGodot) {
                return $nestedGodot.FullName
            }
        }
        throw "Godot executable not found at -GodotPath '$ExplicitPath'."
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_EXE)) {
        if (Test-Path -LiteralPath $env:GODOT_EXE -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:GODOT_EXE).Path
        }
        if (Test-Path -LiteralPath $env:GODOT_EXE -PathType Container) {
            $nestedGodot = Get-ChildItem -LiteralPath $env:GODOT_EXE -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notlike "*console*" } |
                Sort-Object Name -Descending |
                Select-Object -First 1
            if ($nestedGodot) {
                return $nestedGodot.FullName
            }
        }
        throw "GODOT_EXE is set, but the file does not exist: $env:GODOT_EXE"
    }

    $projectLocalGodot = Get-ChildItem -LiteralPath $ProjectRoot -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*console*" } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($projectLocalGodot) {
        return $projectLocalGodot.FullName
    }

    $projectLocalGodotDir = Get-ChildItem -LiteralPath $ProjectRoot -Filter "Godot*.exe" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($projectLocalGodotDir) {
        $nestedGodot = Get-ChildItem -LiteralPath $projectLocalGodotDir.FullName -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike "*console*" } |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($nestedGodot) {
            return $nestedGodot.FullName
        }
    }

    foreach ($commandName in @("godot", "godot4", "godot.exe", "godot4.exe")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source) {
            return $command.Source
        }
    }

    $candidateRoots = @(
        "$env:ProgramFiles\Godot",
        "${env:ProgramFiles(x86)}\Godot",
        "$env:LOCALAPPDATA\Programs\Godot",
        "$env:USERPROFILE\scoop\apps\godot\current",
        "$env:USERPROFILE\scoop\shims"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($root in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        $direct = Get-ChildItem -LiteralPath $root -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($direct) {
            return $direct.FullName
        }

        $nested = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue
            } |
            Select-Object -First 1
        if ($nested) {
            return $nested.FullName
        }
    }

    throw @"
Could not find Godot.

Install Godot 4.x, then use one of these:

  winget install -e --id GodotEngine.GodotEngine

Then open a new terminal and run:

  .\run_game.ps1

If you already have Godot downloaded somewhere:

  .\run_game.ps1 -GodotPath "C:\Path\To\Godot_v4.x-stable_win64.exe"

Or set GODOT_EXE for the current PowerShell session:

  `$env:GODOT_EXE = "C:\Path\To\Godot_v4.x-stable_win64.exe"
  .\run_game.ps1

Or add the Godot executable folder to PATH so `godot --version` works.
"@
}

try {
    $godot = Resolve-GodotExecutable -ExplicitPath $GodotPath
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}

$argsForGodot = @()
if ($ProjectManager) {
    $argsForGodot += "--project-manager"
}
else {
    $argsForGodot += @("--path", $ProjectRoot)
    if ($Editor) {
        $argsForGodot += "--editor"
    }
}

if ($GodotArgs) {
    $argsForGodot += $GodotArgs
}

Write-Host "Godot:  $godot"
if (-not $ProjectManager) {
    Write-Host "Project: $ProjectRoot"
}

if ($PrintCommand) {
    Write-Host ("Command: `"{0}`" {1}" -f $godot, ($argsForGodot -join " "))
}

& $godot @argsForGodot
exit $LASTEXITCODE
