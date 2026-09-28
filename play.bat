@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"

:: Find PowerShell path (in case it is not in the system PATH)
set "POWERSHELL_BIN=powershell"
if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    set "POWERSHELL_BIN=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
) else if exist "%windir%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    set "POWERSHELL_BIN=%windir%\System32\WindowsPowerShell\v1.0\powershell.exe"
) else if exist "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" (
    set "POWERSHELL_BIN=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
)


:: 1. Setup local Python interpreter if it doesn't exist
if not exist "%SCRIPT_DIR%python_local\python.exe" (
    echo Python not found in the project directory.
    echo Downloading and installing a local Python interpreter...
    
    :: Download Python Embeddable Package (much faster and requires no installer/admin UAC elevation)
    "%POWERSHELL_BIN%" -Command "$ProgressPreference = 'SilentlyContinue'; Write-Host 'Downloading Python 3.11 embeddable package...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip' -OutFile '%SCRIPT_DIR%python_embed.zip'"
    
    if not exist "%SCRIPT_DIR%python_embed.zip" (
        echo Failed to download Python package. Please check your internet connection.
        pause
        exit /b 1
    )
    
    :: Extract the zip archive
    echo Extracting Python locally to %SCRIPT_DIR%python_local...
    "%POWERSHELL_BIN%" -Command "Expand-Archive -Path '%SCRIPT_DIR%python_embed.zip' -DestinationPath '%SCRIPT_DIR%python_local'; Remove-Item -Path '%SCRIPT_DIR%python_embed.zip' -Force"
    
    if not exist "%SCRIPT_DIR%python_local\python.exe" (
        echo Failed to extract Python locally.
        pause
        exit /b 1
    )
    
    :: Configure the local Python path structure to support standard package libraries and local project modules
    "%POWERSHELL_BIN%" -Command "Add-Content -Path '%SCRIPT_DIR%python_local\python311._pth' -Value '..'; Add-Content -Path '%SCRIPT_DIR%python_local\python311._pth' -Value '..\termtube'; Add-Content -Path '%SCRIPT_DIR%python_local\python311._pth' -Value 'import site'"
    
    :: Download get-pip.py to bootstrap pip
    echo Bootstrapping pip manager...
    "%POWERSHELL_BIN%" -Command "$ProgressPreference = 'SilentlyContinue'; Write-Host 'Downloading get-pip.py...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%SCRIPT_DIR%get-pip.py'"
    
    if exist "%SCRIPT_DIR%get-pip.py" (
        "%SCRIPT_DIR%python_local\python.exe" "%SCRIPT_DIR%get-pip.py" --no-warn-script-location
        del "%SCRIPT_DIR%get-pip.py"
    )
    
    if not exist "%SCRIPT_DIR%python_local\Scripts\pip.exe" (
        echo Failed to bootstrap pip inside local Python. Please install Python manually.
        pause
        exit /b 1
    )
    
    echo Installing Python dependencies locally...
    "%SCRIPT_DIR%python_local\python.exe" -m pip install yt-dlp numpy --no-warn-script-location
)

:: Ensure local Python path structure is properly configured (auto-fix for existing installations)
if exist "%SCRIPT_DIR%python_local\python311._pth" (
    findstr /C:"..\termtube" "%SCRIPT_DIR%python_local\python311._pth" >nul
    if errorlevel 1 (
        echo Configuring local Python paths...
        echo ..>> "%SCRIPT_DIR%python_local\python311._pth"
        echo ..\termtube>> "%SCRIPT_DIR%python_local\python311._pth"
        findstr /C:"import site" "%SCRIPT_DIR%python_local\python311._pth" >nul
        if errorlevel 1 (
            echo import site>> "%SCRIPT_DIR%python_local\python311._pth"
        )
    )
)

:: 2. Setup local FFmpeg binaries if they don't exist
set "DOWNLOAD_FF="
if not exist "%SCRIPT_DIR%ffmpeg.exe" (
    set "DOWNLOAD_FF=y"
)
if not exist "%SCRIPT_DIR%ffplay.exe" (
    set "DOWNLOAD_FF=y"
)

