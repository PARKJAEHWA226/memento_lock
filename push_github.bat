@echo off
cd /d C:\dev\memento_lock
echo ===================================================
echo   Memento Lock - GitHub Upload (PARKJAEHWA226)
echo ===================================================
echo.
git remote remove origin 2>nul
git remote add origin https://github.com/PARKJAEHWA226/memento_lock.git
git branch -M main

echo Pushing to https://github.com/PARKJAEHWA226/memento_lock.git ...
echo.
git push -u origin main
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ===================================================
    echo [!] Push failed. Please check:
    echo   1. Go to https://github.com/new in your browser
    echo   2. Type Repository name: memento_lock
    echo   3. Click [Create repository] at the bottom
    echo   4. Run this file (push_github.bat) again!
    echo ===================================================
    start https://github.com/new
) else (
    echo.
    echo ===================================================
    echo [SUCCESS] Uploaded to GitHub!
    echo https://github.com/PARKJAEHWA226/memento_lock
    echo ===================================================
    start https://github.com/PARKJAEHWA226/memento_lock
)
pause
