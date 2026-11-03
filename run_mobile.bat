@echo off
chcp 65001 > nul
echo ===================================================
echo   Memento Lock - 가상 휴대폰 실행 및 최신 앱 켜기
echo ===================================================
set ANDROID_AVD_HOME=C:\Android\avd
set ANDROID_SDK_ROOT=C:\Android\Sdk
set ANDROID_HOME=C:\Android\Sdk

del /q "C:\Android\avd\Pixel_API_35.avd\*.lock" 2>nul

echo [1/3] 가상 휴대폰(Pixel_API_35) 창을 화면에 띄웁니다...
start "Pixel_API_35" C:\Android\Sdk\emulator\emulator.exe -avd Pixel_API_35 -no-audio

echo [2/3] 부팅 완료를 기다리는 중 (약 20~30초)...
:wait_boot
timeout /t 3 /nobreak > nul
for /f "delims=" %%i in ('C:\Android\Sdk\platform-tools\adb.exe shell getprop sys.boot_completed 2^>nul') do set BOOT=%%i
if not "%BOOT%"=="1" goto wait_boot

echo [3/3] 최신 Memento Lock 앱을 설치하고 화면에 엽니다!
C:\Android\Sdk\platform-tools\adb.exe install -r "C:\dev\memento_lock\build\app\outputs\flutter-apk\app-debug.apk"
C:\Android\Sdk\platform-tools\adb.exe shell am start -n com.mementolock.memento_lock/.MainActivity
echo 완료되었습니다! 가상 휴대폰 창을 확인해 보세요.
timeout /t 5
