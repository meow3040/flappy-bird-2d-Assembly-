@echo off
REM ============================================================================
REM Build script for 2D Game Engine (Assembly x86_64)
REM ============================================================================

echo ========================================
echo Building 2D Game Engine
echo ========================================

REM Assemble the .asm file to object file
echo [1/3] Assembling game.asm...
nasm -f win64 game.asm -o game.obj
if %errorlevel% neq 0 (
    echo ERROR: Assembly failed!
    pause
    exit /b 1
)

REM Link the object file with Windows libraries
echo [2/3] Linking with GCC...
gcc game.obj -o ..\release\game.exe -luser32 -lgdi32 -lkernel32 -mwindows
if %errorlevel% neq 0 (
    echo ERROR: Linking failed!
    pause
    exit /b 1
)

REM Clean up object file
echo [3/3] Cleaning up...
del game.obj

echo ========================================
echo Build complete!
echo Executable saved to: ..\release\game.exe
echo ========================================
echo.
echo Controls:
echo   Arrow Keys - Move player (green square)
echo   ESC        - Exit game
echo.
echo Avoid the red enemies!
echo.
pause
