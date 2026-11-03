@echo off
cd /d C:\dev\memento_lock
echo ===================================================
echo   Memento Lock - Starting Android Emulator and App
echo ===================================================
set ANDROID_AVD_HOME=C:\Android\avd
set ANDROID_SDK_ROOT=C:\Android\Sdk
set ANDROID_HOME=C:\Android\Sdk

del /q "C:\Android\avd\Pixel_API_35.avd\*.lock" 2>nul

echo [1/3] Opening Pixel_API_35 emulator window...
start "Pixel_API_35" C:\Android\Sdk\emulator\emulator.exe -avd Pixel_API_35 -no-audio

echo [2/3] Waiting for emulator to finish booting (20~40 sec)...
:wait_boot
timeout /t 3 /nobreak > nul
for /f "delims=" %%i in ('C:\Android\Sdk\platform-tools\adb.exe shell getprop sys.boot_completed 2^>nul') do set BOOT=%%i
if not "%BOOT%"=="1" goto wait_boot

echo [3/3] Installing and launching Memento Lock app...
C:\Android\Sdk\platform-tools\adb.exe install -r "C:\dev\memento_lock\build\app\outputs\flutter-apk\app-debug.apk"
C:\Android\Sdk\platform-tools\adb.exe shell am start -n com.mementolock.memento_lock/.MainActivity
echo.
echo [DONE] Check the Pixel_API_35 emulator window!
pause
