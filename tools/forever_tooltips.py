"""Prints Wowhead's Forever tooltip for every spell ID with each name, to check a spell or proc
buff is in Forever before adding it (and which ID is the buff, not the talent or a rune).

Run: python3 tools/forever_tooltips.py "Bloodthrill" "Expose Prey"
It reads the SpellName table that tools/gen_data.py caches in .scratch/ (run that first).
"""
import csv
import json
import pathlib
import re
import sys
import time
import urllib.request

CACHE = pathlib.Path(__file__).resolve().parent.parent / ".scratch" / "SpellName.csv"


def main(names):
    if not CACHE.exists():
        sys.exit("No .scratch/SpellName.csv: run tools/gen_data.py first.")
    with CACHE.open(encoding="utf-8", newline="") as f:
        rows = [(int(r["ID"]), r["Name_lang"]) for r in csv.DictReader(f)]
    for name in names:
        ids = [i for i, n in rows if n == name]
        print(f"== {name}: {ids}")
        for i in ids[:10]:
            try:
                with urllib.request.urlopen(f"https://nether.wowhead.com/forever/tooltip/spell/{i}", timeout=20) as r:
                    tip = json.load(r).get("tooltip", "")
                print(f"  {i}: {re.sub(r'\s+', ' ', re.sub('<[^>]+>', ' ', tip)).strip()[:220]}")
            except Exception as e:
                print(f"  {i}: no Forever tooltip ({e.__class__.__name__})")
            time.sleep(0.2)


if __name__ == "__main__":
    main(sys.argv[1:])
