@echo off
setlocal
cd /d "%~dp0"

set PORT=8799
if not "%IP2PX_PORT%"=="" set PORT=%IP2PX_PORT%
set URL=http://127.0.0.1:%PORT%/img2pixel.html

rem ============================================================
rem  Why use this launcher instead of double-clicking img2pixel.html?
rem  Opening the file directly (file://) makes Chromium tag every
rem  download as ZoneId=4 (Restricted Sites), which Windows blocks
rem  by default (cannot extract / cannot open).
rem  Serving over http://127.0.0.1 tags downloads as ZoneId=3
rem  (Internet), so saving and extracting work normally.
rem ============================================================

rem server already running -> just open the browser
netstat -ano | findstr /r /c:"TCP.*:%PORT% .*LISTENING" >nul 2>&1
if not errorlevel 1 (
  echo [img2pixel] local server already running on port %PORT%
  if not "%1"=="--no-open" start "" "%URL%"
  exit /b 0
)

rem find Python
set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" (
  where python >nul 2>&1 && set PY=python
)
if "%PY%"=="" (
  echo [img2pixel] Python not found. Please install Python first:
  echo             https://www.python.org/
  pause
  exit /b 1
)

echo [img2pixel] starting local server: %URL%
echo             (this window is the tool server; close it when done)

rem start server in a minimized window
start "img2pixel local server" /min %PY% -m http.server %PORT% --bind 127.0.0.1

rem wait until the server answers (up to ~10s), then open the browser
for /l %%i in (1,1,40) do (
  curl -s -o nul "%URL%" 2>nul && goto open
  ping -n 1 -w 250 127.0.0.1 >nul
)

:open
if not "%1"=="--no-open" start "" "%URL%"
exit /b 0
