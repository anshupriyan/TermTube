# TermTube

<p align="center">
  <strong>Stream YouTube videos directly inside your terminal using ANSI truecolor or ASCII rendering with synchronized audio.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB?logo=python&logoColor=white" alt="Python" />
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-success" alt="Platform" />
  <img src="https://img.shields.io/github/license/anshupriyan/TermTube" alt="License" />
  <img src="https://img.shields.io/github/v/release/anshupriyan/TermTube" alt="Release" />
  <img src="https://img.shields.io/github/stars/anshupriyan/TermTube?style=social" alt="Stars" />
</p>

<p align="center">
  <img src="assets/ascii_demo.gif" alt="TermTube Demo" width="850"/>
</p>

---

TermTube is an open-source command-line YouTube player that streams videos directly inside modern terminal emulators using ANSI truecolor or ASCII rendering while keeping audio synchronized in real time.

## ✨ Features

- 🎨 **ANSI Truecolor Half-Block Rendering (`--style halfblock`)**
  - High-density full-color playback using Unicode half-block (`▀`) characters.
  - Packs two vertical pixels into a single terminal cell for maximum visual fidelity.

- 📝 **Vibrant Character Presets & ASCII Art**
  - **Block Shades (`--style shades` or `--preset shades`)**: Smooth Unicode density blocks (` ░▒▓█`) with rich shadows, vivid mid-tones, and bright highlights.
  - **Binary 0101 (`--style binary` or `--preset binary_0101`)**: Stream video in digital matrix binary `0` and `1` streams!
  - **High-Contrast ASCII (`--preset highcontrast`)**: Deep blacks and luminous bright highlights.
  - **Matrix Rain (`--preset matrix`)**: Digital code characters.
  - **Dots / Math / Minimal / Detailed**: Built-in artistic character sets.
  - **Custom Ramps (`--ramp "..."`)**: Supply any custom character sequence.

- ☀️ **Contrast & Lighting Controls**
  - **Contrast (`--contrast 1.5`)**: Multiplier to punch up deep blacks and luminous highlights.
  - **Brightness (`--brightness 0.1`)**: Offset to brighten dark scenes or adjust exposure.
  - **Gamma (`--gamma 0.8`)**: Non-linear lighting curve adjustment.
  - **Auto-Contrast (`--auto-contrast`)**: Dynamically stretches luminance range to maximize visual clarity on any video.
  - **Light & Color Boost (`--light-boost 0.2`)**: Increases saturation and color glow.

- 🌈 **Aesthetic Color Themes (`--color-mode`)**
  - `rgb`: Full 24-bit ANSI truecolor.
  - `glitch`: Multicolor chromatic aberration + VHS scanline split.
  - `rainbow`: Psychedelic neon rainbow spectrum.
  - `matrix`: Glowing cyberpunk green phosphor monitor.
  - `cyberpunk`: Electric neon cyan and magenta.
  - `amber`: Vintage cathode-ray tube (CRT) amber phosphor.
  - `fire`: Thermal flame gradient.
  - `gray`: Crisp monochrome black & white.

- 🔊 **Synchronized Audio**
  - Streams audio alongside video with clock-driven synchronization and drift tracking.

- 📐 **Automatic Terminal Scaling**
  - Detects terminal size automatically to maximize detail while preventing wrapping and scrolling.

- ⌨️ **Live Real-Time Hotkeys (No Interruption!)**
  - Change styles, characters, lighting, and colors mid-playback instantaneously with your keyboard:

| Key | Action | Effect |
| :--- | :--- | :--- |
| `S` / `Tab` | **Cycle Styles** | Cycles through all styles and wraps 7/7 → 1/7 |
| `1` | **Binary 0101** | Instantly switches to digital matrix binary stream (`0101`) |
| `2` | **Block Shades** | Switches to smooth density blocks (` ░▒▓█`) |
| `3` | **High-Contrast** | Switches to high-contrast ASCII art |
| `4` | **Classic ASCII** | Switches to standard ASCII density art |
| `5` | **Matrix Code** | Switches to Matrix code characters |
| `6` | **Dots** | Switches to circular dot characters (`·•○●█`) |
| `0` / `H` | **Half-Block HD** | Switches to HD Truecolor half-blocks (`▀`) |
| `C` | **Cycle Colors** | Cycles RGB -> Matrix -> Cyberpunk -> Glitch -> Rainbow -> Amber -> Fire -> Gray |
| `G` | **Glitch Mode** | Quick toggle VHS multicolor chromatic aberration glitch |
| `M` | **Matrix Green** | Quick toggle Cyberpunk matrix neon green glow |
| `+` / `-` | **Contrast +/-** | Boosts or lowers contrast dynamically |
| `]` / `[` | **Brightness +/-**| Adjusts brightness on the fly |
| `A` | **Auto-Contrast** | Toggles dynamic range lighting stretch ON/OFF |
| `I` | **Invert Ramp** | Inverts dark and bright characters |
| `Q` | **Quit** | Exits playback cleanly |

