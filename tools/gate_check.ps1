[CmdletBinding()]
param(
    [string]$GodotPath,
    [switch]$SkipScreenshot,
    [switch]$SkipTests,
    [int]$TestTimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Get-GodotExecutable {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path -LiteralPath $Explicit -PathType Leaf)) { return $Explicit }
    if ($env:GODOT_EXE -and (Test-Path -LiteralPath $env:GODOT_EXE -PathType Leaf)) { return $env:GODOT_EXE }
    $local = Get-ChildItem -LiteralPath $ProjectRoot -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*console*" } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($local) { return $local.FullName }
    $cmd = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Godot not found. Pass -GodotPath or set `$env:GODOT_EXE."
}

try {
    $godot = Get-GodotExecutable -Explicit $GodotPath
} catch {
    Write-Host "[gate] FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "[gate] Godot: $godot"

$overallPass = $true
$testExitCode = 0
$screenshotOK = $true

if (-not $SkipTests) {
    Write-Host "[gate] Running bootstrap test (headless)..."
    $testLog = Join-Path $ProjectRoot "gate_test.log"
    if (Test-Path -LiteralPath $testLog) { Remove-Item -LiteralPath $testLog -Force }

    $testArgs = @("--headless", "--path", $ProjectRoot, "res://tests/bootstrap_test.tscn")
    $proc = Start-Process -FilePath $godot -ArgumentList $testArgs `
        -NoNewWindow -Wait -PassThru -RedirectStandardOutput $testLog -RedirectStandardError "$testLog.err"

    $testExitCode = $proc.ExitCode
        $tail = ""
        if (Test-Path -LiteralPath $testLog) {
            $tail = (Get-Content -LiteralPath $testLog -Tail 20 -ErrorAction SilentlyContinue) -join "`n"
        }
        $errTail = ""
        if (Test-Path -LiteralPath "$testLog.err") {
            $errTail = (Get-Content -LiteralPath "$testLog.err" -Tail 20 -ErrorAction SilentlyContinue) -join "`n"
        }
        if ($testExitCode -eq 0) {
            Write-Host "[gate] tests OK (exit 0)"
            if ($tail) { Write-Host $tail }
        } else {
            Write-Host "[gate] FAIL - bootstrap test exit $testExitCode" -ForegroundColor Red
            if ($tail) { Write-Host "--- stdout (tail) ---`n$tail" }
            if ($errTail) { Write-Host "--- stderr (tail) ---`n$errTail" }
            $overallPass = $false
        }
} else {
    Write-Host "[gate] tests skipped (-SkipTests)"
}

if (-not $SkipScreenshot) {
    Write-Host "[gate] Capturing runtime screenshot..."
    $shotScript = Join-Path $ProjectRoot "tools\capture_runtime_screenshot.ps1"
    if (-not (Test-Path -LiteralPath $shotScript -PathType Leaf)) {
        Write-Host "[gate] FAIL - capture_runtime_screenshot.ps1 not found" -ForegroundColor Red
        $overallPass = $false
        $screenshotOK = $false
    } else {
        try {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $shotScript
            $shotPath = Join-Path $ProjectRoot "godot_runtime_screenshot.png"
            if (-not (Test-Path -LiteralPath $shotPath)) {
                Write-Host "[gate] FAIL - screenshot file was not produced" -ForegroundColor Red
                $overallPass = $false
                $screenshotOK = $false
            } else {
                $size = (Get-Item -LiteralPath $shotPath).Length
                if ($size -lt 3000) {
                    Write-Host "[gate] FAIL - screenshot too small ($size bytes) - likely blank" -ForegroundColor Red
                    $overallPass = $false
                    $screenshotOK = $false
                } else {
                    Write-Host "[gate] screenshot OK ($size bytes)"
                }
            }
        } catch {
            Write-Host "[gate] FAIL - screenshot capture threw: $($_.Exception.Message)" -ForegroundColor Red
            $overallPass = $false
            $screenshotOK = $false
        }
    }
} else {
    Write-Host "[gate] screenshot skipped (-SkipScreenshot)"
}

if ($overallPass) {
    Write-Host "[gate] OK - all checks passed" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[gate] FAIL - test_exit=$testExitCode screenshot_ok=$screenshotOK" -ForegroundColor Red
    exit 1
}
