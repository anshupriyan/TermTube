@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"

:: 1. If local virtual env exists, use it directly
if exist "%SCRIPT_DIR%.venv\Scripts\python.exe" (
    set "PYTHON_RUN=%SCRIPT_DIR%.venv\Scripts\python.exe"
    goto run_player
)

:: 2. Find a working Python interpreter to create the virtual environment
set "PYTHON_EXE=python"
!PYTHON_EXE! -c "import sys" >nul 2>nul
if %errorlevel% neq 0 (
    set "PYTHON_EXE=py"
    !PYTHON_EXE! -c "import sys" >nul 2>nul
    if %errorlevel% neq 0 (
        set "PYTHON_EXE="
        
        :: Check user's pythoncore paths (common on Windows)
        for /d %%d in ("%USERPROFILE%\AppData\Local\Python\pythoncore-*") do (
            if exist "%%d\python.exe" (
                set "PYTHON_EXE=%%d\python.exe"
            )
        )
        
        :: Check user's local Programs\Python paths
        if not defined PYTHON_EXE (
            for /d %%d in ("%USERPROFILE%\AppData\Local\Programs\Python\Python*") do (
                if exist "%%d\python.exe" (
                    set "PYTHON_EXE=%%d\python.exe"
                )
            )
        )
        
        :: Check system-wide Python paths
        if not defined PYTHON_EXE (
            for /d %%d in ("%SystemDrive%\Python*") do (
                if exist "%%d\python.exe" (
                    set "PYTHON_EXE=%%d\python.exe"
                )
            )
        )
        
        if not defined PYTHON_EXE (
            echo Python was not found or is not working properly on your system.
            set /p INSTALL_PY="Would you like to install Python 3 automatically using winget? (y/n): "
            if /i "!INSTALL_PY!"=="y" (
                echo Installing Python...
                winget install Python.Python.3
                echo Please restart your terminal window and run play.bat again.
                exit /b 0
            ) else (
                echo Please install Python manually from https://www.python.org/downloads/
                exit /b 1
            )
        )
    )
)

:: 3. Setup local virtual environment (.venv) using the found python interpreter
echo Creating local Python virtual environment venv...
"!PYTHON_EXE!" -m venv "%SCRIPT_DIR%.venv"
if %errorlevel% neq 0 (
    echo Failed to create virtual environment.
    exit /b 1
)
echo Installing Python dependencies locally...
"%SCRIPT_DIR%.venv\Scripts\python.exe" -m pip install --upgrade pip
"%SCRIPT_DIR%.venv\Scripts\python.exe" -m pip install yt-dlp numpy

set "PYTHON_RUN=%SCRIPT_DIR%.venv\Scripts\python.exe"

:run_player
:: 4. Setup local FFmpeg binaries
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

:: 5. Configure paths for local binaries
set "PATH=%SCRIPT_DIR%;%PATH%"
set "PYTHONPATH=%SCRIPT_DIR%termtube;%PYTHONPATH%"

:: 6. Validate arguments and run
if "%~1"=="" (
    echo Usage: play.bat [youtube_url] [additional_options]
    echo.
    echo Examples:
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style ascii
    echo   play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style halfblock --fps 15
    exit /b 1
)

"!PYTHON_RUN!" -m termtube.cli %*
