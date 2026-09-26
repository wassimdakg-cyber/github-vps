@echo off
setlocal
title VPS Start
set "NAME=jubilant-parakeet-r77jxgr4vxrxfp69w"

echo [1/3] Making sure the VPS codespace is started...
gh codespace start -c %NAME% >nul 2>&1

echo [2/3] Starting desktop + cloudflare tunnel...
:retry
gh codespace ssh -c %NAME% -- vps-start
if errorlevel 1 (
  echo   (still booting, retrying in 8s...)
  ping -n 9 127.0.0.1 >nul
  goto retry
)

echo.
echo [3/3] Done. Open the VPS URL above in your browser (add /vnc.html).
echo.
pause