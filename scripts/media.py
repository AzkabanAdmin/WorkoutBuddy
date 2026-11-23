"""Screenshot helpers for the CurseForge page and README.

Needs Pillow (pip install pillow). Images are written to media/, which the
packager ignores, so they never ship inside the addon.

  python scripts/media.py collect [--minutes 120] [--wow "C:/Program Files (x86)/World of Warcraft"]
      Copy screenshots taken in the last N minutes, from every client's
      Screenshots folder, into media/_incoming/ (not committed).

  python scripts/media.py crop SRC OUT LEFT TOP RIGHT BOTTOM [--width 1200] [--scale 1]
      Crop a screenshot to a box (in source pixels), scale it down to at most
      --width pixels wide and save it as PNG or JPG by OUT's extension.

  python scripts/media.py gif OUT LEFT TOP RIGHT BOTTOM FRAME [FRAME ...] [--width 800] [--scale 1] [--ms 900] [--hold 2]
      Crop every frame to the same box and join them into a looping GIF.
      The first and last frames stay up --hold times longer.
"""

import argparse
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INCOMING = ROOT / "media" / "_incoming"
DEFAULT_WOW = Path("C:/Program Files (x86)/World of Warcraft")
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".tga"}


def need_pillow():
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        sys.exit("Pillow is missing. Run: pip install pillow")


def collect(args):
    wow = Path(args.wow)
    cutoff = time.time() - args.minutes * 60
    INCOMING.mkdir(parents=True, exist_ok=True)
    found = []
    for folder in sorted(wow.glob("_*_/Screenshots")):
        client = folder.parent.name.strip("_")
        for f in folder.iterdir():
            if f.suffix.lower() in IMAGE_EXT and f.stat().st_mtime >= cutoff:
                found.append((f.stat().st_mtime, client, f))
    for _, client, f in sorted(found):
        target = INCOMING / f"{client}_{f.name}"
        shutil.copy2(f, target)
        print(target)
    print(f"{len(found)} screenshot(s) copied to {INCOMING}")


def cropped(src, box, width, scale=1.0):
    from PIL import Image
    img = Image.open(src).convert("RGB").crop(tuple(box))
    if scale != 1.0:  # enlarge small UI crops so text stays readable on the page
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    if img.width > width:
        img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    return img


def crop(args):
    need_pillow()
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    img = cropped(args.src, args.box, args.width, args.scale)
    if out.suffix.lower() in {".jpg", ".jpeg"}:
        img.save(out, quality=90, optimize=True)
    else:
        img.save(out, optimize=True)
    print(f"{out} {img.width}x{img.height} {out.stat().st_size // 1024} KB")


def gif(args):
    need_pillow()
    frames = [cropped(f, args.box, args.width, args.scale) for f in args.frames]
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    durations = [args.ms] * len(frames)
    durations[0] = durations[-1] = args.ms * args.hold  # linger on the start and end
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)
    print(f"{out} {len(frames)} frames {frames[0].width}x{frames[0].height} {out.stat().st_size // 1024} KB")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("collect")
    c.add_argument("--minutes", type=int, default=120)
    c.add_argument("--wow", default=str(DEFAULT_WOW))
    c.set_defaults(fn=collect)

    k = sub.add_parser("crop")
    k.add_argument("src")
    k.add_argument("out")
    k.add_argument("box", nargs=4, type=int, metavar="LTRB")
    k.add_argument("--width", type=int, default=1200)
    k.add_argument("--scale", type=float, default=1.0)
    k.set_defaults(fn=crop)

    g = sub.add_parser("gif")
    g.add_argument("out")
    g.add_argument("box", nargs=4, type=int, metavar="LTRB")
    g.add_argument("frames", nargs="+")
    g.add_argument("--width", type=int, default=800)
    g.add_argument("--scale", type=float, default=1.0)
    g.add_argument("--ms", type=int, default=900)
    g.add_argument("--hold", type=int, default=2, help="first and last frames last this many times longer")
    g.set_defaults(fn=gif)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
