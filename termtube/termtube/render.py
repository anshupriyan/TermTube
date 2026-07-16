import sys
import time
import numpy as np

def frame_to_halfblock_ansi(frame: np.ndarray) -> str:
    """
    Converts a (H, W, 3) uint8 numpy array frame into a half-block terminal ANSI string.
    Each character cell represents two vertical pixels.
    """
    H, W, _ = frame.shape
    if H % 2 != 0:
        frame = np.pad(frame, ((0, 1), (0, 0), (0, 0)), mode='constant')
        H += 1

    top = frame[0::2]
    bottom = frame[1::2]

    # Pre-extract R, G, B channels to avoid lookup overhead in the loop
    tr, tg, tb = top[:, :, 0], top[:, :, 1], top[:, :, 2]
    br, bg, bb = bottom[:, :, 0], bottom[:, :, 1], bottom[:, :, 2]

    all_rows = []
    for y in range(H // 2):
        row_str = "".join([
            f"\x1b[38;2;{r};{g};{b}m\x1b[48;2;{br_};{bg_};{bb_}m▀"
            for r, g, b, br_, bg_, bb_ in zip(tr[y], tg[y], tb[y], br[y], bg[y], bb[y])
        ])
        all_rows.append(row_str + "\x1b[0m\n")

    return "\x1b[H" + "".join(all_rows)

def benchmark_render(frame: np.ndarray, render_fn, iterations: int = 30, **kwargs):
    """
    Measures rendering performance of the given render function over N iterations
    and prints metrics to sys.stderr.
    """
    t0 = time.perf_counter()
    for _ in range(iterations):
        _ = render_fn(frame, **kwargs)
    t1 = time.perf_counter()

    avg_ms = ((t1 - t0) * 1000.0) / iterations
    max_fps = 1000.0 / avg_ms if avg_ms > 0 else float('inf')

    print(
        f"Benchmark: {avg_ms:.2f} ms/frame (Max: {max_fps:.1f} FPS) over {iterations} iterations",
        file=sys.stderr
    )

def frame_to_ascii_color(frame: np.ndarray, ramp: str = " .:-=+*#%@") -> str:
    """
    Converts a (H, W, 3) uint8 numpy array frame into a colored ASCII density string.
    Luminance is calculated per pixel and mapped to characters in the ramp.
    """
    H, W, _ = frame.shape
    r_float = frame[:, :, 0].astype(float)
    g_float = frame[:, :, 1].astype(float)
    b_float = frame[:, :, 2].astype(float)
    
    # Standard weighted formula for luminance
    lum = 0.299 * r_float + 0.587 * g_float + 0.114 * b_float

    ramp_len = len(ramp)
    idx_arr = (lum * (ramp_len / 256.0)).astype(int)
    idx_arr = np.clip(idx_arr, 0, ramp_len - 1)

    r_uint8 = frame[:, :, 0]
    g_uint8 = frame[:, :, 1]
    b_uint8 = frame[:, :, 2]

    all_rows = []
    for y in range(H):
        row_str = "".join([
            f"\x1b[48;2;0;0;0m\x1b[38;2;{red};{green};{blue}m{ramp[idx]}"
            for red, green, blue, idx in zip(r_uint8[y], g_uint8[y], b_uint8[y], idx_arr[y])
        ])
        all_rows.append(row_str + "\x1b[0m\n")

    return "\x1b[H" + "".join(all_rows)
