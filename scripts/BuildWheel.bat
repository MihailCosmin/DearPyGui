@echo off
setlocal EnableDelayedExpansion

:: ---------------------------------------------------------------------------
:: BuildWheel.bat
:: Compiles DearPyGui from source and produces a .whl ready to pip install.
::
:: Usage:
::   scripts\BuildWheel.bat              -- build wheel only
::   scripts\BuildWheel.bat --install    -- build wheel then pip install it
:: ---------------------------------------------------------------------------

set REPO_DIR=%~dp0..
cd /d "%REPO_DIR%"

:: ---- Locate Visual Studio via vswhere ------------------------------------
set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist %VSWHERE% (
    set VSWHERE="%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
)

if not exist %VSWHERE% (
    echo [ERROR] vswhere.exe not found. Please install Visual Studio 2019 or 2022
    echo         with the "Desktop development with C++" workload.
    exit /b 1
)

for /f "usebackq delims=" %%i in (`%VSWHERE% -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
    set VS_PATH=%%i
)

if "!VS_PATH!"=="" (
    echo [ERROR] No Visual Studio installation with C++ tools found.
    exit /b 1
)

:: Activate the VS developer environment (sets up MSVC, CMake, etc.)
call "!VS_PATH!\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
if ERRORLEVEL 1 (
    echo [ERROR] Failed to initialise Visual Studio environment.
    exit /b 1
)
echo [OK] Visual Studio environment initialised.

:: ---- Check Python is available -------------------------------------------
python --version >nul 2>&1
if ERRORLEVEL 1 (
    echo [ERROR] python not found on PATH. Install Python 3.x and ensure it is on PATH.
    exit /b 1
)
echo [OK] Python found:
python --version

:: ---- Initialise git submodules (thirdparty deps: freetype, imgui, etc.) --
echo.
echo [STEP] Initialising git submodules (skipping cpython)...
git submodule update --init --recursive -- thirdparty/freetype thirdparty/glfw thirdparty/imgui thirdparty/implot
if ERRORLEVEL 1 (
    echo [ERROR] git submodule update failed.
    exit /b 1
)
echo [OK] Submodules ready.

:: ---- Install build dependencies ------------------------------------------
echo.
echo [STEP] Installing/upgrading build dependencies...
python -m pip install --upgrade pip wheel setuptools --quiet
if ERRORLEVEL 1 (
    echo [ERROR] pip install failed.
    exit /b 1
)

:: ---- Build the wheel -----------------------------------------------------
echo.
echo [STEP] Building wheel (this will run CMake + MSBuild internally)...
echo       Output is being logged to build_wheel.log ...
python setup.py bdist_wheel > build_wheel.log 2>&1
if ERRORLEVEL 1 (
    echo.
    echo [ERROR] Wheel build failed. First compiler/CMake errors found in build_wheel.log:
    echo -----------------------------------------------------------------------
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_show_build_errors.ps1" build_wheel.log
    echo -----------------------------------------------------------------------
    echo Full log: %REPO_DIR%\build_wheel.log
    exit /b 1
)
type build_wheel.log

echo.
echo [OK] Wheel built successfully. Output in dist\:
dir /b dist\*.whl

:: ---- Optionally install the wheel ----------------------------------------
if /i "%~1"=="--install" (
    echo.
    echo [STEP] Installing wheel into current Python environment...
    for /f "delims=" %%w in ('dir /b /o-n dist\dearpygui-*.whl 2^>nul') do (
        set WHEEL_FILE=dist\%%w
        goto :do_install
    )
    echo [ERROR] No dearpygui wheel found in dist\
    exit /b 1
    :do_install
    python -m pip install "!WHEEL_FILE!" --force-reinstall
    if ERRORLEVEL 1 (
        echo [ERROR] pip install failed.
        exit /b 1
    )
    echo [OK] Installed: !WHEEL_FILE!
)

echo.
echo Done.
endlocal
