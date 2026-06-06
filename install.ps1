#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for Cursed Cursor. Downloads the script from GitHub, installs it
    per-user, and puts a 'cursed-cursor' command on your PATH.

.DESCRIPTION
    Run it straight from the web (no clone, no admin):

        irm https://raw.githubusercontent.com/r000bin/cursed-cursor/main/install.ps1 | iex

    To uninstall, invoke it as a scriptblock so you can pass the switch:

        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/r000bin/cursed-cursor/main/install.ps1))) -Uninstall

.PARAMETER Ref
    Branch or tag to install from. Defaults to 'main'.

.PARAMETER Uninstall
    Remove the installed files and the PATH entry.
#>
[CmdletBinding()]
param(
    [string]$Ref = 'main',
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$AppName    = 'CursedCursor'
$Command    = 'cursed-cursor'
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\$AppName"
$ScriptPath = Join-Path $InstallDir "$AppName.ps1"
$ShimPath   = Join-Path $InstallDir "$Command.cmd"
$RawBase    = "https://raw.githubusercontent.com/r000bin/cursed-cursor/$Ref"

function Add-ToUserPath {
    param([string]$Dir)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @(); if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_ -ne '' } }
    if ($parts -notcontains $Dir) {
        [Environment]::SetEnvironmentVariable('Path', ((@($parts) + $Dir) -join ';'), 'User')
        return $true
    }
    return $false
}

function Remove-FromUserPath {
    param([string]$Dir)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { return }
    $parts = $userPath -split ';' | Where-Object { $_ -ne '' -and $_ -ne $Dir }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

if ($Uninstall) {
    Write-Host "Uninstalling $AppName..." -ForegroundColor Cyan
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    Remove-FromUserPath -Dir $InstallDir
    Write-Host "Done. '$Command' removed. Open a new terminal for PATH to update." -ForegroundColor Green
    return
}

Write-Host "Installing $AppName (ref: $Ref)..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Download the tool.
Invoke-WebRequest -Uri "$RawBase/CursedCursor.ps1" -OutFile $ScriptPath -UseBasicParsing

# Write a .cmd shim so 'cursed-cursor' works from any shell and bypasses the
# execution policy (the downloaded .ps1 itself is never run by name).
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0$AppName.ps1" %*
"@ | Set-Content -Path $ShimPath -Encoding ASCII

$added = Add-ToUserPath -Dir $InstallDir
if ($env:Path -notlike "*$InstallDir*") { $env:Path = "$env:Path;$InstallDir" }  # usable now

Write-Host ""
Write-Host "Installed to $InstallDir" -ForegroundColor Green
Write-Host "Command available: $Command" -ForegroundColor Green
if ($added) { Write-Host "Added to PATH - open a NEW terminal to make it permanent." -ForegroundColor Yellow }
Write-Host ""
Write-Host "Try it:" -ForegroundColor Cyan
Write-Host "    $Command wild       # maximum chaos (Ctrl+C to stop and restore)"
Write-Host "    $Command restore    # put your pointer back"
Write-Host ""
Write-Host "Uninstall:" -ForegroundColor Cyan
Write-Host "    & ([scriptblock]::Create((irm $RawBase/install.ps1))) -Uninstall"
