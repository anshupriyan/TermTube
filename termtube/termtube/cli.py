import argparse
import sys
import time
import subprocess
import shutil
from termtube.resolver import resolve_streams, update_yt_dlp, YtDlpUpdatedError
from termtube.player import open_video_frame_pipe, read_frame, start_audio
from termtube.render import (
    frame_to_halfblock_ansi,
    frame_to_ascii_color,
    benchmark_render,
    CHARACTER_PRESETS
)

def disable_quick_edit() -> None:
    """
    Disables Windows Console QuickEdit mode on CONIN$ to prevent mouse clicks
    or switching applications from freezing terminal output and input.
    """
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        conin = kernel32.CreateFileW("CONIN$", 0xC0000000, 3, None, 3, 0, None)
        if conin != -1:
            mode = ctypes.c_ulong()
            if kernel32.GetConsoleMode(conin, ctypes.byref(mode)):
                # Clear ENABLE_QUICK_EDIT_MODE (0x0040) and set ENABLE_EXTENDED_FLAGS (0x0080)
                new_mode = (mode.value & ~0x0040) | 0x0080
                kernel32.SetConsoleMode(conin, new_mode)
            kernel32.CloseHandle(conin)
    except Exception:
        pass

def get_all_keypresses() -> list[str]:
    """
    Non-blocking check that drains and returns all available key characters
    without hanging, blocking, or queuing up stale events when switching apps.
    """
    keys = []
    try:
        import msvcrt
        while msvcrt.kbhit():
            ch = msvcrt.getch()
            if ch in (b'\x00', b'\xe0'):
                # consume extended / arrow key prefix only if a second byte is ready
                if msvcrt.kbhit():
                    msvcrt.getch()
                continue
            try:
                decoded = ch.decode('utf-8', errors='ignore')
                if decoded:
                    keys.append(decoded)
            except Exception:
                pass
    except ImportError:
        try:
            import select
            while True:
                dr, _, _ = select.select([sys.stdin], [], [], 0)
                if dr:
                    ch = sys.stdin.read(1)
                    if ch:
                        keys.append(ch)
                    else:
                        break
                else:
                    break
        except Exception:
            pass
    return keys

