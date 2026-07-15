#!/bin/bash

# 1. Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is not installed. Please install Python 3 to continue."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Tip: Run 'brew install python'"
    else
        echo "Tip: Run 'sudo apt install python3' or similar for your package manager"
    fi
    exit 1
fi

# 2. Setup local virtual environment (.venv)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "Creating local Python virtual environment (.venv)..."
    python3 -m venv "$SCRIPT_DIR/.venv"
    if [ $? -ne 0 ]; then
        echo "Failed to create virtual environment."
        exit 1
    fi
    echo "Installing Python dependencies locally..."
    "$SCRIPT_DIR/.venv/bin/python3" -m pip install --upgrade pip
    "$SCRIPT_DIR/.venv/bin/python3" -m pip install yt-dlp numpy
fi

# 3. Configure paths for ffmpeg and ffplay
export PATH="$SCRIPT_DIR:$PATH"
export PYTHONPATH="$SCRIPT_DIR/termtube:$PYTHONPATH"

# 4. Check for ffmpeg and ffplay
if ! command -v ffmpeg &> /dev/null || ! command -v ffplay &> /dev/null; then
    echo "ffmpeg/ffplay not found on PATH or in current directory."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Tip: Install them using Homebrew: 'brew install ffmpeg'"
    else
        echo "Tip: Install them using your package manager: 'sudo apt install ffmpeg' or 'sudo pacman -S ffmpeg'"
    fi
    exit 1
fi

# 5. Validate arguments and run
YT_URL="$1"

if [ -z "$YT_URL" ]; then
    while true; do
        echo ""
        echo "==================================================="
        echo "            TermTube Terminal Player"
        echo "==================================================="
        echo ""
        read -p "Enter YouTube Video Link (or press Enter to exit): " YT_URL
        if [ -z "$YT_URL" ]; then
            echo "Goodbye!"
            exit 0
        fi
        
        echo ""
        echo "Select rendering style:"
        echo "  1. Block characters (hd color)"
        echo "  2. ASCII density characters (text art)"
        echo ""
        read -p "Select Option (1 or 2) [Default: 1]: " STYLE_CHOICE
        if [ "$STYLE_CHOICE" = "2" ]; then
            PLAY_STYLE="--style ascii"
        else
            PLAY_STYLE="--style halfblock"
        fi
        echo ""
        echo "Select playback frame rate:"
        echo "  1. 15 FPS"
        echo "  2. 24 FPS"
        echo "  3. 30 FPS"
        echo ""
        read -p "Select Option (1, 2 or 3) [Default: 1]: " FPS_CHOICE
        if [ "$FPS_CHOICE" = "2" ]; then
            PLAY_FPS="--fps 24"
        elif [ "$FPS_CHOICE" = "3" ]; then
            PLAY_FPS="--fps 30"
        else
            PLAY_FPS="--fps 15"
        fi
        echo ""
        
        "$SCRIPT_DIR/.venv/bin/python3" -m termtube.cli "$YT_URL" $PLAY_STYLE $PLAY_FPS
        
        echo ""
        echo "Playback finished."
        YT_URL="" # Clear for the next iteration
    done
else
    "$SCRIPT_DIR/.venv/bin/python3" -m termtube.cli "$@"
fi