if "!DOWNLOAD_FF!"=="y" (
    echo ffmpeg.exe or ffplay.exe is missing from the project directory.
    echo Downloading FFmpeg binaries locally...
    "%POWERSHELL_BIN%" -Command "$ProgressPreference = 'SilentlyContinue'; Write-Host 'Downloading FFmpeg essentials build...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' -OutFile '%SCRIPT_DIR%ffmpeg.zip'; Write-Host 'Extracting FFmpeg...'; Expand-Archive -Path '%SCRIPT_DIR%ffmpeg.zip' -DestinationPath '%SCRIPT_DIR%ffmpeg_temp'; Get-ChildItem -Path '%SCRIPT_DIR%ffmpeg_temp' -Filter 'ffmpeg.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Get-ChildItem -Path '%SCRIPT_DIR%ffmpeg_temp' -Filter 'ffplay.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Remove-Item -Path '%SCRIPT_DIR%ffmpeg.zip', '%SCRIPT_DIR%ffmpeg_temp' -Recurse -Force"
    
    if not exist "%SCRIPT_DIR%ffmpeg.exe" (
        echo Failed to download FFmpeg binaries. Please download them manually and place them in the project folder.
        pause
        exit /b 1
    )
)

:: 2.5 Setup local Deno if not already present in the directory
if not exist "%SCRIPT_DIR%deno.exe" (
    echo deno.exe is missing from the project directory.
    echo Downloading Deno binary locally...
    "%POWERSHELL_BIN%" -Command "$ProgressPreference = 'SilentlyContinue'; Write-Host 'Downloading Deno...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' -OutFile '%SCRIPT_DIR%deno.zip'; Write-Host 'Extracting Deno...'; Expand-Archive -Path '%SCRIPT_DIR%deno.zip' -DestinationPath '%SCRIPT_DIR%deno_temp'; Copy-Item -Path '%SCRIPT_DIR%deno_temp\deno.exe' -Destination '%SCRIPT_DIR%deno.exe'; Remove-Item -Path '%SCRIPT_DIR%deno.zip', '%SCRIPT_DIR%deno_temp' -Recurse -Force"
    
    if not exist "%SCRIPT_DIR%deno.exe" (
        echo Failed to download Deno binary.
    )
)

:: 3. Configure paths for local binaries
set "PATH=%SCRIPT_DIR%;%PATH%"
set "PYTHONPATH=%SCRIPT_DIR%termtube;%PYTHONPATH%"

:: 4. Validate arguments and run
set "YT_URL=%~1"

if "!YT_URL!"=="" (
    goto prompt_loop
) else (
    "%SCRIPT_DIR%python_local\python.exe" -m termtube.cli %*
    exit /b 0
)

:prompt_loop
set "YT_URL="
set "PLAY_STYLE="
set "STYLE_CHOICE="
set "CUSTOM_RAMP="
set "PLAY_LIGHT="
set "LIGHT_CHOICE="
set "PLAY_COLOR="
set "COLOR_CHOICE="
set "PLAY_FPS="
set "FPS_CHOICE="

echo.
echo ===================================================
echo             TermTube Terminal Player
echo ===================================================
echo.
set /p "YT_URL=Enter YouTube Video Link (or press Enter to exit): "
if "!YT_URL!"=="" (
    echo Goodbye!
    exit /b 0
)

echo.
echo Select rendering style / character set:
echo   1. Block characters (hd color) [Default]
echo   2. Block Shades ( ░▒▓█ - Deep Shadows & Bright Light)
echo   3. Binary 0101 (Matrix Digital Stream)
echo   4. High-Contrast ASCII (Vivid highlights & deep shadows)
echo   5. Classic ASCII (Standard text art)
echo   6. Custom Characters (Type your own ramp)
echo.
set /p "STYLE_CHOICE=Select Option (1-6) [Default: 1]: "

