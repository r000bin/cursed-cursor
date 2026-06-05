@echo off
REM Double-click to make the pointer go wild (one-shot randomize).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursedCursor.ps1" randomize
echo.
echo Done. Double-click Restore.cmd to put your pointer back.
pause
