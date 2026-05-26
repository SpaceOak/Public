@echo off
setlocal EnableExtensions EnableDelayedExpansion
Quest install + logcat helper

rem === CONFIG ===
set "DEFAULT_PKG_DIR=D:\Path\to\proj"
set "PACKAGE_NAME=com.organisation.project"
set "ACTIVITY_NAME=com.epicgames.ue4.GameActivity"
set "APK_NAME=project-arm64.apk"
set "OBB_FILE=main.1.com.organisation.project.obb"

echo === Quest install + logcat helper ===
echo.

rem ---------- resolve package dir ----------
set "PKG_DIR="

if exist "%DEFAULT_PKG_DIR%\%APK_NAME%" (
    set "PKG_DIR=%DEFAULT_PKG_DIR%"
    echo [INFO] Using default folder: "!PKG_DIR!"
) else (
    echo [WARN] Default folder not found OR no %APK_NAME% there:
    echo        %DEFAULT_PKG_DIR%
    echo.

    :ASK_PATH
    set "PKG_DIR="
    set /p "PKG_DIR=Enter FULL path to folder with %APK_NAME%: "

    rem remove surrounding quotes if user pasted them
    set "PKG_DIR=!PKG_DIR:"=!"

    rem trim leading spaces (and collapses weird leading whitespace)
    for /f "tokens=* delims= " %%A in ("!PKG_DIR!") do set "PKG_DIR=%%A"

    echo [DEBUG] PKG_DIR = "!PKG_DIR!"

    if "!PKG_DIR!"=="" (
        echo [ERROR] Empty path.
        choice /C YN /M "Try again?"
        if errorlevel 2 goto :END_ERROR
        goto :ASK_PATH
    )

    if not exist "!PKG_DIR!" (
        echo [ERROR] Folder "!PKG_DIR!" does not exist.
        choice /C YN /M "Try again?"
        if errorlevel 2 goto :END_ERROR
        goto :ASK_PATH
    )

    if not exist "!PKG_DIR!\%APK_NAME%" (
        echo [ERROR] File "%APK_NAME%" not found in "!PKG_DIR!".
        choice /C YN /M "Try again?"
        if errorlevel 2 goto :END_ERROR
        goto :ASK_PATH
    )
)

set "HAS_OBB=0"
if exist "!PKG_DIR!\%OBB_FILE%" set "HAS_OBB=1"

echo [INFO] Final package folder: "!PKG_DIR!"
echo.

rem ---------- check device ----------
echo [STEP] Checking connected devices...
set "DEVICE="

rem Only accept lines ending with "device" (real connected devices)
for /f "tokens=1,2" %%D in ('adb devices ^| findstr /R /C:"	device$"') do (
    set "DEVICE=%%D"
    goto :HAVE_DEVICE
)

echo [ERROR] No devices found by adb (or device is unauthorized/offline).
goto :END_ERROR

:HAVE_DEVICE
echo   Found device: !DEVICE!
echo.

rem ---------- uninstall / install ----------
echo [STEP] Uninstall old build (if present)...
adb uninstall %PACKAGE_NAME% >nul 2>&1
echo   Uninstall command sent.
echo.

echo [STEP] Installing new APK...
adb install -r "!PKG_DIR!\%APK_NAME%"
if errorlevel 1 (
    echo [ERROR] adb install failed.
    goto :END_ERROR
)
echo   Install command finished.
echo.

if "!HAS_OBB!"=="1" (
    echo [STEP] Pushing OBB...
    adb shell mkdir -p /sdcard/Android/obb/%PACKAGE_NAME%
    adb push "!PKG_DIR!\%OBB_FILE%" /sdcard/Android/obb/%PACKAGE_NAME%/
    if errorlevel 1 (
        echo [ERROR] OBB push failed.
        goto :END_ERROR
    )
    echo   OBB push finished.
    echo.
) else (
    echo [WARN] No OBB file "%OBB_FILE%" in "!PKG_DIR!". Skipping OBB push.
    echo.
)

rem ---------- prepare log file (locale-agnostic) ----------
set "LDT="
for /f "skip=1 tokens=1" %%I in ('wmic os get localdatetime 2^>nul') do (
    if not "%%I"=="" (
        set "LDT=%%I"
        goto :GOT_LDT
    )
)

:GOT_LDT
if "!LDT!"=="" (
    rem fallback if wmic missing
    set "LOGFILE=!PKG_DIR!\logcat_proj.txt"
) else (
    set "YYYY=!LDT:~0,4!"
    set "MM=!LDT:~4,2!"
    set "DD=!LDT:~6,2!"
    set "HH=!LDT:~8,2!"
    set "MN=!LDT:~10,2!"
    set "LOGFILE=!PKG_DIR!\logcat_proj_!YYYY!-!MM!-!DD!_!HH!-!MN!.txt"
)

echo [STEP] Clearing logcat...
adb logcat -c
echo.

echo [STEP] Starting game on Quest...
adb shell am start -n %PACKAGE_NAME%/%ACTIVITY_NAME%
echo.

echo [STEP] Capturing logcat to:
echo   "!LOGFILE!"
echo Press Ctrl+C when you want to stop capturing (after crash / repro).
echo.

adb logcat > "!LOGFILE!"

goto :END_OK

:END_ERROR
echo.
echo [DONE] Script aborted because of an error above.
echo Press any key to close...
pause >nul
exit /b 1

:END_OK
echo.
echo [DONE] Logcat capture finished.
echo Log was saved to:
echo   "!LOGFILE!"
echo.
echo Press any key to close...
pause >nul
exit /b 0