def main():
    # Ensure stdout supports UTF-8 encoding on Windows consoles
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    # Prevent console from freezing on mouse clicks / task switching
    disable_quick_edit()

    parser = argparse.ArgumentParser(description="Terminal YouTube Video Player")
    parser.add_argument("url", nargs="?", help="YouTube video URL to stream")
    parser.add_argument("-u", "--update", action="store_true", help="Update yt-dlp to the latest version and exit")
    parser.add_argument("--cols", type=int, default=None, help="Target width in columns (default: auto-detect)")
    parser.add_argument("--fps", type=int, default=15, help="Target frames per second (default: 15)")
    parser.add_argument("--style", choices=["halfblock", "ascii", "shades", "binary"],
                        default="halfblock", help="Rendering style (default: halfblock)")
    parser.add_argument("--preset", choices=list(CHARACTER_PRESETS.keys()), default=None,
                        help="Character set preset (e.g. binary, binary_0101, shades, matrix, highcontrast, dots, ascii)")
    parser.add_argument("--ramp", default=None, help="Custom ASCII character density ramp (overrides --preset)")
    parser.add_argument("--contrast", type=float, default=1.0, help="Contrast adjustment multiplier (e.g. 1.3, 1.5, 2.0; default: 1.0)")
    parser.add_argument("--brightness", type=float, default=0.0, help="Brightness offset (-1.0 to 1.0; default: 0.0)")
    parser.add_argument("--gamma", type=float, default=1.0, help="Gamma curve exponent (default: 1.0)")
    parser.add_argument("--auto-contrast", action="store_true", help="Automatically stretch dynamic range to maximize light and contrast")
    parser.add_argument("--light-boost", type=float, default=0.0, help="Color saturation and lighting intensity boost (default: 0.0)")
    parser.add_argument("--color-mode", choices=["rgb", "matrix", "cyberpunk", "glitch", "rainbow", "amber", "fire", "gray"], default="rgb",
                        help="Color theme / lighting palette (default: rgb)")
    parser.add_argument("--invert", action="store_true", help="Invert character luminance mapping")
    args = parser.parse_args()

    if args.update:
        try:
            update_yt_dlp()
            sys.exit(0)
        except Exception:
            sys.exit(1)

    if not args.url:
        parser.error("the following arguments are required: url (unless -u/--update is specified)")

    # Resolve initial style and character ramp
    style = args.style
    if (args.preset or args.ramp) and style == "halfblock":
        style = "ascii"

    if style == "binary":
        effective_ramp = CHARACTER_PRESETS["binary_0101"]
        render_style = "ascii"
    elif style == "shades":
        effective_ramp = CHARACTER_PRESETS["shades"]
        render_style = "ascii"
    else:
        render_style = style
        if args.ramp:
            effective_ramp = args.ramp
        elif args.preset:
            effective_ramp = CHARACTER_PRESETS[args.preset]
        else:
            effective_ramp = CHARACTER_PRESETS["ascii"]

    print(f"Resolving video stream for URL: {args.url}", file=sys.stderr)
    try:
        info = resolve_streams(args.url)
    except YtDlpUpdatedError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error resolving stream: {e}", file=sys.stderr)
        sys.exit(1)

    width = info["width"]
    height = info["height"]
    video_url = info["video_url"]

    if width <= 0 or height <= 0:
        print(f"Error: Invalid resolution resolved ({width}x{height})", file=sys.stderr)
        sys.exit(1)

    # EXACT ORIGINAL RESOLUTION CALCULATION - UNTOUCHED
    term_size = shutil.get_terminal_size(fallback=(80, 24))
    if args.cols is None:
        target_cols = max(1, term_size.columns - 2)
    else:
        target_cols = args.cols

    # Compute target output height forcing a fixed 16:9 ratio, branching on style
    if render_style == "halfblock":
        target_rows = int(target_cols * 1.0 * (9.0 / 16.0))
    else:
        target_rows = int(target_cols * 0.5 * (9.0 / 16.0))
    
    target_rows = max(1, target_rows)

    # Cap target_rows to prevent terminal buffer overflow/scrolling
    target_rows = min(target_rows, term_size.lines - 3)
    target_rows = max(1, target_rows)

    if render_style == "halfblock":
        video_rows = target_rows * 2
    else:
        video_rows = target_rows

    print(f"Resolved resolution: {width}x{height} @ {info['fps']} fps", file=sys.stderr)
    print(f"Target rendering resolution: {target_cols}x{target_rows} @ {args.fps} fps (video decode: {target_cols}x{video_rows})", file=sys.stderr)

    # Real-time state variables for instant mode/style/color switching
    current_style = render_style
    current_ramp = effective_ramp
    current_contrast = args.contrast
    current_brightness = args.brightness
    current_gamma = args.gamma
    current_auto_contrast = args.auto_contrast
    current_light_boost = args.light_boost
    current_color_mode = args.color_mode.lower()
    current_invert = args.invert

    # Cyclic series definitions with full wrap-around support
    color_modes_cycle = ["rgb", "matrix", "cyberpunk", "glitch", "rainbow", "amber", "fire", "gray"]
    style_presets_cycle = [
        ("halfblock", None, "Half-Block HD Color (▀)"),
        ("ascii", "shades", "Block Shades (░▒▓█)"),
        ("ascii", "binary_0101", "Binary 0101"),
        ("ascii", "highcontrast", "High-Contrast ASCII"),
        ("ascii", "ascii", "Classic ASCII"),
        ("ascii", "matrix", "Matrix Code"),
        ("ascii", "dots", "Dots (·•○●█)"),
    ]

    # Current index in style cycle
    current_style_idx = 0
    for idx, (st, pr, _) in enumerate(style_presets_cycle):
        if st == current_style:
            if pr is None or (pr in CHARACTER_PRESETS and CHARACTER_PRESETS[pr] == current_ramp):
                current_style_idx = idx
                break

    osd_text = "[1-6/S] Styles | [C] Color | [G] Glitch | [M] Matrix | [+/-] Contrast | [Q] Quit"
    osd_until = time.monotonic() + 3.5  # Show initial hotkey hint for 3.5 seconds

    i = 0
    frames_dropped = 0
    audio_proc = None
    proc = None

    try:
        # Start audio playback if audio url is resolved
        audio_url = info.get("audio_url")
        headers = info.get("headers", {})
        if audio_url:
            try:
                audio_proc = start_audio(audio_url, headers=headers)
            except Exception as e:
                print(f"Failed to start audio playback: {e}", file=sys.stderr)
        
        # Mark the start time immediately after starting audio
        start_time = time.monotonic()

        proc = open_video_frame_pipe(video_url, target_cols, video_rows, args.fps, headers=headers)
    except Exception as e:
        print(f"Failed to open video frame pipe: {e}", file=sys.stderr)
        sys.exit(1)

    # Disable QuickEdit again right before playback starts
    disable_quick_edit()

    # Hide cursor and clear screen once at startup
    sys.stdout.write("\x1b[?25l\x1b[2J")
    sys.stdout.flush()

    try:
        while True:
            frame = read_frame(proc, target_cols, video_rows)
            if frame is None:
                # Clean break on EOF/short-read
                break
            
            # Benchmark on first frame (writes to sys.stderr, does not skip frame)
            if i == 0:
                if current_style == "halfblock":
                    benchmark_render(frame, frame_to_halfblock_ansi, iterations=30,
                                     contrast=current_contrast, brightness=current_brightness,
                                     gamma=current_gamma, auto_contrast=current_auto_contrast,
                                     light_boost=current_light_boost, color_mode=current_color_mode)
                else:
                    benchmark_render(frame, frame_to_ascii_color, iterations=30,
                                     ramp=current_ramp, contrast=current_contrast,
                                     brightness=current_brightness, gamma=current_gamma,
                                     auto_contrast=current_auto_contrast, light_boost=current_light_boost,
                                     color_mode=current_color_mode, invert=current_invert)
                
            target_time = start_time + i / args.fps
            now = time.monotonic()

            # Process all pending non-blocking keypresses
            keys = get_all_keypresses()
            for key in keys:
                if key.lower() == 'q':
                    raise KeyboardInterrupt
                elif key == '1':
                    current_style = "ascii"
                    current_ramp = CHARACTER_PRESETS["binary_0101"]
                    current_style_idx = 2
                    osd_text = "Style: Binary 0101 (3/7)"
                    osd_until = now + 2.0
                elif key == '2':
                    current_style = "ascii"
                    current_ramp = CHARACTER_PRESETS["shades"]
                    current_style_idx = 1
                    osd_text = "Style: Block Shades (░▒▓█) (2/7)"
                    osd_until = now + 2.0
                elif key == '3':
                    current_style = "ascii"
                    current_ramp = CHARACTER_PRESETS["highcontrast"]
                    current_style_idx = 3
                    osd_text = "Style: High-Contrast (4/7)"
                    osd_until = now + 2.0
                elif key == '4':
                    current_style = "ascii"
                    current_ramp = CHARACTER_PRESETS["ascii"]
                    current_style_idx = 4
                    osd_text = "Style: Classic ASCII (5/7)"
                    osd_until = now + 2.0
                elif key == '5':
                    current_style = "ascii"
                    current_ramp = CHARACTER_PRESETS["matrix"]
                    current_style_idx = 5
                    osd_text = "Style: Matrix Code (6/7)"
                    osd_until = now + 2.0
                elif key == '6':
                    current_style = "ascii"
                    current_ramp = CHARACTER_PRESETS["dots"]
                    current_style_idx = 6
                    osd_text = "Style: Dots (·•○●█) (7/7)"
                    osd_until = now + 2.0
                elif key in ('0', 'h', 'H'):
                    current_style = "halfblock"
                    current_style_idx = 0
                    osd_text = "Style: Half-Block HD Color (1/7)"
                    osd_until = now + 2.0
                elif key in ('s', 'S', '\t', ' '):
                    # Style Cycle: wraps around from last (7/7) back to first (1/7)
                    current_style_idx = (current_style_idx + 1) % len(style_presets_cycle)
                    st, pr, desc = style_presets_cycle[current_style_idx]
                    current_style = st
                    if pr is not None:
                        current_ramp = CHARACTER_PRESETS[pr]
                    osd_text = f"Style: {desc} ({current_style_idx + 1}/{len(style_presets_cycle)})"
                    osd_until = now + 2.0
                elif key in ('c', 'C'):
                    # Color Cycle: wraps around from last (6/6) back to first (1/6)
                    cur_col = current_color_mode.lower()
                    try:
                        cur_idx = color_modes_cycle.index(cur_col)
                    except ValueError:
                        cur_idx = 0
                    next_idx = (cur_idx + 1) % len(color_modes_cycle)
                    current_color_mode = color_modes_cycle[next_idx]
                    osd_text = f"Color: {current_color_mode.upper()} ({next_idx + 1}/{len(color_modes_cycle)})"
                    osd_until = now + 2.0
                elif key in ('m', 'M'):
                    current_color_mode = "rgb" if current_color_mode.lower() == "matrix" else "matrix"
                    osd_text = f"Color: {current_color_mode.upper()}"
                    osd_until = now + 2.0
                elif key in ('g', 'G'):
                    current_color_mode = "rgb" if current_color_mode.lower() == "glitch" else "glitch"
                    osd_text = f"Color: {current_color_mode.upper()} (VHS CHROMATIC)"
                    osd_until = now + 2.0
                elif key in ('+', '='):
                    # Contrast Up: wraps to 1.0x if exceeded max
                    if current_contrast >= 2.6:
                        current_contrast = 1.0
                    else:
                        current_contrast = round(current_contrast + 0.2, 1)
                    osd_text = f"Contrast: {current_contrast:.1f}x"
                    osd_until = now + 2.0
                elif key in ('-', '_'):
                    # Contrast Down: wraps to 2.6x if below min
                    if current_contrast <= 0.6:
                        current_contrast = 2.6
                    else:
                        current_contrast = round(current_contrast - 0.2, 1)
                    osd_text = f"Contrast: {current_contrast:.1f}x"
                    osd_until = now + 2.0
                elif key in (']', '}'):
                    # Brightness Up: wraps to -0.3 if exceeded
                    if current_brightness >= 0.4:
                        current_brightness = -0.3
                    else:
                        current_brightness = round(current_brightness + 0.1, 2)
                    osd_text = f"Brightness: {current_brightness:+.2f}"
                    osd_until = now + 2.0
                elif key in ('[', '{'):
                    # Brightness Down: wraps to +0.4 if below min
                    if current_brightness <= -0.4:
                        current_brightness = 0.4
                    else:
                        current_brightness = round(current_brightness - 0.1, 2)
                    osd_text = f"Brightness: {current_brightness:+.2f}"
                    osd_until = now + 2.0
                elif key in ('a', 'A'):
                    current_auto_contrast = not current_auto_contrast
                    osd_text = f"Auto-Contrast: {'ON' if current_auto_contrast else 'OFF'}"
                    osd_until = now + 2.0
                elif key in ('i', 'I'):
                    current_invert = not current_invert
                    osd_text = f"Invert Mode: {'ON' if current_invert else 'OFF'}"
                    osd_until = now + 2.0
                elif key in ('?', '/'):
                    osd_text = "[1-6/S] Styles | [H] HD | [C] Color | [+/-] Contrast | [Q] Quit"
                    osd_until = now + 3.5

            # If we are early, sleep until target time
            if now < target_time:
                time.sleep(target_time - now)
                now = time.monotonic()

            # If we are more than 2 frame intervals behind, drop formatting/writing
            if now > target_time + (2.0 / args.fps):
                frames_dropped += 1
            else:
                if current_style == "halfblock":
                    rendered_str = frame_to_halfblock_ansi(
                        frame,
                        contrast=current_contrast,
                        brightness=current_brightness,
                        gamma=current_gamma,
                        auto_contrast=current_auto_contrast,
                        light_boost=current_light_boost,
                        color_mode=current_color_mode
                    )
                else:
                    # For ASCII / character modes: sample every 2nd row if frame has 2x rows
                    ascii_frame = frame[0::2] if frame.shape[0] >= target_rows * 2 else frame
                    rendered_str = frame_to_ascii_color(
                        ascii_frame,
                        ramp=current_ramp,
                        contrast=current_contrast,
                        brightness=current_brightness,
                        gamma=current_gamma,
                        auto_contrast=current_auto_contrast,
                        light_boost=current_light_boost,
                        color_mode=current_color_mode,
                        invert=current_invert
                    )

                # Append On-Screen Display (OSD) badge if active
                if osd_text and now < osd_until:
                    rendered_str += f"\x1b[1;30;42m [{osd_text}] \x1b[0m\x1b[K"
                elif osd_text:
                    rendered_str += "\x1b[K"
                    osd_text = None

                sys.stdout.write(rendered_str)
                sys.stdout.flush()

            # Every 30 frames, report current drift in ms to sys.stderr
            if (i + 1) % 30 == 0:
                drift_ms = (now - target_time) * 1000.0
                print(f"Drift: {drift_ms:.2f} ms", file=sys.stderr)

            i += 1

        # Exited loop cleanly (Video EOF)
        if audio_proc:
            poll_status = audio_proc.poll()
            print(f"Video EOF detected. Audio process poll status: {poll_status}", file=sys.stderr)
            if poll_status is None:
                print("Video ended, waiting for audio to finish...", file=sys.stderr)
                try:
                    audio_proc.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    print("Audio wait timed out, proceeding to terminate.", file=sys.stderr)

            # Read and print captured stderr from audio_proc
            try:
                if audio_proc.poll() is not None and audio_proc.stderr is not None:
                    stderr_content = audio_proc.stderr.read()
                    if stderr_content:
                        print(f"ffplay stderr output:\n{stderr_content}", file=sys.stderr)
                print(f"ffplay exit code: {audio_proc.returncode}", file=sys.stderr)
            except Exception as e:
                print(f"Failed to read ffplay diagnostics: {e}", file=sys.stderr)

    except KeyboardInterrupt:
        pass
    finally:
        # Restore cursor
        sys.stdout.write("\x1b[?25h")
        sys.stdout.flush()

        # Terminate audio process if running
        if audio_proc:
            try:
                if audio_proc.poll() is None:
                    audio_proc.terminate()
                    audio_proc.wait(timeout=2)
            except Exception:
                try:
                    audio_proc.kill()
                    audio_proc.wait()
                except Exception:
                    pass

        # Terminate video process if running
        if proc:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()

        print(f"Done. Processed {i} frames. Dropped {frames_dropped} frames.", file=sys.stderr)

if __name__ == "__main__":
    main()
