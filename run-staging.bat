@echo off
REM ============================================================
REM  PROMAX - run on the OPEN emulator against STAGING
REM  Server: staging.promaxfoods.com
REM ============================================================
REM  Debug run, NOT a build. Hot reload works:
REM     r = hot reload      R = hot restart
REM     q = quit            h = help
REM
REM  No flutter clean here on purpose - clean forces a full
REM  rebuild every run and turns a 20-second start into minutes.
REM  Use build-staging.bat when you need a shippable APK.
REM ============================================================
cd /d "%~dp0"

echo.
echo [1/2] looking for a running emulator...
call flutter devices
echo.

REM -d emulator-5554 is the default AVD id. If your emulator has a
REM different id, copy it from the list above and pass it as an
REM argument:  run-staging.bat emulator-5556
set DEVICE=%1
if "%DEVICE%"=="" set DEVICE=emulator-5554

echo [2/2] starting on %DEVICE% against STAGING...
echo.
call flutter run -d %DEVICE% --dart-define=API_BASE=https://staging.promaxfoods.com/api

if errorlevel 1 (
    echo.
    echo ---------------------------------------------------------
    echo  FAILED. Most common causes:
    echo   * emulator id is not %DEVICE%  - check the list above
    echo     and run:  run-staging.bat ^<device-id^>
    echo   * emulator is not booted yet   - wait for the home screen
    echo   * no emulator at all           - flutter emulators --launch ^<id^>
    echo ---------------------------------------------------------
    pause
    exit /b 1
)
