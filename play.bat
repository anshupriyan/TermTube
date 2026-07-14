@echo off
setlocal enabledelayedexpansion

:: 1. Check for Python
python -c "import sys" >nul 2>nul
if %errorlevel% neq 0 (
    echo Python was not found or is not working properly on your system.
    echo Please install Python 3 from https://www.python.org/downloads/ and add it to your PATH.
    exit /b 1
)

:: 2. Setup local virtual environment (.venv)
set "SCRIPT_DIR=%~dp0"
if not exist "%SCRIPT_DIR%.venv" (
    echo Creating local Python virtual environment venv...
    python -m venv "%SCRIPT_DIR%.venv"
    if %errorlevel% neq 0 (
        echo Failed to create virtual environment.
        exit /b 1
    )
    echo Installing Python dependencies locally...
    "%SCRIPT_DIR%.venv\Scripts\python.exe" -m pip install --upgrade pip
    "%SCRIPT_DIR%.venv\Scripts\python.exe" -m pip install yt-dlp numpy
)

:: 3. Setup local FFmpeg binaries
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
    powershell -Command "Write-Host 'Downloading FFmpeg essentials build...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.zip' -OutFile 'ffmpeg.zip'; Write-Host 'Extracting FFmpeg...'; Expand-Archive -Path 'ffmpeg.zip' -DestinationPath 'ffmpeg_temp'; Get-ChildItem -Path 'ffmpeg_temp' -Filter 'ffmpeg.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Get-ChildItem -Path 'ffmpeg_temp' -Filter 'ffplay.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Remove-Item -Path 'ffmpeg.zip', 'ffmpeg_temp' -Recurse -Force"
    
    if not exist "%SCRIPT_DIR%ffmpeg.exe" (
        echo Failed to download FFmpeg binaries. Please download them manually and place them in the project folder.
        exit /b 1
    )
)

:: 4. Configure paths for local binaries
set "PATH=%SCRIPT_DIR%;%PATH%"
set "PYTHONPATH=%SCRIPT_DIR%termtube;%PYTHONPATH%"

:: 5. Validate arguments and run
if "%~1"=="" (
    echo Usage: play.bat [youtube_url] [additional_options]
    echo.
    echo Examples:
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style ascii
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style halfblock --fps 15
    exit /b 1
)

"%SCRIPT_DIR%.venv\Scripts\python.exe" -m termtube.cli %*