---

# 🚀 Quick Start (No Installation Required)

Download the latest release (or clone the repository), then simply run:

### Windows

```cmd
play.bat
```

### Linux / macOS

```bash
chmod +x play.sh
./play.sh
```

On the first launch TermTube automatically downloads and configures:

* Python
* FFmpeg
* Required dependencies

After setup:

1. Paste a YouTube URL.
2. Select your preferred style (Half-Block, Quad-Block, Braille, Block Shades, Binary 0101, etc.).
3. Choose lighting/contrast, color theme, and display size.
4. Enjoy.

> [!NOTE]
> Windows may display an **"Unknown Publisher"** warning because the batch file was downloaded from the Internet.
>
> Either:
>
> * Click **Run**, or
> * Right-click `play.bat` → **Properties** → **Unblock** → **OK**

---

# 📦 Installation (CLI)

If you prefer installing it as a command-line application:

```bash
cd termtube
pip install .
```

Run from anywhere:

```bash
termtube "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

Ensure `ffmpeg` and `ffplay` are available in your system `PATH`.

---

# ⚙️ Command Line Options

```text
Usage:

termtube [url] [options]

Arguments

url
    YouTube video URL

Options

--style {halfblock,ascii,shades,binary}
    Rendering style (default: halfblock)

--preset {binary,binary_0101,matrix,shades,blocks,highcontrast,contrast_lite,glow,braille,dots,ascii,detailed,math,slashes}
    Preset character ramp for ASCII and text art modes

--ramp RAMP
    Custom ASCII density ramp (overrides --preset)

--contrast CONTRAST
    Contrast multiplier (e.g. 1.3, 1.5, 2.0; default: 1.0)

--brightness BRIGHTNESS
    Brightness offset (-1.0 to 1.0; default: 0.0)

--gamma GAMMA
    Gamma lighting curve (default: 1.0)

--auto-contrast
    Automatically stretch dynamic range to maximize contrast and light

--light-boost LIGHT_BOOST
    Boost color saturation and light intensity (default: 0.0)

--color-mode {rgb,matrix,cyberpunk,amber,fire,gray}
    Color theme / lighting palette (default: rgb)

--cols COLS
    Output width in terminal columns (default: auto-detected from terminal size)

--fps FPS
    Target frame rate (default: 15)

--invert
    Invert character luminance mapping
```

---

# 🖥 Display Quality

TermTube renders in **terminal character cells**, not pixels.

That means visual quality depends primarily on your terminal font size.

| Setting      | Result                              |
| ------------ | ------------------------------------ |
| Smaller font | More terminal cells → Sharper image |
| Larger font  | Fewer cells → Lower detail          |

If playback looks blocky:

* Reduce terminal font size (`Ctrl -` / `Cmd -`)
* Increase terminal window size
* Override automatic sizing with:

```bash
--cols 120
```

---

## Performance Tuning

Higher detail requires more rendering work.

If playback becomes choppy:

* Lower `--cols`
* Lower `--fps`
* Try both rendering modes (`ascii` / `halfblock`)
* Watch the reported drift and dropped-frame statistics

Finding the ideal balance depends on:

* Terminal emulator
* CPU performance
* Network speed
* Terminal font size

---

# 💡 Examples

### High-quality ANSI rendering

```bash
termtube "https://www.youtube.com/watch?v=dQw4w9WgXcQ" \
    --style halfblock \
    --fps 15
```

### ASCII mode

```bash
termtube "https://www.youtube.com/watch?v=dQw4w9WgXcQ" \
    --style ascii \
    --cols 80
```

---

# 🏗 Architecture

```text
          YouTube
              │
          yt-dlp
              │
        FFmpeg Stream
              │
     RGB Video Frames
              │
 ANSI / ASCII Renderer
              │
     Terminal Emulator

          Audio Stream
              │
           ffplay
```

---

# 📌 Built With

* Python
* FFmpeg
* ffplay
* yt-dlp
* ANSI Escape Sequences
* Unicode Half-block Rendering

---

# 📄 License

Released under the MIT License.
