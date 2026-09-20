@echo off
rem Publish config changes to github.com/randreg1009-source/n3-config
rem Usage: publish.cmd "what changed"
setlocal
cd /d "%~dp0"
set "MSG=%~1"
if "%MSG%"=="" set "MSG=config update"
git add -A
git status --short
git commit -m "%MSG%" || echo (nothing to commit)
git push
exit /b 0
