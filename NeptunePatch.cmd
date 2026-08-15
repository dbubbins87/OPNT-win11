@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0NeptunePatch.ps1"
set "NEPTUNE_EXIT=%ERRORLEVEL%"
if not "%NEPTUNE_EXIT%"=="0" pause
exit /b %NEPTUNE_EXIT%
