# Contributing to TermTube

Thank you for contributing to TermTube. Follow these guidelines to get started.

---

## 🛠 Development Setup

The easiest way to set up your environment is to use the automated setup scripts referenced in the [README](README.md):

* **Windows:** Run `play.bat`
* **Linux / macOS:** Run `chmod +x play.sh && ./play.sh`

On first launch, these scripts automatically set up Python, FFmpeg, and all required dependencies.

Alternatively, for manual setup:

```bash
cd termtube
python -m venv .venv
# Activate virtual environment
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate

pip install -e .
```

Ensure `ffmpeg` and `ffplay` are installed and available in your system `PATH`.

---

## 💻 Cross-Platform Testing

TermTube supports **Windows**, **Linux**, and **macOS**. 

* Test changes across platforms whenever possible.
* **Linux and macOS support is newer (v1.0.1)** and is more prone to platform-specific edge cases (terminal escape sequence variations, signal handling, audio player synchronization, and shell execution).
* State which platforms and terminal emulators you tested on in your PR.

---

## 🌿 Branch Naming Convention

Name your branches using the following prefixes:

* `feature/` – New features or enhancement additions (e.g., `feature/color-palettes`)
* `fix/` – Bug fixes or patch releases (e.g., `fix/macos-audio-lag`)
* `docs/` – Documentation updates or corrections (e.g., `docs/update-installation`)

---

## 💬 Commit Message Style

Keep commit messages concise, descriptive, and direct. Use imperative mood in the subject line:

* `Fix process cleanup when terminating play.sh`
* `Add --style ascii rendering option`
* `Update README with platform prerequisites`

---

## 🔀 Pull Request Process

1. **Branch off `main`**: Keep your branch updated with `main`.
2. **PR Description**: Include a clear summary of what changed, why it changed, and what testing was performed (including OS and terminal emulator used).
3. **Link Issues**: Reference any relevant issues (e.g., `Fixes #12`).
4. **Maintainer Sign-Off**: No PR will be merged without maintainer (`protagonist.lab`) review and sign-off.
