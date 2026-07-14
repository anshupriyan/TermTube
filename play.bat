@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"

:: 1. Setup local Python interpreter if it doesn't exist
if not exist "%SCRIPT_DIR%python_local\python.exe" (
    echo Python not found in the project directory.
    echo Downloading and installing a local Python interpreter...
    
    :: Download Python Installer
    powershell -Command "Write-Host 'Downloading Python 3.11 installer...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile 'python_installer.exe'"
    
    if not exist "%SCRIPT_DIR%python_installer.exe" (
        echo Failed to download Python installer. Please check your internet connection.
        exit /b 1
    )
    
    :: Run the installer silently, targeting a local folder in the project directory
    echo Installing Python locally to %SCRIPT_DIR%python_local...
    powershell -Command "Start-Process -FilePath 'python_installer.exe' -ArgumentList '/quiet InstallAllUsers=0 TargetDir=\'%SCRIPT_DIR%python_local\' PrependPath=0 AssociateFiles=0 ShortCuts=0 Include_doc=0' -Wait; Remove-Item -Path 'python_installer.exe' -Force"
    
    if not exist "%SCRIPT_DIR%python_local\python.exe" (
        echo Failed to install Python locally. Please install it manually.
        exit /b 1
    )
    
    echo Installing Python dependencies locally...
    "%SCRIPT_DIR%python_local\python.exe" -m pip install --upgrade pip
    "%SCRIPT_DIR%python_local\python.exe" -m pip install yt-dlp numpy
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
    powershell -Command "Write-Host 'Downloading FFmpeg essentials build...'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.zip' -OutFile 'ffmpeg.zip'; Write-Host 'Extracting FFmpeg...'; Expand-Archive -Path 'ffmpeg.zip' -DestinationPath 'ffmpeg_temp'; Get-ChildItem -Path 'ffmpeg_temp' -Filter 'ffmpeg.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Get-ChildItem -Path 'ffmpeg_temp' -Filter 'ffplay.exe' -Recurse | Copy-Item -Destination '%SCRIPT_DIR%'; Remove-Item -Path 'ffmpeg.zip', 'ffmpeg_temp' -Recurse -Force"
    
    if not exist "%SCRIPT_DIR%ffmpeg.exe" (
        echo Failed to download FFmpeg binaries. Please download them manually and place them in the project folder.
        exit /b 1
    )
)

:: 3. Configure paths for local binaries
set "PATH=%SCRIPT_DIR%;%PATH%"
set "PYTHONPATH=%SCRIPT_DIR%termtube;%PYTHONPATH%"

:: 4. Validate arguments and run
if "%~1"=="" (
    echo Usage: play.bat [youtube_url] [additional_options]
    echo.
    echo Examples:
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style ascii
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style halfblock --fps 15
    exit /b 1
)

"%SCRIPT_DIR%python_local\python.exe" -m termtube.cli %*
