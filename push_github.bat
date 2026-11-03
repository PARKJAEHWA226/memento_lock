@echo off
chcp 65001 > nul
echo ===================================================
echo   Memento Lock - GitHub 업로드 (PARKJAEHWA226)
echo ===================================================
cd /d C:\dev\memento_lock
git remote remove origin 2>nul
git remote add origin https://github.com/PARKJAEHWA226/memento_lock.git
echo.
echo [안내] 브라우저 로그인 창이 뜨면 GitHub 계정(PARKJAEHWA226)으로 로그인해 주세요.
echo (아직 GitHub에 memento_lock 저장소가 없다면 https://github.com/new 에서 이름에 memento_lock 만 입력하고 Create repository를 누른 뒤 실행하세요!)
echo.
git push -u origin main
pause
