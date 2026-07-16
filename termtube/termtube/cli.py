import argparse
import sys
import time
import subprocess
import shutil
from termtube.resolver import resolve_streams, update_yt_dlp, YtDlpUpdatedError
from termtube.player import open_video_frame_pipe, read_frame, start_audio
from termtube.render import frame_to_halfblock_ansi, benchmark_render, frame_to_ascii_color

def main():
    # Ensure stdout supports UTF-8 encoding on Windows consoles
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    parser = argparse.ArgumentParser(description="Terminal YouTube Video Player")
    parser.add_argument("url", nargs="?", help="YouTube video URL to stream")
    parser.add_argument("-u", "--update", action="store_true", help="Update yt-dlp to the latest version and exit")
    parser.add_argument("--cols", type=int, default=None, help="Target width in columns (default: auto-detect)")
    parser.add_argument("--fps", type=int, default=15, help="Target frames per second (default: 15)")
    parser.add_argument("--style", choices=["halfblock", "ascii"], default="halfblock", help="Rendering style (default: halfblock)")
    parser.add_argument("--ramp", default=" .:-=+*#%@", help="ASCII character density ramp (default: ' .:-=+*#%%@')")
    args = parser.parse_args()

    if args.update:
        try:
            update_yt_dlp()
            sys.exit(0)
        except Exception:
            sys.exit(1)

    if not args.url:
        parser.error("the following arguments are required: url (unless -u/--update is specified)")

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

    term_size = shutil.get_terminal_size(fallback=(80, 24))
    if args.cols is None:
        target_cols = max(1, term_size.columns - 2)
    else:
        target_cols = args.cols

    # Compute target output height forcing a fixed 16:9 ratio, branching on style
    if args.style == "halfblock":
        target_rows = int(target_cols * 1.0 * (9.0 / 16.0))
    else:
        target_rows = int(target_cols * 0.5 * (9.0 / 16.0))
    
    target_rows = max(1, target_rows)

    # Cap target_rows to prevent terminal buffer overflow/scrolling
    target_rows = min(target_rows, term_size.lines - 3)
    target_rows = max(1, target_rows)

    if args.style == "halfblock":
        video_rows = target_rows * 2
    else:
        video_rows = target_rows

    print(f"Resolved resolution: {width}x{height} @ {info['fps']} fps", file=sys.stderr)
    print(f"Target rendering resolution: {target_cols}x{target_rows} @ {args.fps} fps (video decode: {target_cols}x{video_rows})", file=sys.stderr)

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

    # Hide cursor, set black background/white text, and fill entire terminal viewport with black spaces
    fill_str = "\x1b[?25l\x1b[40m\x1b[37m\x1b[H"
    fill_str += (" " * term_size.columns + "\n") * (term_size.lines - 1)
    fill_str += " " * term_size.columns
    fill_str += "\x1b[H"
    sys.stdout.write(fill_str)
    sys.stdout.flush()

    try:
        while True:
            frame = read_frame(proc, target_cols, video_rows)
            if frame is None:
                # Clean break on EOF/short-read
                break
            
            # Benchmark on first frame (writes to sys.stderr, does not skip frame)
            if i == 0:
                if args.style == "ascii":
                    benchmark_render(frame, frame_to_ascii_color, iterations=30, ramp=args.ramp)
                else:
                    benchmark_render(frame, frame_to_halfblock_ansi, iterations=30)
                
            target_time = start_time + i / args.fps
            now = time.monotonic()

            # If we are early, sleep until target time
            if now < target_time:
                time.sleep(target_time - now)
                now = time.monotonic()

            # If we are more than 2 frame intervals behind, drop formatting/writing
            if now > target_time + (2.0 / args.fps):
                frames_dropped += 1
            else:
                if args.style == "ascii":
                    rendered_str = frame_to_ascii_color(frame, ramp=args.ramp)
                else:
                    rendered_str = frame_to_halfblock_ansi(frame)
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
        # Restore default styling, cursor, clear screen, and home cursor on exit
        sys.stdout.write("\x1b[0m\x1b[?25h\x1b[2J\x1b[H")
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

