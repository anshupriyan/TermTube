import sys
import shutil
import subprocess
import yt_dlp

class YtDlpUpdatedError(Exception):
    """Raised when yt-dlp is updated and the process must be restarted."""
    pass

def update_yt_dlp() -> None:
    """Updates yt-dlp to the latest version via pip."""
    print("Updating yt-dlp to the latest version...", file=sys.stderr)
    try:
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-U", "yt-dlp"],
            check=True
        )
        print("yt-dlp updated successfully!", file=sys.stderr)
    except subprocess.CalledProcessError as e:
        print(f"Error updating yt-dlp: {e}", file=sys.stderr)
        raise

def _get_js_runtime_extractor_args() -> dict:
    """
    Checks if 'deno' is available on PATH.
    Returns extractor args configuration for yt-dlp to use deno for JavaScript execution.
    """
    if shutil.which("deno"):
        return {"youtube": {"js_runtimes": ["deno"]}}
    return {}

def resolve_streams(url: str) -> dict:
    """
    Uses yt_dlp.YoutubeDL to extract format information from the given URL.
    Selects the best video-only stream and best audio-only stream, preferring
    formats that ffmpeg can consume directly (e.g. mp4/webm for video, m4a/opus for audio).

    Returns a dict:
        {"video_url": str, "audio_url": str, "width": int, "height": int, "fps": float}
    """
    extractor_args = _get_js_runtime_extractor_args()
    if extractor_args:
        print("Using deno JS runtime for extraction", file=sys.stderr)
    else:
        print("No deno runtime found, using yt-dlp defaults", file=sys.stderr)

    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extractor_args': extractor_args,
    }
    if extractor_args:
        ydl_opts['remote_components'] = ['ejs:github']

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
    except yt_dlp.utils.DownloadError as e:
        print(f"Error resolving stream: {e}", file=sys.stderr)
        print("Attempting to auto-update yt-dlp to resolve the issue...", file=sys.stderr)
        try:
            update_yt_dlp()
            raise YtDlpUpdatedError("yt-dlp updated, please rerun the command")
        except Exception as update_err:
            if isinstance(update_err, YtDlpUpdatedError):
                raise
            # Re-raise original error if update failed
            raise e


    formats = info.get('formats', [])
    video_formats = []
    audio_formats = []

    for f in formats:
        vcodec = f.get('vcodec')
        acodec = f.get('acodec')
        url_str = f.get('url')
        
        if not url_str:
            continue

        # Check if video (vcodec is not None and not 'none')
        is_video = vcodec and vcodec.lower() != 'none'
        # Check if audio (acodec is not None and not 'none')
        is_audio = acodec and acodec.lower() != 'none'

        if is_video:
            video_formats.append(f)
        if is_audio:
            audio_formats.append(f)

    if not video_formats:
        raise ValueError("No video streams found for the given URL.")

    # Filter to video-only formats
    video_formats_only = []
    for f in video_formats:
        acodec = f.get('acodec')
        is_video_only = not acodec or acodec.lower() == 'none'
        if is_video_only:
            video_formats_only.append(f)

    # Fall back to all video formats if no video-only format is found
    target_formats = video_formats_only if video_formats_only else video_formats

    # Split into <= 720 and > 720 formats
    under_720 = []
    above_720 = []
    for f in target_formats:
        h = f.get('height') or 0
        if h <= 720:
            under_720.append(f)
        else:
            above_720.append(f)

    if under_720:
        # Closest to 720p but not exceeding (highest height first)
        # Sort descending: highest height, preferred container (mp4/webm), width, fps, tbr
        def under_key(f):
            height = f.get('height') or 0
            ext = (f.get('ext') or '').lower()
            is_preferred_ext = 1 if ext in ('mp4', 'webm') else 0
            width = f.get('width') or 0
            fps = f.get('fps') or 0.0
            tbr = f.get('tbr') or 0.0
            return (height, is_preferred_ext, width, fps, tbr)
        under_720.sort(key=under_key, reverse=True)
        best_video = under_720[0]
    else:
        # Fall back to lowest height above 720p
        # Sort ascending: lowest height, preferred container first (mp4/webm), then highest width/fps/tbr
        def above_key(f):
            height = f.get('height') or 99999
            ext = (f.get('ext') or '').lower()
            is_preferred_ext = -1 if ext in ('mp4', 'webm') else 0
            width = f.get('width') or 0
            fps = f.get('fps') or 0.0
            tbr = f.get('tbr') or 0.0
            return (height, is_preferred_ext, -width, -fps, -tbr)
        above_720.sort(key=above_key)
        best_video = above_720[0]

    # Sort audio formats descending:
    # 1. Audio-only streams (vcodec is None or 'none')
    # 2. Preferred containers (m4a, opus, mp3, webm, ogg)
    # 3. Bitrate (tbr, abr)
    best_audio = None
    if audio_formats:
        def audio_key(f):
            vcodec = f.get('vcodec')
            ext = (f.get('ext') or '').lower()
            is_audio_only = 1 if (not vcodec or vcodec.lower() == 'none') else 0
            is_preferred_ext = 1 if ext in ('m4a', 'opus', 'mp3', 'webm', 'ogg') else 0
            tbr = f.get('tbr') or 0.0
            abr = f.get('abr') or 0.0
            return (is_audio_only, is_preferred_ext, tbr, abr)

        audio_formats.sort(key=audio_key, reverse=True)
        best_audio = audio_formats[0]

    return {
        "video_url": best_video.get('url', ''),
        "audio_url": best_audio.get('url', '') if best_audio else '',
        "width": int(best_video.get('width') or 0),
        "height": int(best_video.get('height') or 0),
        "fps": float(best_video.get('fps') or 0.0),
        "headers": best_video.get('http_headers') or {}
    }
