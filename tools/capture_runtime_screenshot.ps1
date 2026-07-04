param(
    [string]$GodotPath = "",
    [string]$OutputPath = "godot_runtime_screenshot.png",
    [int]$LoadDelayMs = 6000,
    [int]$TimeoutSeconds = 8
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Resolve-GodotForCapture {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (Test-Path -LiteralPath $ExplicitPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $ExplicitPath).Path
        }
        if (Test-Path -LiteralPath $ExplicitPath -PathType Container) {
            $nested = Get-ChildItem -LiteralPath $ExplicitPath -Filter "Godot*.exe" -File |
                Where-Object { $_.Name -notlike "*console*" } |
                Select-Object -First 1
            if ($nested) { return $nested.FullName }
        }
        throw "Godot not found at $ExplicitPath"
    }

    $localFolder = Get-ChildItem -LiteralPath $ProjectRoot -Filter "Godot*.exe" -Directory -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($localFolder) {
        $nested = Get-ChildItem -LiteralPath $localFolder.FullName -Filter "Godot*.exe" -File |
            Where-Object { $_.Name -notlike "*console*" } |
            Select-Object -First 1
        if ($nested) { return $nested.FullName }
    }

    $localExe = Get-ChildItem -LiteralPath $ProjectRoot -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*console*" } |
        Select-Object -First 1
    if ($localExe) { return $localExe.FullName }

    throw "Godot executable not found."
}

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class RuntimeCaptureWin32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

function Find-TbhWindow {
    param([int]$ProcessId)

    $script:FoundTbhWindow = [IntPtr]::Zero
    $callback = [RuntimeCaptureWin32+EnumWindowsProc]{
        param([IntPtr]$Hwnd, [IntPtr]$Lparam)
        if (-not [RuntimeCaptureWin32]::IsWindowVisible($Hwnd)) { return $true }
        [uint32]$ownerProcessId = 0
        [void][RuntimeCaptureWin32]::GetWindowThreadProcessId($Hwnd, [ref]$ownerProcessId)
        if ($ownerProcessId -ne [uint32]$ProcessId) { return $true }
        $titleBuffer = New-Object System.Text.StringBuilder 512
        [void][RuntimeCaptureWin32]::GetWindowText($Hwnd, $titleBuffer, $titleBuffer.Capacity)
        if ($titleBuffer.ToString() -like "*TBH: Task Bar Hero*") {
            $script:FoundTbhWindow = $Hwnd
            return $false
        }
        return $true
    }
    [void][RuntimeCaptureWin32]::EnumWindows($callback, [IntPtr]::Zero)
    return $script:FoundTbhWindow
}

$godot = Resolve-GodotForCapture -ExplicitPath $GodotPath
$absoluteOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path $ProjectRoot $OutputPath
}
Remove-Item -LiteralPath $absoluteOutput -ErrorAction SilentlyContinue

$process = Start-Process -FilePath $godot -ArgumentList @("--path", $ProjectRoot) -PassThru
try {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $window = [IntPtr]::Zero
    while ($window -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
        $window = Find-TbhWindow -ProcessId $process.Id
    }
    if ($window -eq [IntPtr]::Zero) {
        throw "TBH Godot window was not found."
    }

    Start-Sleep -Milliseconds $LoadDelayMs
    $HWND_TOPMOST = [IntPtr]::new(-1)
    $SW_SHOW = 5
    $SWP_NOSIZE = 0x0001
    $SWP_NOMOVE = 0x0002
    $SWP_SHOWWINDOW = 0x0040
    [void][RuntimeCaptureWin32]::ShowWindow($window, $SW_SHOW)
    [void][RuntimeCaptureWin32]::SetWindowPos($window, $HWND_TOPMOST, 0, 0, 0, 0, ($SWP_NOSIZE -bor $SWP_NOMOVE -bor $SWP_SHOWWINDOW))
    [void][RuntimeCaptureWin32]::SetForegroundWindow($window)
    Start-Sleep -Milliseconds 350

    [RuntimeCaptureWin32+RECT]$rect = New-Object RuntimeCaptureWin32+RECT
    if (-not [RuntimeCaptureWin32]::GetWindowRect($window, [ref]$rect)) {
        throw "GetWindowRect failed."
    }

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) {
        throw "Invalid capture dimensions: ${width}x${height}"
    }

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save($absoluteOutput, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }

    Write-Host "Godot: $godot"
    Write-Host "Screenshot: $absoluteOutput"
    Write-Host "Window: ${width}x${height}"
}
finally {
    if (-not $process.HasExited) {
        Wait-Process -Id $process.Id -Timeout ($TimeoutSeconds + 2) -ErrorAction SilentlyContinue
    }
    Get-Process | Where-Object { $_.ProcessName -like "Godot*" } | Stop-Process -Force -ErrorAction SilentlyContinue
}
