"""Build an installable WorkoutBuddy zip, like CurseForge's packager does.

Usage:  python scripts/build_zip.py 2.1.0 [output_dir]

Reads the ignore list from .pkgmeta, skips dot-files, replaces
@project-version@ with the given version, and writes
WorkoutBuddy-<version>.zip with a single top-level WorkoutBuddy folder.
Uses only the Python standard library.
"""
import fnmatch
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = "WorkoutBuddy"
TEXT_EXT = {".lua", ".toc", ".xml", ".txt", ".md"}


def read_ignores():
    ignores, in_ignore = [], False
    with open(os.path.join(ROOT, ".pkgmeta"), encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if not line.startswith((" ", "\t", "-")):
                in_ignore = stripped.startswith("ignore:")
                continue
            if in_ignore and stripped.startswith("-"):
                ignores.append(stripped[1:].strip().strip("\"'"))
    return ignores + ["scripts"]


def ignored(rel, ignores):
    parts = rel.split("/")
    if any(p.startswith(".") for p in parts) or "node_modules" in parts:
        return True
    return any(rel == pat or rel.startswith(pat.rstrip("/") + "/") or fnmatch.fnmatch(rel, pat)
               for pat in ignores)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    version = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "dist")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{PACKAGE}-{version}.zip")
    ignores = read_ignores()
    count = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for folder, dirs, files in os.walk(ROOT):
            dirs.sort()
            rel_dir = os.path.relpath(folder, ROOT).replace(os.sep, "/")
            dirs[:] = [d for d in dirs
                       if not ignored(d if rel_dir == "." else f"{rel_dir}/{d}", ignores) and d != "dist"]
            for name in sorted(files):
                rel = name if rel_dir == "." else f"{rel_dir}/{name}"
                if ignored(rel, ignores) or name.endswith(".zip"):
                    continue
                path = os.path.join(folder, name)
                arc = f"{PACKAGE}/{rel}"
                if os.path.splitext(name)[1].lower() in TEXT_EXT:
                    with open(path, encoding="utf-8") as f:
                        data = f.read().replace("@project-version@", version)
                    z.writestr(arc, data.encode("utf-8"))
                else:
                    z.write(path, arc)
                count += 1
    print(f"Wrote {out} ({count} files)")


if __name__ == "__main__":
    main()
