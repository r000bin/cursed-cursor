<#PSScriptInfo

.VERSION 1.0.0

.GUID bf1679f7-0923-4c7c-bc37-23fed38c538b

.AUTHOR r000bin

.COPYRIGHT (c) 2026 r000bin

.TAGS Windows cursor mouse pointer fun prank toy

.LICENSEURI https://github.com/r000bin/cursed-cursor/blob/main/LICENSE

.PROJECTURI https://github.com/r000bin/cursed-cursor

.RELEASENOTES
Initial release: randomize / restore / run / wild / set modes.

#>

#Requires -Version 5.1

<#
.SYNOPSIS
    Cursed Cursor - randomly changes the Windows mouse pointer (appearance, size,
    and speed) just for fun.

.DESCRIPTION
    Uses the native Win32 cursor APIs (LoadImage, SetSystemCursor,
    SystemParametersInfo) via P/Invoke to swap the system cursors for random ones
    found in C:\Windows\Cursors - at random sizes - and optionally randomize the
    pointer speed.

    IMPORTANT: cursor changes made with SetSystemCursor are SYSTEM-WIDE and STICKY.
    Always run 'restore' (or use 'run'/'wild' which restore on Ctrl+C) to put
    things back. A reboot or sign-out also resets the system cursors.

.PARAMETER Mode
    randomize : pick random cursors + size + speed, apply, and exit (persists).
    restore   : put the user's real cursors and speed back.
    run       : loop forever, re-randomizing on an interval; restores on Ctrl+C.
    wild      : like 'run', but cranked - bimodal size (tiny specks <-> huge
                monsters) + bimodal speed (sluggish <-> flighty) on a random
                interval, with the explicit aim of making it hard to click.
    set       : apply an explicit cursor file and/or speed/size (for testing).

.PARAMETER IntervalSeconds
    Seconds between changes in 'run' mode. Default 10.

.PARAMETER Cursor
    Path to a .cur/.ani file (used by 'set' mode).

.PARAMETER Speed
    Mouse speed 1-20 (used by 'set' mode). 10 is the Windows default.

.PARAMETER Size
    Cursor size in pixels, 8-256 (used by 'set' mode). 32 is the normal default.

.PARAMETER SkipSpeed
    Don't touch the pointer speed; only change the cursor appearance.

.PARAMETER SkipSize
    Don't randomize the cursor size; load cursors at the system default size.

.EXAMPLE
    .\CursedCursor.ps1 randomize
.EXAMPLE
    .\CursedCursor.ps1 run -IntervalSeconds 5
.EXAMPLE
    .\CursedCursor.ps1 restore
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('randomize', 'restore', 'run', 'wild', 'set')]
    [string]$Mode = 'randomize',

    [int]$IntervalSeconds = 10,

    [string]$Cursor,

    [ValidateRange(1, 20)]
    [int]$Speed,

    [ValidateRange(8, 256)]
    [int]$Size,

    [switch]$SkipSpeed,

    [switch]$SkipSize
)

