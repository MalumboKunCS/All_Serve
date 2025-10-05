@echo off
echo.
echo ========================================
echo    All-Serve Admin Setup Script
echo ========================================
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed!
    echo    Please install Node.js from https://nodejs.org/
    echo    Then run this script again.
    pause
    exit /b 1
)

REM Check if firebase-admin is installed
npm list firebase-admin >nul 2>&1
if %errorlevel% neq 0 (
    echo 📦 Installing firebase-admin...
    npm install firebase-admin
    if %errorlevel% neq 0 (
        echo ❌ Failed to install firebase-admin!
        pause
        exit /b 1
    )
)

echo ✅ Dependencies are ready!
echo.

REM Run the setup script
node setup-admin.js

echo.
echo Press any key to exit...
pause >nul





