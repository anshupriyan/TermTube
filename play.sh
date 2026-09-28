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
    python3 -m ensurepip --version &> /dev/null
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
                PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
                apt_packages+=("python${PYVER}-venv" "python3-pip")
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
    python3 -m ensurepip --version &> /dev/null
    if [ $? -ne 0 ]; then
        PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        echo "Failed to install Python venv/ensurepip support."
        echo "Attempted package: python${PYVER}-venv"
        echo "Current Python version: $(python3 --version)"
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
        echo "Select rendering style / character set:"
        echo "  1. Block characters (hd color) [Default]"
        echo "  2. Block Shades ( ░▒▓█ - Deep Shadows & Bright Light)"
        echo "  3. Binary 0101 (Matrix Digital Stream)"
        echo "  4. High-Contrast ASCII (Vivid highlights & deep shadows)"
        echo "  5. Classic ASCII (Standard text art)"
        echo "  6. Custom Characters (Type your own ramp)"
        echo ""
        read -p "Select Option (1-6) [Default: 1]: " STYLE_CHOICE
        if [ "$STYLE_CHOICE" = "2" ]; then
            PLAY_STYLE="--style shades"
        elif [ "$STYLE_CHOICE" = "3" ]; then
            PLAY_STYLE="--style binary"
        elif [ "$STYLE_CHOICE" = "4" ]; then
            PLAY_STYLE="--style ascii --preset highcontrast"
        elif [ "$STYLE_CHOICE" = "5" ]; then
            PLAY_STYLE="--style ascii --preset ascii"
        elif [ "$STYLE_CHOICE" = "6" ]; then
            echo ""
            read -p "Enter custom character ramp (from dark to bright): " CUSTOM_RAMP
            if [ -z "$CUSTOM_RAMP" ]; then
                PLAY_STYLE="--style ascii"
            else
                PLAY_STYLE="--style ascii --ramp \"$CUSTOM_RAMP\""
            fi
        else
            PLAY_STYLE="--style halfblock"
        fi
        echo ""

        echo "Select contrast & lighting tuning:"
        echo "  1. Standard (Natural balance) [Default]"
        echo "  2. High Contrast & Vivid Light (Deep blacks & glowing highlights)"
        echo "  3. Ultra Bright (Light boost for dark videos)"
        echo "  4. Dynamic Auto-Contrast (Auto-stretches lighting range)"
        echo ""
        read -p "Select Option (1-4) [Default: 1]: " LIGHT_CHOICE
        if [ "$LIGHT_CHOICE" = "2" ]; then
            PLAY_LIGHT="--contrast 1.5 --light-boost 0.15"
        elif [ "$LIGHT_CHOICE" = "3" ]; then
            PLAY_LIGHT="--contrast 1.2 --brightness 0.15 --light-boost 0.25"
        elif [ "$LIGHT_CHOICE" = "4" ]; then
            PLAY_LIGHT="--auto-contrast --contrast 1.3"
        else
            PLAY_LIGHT=""
        fi
        echo ""

        echo "Select color theme:"
        echo "  1. Full Truecolor RGB [Default]"
        echo "  2. Matrix Neon Green (Cyberpunk phosphor glow)"
        echo "  3. Cyberpunk (Neon Cyan & Magenta)"
        echo "  4. Glitch Multicolor (Chromatic Aberration & VHS Split)"
        echo "  5. Rainbow Psychedelic (Full Neon Spectrum)"
        echo "  6. Amber CRT (Vintage monitor glow)"
        echo "  7. Monochrome Grayscale (High-contrast B&W)"
        echo ""
        read -p "Select Option (1-7) [Default: 1]: " COLOR_CHOICE
        if [ "$COLOR_CHOICE" = "2" ]; then
            PLAY_COLOR="--color-mode matrix"
        elif [ "$COLOR_CHOICE" = "3" ]; then
            PLAY_COLOR="--color-mode cyberpunk"
        elif [ "$COLOR_CHOICE" = "4" ]; then
            PLAY_COLOR="--color-mode glitch"
        elif [ "$COLOR_CHOICE" = "5" ]; then
            PLAY_COLOR="--color-mode rainbow"
        elif [ "$COLOR_CHOICE" = "6" ]; then
            PLAY_COLOR="--color-mode amber"
        elif [ "$COLOR_CHOICE" = "7" ]; then
            PLAY_COLOR="--color-mode gray"
        else
            PLAY_COLOR="--color-mode rgb"
        fi
        echo ""

        echo "Select playback frame rate:"
        echo "  1. 15 FPS [Default]"
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
        echo "==================================================="
        echo " Tip: Switch styles & colors live with keyboard!"
        echo "   [S] Cycle Styles  [1-6] Jump to Style [H] HD Color"
        echo "   [C] Cycle Colors  [G] Glitch Mode     [M] Matrix"
        echo "   [+/-] Contrast    []]/[[] Brightness  [Q] Quit"
        echo "==================================================="
        echo ""
        
        "$SCRIPT_DIR/.venv/bin/python3" -m termtube.cli "$YT_URL" $PLAY_STYLE $PLAY_LIGHT $PLAY_COLOR $PLAY_FPS
        
        echo ""
        echo "Playback finished."
        YT_URL="" # Clear for the next iteration
    done
else
    "$SCRIPT_DIR/.venv/bin/python3" -m termtube.cli "$@"
fi
