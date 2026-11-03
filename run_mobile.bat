@echo off
chcp 65001 > nul
echo ===================================================
echo   Memento Lock - 가상 휴대폰 실행 및 최신 앱 설치
echo ===================================================
set ANDROID_AVD_HOME=C:\Android\avd
set ANDROID_SDK_ROOT=C:\Android\Sdk
set ANDROID_HOME=C:\Android\Sdk
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set GRADLE_USER_HOME=C:\dev\.gradle
set TEMP=C:\dev\tmp
set TMP=C:\dev\tmp
set PATH=%PATH%;C:\src\flutter\bin;C:\Android\Sdk\platform-tools

echo [1/3] 가상 휴대폰(Pixel_API_35) 창을 엽니다...
start "Pixel_API_35" C:\Android\Sdk\emulator\emulator.exe -avd Pixel_API_35 -no-audio

echo [2/3] 가상 휴대폰 부팅 완료를 기다리는 중...
:wait_boot
timeout /t 3 /nobreak > nul
for /f "delims=" %%i in ('C:\Android\Sdk\platform-tools\adb.exe shell getprop sys.boot_completed 2^>nul') do set BOOT=%%i
if not "%BOOT%"=="1" goto wait_boot

echo [3/3] 부팅 완료! 최신 Memento Lock 앱을 설치하고 실행합니다...
cd /d C:\dev\memento_lock
call flutter run -d emulator-5554
pause
