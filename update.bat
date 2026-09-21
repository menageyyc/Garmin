@echo off
REM ============================================================
REM  Double-click this to pull the latest code from GitHub.
REM  Nothing else to remember.
REM ============================================================

cd /d "%~dp0"

echo.
echo  Fetching latest changes...
echo.

git pull --ff-only

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ---------------------------------------------------------
    echo   That did not go through cleanly.
    echo.
    echo   The usual cause is a local edit clashing with an
    echo   incoming change. Nothing has been lost - your files are
    echo   exactly as they were.
    echo.
    echo   Copy the message above and send it to Claude.
    echo  ---------------------------------------------------------
) else (
    echo.
    echo  ---------------------------------------------------------
    echo   Up to date. Press F5 in VS Code to build and run.
    echo  ---------------------------------------------------------
)

echo.
pause
