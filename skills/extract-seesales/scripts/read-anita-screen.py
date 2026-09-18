"""Classify an AniTa canvas snap without an agent watching.

Prints one line: CLASS=text|form|empty KEYS=password,remove,iforms,menu,seesales,oneofone
Used by login-seesales.ps1. Invert is written next to the source png.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageOps

KEYS = (
    ("password", ("password", "enter password")),
    ("remove", ("remove?", "if remove", "currently exist")),
    ("iforms", ("iforms", "please log", "enter user", "log on")),
    ("menu", ("main menu", "hotkey", "hot key")),
    ("seesales", ("see sales", "seesales", "september", "month of")),
    ("invoicedisk", ("invoice disc", "invoice disk", "disc generation", "billing date", "disc format")),
    ("future", ("in the future", "invoice date is in the future")),
    ("committed", ("transaction complete", "posted and committed")),
    ("needaccount", ("must select an account", "select an account")),
    ("invaliduser", ("invalid username", "missing or invalid")),
    ("oneofone", ("1 of 1", "1of1")),
    ("companywide", ("company wide", "companywide", "company-wide")),
    ("done", ("see group prod done", "emailed to", "data export")),
    ("accountview", ("account view", "account of", "learflag")),
    ("groups", ("service group", "product for service")),
)


def _load_rgb(path: str) -> Image.Image:
    im = Image.open(path)
    if im.mode == "RGBA":
        rgb = Image.new("RGB", im.size, (0, 0, 0))
        rgb.paste(im, mask=im.split()[-1])
        return rgb
    return im.convert("RGB")


def _content(rgb: Image.Image) -> Image.Image:
    w, h = rgb.size
    top = 36 if h > 80 else 0
    return rgb.crop((0, top, w, max(top + 1, h - 8)))


def features(rgb: Image.Image) -> dict[str, float]:
    im = _content(rgb)
    w, h = im.size
    pix = im.load()
    white_rows = 0
    white_px = 0
    olive = 0
    cyan = 0
    green = 0
    for y in range(h):
        row_ink = 0
        for x in range(w):
            r, g, b = pix[x, y]
            if r > 210 and g > 210 and b > 210:
                row_ink += 1
                white_px += 1
            if 140 < r < 230 and 140 < g < 210 and b < 130:
                olive += 1
            if r < 130 and g > 170 and b > 170:
                cyan += 1
            if g > 140 and r < 90 and b < 90:
                green += 1
        if row_ink > 4:
            white_rows += 1
    n = float(w * h)
    return {
        "white_rows": float(white_rows),
        "white_px": float(white_px),
        "olive": olive / n,
        "cyan": cyan / n,
        "green": green / n,
        "n": n,
    }


def classify(rgb: Image.Image) -> str:
    f = features(rgb)
    if f["n"] < 100:
        return "empty"
    if f["olive"] > 0.003:
        return "form"
    if f["white_px"] > 1800 or f["green"] > 0.0003:
        return "form"
    if f["white_px"] < 400 and f["white_rows"] < 1:
        return "empty"
    # Sparse white glyphs: Linux login: or IFORMS Please Log On.
    if f["white_rows"] <= 10:
        return "logon"
    return "text"


def keywords(rgb: Image.Image) -> list[str]:
    f = features(rgb)
    found: list[str] = []
    if f["olive"] > 0.003:
        found.append("menu")
    if f["white_rows"] >= 35 and f["white_px"] > 2800:
        found.append("groups")
    if f["green"] > 0.0003 or (f["white_px"] > 1400 and f["olive"] > 0.0004 and f["white_rows"] >= 7):
        found.append("seesales")
    if f["white_rows"] >= 22 and f["olive"] < 0.002:
        found.append("remove")
    if (
        f["white_rows"] <= 6
        and f["olive"] < 0.002
        and f["white_px"] >= 400
        and "seesales" not in found
    ):
        found.append("iforms")
    if f["cyan"] > 0.001 and f["white_rows"] <= 12:
        found.append("invaliduser")
    inv = ImageOps.invert(ImageOps.autocontrast(rgb.convert("L")))
    text = ""
    try:
        import pytesseract  # type: ignore

        text = pytesseract.image_to_string(inv) or ""
    except Exception:
        text = ""
    blob = " ".join(text.lower().split())
    for name, needles in KEYS:
        if name not in found and any(n in blob for n in needles):
            found.append(name)
    return found


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: read-anita-screen.py <snap.png>", file=sys.stderr)
        return 2
    cap = os.path.join(os.environ["LOCALAPPDATA"], "Temp", "anita-capture")
    name = sys.argv[1]
    path = name if os.path.isabs(name) else os.path.join(cap, name)
    canvas = os.path.join(cap, os.path.splitext(os.path.basename(path))[0] + "-canvas.png")
    src = canvas if os.path.isfile(canvas) else path
    rgb = _load_rgb(src)
    kind = classify(rgb)
    keys = keywords(rgb)
    inv_path = os.path.join(cap, os.path.splitext(os.path.basename(src))[0] + "-inv.png")
    ImageOps.invert(rgb.convert("L")).save(inv_path)
    print(f"CLASS={kind} KEYS={','.join(keys) if keys else '-'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
