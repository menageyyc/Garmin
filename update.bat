@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  Double-click this to pull the latest code from GitHub.
REM  It now tells you whether anything actually changed, rather
REM  than printing the same "up to date" either way.
REM ============================================================

cd /d "%~dp0"

for /f "delims=" %%i in ('git rev-parse --short HEAD 2^>nul') do set BEFORE=%%i

echo.
echo  Currently on commit !BEFORE!
echo  Fetching latest changes...
echo.

git pull --ff-only
set PULLCODE=%ERRORLEVEL%

for /f "delims=" %%i in ('git rev-parse --short HEAD 2^>nul') do set AFTER=%%i

echo.
if %PULLCODE% NEQ 0 (
    echo  ---------------------------------------------------------
    echo   THAT DID NOT GO THROUGH.
    echo.
    echo   Usual causes: no network connection, or a local edit
    echo   clashing with an incoming change. Nothing has been lost
    echo   - your files are exactly as they were.
    echo.
    echo   Copy the message above and send it to Claude.
    echo  ---------------------------------------------------------
) else if "!BEFORE!"=="!AFTER!" (
    echo  ---------------------------------------------------------
    echo   NOTHING NEW. You were already on the latest commit.
    echo.
    echo   Still on !AFTER!
    echo.
    echo   If you were expecting a change, it had not been pushed
    echo   yet when you ran this. Wait a moment and run it again.
    echo  ---------------------------------------------------------
) else (
    echo  ---------------------------------------------------------
    echo   UPDATED.   !BEFORE!  to  !AFTER!
    echo.
    echo   What came in:
    git log --oneline !BEFORE!..!AFTER!
    echo.
    echo   Press F5 in VS Code to build and run.
    echo  ---------------------------------------------------------
)

echo.
pause
