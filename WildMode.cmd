@echo off
REM Double-click for WILD MODE: giant cursors + near-max speed, so clicking is
REM genuinely hard. Press Ctrl+C in this window (keyboard, no clicking needed)
REM to stop AND auto-restore your pointer.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PointerGoesWild.ps1" wild
pause
