@echo off
chcp 65001 >nul
cd /d "%~dp0"
title ClickedClone AI Server

echo ============================================
echo   ClickedClone AI Server
echo ============================================
echo.

REM --- Locate Python (WorkBuddy bundled first, then system) ---
set "PYEXE=C:\Users\30404\.workbuddy\binaries\python\versions\3.13.12\python.exe"
if not exist "%PYEXE%" (
    where python >nul 2>nul
    if %ERRORLEVEL%==0 (
        set "PYEXE=python"
    ) else (
        echo [ERROR] Python not found. Please install Python 3.9+ first.
        pause
        exit /b 1
    )
)

echo Using Python: %PYEXE%
echo.
echo --- Your LAN IP (use this in the iOS App's apiBaseURL) ---
ipconfig | findstr /i "IPv4"
echo.
echo --- Checking dependencies ---
"%PYEXE%" -c "import fastapi, uvicorn, cv2, numpy" >nul 2>nul
if not %ERRORLEVEL%==0 (
    echo Dependencies missing. Installing from Aliyun mirror...
    "%PYEXE%" -m pip install -i https://mirrors.aliyun.com/pypi/simple/ --timeout 120 -r requirements.txt
)
echo.
echo ============================================
echo   Server starting at http://0.0.0.0:8000
echo   Open http://localhost:8000/health to verify
echo   Press Ctrl+C to stop
echo ============================================
echo.

"%PYEXE%" -m uvicorn app:app --host 0.0.0.0 --port 8000
pause
