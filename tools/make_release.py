"""Builds release/Leproc-<version>.zip from the committed addon files.

The version comes from ## Version in Leproc/Leproc.toc. Only files tracked by git under Leproc/
go in, so the zip matches what's committed (Build.lua is the empty one: releases carry no build
stamp). The zip holds the Leproc folder at its top level, as players unzip it into AddOns.
Run from anywhere: python3 tools/make_release.py
"""
import pathlib
import re
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main():
    toc = (ROOT / "Leproc" / "Leproc.toc").read_text(encoding="utf-8")
    match = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not match:
        sys.exit("No ## Version in Leproc/Leproc.toc")
    version = match.group(1)
    if subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain", "--", "Leproc"], text=True).strip():
        sys.exit("Leproc/ has uncommitted changes: commit them first, so the zip matches a commit.")
    files = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "Leproc"], text=True).split()
    out = ROOT / "release" / f"Leproc-{version}.zip"
    out.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name in sorted(files):
            z.write(ROOT / name, name)
    print(f"{out.relative_to(ROOT)}: {len(files)} files, {out.stat().st_size} bytes")


if __name__ == "__main__":
    main()
