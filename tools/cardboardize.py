"""Offline "cardboard-izer" for the monster sprite pack.

  python tools/cardboardize.py            # assets/monsters/*.png -> assets/beasts/*.png

For every sprite we keep, it adds a wobbly hand-cut paper rim and an ink
outline around the art, multiplies the picture with the wrinkled paper grain,
flattens the colours a little (like printed card), and shades the inner edge so
it reads as a thick cut-out. Sprites that do not fit the game (people, sci-fi,
suggestive art, illustration pages) are dropped and listed in
assets/beasts/MANIFEST.json with the reason. Needs Pillow and numpy.
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "monsters")
DST = os.path.join(ROOT, "assets", "beasts")
PAPER = os.path.join(ROOT, "assets", "paper", "wrinkled.jpg")

# (regex on the file stem, reason). First match wins.
DROP = [
    (r"succubus|demoness|mix_match|battler_woman|undead_girls|asp_girl|medusa|beachgoer|pixie", "suggestive or not a creature"),
    (r"^air_elemental_0[24]|^earth_elemental_01|^water_elemental_0[23]|^imp_", "female-figure or revealing art, dropped to keep the game family friendly"),
    (r"townsfolk|guard_|scout|pirate|sentry_0|dark_?elf|evil_elf|koboglins", "human or humanoid townsfolk, not a monster for this game"),
    (r"sci_?fi|scifi|spider_bot|War_Machine|beetle_mech|Float_Armour|evil_empire", "sci-fi, does not fit the setting"),
]

INK = np.array([44, 28, 16], dtype=np.float32)
RIM = np.array([238, 220, 178], dtype=np.float32)
SHADE = np.array([120, 90, 55], dtype=np.float32)


def blur_mask(a: np.ndarray, r: float) -> np.ndarray:
    im = Image.fromarray(a.astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im, dtype=np.float32)


def noise(shape, seed, scale):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, shape[0] // scale), max(2, shape[1] // scale))).astype(np.float32)
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((shape[1], shape[0]), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0 - 0.5


def dilate(alpha: np.ndarray, r: float, seed: int, wobble: float) -> np.ndarray:
    """Rounded grow by r px with a hand-cut wobble."""
    b = blur_mask(alpha, r * 0.75) / 255.0
    near = b > 0.06  # wobble only on the band around the art, never as stray islands
    b = b + noise(alpha.shape, seed, 9) * wobble * 0.5
    out = np.clip((b - 0.14) * 6.0, 0.0, 1.0) * near
    # drop any loose specks: keep only what touches the art's grown outline
    solid = blur_mask((alpha > 24).astype(np.float32) * 255.0, r * 1.4) > 40
    return out * solid


def process(path: str, out: str, paper: np.ndarray) -> tuple:
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if box is None:
        raise ValueError("empty sprite")
    im = im.crop(box)
    # normalise size: long side 256 keeps the pack small and consistent
    k = 256.0 / max(im.size)
    if k < 1.0 or max(im.size) < 160:
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    pad = 12
    canvas = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    canvas.paste(im, (pad, pad))
    arr = np.asarray(canvas, dtype=np.float32)
    h, w = arr.shape[:2]
    seed = abs(hash(os.path.basename(path))) % 100000
    a = arr[:, :, 3]

    # paper grain, tiled to size
    ty = np.tile(paper, (h // paper.shape[0] + 1, w // paper.shape[1] + 1))[:h, :w]
    grain = 0.86 + 0.18 * ty  # 0.86 .. 1.04

    rgb = arr[:, :, :3]
    # flatten a little: posterise to 20 levels, desaturate 12%
    rgb = np.round(rgb / 255.0 * 20.0) / 20.0 * 255.0
    gray = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * 0.88 + gray * 0.12
    rgb = np.clip(rgb * grain[:, :, None], 0, 255)

    # inner edge shade so the cut-out has body
    inner = 1.0 - np.clip(blur_mask((a > 127).astype(np.float32) * 255.0, 2.2) / 255.0, 0.0, 1.0)
    edge_in = np.clip((a / 255.0) * inner * 2.2, 0.0, 1.0)[:, :, None]
    rgb = rgb * (1.0 - 0.28 * edge_in) + SHADE * 0.28 * edge_in

    rim_a = dilate(a, 5.0, seed, 0.30)
    ink_a = dilate(a, 8.0, seed + 7, 0.42)
    art = (a / 255.0)[:, :, None]
    # layer: ink under rim under art
    out_rgb = INK[None, None, :] * ink_a[:, :, None]
    out_rgb = np.where(rim_a[:, :, None] > 0.02, RIM * (0.94 + 0.08 * ty[:, :, None]) * 1.0, out_rgb)
    out_rgb = out_rgb * (1 - art) + rgb * art
    out_a = np.maximum(ink_a, art[:, :, 0])
    res = np.dstack([np.clip(out_rgb, 0, 255), out_a * 255.0]).astype(np.uint8)
    img = Image.fromarray(res, "RGBA")
    bb = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if bb:
        img = img.crop(bb)
    img.save(out, optimize=True)
    return img.size


def main() -> None:
    os.makedirs(DST, exist_ok=True)
    for old in os.listdir(DST):
        if old.lower().endswith(".png"):
            os.remove(os.path.join(DST, old))
    paper_img = Image.open(PAPER).convert("L").resize((256, 256), Image.LANCZOS)
    paper = np.asarray(paper_img, dtype=np.float32) / 255.0
    paper = (paper - paper.min()) / max(1e-6, paper.max() - paper.min())
    manifest = {"kept": {}, "dropped": {}}
    for name in sorted(os.listdir(SRC)):
        if not name.lower().endswith(".png"):
            continue
        stem = os.path.splitext(name)[0]
        reason = None
        for rx, why in DROP:
            if re.search(rx, stem, re.I):
                reason = why
                break
        if reason:
            manifest["dropped"][name] = reason
            continue
        try:
            size = process(os.path.join(SRC, name), os.path.join(DST, name), paper)
            manifest["kept"][name] = list(size)
        except Exception as e:  # noqa: BLE001
            manifest["dropped"][name] = "failed: %s" % e
    for d in sorted(os.listdir(SRC)):
        if os.path.isdir(os.path.join(SRC, d)):
            manifest["dropped"][d + "/"] = "illustration sheets / painted battlers: not sprites for this game (and CC BY-NC)"
    with open(os.path.join(DST, "MANIFEST.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    print("kept %d, dropped %d" % (len(manifest["kept"]), len(manifest["dropped"])))


if __name__ == "__main__":
    sys.exit(main())
