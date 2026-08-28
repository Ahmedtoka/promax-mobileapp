@echo off
REM PROMAX LIVE build - points to erp.promaxfoods.com (default)
REM Output: promax-LIVE.apk
cd /d "%~dp0"
echo [1/3] flutter clean...
call flutter clean
echo [2/3] flutter pub get...
call flutter pub get
echo [3/3] building LIVE apk...
call flutter build apk --release
if errorlevel 1 (
    echo BUILD FAILED - see errors above
    pause
    exit /b 1
)
copy /y "build\app\outputs\flutter-apk\app-release.apk" "promax-LIVE.apk" >nul
echo.
echo DONE: promax-LIVE.apk  (server: erp.promaxfoods.com)
pause
