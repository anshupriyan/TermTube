# TermTube 📺

A high-performance command-line YouTube video and audio player that renders videos directly in your terminal using ANSI color codes or ASCII text art, synchronized with live audio.

Developed for modern terminal emulators with truecolor support.

---

## Features

- **Truecolor Block Rendering (`--style halfblock`)**: Packs two vertical pixels per character cell using Unicode half-block characters (`▀`), rendering high-density full-color visual video frames.
- **ASCII Density Art (`--style ascii`)**: Renders details using a custom density character ramp while retaining true RGB color values per pixel.
- **Auto-Reconnection**: Resilient socket streaming. Ffmpeg/ffplay automatically reconnect and resume if YouTube throttles or drops the connection during playback.
- **Dynamic Terminal Scaling**: Auto-detects terminal width and height to fit the window cleanly, preventing awkward layout wraps or console buffer scrolling.
- **Synced Audio**: Launches synced audio streaming alongside the video with clock-driven drift tracking.

---

## Quick Start (No Installation Needed)

Just clone the repository, download/copy `ffmpeg` and `ffplay` executable binaries to the root folder, and run:

### Windows (cmd / PowerShell)
```powershell
.\play.bat "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

### macOS & Linux
```bash
chmod +x play.sh
./play.sh "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

*Note: The script automatically checks for Python, installs required packages (`yt-dlp` and `numpy`), configures path variables, and bootstraps setup dependencies.*

> [!NOTE]
> **Windows Security Warning ("Unknown Publisher")**: 
> Windows flags files downloaded directly from browsers (like GitHub ZIP releases) with a security warning. If you encounter this prompt:
> 1. Click **Run** to execute the script.
> 2. Alternatively, right-click `play.bat` -> select **Properties** -> check the **Unblock** box at the bottom -> click **OK** to permanently remove the warning.


---

## Native Installation (Global Command)

Alternatively, you can install the package globally to run `termtube` directly from anywhere in your console:

1. Change directory to `termtube` containing `pyproject.toml`:
   ```bash
   cd termtube
   ```
2. Install the package using `pip` (standard user-install or developer mode):
   ```bash
   pip install .
   ```
3. Run the player from any directory:
   ```bash
   termtube "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style ascii
   ```

*Ensure `ffmpeg` and `ffplay` are available on your system's `PATH` variable.*

---

## Command Line Arguments

```
Usage: play.bat/play.sh/termtube [url] [options]

Arguments:
  url                  YouTube video URL to stream

Options:
  --cols COLS          Target width in columns (default: None for auto-detect)
  --fps FPS            Target frames per second (default: 15)
  --style {halfblock,ascii}
                       Rendering style (default: halfblock)
  --ramp RAMP          ASCII character density ramp (default: ' .:-=+*#%@')
```

### Examples

- **High-definition color rendering**:
  ```bash
  termtube "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style halfblock --fps 15
  ```
- **ASCII style with manual width override (80 columns)**:
  ```bash
  termtube "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --style ascii --cols 80
  ```
