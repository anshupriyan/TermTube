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

- 🎨 **ANSI Truecolor Rendering (`--style halfblock`)**
  - High-density full-color playback using Unicode half-block (`▀`) characters.
  - Packs two vertical pixels into a single terminal cell for maximum visual fidelity.

<p align="center">
<img src="assets/halfblock_demo.gif" width="850">
</p>

<p align="center">
<img src="assets/halfblock_render.png" width="55%">
<img src="assets/halfblock_detail.png" width="35%">
</p>

---

- 📝 **ASCII Density Rendering (`--style ascii`)**
  - Converts video frames into colored ASCII art using a configurable density ramp while preserving RGB colors.

<p align="center">
<img src="assets/ascii_render.png" width="55%">
<img src="assets/ascii_detail.png" width="35%">
</p>

---

- 🔊 **Synchronized Audio**
  - Streams audio alongside video with clock-driven synchronization and drift tracking.

- 📐 **Automatic Terminal Scaling**
  - Detects terminal size automatically to maximize detail while preventing wrapping and scrolling.

- 🔄 **Automatic Reconnection**
  - FFmpeg automatically reconnects when YouTube temporarily throttles or drops the connection.

- ⚡ **Cross-platform**
  - Windows
  - Linux
  - macOS

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
2. Select a rendering style.
3. Enjoy.

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

--cols COLS
    Output width in terminal columns
    (default: auto)

--fps FPS
    Target frame rate
    (default: 15)

--style {halfblock,ascii}
    Rendering mode
    (default: halfblock)

--ramp RAMP
    ASCII density ramp
    (default: " .:-=+*#%@")
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
