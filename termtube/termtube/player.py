import shutil
import subprocess
import numpy as np

# Ensure ffmpeg and ffplay are available on the system PATH
if not shutil.which("ffmpeg"):
    raise RuntimeError("ffmpeg not found on PATH")
if not shutil.which("ffplay"):
    raise RuntimeError("ffplay not found on PATH")

def start_audio(audio_url: str, headers: dict = None) -> subprocess.Popen:
    """
    Launches ffplay as a subprocess to play the resolved audio stream directly.
    """
    if not shutil.which("ffplay"):
        raise RuntimeError("ffplay not found on PATH")

    headers_str = "".join(f"{k}: {v}\r\n" for k, v in headers.items()) if headers else ""
    cmd = ["ffplay"]
    if headers_str:
        cmd.extend(["-headers", headers_str])
    cmd.extend([
        "-reconnect", "1",
        "-reconnect_at_eof", "1",
        "-reconnect_streamed", "1",
        "-reconnect_delay_max", "5",
        "-i", audio_url,
        "-nodisp",
        "-autoexit",
        "-loglevel", "warning"
    ])
    return subprocess.Popen(
        cmd,
        shell=False,
        stderr=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        text=True
    )

def open_video_frame_pipe(video_url: str, width: int, height: int, fps: int, headers: dict = None) -> subprocess.Popen:
    """
    Launches ffmpeg as a subprocess to decode the video stream and pipe the raw RGB frames.

    Args:
        video_url: The direct URL of the video stream.
        width: Output target width of the frames.
        height: Output target height of the frames.
        fps: Target frame rate.
        headers: Optional HTTP headers dict.

    Returns:
        subprocess.Popen instance.
    """
    headers_str = "".join(f"{k}: {v}\r\n" for k, v in headers.items()) if headers else ""
    cmd = ["ffmpeg"]
    if headers_str:
        cmd.extend(["-headers", headers_str])
    cmd.extend([
        "-reconnect", "1",
        "-reconnect_at_eof", "1",
        "-reconnect_streamed", "1",
        "-reconnect_delay_max", "5",
        "-i", video_url,
        "-f", "rawvideo",
        "-pix_fmt", "rgb24",
        "-vf", f"scale={width}:{height}",
        "-r", str(fps),
        "-an",
        "-"
    ])

    return subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        bufsize=10**8  # Explicit 100MB buffer size to prevent stuttering/delay on raw reads
    )

def read_frame(proc: subprocess.Popen, width: int, height: int) -> np.ndarray | None:
    """
    Reads exactly width*height*3 bytes from proc.stdout.
    Returns None on EOF or short-read.
    Otherwise returns a (height, width, 3) uint8 numpy array.
    """
    frame_size = width * height * 3
    try:
        data = proc.stdout.read(frame_size)
    except Exception:
        return None

    if len(data) < frame_size:
        return None

    return np.frombuffer(data, dtype=np.uint8).reshape((height, width, 3))
