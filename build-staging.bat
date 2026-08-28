@echo off
REM PROMAX STAGING build - points to staging.promaxfoods.com
REM Output: promax-STAGING.apk
REM WARNING: same package as LIVE app - installing replaces it on the phone
cd /d "%~dp0"
echo [1/3] flutter clean...
call flutter clean
echo [2/3] flutter pub get...
call flutter pub get
echo [3/3] building STAGING apk...
call flutter build apk --release --dart-define=API_BASE=https://staging.promaxfoods.com/api
if errorlevel 1 (
    echo BUILD FAILED - see errors above
    pause
    exit /b 1
)
copy /y "build\app\outputs\flutter-apk\app-release.apk" "promax-STAGING.apk" >nul
echo.
echo DONE: promax-STAGING.apk  (server: staging.promaxfoods.com)
pause