# --- Native interop -----------------------------------------------------------
if (-not ('PointerNative' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class PointerNative
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetSystemCursor(IntPtr hcur, uint id);

    // LoadImage lets us request an explicit cursor size (cx/cy); pass 0 + LR_DEFAULTSIZE
    // for the system default. Works for both .cur and .ani.
    [DllImport("user32.dll", EntryPoint = "LoadImageW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr LoadImage(IntPtr hinst, string name, uint type, int cx, int cy, uint fuLoad);

    // pvParam carries a value (mouse speed) or IntPtr.Zero (reload cursors).
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    public static extern bool SystemParametersInfoSet(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

    // pvParam points to an int that receives a value (get mouse speed).
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    public static extern bool SystemParametersInfoGet(uint uiAction, uint uiParam, ref int pvParam, uint fWinIni);
}
'@
}

# Win32 constants
$SPI_SETCURSORS    = 0x0057
$SPI_GETMOUSESPEED = 0x0070
$SPI_SETMOUSESPEED = 0x0071
$SPIF_SENDCHANGE   = 0x02

$IMAGE_CURSOR    = 0x02
$LR_LOADFROMFILE = 0x10
$LR_DEFAULTSIZE  = 0x40

# Range of random cursor sizes (px). 32 is the normal default; bigger = sillier.
$MinCursorSize = 24
$MaxCursorSize = 128

# 'wild' mode: cranked so clicking precisely is genuinely hard - extreme cursors
# + lurching speed + an unpredictable loop. Each round waits a random time in
# [WildIntervalMinSec, WildIntervalMaxSec] so you can't anticipate the reshuffle.
$WildIntervalMinSec = 0.5
$WildIntervalMaxSec = 3.0

# Wild size is bimodal: each cursor slot flips between a tiny band (you can
# barely find the pointer) and a huge band (covers a chunk of the screen, with
# the hotspot nowhere near where the graphic looks like it points).
$TinySizeMin = 8   ; $TinySizeMax = 28    # specks
$HugeSizeMin = 320 ; $HugeSizeMax = 512   # screen-hogging monsters

# Wild speed is bimodal: each round flips between a super-sluggish band and a
# super-flighty band (nothing in the usable middle), so the pointer's feel
# lurches unpredictably.
$SluggishMin = 1   ; $SluggishMax = 2    # crawls
$FlightyMin  = 19  ; $FlightyMax  = 20   # rockets across the screen

# System cursor (OCR_*) ids that SetSystemCursor understands.
$OCR = @{
    Normal      = 32512  # arrow
    IBeam       = 32513  # text select
    Wait        = 32514  # busy / hourglass
    Cross       = 32515  # precision select
    Up          = 32516
    SizeNWSE    = 32642
    SizeNESW    = 32643
    SizeWE      = 32644
    SizeNS      = 32645
    SizeAll     = 32646
    No          = 32648  # unavailable
    Hand        = 32649  # link select
    AppStarting = 32650  # working in background
}

$CursorDir = Join-Path $env:WINDIR 'Cursors'
$StateFile = Join-Path $env:LOCALAPPDATA 'cursed-cursor-state.json'

# --- Helpers ------------------------------------------------------------------
function Get-CursorFiles {
    # NB: -Include only works when the path ends in a wildcard (or with -Recurse).
    Get-ChildItem -Path (Join-Path $CursorDir '*') -Include '*.cur', '*.ani' -File -ErrorAction SilentlyContinue
}

function Get-MouseSpeed {
    $value = 0
    [void][PointerNative]::SystemParametersInfoGet($SPI_GETMOUSESPEED, 0, [ref]$value, 0)
    return $value
}

function Set-MouseSpeed {
    param([int]$Value)
    [void][PointerNative]::SystemParametersInfoSet($SPI_SETMOUSESPEED, 0, [IntPtr]$Value, $SPIF_SENDCHANGE)
}

function Save-OriginalSpeed {
    # Only capture the *original* speed once, so repeated randomizes don't
    # overwrite it with an already-randomized value.
    if (-not (Test-Path $StateFile)) {
        $state = @{ OriginalSpeed = Get-MouseSpeed }
        $state | ConvertTo-Json | Set-Content -Path $StateFile -Encoding utf8
    }
}

function Restore-Pointers {
    # Reload the real system cursors from the registry...
    [void][PointerNative]::SystemParametersInfoSet($SPI_SETCURSORS, 0, [IntPtr]::Zero, 0)

    # ...and restore the saved original speed, if we have one.
    if (Test-Path $StateFile) {
        try {
            $state = Get-Content -Path $StateFile -Raw | ConvertFrom-Json
            if ($null -ne $state.OriginalSpeed) {
                Set-MouseSpeed -Value ([int]$state.OriginalSpeed)
            }
        }
        catch { }
        Remove-Item -Path $StateFile -ErrorAction SilentlyContinue
    }
    Write-Host 'Pointers restored to normal.' -ForegroundColor Green
}

function Get-CursorHandle {
    # Load a cursor file at a specific pixel size. Size 0 = system default.
    param([string]$Path, [int]$Size = 0)
    if ($Size -gt 0) {
        return [PointerNative]::LoadImage([IntPtr]::Zero, $Path, $IMAGE_CURSOR, $Size, $Size, $LR_LOADFROMFILE)
    }
    return [PointerNative]::LoadImage([IntPtr]::Zero, $Path, $IMAGE_CURSOR, 0, 0, ($LR_LOADFROMFILE -bor $LR_DEFAULTSIZE))
}

function Set-CursorForAll {
    # Apply one specific cursor file to every system cursor slot.
    param([string]$Path, [int]$Size = 0)
    foreach ($id in $OCR.Values) {
        # SetSystemCursor destroys the handle it is given, so load a fresh
        # handle for each slot.
        $h = Get-CursorHandle -Path $Path -Size $Size
        if ($h -ne [IntPtr]::Zero) {
            [void][PointerNative]::SetSystemCursor($h, [uint32]$id)
        }
    }
}

function Set-RandomCursors {
    # Give each system cursor slot its own random cursor for maximum chaos.
    # Size behaviour per slot:
    #   -BimodalSize : coin-flip between the tiny band and the huge band
    #   -RandomSize  : uniform random in [MinSize, MaxSize]
    #   neither      : system default size
    # (-BimodalSize implies random sizing and takes precedence over -RandomSize.)
    param(
        [switch]$RandomSize,
        [switch]$BimodalSize,
        [int]$MinSize = $MinCursorSize,
        [int]$MaxSize = $MaxCursorSize
    )
    $files = Get-CursorFiles
    if (-not $files -or $files.Count -eq 0) {
        Write-Warning "No cursor files found in $CursorDir."
        return
    }
    foreach ($id in $OCR.Values) {
        $file = $files | Get-Random
        $slotSize =
            if ($BimodalSize) {
                if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) {
                    Get-Random -Minimum $TinySizeMin -Maximum ($TinySizeMax + 1)
                }
                else {
                    Get-Random -Minimum $HugeSizeMin -Maximum ($HugeSizeMax + 1)
                }
            }
            elseif ($RandomSize) { Get-Random -Minimum $MinSize -Maximum ($MaxSize + 1) }
            else { 0 }
        $h = Get-CursorHandle -Path $file.FullName -Size $slotSize
        if ($h -ne [IntPtr]::Zero) {
            [void][PointerNative]::SetSystemCursor($h, [uint32]$id)
        }
    }
    $sizeNote =
        if ($BimodalSize) { "bimodal sizes ($TinySizeMin-$TinySizeMax px specks / $HugeSizeMin-$HugeSizeMax px monsters)" }
        elseif ($RandomSize) { "random sizes $MinSize-$MaxSize px" }
        else { 'default size' }
    Write-Host "Cursors randomized from $($files.Count) files ($sizeNote)." -ForegroundColor Cyan
}

function Invoke-Randomize {
    param(
        [switch]$NoSpeed,
        [switch]$NoSize,
        [switch]$BimodalSpeed,   # flip between super-sluggish and super-flighty
        [switch]$BimodalSize,    # flip between tiny specks and huge monsters
        [int]$MinSize = $MinCursorSize,
        [int]$MaxSize = $MaxCursorSize,
        [int]$MinSpeed = 4,    # 4..20 keeps normal mode usable-ish
        [int]$MaxSpeed = 20
    )
    Save-OriginalSpeed
    Set-RandomCursors -RandomSize:(-not $NoSize) -BimodalSize:($BimodalSize -and -not $NoSize) -MinSize $MinSize -MaxSize $MaxSize
    if (-not $NoSpeed) {
        if ($BimodalSpeed) {
            # Coin-flip between the two extreme bands - nothing in between.
            if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) {
                $newSpeed = Get-Random -Minimum $SluggishMin -Maximum ($SluggishMax + 1)
                $mood = 'super-sluggish'
            }
            else {
                $newSpeed = Get-Random -Minimum $FlightyMin -Maximum ($FlightyMax + 1)
                $mood = 'super-flighty'
            }
            Set-MouseSpeed -Value $newSpeed
            Write-Host "Pointer speed set to $newSpeed - $mood (default is 10)." -ForegroundColor Cyan
        }
        else {
            $newSpeed = Get-Random -Minimum $MinSpeed -Maximum ($MaxSpeed + 1)
            Set-MouseSpeed -Value $newSpeed
            Write-Host "Pointer speed set to $newSpeed (default is 10)." -ForegroundColor Cyan
        }
    }
}

# --- Main ---------------------------------------------------------------------
switch ($Mode) {
    'restore' {
        Restore-Pointers
    }

    'set' {
        Save-OriginalSpeed
        if ($Cursor) {
            if (Test-Path $Cursor) {
                $applySize = if ($PSBoundParameters.ContainsKey('Size')) { $Size } else { 0 }
                Set-CursorForAll -Path (Resolve-Path $Cursor) -Size $applySize
                $sizeNote = if ($applySize -gt 0) { " at $applySize px" } else { '' }
                Write-Host "Applied cursor: $Cursor$sizeNote" -ForegroundColor Cyan
            }
            else {
                Write-Warning "Cursor file not found: $Cursor"
            }
        }
        if ($PSBoundParameters.ContainsKey('Speed')) {
            Set-MouseSpeed -Value $Speed
            Write-Host "Pointer speed set to $Speed." -ForegroundColor Cyan
        }
    }

    'randomize' {
        Invoke-Randomize -NoSpeed:$SkipSpeed -NoSize:$SkipSize
        Write-Host "Run '.\CursedCursor.ps1 restore' to put things back." -ForegroundColor Yellow
    }

    'run' {
        Write-Host "Going wild every $IntervalSeconds s. Press Ctrl+C to stop and restore." -ForegroundColor Magenta
        try {
            while ($true) {
                Invoke-Randomize -NoSpeed:$SkipSpeed -NoSize:$SkipSize
                Start-Sleep -Seconds $IntervalSeconds
            }
        }
        finally {
            # Runs on Ctrl+C / window close so we never leave the pointer wild.
            Restore-Pointers
        }
    }

    'wild' {
        # Explicit -IntervalSeconds pins the wait; otherwise it's random per round.
        $fixedSec = if ($PSBoundParameters.ContainsKey('IntervalSeconds')) { $IntervalSeconds } else { $null }
        $intervalNote = if ($null -ne $fixedSec) { "$fixedSec s" } else { "$WildIntervalMinSec-$WildIntervalMaxSec s (random)" }
        Write-Host "WILD MODE: bimodal size (specks<->monsters) + bimodal speed (sluggish<->flighty) every $intervalNote." -ForegroundColor Red
        Write-Host "Good luck clicking anything. Press Ctrl+C to stop and restore." -ForegroundColor Red
        try {
            while ($true) {
                Invoke-Randomize -NoSpeed:$SkipSpeed -NoSize:$SkipSize -BimodalSpeed -BimodalSize
                $sleepSec = if ($null -ne $fixedSec) { $fixedSec } else { Get-Random -Minimum $WildIntervalMinSec -Maximum $WildIntervalMaxSec }
                Start-Sleep -Milliseconds ([int]($sleepSec * 1000))
            }
        }
        finally {
            # Always restore, even on Ctrl+C - otherwise the pointer stays unusable.
            Restore-Pointers
        }
    }
}
