"""Generate the KKSN app icon source from the phone reference image.

Reads the app icon out of `flutter_01.png`, recovers the white rocket as an
alpha mask and the blue background as a diagonal gradient, then writes a
single 1024x1024 RGB source:

  assets/icon/app_icon.png   1024x1024 RGB, full-bleed, no alpha

That one file feeds both `flutter_launcher_icons` and `flutter_native_splash`.

Then run, in this order (not concurrently -- the generators read the file this
script writes):

    python tool/generate_launcher_icon.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

Requires: pip install pillow
"""
import os
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "flutter_01.png")
ICON_DIR = os.path.join(ROOT, "assets", "icon")

# ---------------------------------------------------------------- reference ---
L, T, R, B = 280, 525, 439, 684      # app-icon square inside the mockup
cs = R - L + 1
ref = Image.open(REF).convert("RGB")
cp = ref.crop((L, T, R + 1, B + 1)).load()

SIZE = 1024

# ------------------------------------------------------- blue diagonal ramp ---
# The reference background is a smooth diagonal gradient. Least-squares over
# this tiny crop cancels catastrophically, so read the colour directly at the
# mid-points of each edge (the rounded corners put the sampled points clear of
# the corner arcs) and lerp along the x+y axis.
MID = cs // 2
c_top = cp[MID, 4]
c_bot = cp[MID, cs - 5]
c_left = cp[4, MID]
c_right = cp[cs - 5, MID]
print("edge colours  top", c_top, "bottom", c_bot,
      "left", c_left, "right", c_right)

# average the two ways of measuring each end of the ramp
lo = tuple((c_top[i] + c_left[i]) / 2.0 for i in range(3))
hi = tuple((c_bot[i] + c_right[i]) / 2.0 for i in range(3))
print("ramp lo", tuple(round(v) for v in lo), "hi", tuple(round(v) for v in hi))

# lo sits at x+y = MID, hi at x+y = MID + cs  ->  rebase onto the output size
S_LO = MID
S_HI = MID + cs


def gradient(size):
    """Linear diagonal blue gradient matching the reference."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    scale = size / cs
    s_lo, s_hi = S_LO * scale, S_HI * scale
    for y in range(size):
        for x in range(size):
            t = ((x + y) - s_lo) / (s_hi - s_lo)
            t = 0.0 if t < 0 else (1.0 if t > 1 else t)
            px[x, y] = (
                int(lo[0] + (hi[0] - lo[0]) * t),
                int(lo[1] + (hi[1] - lo[1]) * t),
                int(lo[2] + (hi[2] - lo[2]) * t),
            )
    return img


# ------------------------------------------------- extract the rocket shape ---
# Alpha from the red channel: background ~48, rocket ~255. Inset the sampling
# window so the rounded corners' white background cannot leak into the mask.
INSET = 42
R_BLUE, SPAN = 48.0, 255.0 - 48.0
mask = Image.new("L", (cs, cs), 0)
mp = mask.load()
for y in range(INSET, cs - INSET):
    for x in range(INSET, cs - INSET):
        a = (cp[x, y][0] - R_BLUE) / SPAN
        if a > 0.02:
            mp[x, y] = int(min(1.0, a) * 255)

# Upscale to full size and steepen the contrast curve to recover crisp,
# vector-like edges after the 6.4x magnification.
rocket = mask.resize((SIZE, SIZE), Image.LANCZOS)
px = rocket.load()
SHARP = 3.2
for y in range(SIZE):
    for x in range(SIZE):
        v = px[x, y] / 255.0
        px[x, y] = int(max(0.0, min(1.0, (v - 0.5) * SHARP + 0.5)) * 255)
rocket = rocket.filter(ImageFilter.GaussianBlur(0.7))

# measure the rocket inside the 1024 canvas
rp = rocket.load()
rx0, ry0, rx1, ry1 = SIZE, SIZE, 0, 0
for y in range(SIZE):
    for x in range(SIZE):
        if rp[x, y] > 128:
            rx0, ry0 = min(rx0, x), min(ry0, y)
            rx1, ry1 = max(rx1, x), max(ry1, y)
print(f"rocket bbox in 1024: {rx0},{ry0} - {rx1},{ry1} "
      f"(w {rx1-rx0+1}, h {ry1-ry0+1})")

# --------------------------------------------------------------- app_icon.png --
# iOS and desktop platforms apply their own rounded mask on top of the icon, so
# the source must be a full-bleed square with NO rounding baked in and NO alpha.
# Baking the mockup's corners in here would double-round on iOS and leave
# transparent notches outside the mask.
icon = gradient(SIZE)
icon.paste((255, 255, 255), (0, 0), rocket)
icon_path = os.path.join(ICON_DIR, "app_icon.png")
icon.save(icon_path)

# verify the result actually contains the rocket (not a flat blue square)
colours = icon.convert("RGB").getcolors(maxcolors=1 << 24)
white = sum(n for n, c in colours if min(c) > 200)
print("wrote", icon_path, icon.size, icon.mode)
print("  distinct colours", len(colours), "| near-white px", white)
assert white > 20_000, "app_icon.png has no rocket!"