if "!STYLE_CHOICE!"=="2" (
    set "PLAY_STYLE=--style shades"
) else if "!STYLE_CHOICE!"=="3" (
    set "PLAY_STYLE=--style binary"
) else if "!STYLE_CHOICE!"=="4" (
    set "PLAY_STYLE=--style ascii --preset highcontrast"
) else if "!STYLE_CHOICE!"=="5" (
    set "PLAY_STYLE=--style ascii --preset ascii"
) else if "!STYLE_CHOICE!"=="6" (
    echo.
    set /p "CUSTOM_RAMP=Enter custom character ramp (from dark to bright): "
    if "!CUSTOM_RAMP!"=="" (
        set "PLAY_STYLE=--style ascii"
    ) else (
        set "PLAY_STYLE=--style ascii --ramp "!CUSTOM_RAMP!""
    )
) else (
    set "PLAY_STYLE=--style halfblock"
)
echo.

echo Select contrast & lighting tuning:
echo   1. Standard (Natural balance) [Default]
echo   2. High Contrast & Vivid Light (Deep blacks & glowing highlights)
echo   3. Ultra Bright (Light boost for dark videos)
echo   4. Dynamic Auto-Contrast (Auto-stretches lighting range)
echo.
set /p "LIGHT_CHOICE=Select Option (1-4) [Default: 1]: "
if "!LIGHT_CHOICE!"=="2" (
    set "PLAY_LIGHT=--contrast 1.5 --light-boost 0.15"
) else if "!LIGHT_CHOICE!"=="3" (
    set "PLAY_LIGHT=--contrast 1.2 --brightness 0.15 --light-boost 0.25"
) else if "!LIGHT_CHOICE!"=="4" (
    set "PLAY_LIGHT=--auto-contrast --contrast 1.3"
) else (
    set "PLAY_LIGHT="
)
echo.

echo Select color theme:
echo   1. Full Truecolor RGB [Default]
echo   2. Matrix Neon Green (Cyberpunk phosphor glow)
echo   3. Cyberpunk (Neon Cyan & Magenta)
echo   4. Glitch Multicolor (Chromatic Aberration & VHS Split)
echo   5. Rainbow Psychedelic (Full Neon Spectrum)
echo   6. Amber CRT (Vintage monitor glow)
echo   7. Monochrome Grayscale (High-contrast B&W)
echo.
set /p "COLOR_CHOICE=Select Option (1-7) [Default: 1]: "
if "!COLOR_CHOICE!"=="2" (
    set "PLAY_COLOR=--color-mode matrix"
) else if "!COLOR_CHOICE!"=="3" (
    set "PLAY_COLOR=--color-mode cyberpunk"
) else if "!COLOR_CHOICE!"=="4" (
    set "PLAY_COLOR=--color-mode glitch"
) else if "!COLOR_CHOICE!"=="5" (
    set "PLAY_COLOR=--color-mode rainbow"
) else if "!COLOR_CHOICE!"=="6" (
    set "PLAY_COLOR=--color-mode amber"
) else if "!COLOR_CHOICE!"=="7" (
    set "PLAY_COLOR=--color-mode gray"
) else (
    set "PLAY_COLOR=--color-mode rgb"
)
echo.

echo Select playback frame rate:
echo   1. 15 FPS [Default]
echo   2. 24 FPS
echo   3. 30 FPS
echo.
set /p "FPS_CHOICE=Select Option (1, 2 or 3) [Default: 1]: "
if "!FPS_CHOICE!"=="2" (
    set "PLAY_FPS=--fps 24"
) else if "!FPS_CHOICE!"=="3" (
    set "PLAY_FPS=--fps 30"
) else (
    set "PLAY_FPS=--fps 15"
)
echo.
echo.
echo ===================================================
echo  Tip: Switch styles & colors live with keyboard!
echo    [S] Cycle Styles  [1-6] Jump to Style [H] HD Color
echo    [C] Cycle Colors  [G] Glitch Mode     [M] Matrix
echo    [+/-] Contrast    []]/[[] Brightness  [Q] Quit
echo ===================================================
echo.

"%SCRIPT_DIR%python_local\python.exe" -m termtube.cli "!YT_URL!" !PLAY_STYLE! !PLAY_LIGHT! !PLAY_COLOR! !PLAY_FPS!

echo.
echo Playback finished.
goto prompt_loop
