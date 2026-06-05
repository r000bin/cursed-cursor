# 🖱️ Cursed Cursor

A small, just-for-fun Windows tool that randomizes your mouse pointer — its
**appearance**, **size**, and **speed** — using the native Win32 cursor APIs.
Run it for a laugh, prank a friend, or crank it up to **wild mode**, where the
explicit goal is to make clicking anything genuinely hard.

> ⚠️ Changes are **system-wide**. Always `restore` when you're done (a sign-out
> or reboot also resets the system cursors). See [Safety](#safety).

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (built in) or PowerShell 7+
- No install, no admin rights, no dependencies — it's a single script

## Quick start

Double-click one of the `.cmd` launchers:

| File | What it does |
|------|--------------|
| **`Wild.cmd`** | One-shot randomize (cursors + size + speed), then exits |
| **`RunWild.cmd`** | Continuous chaos every 5 s; `Ctrl+C` stops & restores |
| **`WildMode.cmd`** | **Wild mode** — extreme size/speed, aims to be unclickable |
| **`Restore.cmd`** | Puts your normal pointer back |

Or run it from a PowerShell window:

```powershell
powershell -ExecutionPolicy Bypass -File .\CursedCursor.ps1 randomize
powershell -ExecutionPolicy Bypass -File .\CursedCursor.ps1 restore
```

(Tip: run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once and you can
drop the `-ExecutionPolicy Bypass`.)

## Modes

```
randomize   Pick random cursors + size + speed, apply, and exit (persists).
restore     Put your real cursors and speed back.
run         Loop forever, re-randomizing on an interval; restores on Ctrl+C.
wild        Like 'run', but cranked — bimodal size + bimodal speed on a random
            interval, with the explicit aim of making it hard to click.
set         Apply an explicit cursor file and/or speed/size (for testing).
```

### Examples

```powershell
# Gentle continuous fun, re-rolling every 8 seconds
.\CursedCursor.ps1 run -IntervalSeconds 8

# Maximum havoc
.\CursedCursor.ps1 wild

# Only change the look, leave speed and size alone
.\CursedCursor.ps1 randomize -SkipSpeed -SkipSize

# A specific giant cursor, no speed change
.\CursedCursor.ps1 set -Cursor C:\Windows\Cursors\dinosaur.ani -Size 200 -SkipSpeed
```

### What "wild" does

- **Bimodal size** — each cursor is either a tiny speck (8–28 px) or a
  screen-hogging monster (320–512 px), nothing in between.
- **Bimodal speed** — the pointer lurches between super-sluggish (1–2) and
  super-flighty (19–20).
- **Random interval** — everything reshuffles on a random 0.5–3 s timer, so you
  can never settle into a rhythm.

## Safety

`SetSystemCursor` replaces the system cursors **globally and persistently**, so:

- The `run`/`wild` loops restore your pointer automatically on `Ctrl+C` (use the
  **keyboard** to stop — in wild mode clicking is the whole problem!).
- One-shot `randomize` persists until you run `restore` (or sign out / reboot).
- Your original pointer **speed** is saved to
  `%LOCALAPPDATA%\cursed-cursor-state.json` so `restore` can recover it.
  Cursor appearance and size are restored by reloading the system scheme.

## How it works

All via P/Invoke into `user32.dll`:

- **`LoadImage`** loads each `.cur`/`.ani` from `C:\Windows\Cursors` at a chosen
  pixel size (this is what gives true size control).
- **`SetSystemCursor`** assigns it to each system cursor slot (arrow, hand,
  busy, I-beam, resize handles, …).
- **`SystemParametersInfo`** gets/sets pointer speed (`SPI_*MOUSESPEED`) and
  reloads the real cursors on restore (`SPI_SETCURSORS`).

## Tuning

The randomization ranges are constants at the top of `CursedCursor.ps1`:

```powershell
$MinCursorSize / $MaxCursorSize          # 'run' mode size range
$TinySize* / $HugeSize*                  # 'wild' bimodal size bands
$SluggishMin/Max, $FlightyMin/Max        # 'wild' bimodal speed bands
$WildIntervalMinSec / $WildIntervalMaxSec # 'wild' random interval
```

## License

MIT — see [LICENSE](LICENSE).
