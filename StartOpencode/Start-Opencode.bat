@echo off
REM Double-click shim. Pass a project name as the first arg, or edit the default below.
REM Usage: Start-Opencode.bat [project-name]
set "PROJECT=%~1"
if "%PROJECT%"=="" set "PROJECT=liftosaur"
powershell -ExecutionPolicy Bypass -Command ". '%~dp0Start-Opencode.ps1'; Start-Opencode -Project '%PROJECT%'"
pause
