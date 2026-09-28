import sys
import time
import numpy as np

# Preset character ramps for diverse visual styles
CHARACTER_PRESETS = {
    # 1. Binary & Matrix (requested: 0101 characters)
    "binary": " 01",
    "binary_0101": " 0101",
    "binary_dense": "01",
    "matrix": " 0123456789$+-*/=%",
    
    # 2. Block Shades & Geometrics (vivid contrast & smooth lighting gradient)
    "shades": " ░▒▓█",
    "blocks": " ▏▎▍▌▋▊▉█",
    "quadrants": " ▖▗▘▝▌▐▄▀█",
    
    # 3. High-Contrast & Vivid Light
    "highcontrast": "  ··::!!**##%%@@██",
    "contrast_lite": " ·:+*#%@█",
    "glow": "  ..::**##██",
    
    # 4. Braille & Dots (aesthetic delicate matrix)
    "braille": " ⠀⠁⠃⠇⡇⣇⣧⣷⣿",
    "dots": " ·•○●█",
    "minimal": " .oO@",
    
    # 5. Classic & Detailed
    "ascii": " .:-=+*#%@",
    "detailed": " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$",
    "math": " ·÷±×∑∏∆∇∞█",
    "slashes": " ·/|\\#█",
}

# Lookup table for 2x2 quadrant block rendering (16 combinations)
QUAD_CHARS = np.array([' ', '▘', '▝', '▀', '▖', '▌', '▞', '▛', '▗', '▚', '▐', '▜', '▄', '▙', '▟', '█'])

# Lookup table for 2x4 Braille dot rendering (256 combinations)
BRAILLE_CHARS = np.array([chr(0x2800 + i) for i in range(256)])

