"""Builds the launch videos from clips recorded with Godot's movie writer.

  python tools/edit_launch.py CLIPDIR OUTDIR

Writes pennyfold_full_clean.mp4, pennyfold_full_subs.mp4 (burned-in captions
that match launch/VOICEOVER.md) and pennyfold_trailer.mp4 (fast flash cuts).
Needs ffmpeg on PATH or in FFMPEG. Everything shown is the real game.
"""
import os
import subprocess
import sys

FF = os.environ.get("FFMPEG", "ffmpeg")
FONT = "C\\:/Windows/Fonts/arialbd.ttf"
W, H = 1920, 1080
clips, out = sys.argv[1], sys.argv[2]
tmp = os.path.join(out, "_tmp")
os.makedirs(tmp, exist_ok=True)


def run(args):
    r = subprocess.run([FF, "-v", "error", "-y"] + args, capture_output=True, text=True)
    if r.returncode:
        print(r.stderr)
        raise SystemExit(1)


def seg(name, clip, start, dur):
    """One scaled, silent segment cut from a recorded clip."""
    p = os.path.join(tmp, name + ".mp4")
    src = os.path.join(clips, clip + ".avi")
    if not os.path.exists(src):
        return None
    run(["-ss", str(start), "-t", str(dur), "-i", src, "-vf", f"scale={W}:{H}:flags=lanczos,fps=30,setsar=1",
         "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "17", p])
    return p


def card(name, text, dur, size=72, bg="0x2b1d12", fg="0xf3e3bf"):
    p = os.path.join(tmp, name + ".mp4")
    tf = os.path.join(tmp, name + ".txt")
    open(tf, "w", encoding="utf-8").write(text)
    tfe = tf.replace("\\", "/").replace(":", "\\:")
    vf = (f"drawtext=fontfile='{FONT}':textfile='{tfe}':fontcolor={fg}:fontsize={size}:line_spacing=18:"
          f"x=(w-text_w)/2:y=(h-text_h)/2,fade=t=in:st=0:d=0.4,fade=t=out:st={dur-0.4}:d=0.4")
    run(["-f", "lavfi", "-i", f"color=c={bg}:s={W}x{H}:d={dur}:r=30", "-vf", vf, "-c:v", "libx264", "-pix_fmt", "yuv420p", p])
    return p


def join(parts, dest, captions=None):
    lst = os.path.join(tmp, "list.txt")
    open(lst, "w").write("".join(f"file '{p.replace(chr(92), '/')}'\n" for p in parts if p))
    vf = []
    if captions:
        for i, (a, b, t) in enumerate(captions):
            cf = os.path.join(tmp, f"cap{i}.txt")
            open(cf, "w", encoding="utf-8").write(t)
            cfe = cf.replace("\\", "/").replace(":", "\\:")
            vf.append(f"drawtext=fontfile='{FONT}':textfile='{cfe}':fontcolor=white:fontsize=46:borderw=4:bordercolor=black:"
                      f"line_spacing=8:x=(w-text_w)/2:y=h-170:enable='between(t,{a},{b})'")
    args = ["-f", "concat", "-safe", "0", "-i", lst, "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo"]
    if vf:
        args += ["-vf", ",".join(vf)]
    run(args + ["-shortest", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-c:a", "aac", dest])


# ---- the full cut (about 51 s) ----
T = 0.9  # skip the first moments of each clip (the scene is still settling)
full = [
    card("p1", "In most game economies,\ngold is printed from nothing.\n\nPrices inflate. Loot loses meaning.\nNobody can check the books.", 8),
    seg("title", "c01_title", T, 3),
    seg("creator", "c02_creator", T, 4),
    seg("town", "c03_town", T, 4),
    seg("shop", "c05_shop", T, 3),
    seg("talk", "c07_talk", T, 3),
    seg("fight", "c04_fight", T, 5),
    seg("gear", "c08_gear", T, 2),
    seg("dragon", "c06_dragon", T, 5),
    seg("guard", "c09_guard", T, 3),
    seg("merch", "c10_merch", T, 3),
    card("end", "Pennyfold\n\nEvery coin conserved.\nSettled on NEAR testnet.\n\nNEAR Hackathon: Games With Real Economies", 8, 64),
]
caps = [
    (0.3, 7.7, "In most game economies, gold is printed from nothing.\nPrices inflate, loot loses meaning,\nand nobody can check the books."),
    (8.2, 11.5, "Pennyfold: a cardboard town\nwhere every coin is conserved."),
    (11.5, 14.8, "Make a hero, roll the dice for bonus points."),
    (15.2, 18.8, "Townsfolk have wallets, jobs and schedules."),
    (19.2, 21.8, "Buy bread, and the baker's till rises\nby exactly what you paid."),
    (22.2, 24.8, "Ask a shopkeeper for their goods\nand they walk you there."),
    (25.2, 29.8, "Monsters drop gold paid from the town treasury,\nnever printed."),
    (30.2, 32.0, "Spend it at the armoury:\nthe coins go into the till."),
    (32.4, 36.8, "Learn skills, even a paper dragon."),
    (37.2, 42.8, "Guards earn bounties from the same treasury.\nMerchants chase price gaps between four towns."),
    (43.4, 50.5, "Every night, the day's net flows settle on NEAR testnet.\nOpen the explorer and check every coin."),
]
join(full, os.path.join(out, "pennyfold_full_clean.mp4"))
join(full, os.path.join(out, "pennyfold_full_subs.mp4"), caps)

# ---- the trailer: flashes of different scenes (about 20 s) ----
quick = [
    ("c01_title", 1.2, 1.3), ("c03_town", 1.5, 1.2), ("c04_fight", 1.5, 1.2), ("c06_dragon", 2.0, 1.3),
    ("c08_gear", 0.8, 0.9), ("c05_shop", 1.2, 1.0), ("c09_guard", 1.0, 1.0), ("c10_merch", 1.0, 1.0),
    ("c02_creator", 1.2, 1.0), ("c07_talk", 1.0, 1.0), ("c04_fight", 3.0, 1.2), ("c06_dragon", 3.5, 1.4),
]
tr = [card("t0", "Every coin\nis real.", 2.2, 110)]
for i, (c, s, d) in enumerate(quick):
    tr.append(seg(f"q{i}", c, s, d))
tr.append(card("t1", "PENNYFOLD\nDon't fold under pressure.", 3.5, 100, "0xf2c230", "0x2b1d12"))
join(tr, os.path.join(out, "pennyfold_trailer.mp4"))
print("done:", os.listdir(out))
