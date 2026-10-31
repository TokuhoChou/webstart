@echo off
setlocal
cd /d "%~dp0"
title Website Console
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0site-console.ps1"
if errorlevel 1 pause