def process_lighting_and_contrast(
    frame: np.ndarray,
    contrast: float = 1.0,
    brightness: float = 0.0,
    gamma: float = 1.0,
    auto_contrast: bool = False,
    light_boost: float = 0.0,
    color_mode: str = "rgb"
) -> tuple[np.ndarray, np.ndarray]:
    """
    Applies lighting, contrast curve, auto-contrast stretching, and color mode mapping.
    Returns:
        norm_lum: (H, W) float array normalized in [0.0, 1.0] for character selection.
        processed_rgb: (H, W, 3) uint8 array of colors for terminal ANSI escape codes.
    """
    H, W, _ = frame.shape
    r = frame[:, :, 0].astype(float)
    g = frame[:, :, 1].astype(float)
    b = frame[:, :, 2].astype(float)

    lum = 0.299 * r + 0.587 * g + 0.114 * b

    if auto_contrast:
        p_low = float(np.percentile(lum, 1.0))
        p_high = float(np.percentile(lum, 99.0))
        if p_high > p_low:
            lum = np.clip((lum - p_low) / (p_high - p_low) * 255.0, 0.0, 255.0)

    norm_lum = np.clip(lum / 255.0, 0.0, 1.0)
    if gamma != 1.0 and gamma > 0:
        norm_lum = norm_lum ** (1.0 / gamma)
    if contrast != 1.0 or brightness != 0.0:
        norm_lum = np.clip((norm_lum - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0)

    if color_mode == "matrix":
        r_out = np.zeros_like(r, dtype=np.uint8)
        g_out = np.clip(norm_lum * 255.0 * (1.0 + light_boost), 0, 255).astype(np.uint8)
        b_out = np.clip(norm_lum * 50.0, 0, 255).astype(np.uint8)
    elif color_mode == "amber":
        r_out = np.clip(norm_lum * 255.0 * (1.0 + light_boost), 0, 255).astype(np.uint8)
        g_out = np.clip(norm_lum * 175.0 * (1.0 + light_boost), 0, 255).astype(np.uint8)
        b_out = np.zeros_like(b, dtype=np.uint8)
    elif color_mode == "cyberpunk":
        r_out = np.clip((norm_lum * 220.0 + 35.0) * (1.0 + light_boost), 0, 255).astype(np.uint8)
        g_out = np.clip(((1.0 - norm_lum) * 200.0) * (1.0 + light_boost), 0, 255).astype(np.uint8)
        b_out = np.clip((norm_lum * 255.0 + 50.0) * (1.0 + light_boost), 0, 255).astype(np.uint8)
    elif color_mode == "gray":
        gray_val = np.clip(norm_lum * 255.0 * (1.0 + light_boost), 0, 255).astype(np.uint8)
        r_out = gray_val
        g_out = gray_val
        b_out = gray_val
    elif color_mode == "fire":
        r_out = np.clip(norm_lum * 3.0 * 255.0, 0, 255).astype(np.uint8)
        g_out = np.clip((norm_lum - 0.33) * 3.0 * 255.0, 0, 255).astype(np.uint8)
        b_out = np.clip((norm_lum - 0.66) * 3.0 * 255.0, 0, 255).astype(np.uint8)
    elif color_mode == "glitch":
        # Multicolor Chromatic Aberration & VHS Glitch Split
        r_shift = np.roll(r, -2, axis=1)
        b_shift = np.roll(b, 2, axis=1)
        row_idx = np.arange(H)[:, None]
        glitch_rows = (row_idx % 7 == 0) | (row_idx % 19 == 0)
        r_glitch = np.where(glitch_rows, np.roll(r_shift, 4, axis=1), r_shift)
        b_glitch = np.where(glitch_rows, np.roll(b_shift, -4, axis=1), b_shift)

        col_phase = np.linspace(0, 10 * np.pi, W)[None, :]
        fringe_r = np.sin(col_phase) * 45.0
        fringe_b = np.cos(col_phase) * 45.0
        fringe_g = np.sin(col_phase + np.pi / 2.0) * 30.0

        r_out = np.clip((r_glitch + fringe_r) * (1.0 + light_boost), 0, 255).astype(np.uint8)
        g_out = np.clip((g + fringe_g) * (1.0 + light_boost), 0, 255).astype(np.uint8)
        b_out = np.clip((b_glitch + fringe_b) * (1.0 + light_boost), 0, 255).astype(np.uint8)
    elif color_mode == "rainbow":
        # Psychedelic multicolor neon spectrum mapped across luminance
        phase = norm_lum * 2.0 * np.pi
        r_out = np.clip((np.sin(phase) * 127.0 + 128.0) * (1.0 + light_boost), 0, 255).astype(np.uint8)
        g_out = np.clip((np.sin(phase + 2.094) * 127.0 + 128.0) * (1.0 + light_boost), 0, 255).astype(np.uint8)
        b_out = np.clip((np.sin(phase + 4.188) * 127.0 + 128.0) * (1.0 + light_boost), 0, 255).astype(np.uint8)
    else:  # rgb
        if contrast != 1.0 or brightness != 0.0 or gamma != 1.0 or light_boost > 0.0 or auto_contrast:
            scale = (norm_lum * 255.0) / np.maximum(lum, 1e-3) * (1.0 + light_boost)
            r_out = np.clip(r * scale, 0, 255).astype(np.uint8)
            g_out = np.clip(g * scale, 0, 255).astype(np.uint8)
            b_out = np.clip(b * scale, 0, 255).astype(np.uint8)
        else:
            r_out = frame[:, :, 0]
            g_out = frame[:, :, 1]
            b_out = frame[:, :, 2]

    processed_rgb = np.stack([r_out, g_out, b_out], axis=2)
    return norm_lum, processed_rgb

def frame_to_halfblock_ansi(
    frame: np.ndarray,
    contrast: float = 1.0,
    brightness: float = 0.0,
    gamma: float = 1.0,
    auto_contrast: bool = False,
    light_boost: float = 0.0,
    color_mode: str = "rgb",
    **kwargs
) -> str:
    """
    Converts a (H, W, 3) uint8 numpy array frame into a half-block terminal ANSI string.
    Each character cell represents two vertical pixels (1x2 blocks).
    """
    H, W, _ = frame.shape
    if H % 2 != 0:
        frame = np.pad(frame, ((0, 1), (0, 0), (0, 0)), mode='constant')
        H += 1

    if contrast != 1.0 or brightness != 0.0 or gamma != 1.0 or auto_contrast or light_boost > 0.0 or color_mode != "rgb":
        _, frame = process_lighting_and_contrast(
            frame, contrast, brightness, gamma, auto_contrast, light_boost, color_mode
        )

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

def frame_to_fullblock_ansi(
    frame: np.ndarray,
    contrast: float = 1.0,
    brightness: float = 0.0,
    gamma: float = 1.0,
    auto_contrast: bool = False,
    light_boost: float = 0.0,
    color_mode: str = "rgb",
    **kwargs
) -> str:
    """
    Converts a (H, W, 3) uint8 numpy array frame into chunky 1x1 full block ('█') ANSI string.
    """
    H, W, _ = frame.shape
    if contrast != 1.0 or brightness != 0.0 or gamma != 1.0 or auto_contrast or light_boost > 0.0 or color_mode != "rgb":
        _, frame = process_lighting_and_contrast(
            frame, contrast, brightness, gamma, auto_contrast, light_boost, color_mode
        )

    r = frame[:, :, 0]
    g = frame[:, :, 1]
    b = frame[:, :, 2]

    all_rows = []
    for y in range(H):
        row_str = "".join([
            f"\x1b[38;2;{red};{green};{blue}m█"
            for red, green, blue in zip(r[y], g[y], b[y])
        ])
        all_rows.append(row_str + "\x1b[0m\n")

    return "\x1b[H" + "".join(all_rows)

def frame_to_quadblock_ansi(
    frame: np.ndarray,
    contrast: float = 1.0,
    brightness: float = 0.0,
    gamma: float = 1.0,
    auto_contrast: bool = False,
    light_boost: float = 0.0,
    color_mode: str = "rgb",
    **kwargs
) -> str:
    """
    Converts a (H, W, 3) uint8 numpy array frame into a 2x2 quadrant subpixel ANSI string.
    Each character cell represents a 2x2 grid of pixels using quadrant characters.
    """
    H, W, _ = frame.shape
    pad_h = H % 2
    pad_w = W % 2
    if pad_h or pad_w:
        frame = np.pad(frame, ((0, pad_h), (0, pad_w), (0, 0)), mode='constant')
        H += pad_h
        W += pad_w

    norm_lum, frame = process_lighting_and_contrast(
        frame, contrast, brightness, gamma, auto_contrast, light_boost, color_mode
    )

    tl_lum = norm_lum[0::2, 0::2]
    tr_lum = norm_lum[0::2, 1::2]
    bl_lum = norm_lum[1::2, 0::2]
    br_lum = norm_lum[1::2, 1::2]

    avg_lum = (tl_lum + tr_lum + bl_lum + br_lum) * 0.25

    m0 = (tl_lum >= avg_lum).astype(int)
    m1 = (tr_lum >= avg_lum).astype(int)
    m2 = (bl_lum >= avg_lum).astype(int)
    m3 = (br_lum >= avg_lum).astype(int)

    mask = m0 | (m1 << 1) | (m2 << 2) | (m3 << 3)

    tl = frame[0::2, 0::2].astype(float)
    tr = frame[0::2, 1::2].astype(float)
    bl = frame[1::2, 0::2].astype(float)
    br = frame[1::2, 1::2].astype(float)

    fg_weights = np.maximum((m0 + m1 + m2 + m3)[:, :, None], 1)
    fg_rgb = ((tl * m0[:, :, None] + tr * m1[:, :, None] + bl * m2[:, :, None] + br * m3[:, :, None]) / fg_weights).astype(np.uint8)

    bg_m0 = 1 - m0
    bg_m1 = 1 - m1
    bg_m2 = 1 - m2
    bg_m3 = 1 - m3
    bg_weights = np.maximum((bg_m0 + bg_m1 + bg_m2 + bg_m3)[:, :, None], 1)
    bg_rgb = ((tl * bg_m0[:, :, None] + tr * bg_m1[:, :, None] + bl * bg_m2[:, :, None] + br * bg_m3[:, :, None]) / bg_weights).astype(np.uint8)

    chars = QUAD_CHARS[mask]
    cell_H, cell_W = chars.shape

    all_rows = []
    for y in range(cell_H):
        row_str = "".join([
            f"\x1b[38;2;{fr};{fg};{fb}m\x1b[48;2;{br_};{bg_};{bb_}m{ch}"
            for fr, fg, fb, br_, bg_, bb_, ch in zip(
                fg_rgb[y, :, 0], fg_rgb[y, :, 1], fg_rgb[y, :, 2],
                bg_rgb[y, :, 0], bg_rgb[y, :, 1], bg_rgb[y, :, 2],
                chars[y]
            )
        ])
        all_rows.append(row_str + "\x1b[0m\n")

    return "\x1b[H" + "".join(all_rows)

def frame_to_braille_ansi(
    frame: np.ndarray,
    contrast: float = 1.0,
    brightness: float = 0.0,
    gamma: float = 1.0,
    auto_contrast: bool = False,
    light_boost: float = 0.0,
    color_mode: str = "rgb",
    **kwargs
) -> str:
    """
    Converts a (H, W, 3) uint8 numpy array frame into a 2x4 Braille dot matrix ANSI string.
    Each character cell represents a 2x4 grid of dots (8 dots total).
    """
    H, W, _ = frame.shape
    pad_h = (4 - (H % 4)) % 4
    pad_w = (2 - (W % 2)) % 2
    if pad_h or pad_w:
        frame = np.pad(frame, ((0, pad_h), (0, pad_w), (0, 0)), mode='constant')
        H += pad_h
        W += pad_w

    norm_lum, frame = process_lighting_and_contrast(
        frame, contrast, brightness, gamma, auto_contrast, light_boost, color_mode
    )

    # 4 rows x 2 cols per Braille cell
    d0 = (norm_lum[0::4, 0::2] > 0.42).astype(int)
    d1 = (norm_lum[1::4, 0::2] > 0.42).astype(int)
    d2 = (norm_lum[2::4, 0::2] > 0.42).astype(int)
    d3 = (norm_lum[0::4, 1::2] > 0.42).astype(int)
    d4 = (norm_lum[1::4, 1::2] > 0.42).astype(int)
    d5 = (norm_lum[2::4, 1::2] > 0.42).astype(int)
    d6 = (norm_lum[3::4, 0::2] > 0.42).astype(int)
    d7 = (norm_lum[3::4, 1::2] > 0.42).astype(int)

    code = d0 | (d1 << 1) | (d2 << 2) | (d3 << 3) | (d4 << 4) | (d5 << 5) | (d6 << 6) | (d7 << 7)
    chars = BRAILLE_CHARS[code]

    # Average cell color for foreground
    cr = (frame[0::4, 0::2, 0].astype(int) + frame[2::4, 1::2, 0].astype(int)) // 2
    cg = (frame[0::4, 0::2, 1].astype(int) + frame[2::4, 1::2, 1].astype(int)) // 2
    cb = (frame[0::4, 0::2, 2].astype(int) + frame[2::4, 1::2, 2].astype(int)) // 2

    cell_H, cell_W = chars.shape
    all_rows = []
    for y in range(cell_H):
        row_str = "".join([
            f"\x1b[38;2;{red};{green};{blue}m{ch}"
            for red, green, blue, ch in zip(cr[y], cg[y], cb[y], chars[y])
        ])
        all_rows.append(row_str + "\x1b[0m\n")

    return "\x1b[H" + "".join(all_rows)

def frame_to_ascii_color(
    frame: np.ndarray,
    ramp: str = " .:-=+*#%@",
    contrast: float = 1.0,
    brightness: float = 0.0,
    gamma: float = 1.0,
    auto_contrast: bool = False,
    light_boost: float = 0.0,
    color_mode: str = "rgb",
    invert: bool = False,
    **kwargs
) -> str:
    """
    Converts a (H, W, 3) uint8 numpy array frame into a colored ASCII density string.
    Luminance is calculated per pixel and mapped to characters in the ramp with full
    contrast, brightness, gamma, auto-contrast stretching, and color mode enhancements.
    """
    H, W, _ = frame.shape
    if invert and ramp:
        ramp = ramp[::-1]

    norm_lum, processed_rgb = process_lighting_and_contrast(
        frame, contrast, brightness, gamma, auto_contrast, light_boost, color_mode
    )

    ramp_len = len(ramp)
    idx_arr = np.clip((norm_lum * (ramp_len - 1) + 0.5).astype(int), 0, ramp_len - 1)

    r_uint8 = processed_rgb[:, :, 0]
    g_uint8 = processed_rgb[:, :, 1]
    b_uint8 = processed_rgb[:, :, 2]

    all_rows = []
    for y in range(H):
        row_str = "".join([
            f"\x1b[48;2;0;0;0m\x1b[38;2;{red};{green};{blue}m{ramp[idx]}"
            for red, green, blue, idx in zip(r_uint8[y], g_uint8[y], b_uint8[y], idx_arr[y])
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
