#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper function to check if command exists globally or locally in the project directory
check_cmd() {
    command -v "$1" &> /dev/null || [ -f "$SCRIPT_DIR/$1" ]
}

# 1. Detect missing system dependencies (Python3, venv, ffmpeg, ffplay)
missing_deps=()

if ! command -v python3 &> /dev/null; then
    missing_deps+=("python3")
fi

if command -v python3 &> /dev/null; then
    python3 -c "import venv" &> /dev/null
    if [ $? -ne 0 ]; then
        missing_deps+=("python3-venv")
    fi
fi

if ! check_cmd ffmpeg || ! check_cmd ffplay; then
    missing_deps+=("ffmpeg")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "The following system dependencies are missing: ${missing_deps[*]}"
    echo "Attempting to install them automatically (may prompt for your sudo password)..."
    
    # Detect OS / Package Manager
    if [ -f /etc/debian_version ]; then
        echo "Detected Debian/Ubuntu system. Installing via apt-get..."
        sudo apt-get update
        
        apt_packages=()
        for dep in "${missing_deps[@]}"; do
            if [ "$dep" = "python3" ]; then
                apt_packages+=("python3")
            elif [ "$dep" = "python3-venv" ]; then
                apt_packages+=("python3-venv" "python3-pip")
            elif [ "$dep" = "ffmpeg" ]; then
                apt_packages+=("ffmpeg")
            fi
        done
        
        sudo apt-get install -y "${apt_packages[@]}"
        
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Detected macOS system. Installing via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "Homebrew is not installed. Please install Homebrew first (https://brew.sh) to proceed."
            exit 1
        fi
        
        brew_packages=()
        for dep in "${missing_deps[@]}"; do
            if [ "$dep" = "python3" ]; then
                brew_packages+=("python")
            elif [ "$dep" = "ffmpeg" ]; then
                brew_packages+=("ffmpeg")
            fi
        done
        
        if [ ${#brew_packages[@]} -ne 0 ]; then
            brew install "${brew_packages[@]}"
        fi
        
    elif [ -f /etc/arch-release ]; then
        echo "Detected Arch Linux. Installing via pacman..."
        pacman_packages=()
        for dep in "${missing_deps[@]}"; do
            if [ "$dep" = "python3" ]; then
                pacman_packages+=("python")
            elif [ "$dep" = "ffmpeg" ]; then
                pacman_packages+=("ffmpeg")
            fi
        done
        
        if [ ${#pacman_packages[@]} -ne 0 ]; then
            sudo pacman -S --noconfirm "${pacman_packages[@]}"
        fi
        
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
        echo "Detected Fedora/RHEL. Installing via dnf..."
        dnf_packages=()
        for dep in "${missing_deps[@]}"; do
            if [ "$dep" = "python3" ]; then
                dnf_packages+=("python3")
            elif [ "$dep" = "python3-venv" ]; then
                dnf_packages+=("python3-venv")
            elif [ "$dep" = "ffmpeg" ]; then
                dnf_packages+=("ffmpeg")
            fi
        done
        
        if [ ${#dnf_packages[@]} -ne 0 ]; then
            sudo dnf install -y "${dnf_packages[@]}"
        fi
    else
        echo "Could not detect package manager automatically."
        echo "Please install the missing dependencies manually: ${missing_deps[*]}"
        exit 1
    fi
    
    # Re-verify critical dependencies after installation attempt
    if ! command -v python3 &> /dev/null; then
        echo "Failed to install Python 3. Please install it manually."
        exit 1
    fi
    python3 -c "import venv" &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to install Python venv support. Please install python3-venv manually."
        exit 1
    fi
    if ! check_cmd ffmpeg || ! check_cmd ffplay; then
        echo "Failed to install ffmpeg/ffplay. Please install them manually."
        exit 1
    fi
    echo "All system dependencies successfully installed!"
fi

# 2. Setup local virtual environment (.venv)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "Creating local Python virtual environment (.venv)..."
    python3 -m venv "$SCRIPT_DIR/.venv"
    if [ $? -ne 0 ]; then
        echo "Failed to create virtual environment."
        rm -rf "$SCRIPT_DIR/.venv"
        exit 1
    fi
    echo "Installing Python dependencies locally..."
    "$SCRIPT_DIR/.venv/bin/python3" -m pip install --upgrade pip
    "$SCRIPT_DIR/.venv/bin/python3" -m pip install yt-dlp numpy
    if [ $? -ne 0 ]; then
        echo "Failed to install dependencies."
        rm -rf "$SCRIPT_DIR/.venv"
        exit 1
    fi
fi

# 2.5 Setup local Deno if not already present globally or locally
if ! command -v deno &> /dev/null && [ ! -f "$SCRIPT_DIR/deno" ]; then
    echo "deno is missing. Attempting to download Deno binary locally..."
    
    # Detect OS and architecture to download appropriate zip
    DENO_URL=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ "$(uname -m)" == "arm64" ]]; then
            DENO_URL="https://github.com/denoland/deno/releases/latest/download/deno-aarch64-apple-darwin.zip"
        else
            DENO_URL="https://github.com/denoland/deno/releases/latest/download/deno-x86_64-apple-darwin.zip"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ "$(uname -m)" == "x86_64" ]]; then
            DENO_URL="https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip"
        fi
    fi
    
    if [ -n "$DENO_URL" ]; then
        echo "Downloading Deno from $DENO_URL..."
        if command -v curl &> /dev/null; then
            curl -L "$DENO_URL" -o "$SCRIPT_DIR/deno.zip"
        elif command -v wget &> /dev/null; then
            wget "$DENO_URL" -O "$SCRIPT_DIR/deno.zip"
        fi
        
        if [ -f "$SCRIPT_DIR/deno.zip" ]; then
            echo "Extracting Deno..."
            unzip -o "$SCRIPT_DIR/deno.zip" -d "$SCRIPT_DIR"
            rm "$SCRIPT_DIR/deno.zip"
            chmod +x "$SCRIPT_DIR/deno"
        else
            echo "Failed to download Deno zip file."
        fi
    else
        echo "Unsupported OS/architecture for automatic Deno installation. Please install Deno manually."
    fi
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
