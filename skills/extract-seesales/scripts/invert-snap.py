"""Invert an anita-capture snap so dark-blue canvas text is readable."""
import os
import sys
from PIL import Image, ImageOps

name = sys.argv[1]
_cap_root = os.path.join(os.environ["LOCALAPPDATA"], "Temp", "anita-capture")
_label = (os.environ.get("ANITA_CAPTURE_LABEL") or "").strip()
cap = os.path.join(_cap_root, _label) if _label else _cap_root
out_dir = cap
prefix = os.path.splitext(os.path.basename(name))[0]
for arg in sys.argv[2:]:
    if arg.startswith("--out-dir="):
        out_dir = arg.split("=", 1)[1]
    elif arg.startswith("--prefix="):
        prefix = arg.split("=", 1)[1]
os.makedirs(out_dir, exist_ok=True)
stem = os.path.splitext(os.path.basename(name))[0]
for candidate in (name, stem + "-canvas.png"):
    path = os.path.join(cap, candidate)
    if not os.path.isfile(path):
        continue
    im = Image.open(path)
    if im.mode == "RGBA":
        rgb = Image.new("RGB", im.size, (0, 0, 0))
        rgb.paste(im, mask=im.split()[-1])
    else:
        rgb = im.convert("RGB")
    if candidate == name:
        out_name = prefix + "-inv.png"
    else:
        out_name = prefix + "-canvas-inv.png"
    out = os.path.join(out_dir, out_name)
    ImageOps.invert(rgb.convert("L")).save(out)
    print("invert", out_name, rgb.size)
