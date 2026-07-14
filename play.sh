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
if [ -z "$1" ]; then
    echo "Usage: ./play.sh [youtube_url] [additional_options]"
    echo ""
    echo "Examples:"
    echo "  ./play.sh \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\""
    echo "  ./play.sh \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" --style ascii"
    echo "  ./play.sh \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" --style halfblock --fps 15"
    exit 1
fi

"$SCRIPT_DIR/.venv/bin/python3" -m termtube.cli "$@"
