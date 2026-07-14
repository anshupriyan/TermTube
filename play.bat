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
    "%POWERSHELL_BIN%" -Command "Write-Host 'Downloading Python 3.11 embeddable package...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip' -OutFile '%SCRIPT_DIR%python_embed.zip'"
    
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
    "%POWERSHELL_BIN%" -Command "Write-Host 'Downloading get-pip.py...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%SCRIPT_DIR%get-pip.py'"
    
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
    "%POWERSHELL_BIN%" -Command "Write-Host 'Downloading FFmpeg essentials build...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' -OutFile '%SCRIPT_DIR%ffmpeg.zip'; Write-Host 'Extracting FFmpeg...'; Expand-Archive -Path '%SCRIPT_DIR%ffmpeg.zip' -DestinationPath '%SCRIPT_DIR%ffmpeg_temp'; Get-ChildItem -Path '%SCRIPT_DIR%ffmpeg_temp' -Filter 'ffmpeg.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Get-ChildItem -Path '%SCRIPT_DIR%ffmpeg_temp' -Filter 'ffplay.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Remove-Item -Path '%SCRIPT_DIR%ffmpeg.zip', '%SCRIPT_DIR%ffmpeg_temp' -Recurse -Force"
    
    if not exist "%SCRIPT_DIR%ffmpeg.exe" (
        echo Failed to download FFmpeg binaries. Please download them manually and place them in the project folder.
        pause
        exit /b 1
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
echo Select rendering style:
echo   1. Block characters (hd color)
echo   2. ASCII density characters (text art)
echo.
set /p "STYLE_CHOICE=Select Option (1 or 2) [Default: 1]: "
if "!STYLE_CHOICE!"=="2" (
    set "PLAY_STYLE=--style ascii"
) else (
    set "PLAY_STYLE=--style halfblock"
)
echo.

"%SCRIPT_DIR%python_local\python.exe" -m termtube.cli "!YT_URL!" !PLAY_STYLE!

echo.
echo Playback finished.
goto prompt_loop
