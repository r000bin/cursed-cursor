@echo off
REM Double-click for continuous chaos: re-randomizes every 5 seconds.
REM Press Ctrl+C (or close this window) to stop AND auto-restore your pointer.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PointerGoesWild.ps1" run -IntervalSeconds 5
pause
