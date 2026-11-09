"""Leproc's checks: Lua 5.1 syntax, the TOC file list, globals, and the scenarios in smoke.lua
against the fake client in wowmock.lua.

Run: .venv/bin/python tests/run_tests.py   (needs lupa: python3 -m venv .venv && .venv/bin/pip install lupa)
"""
import pathlib
import sys

try:
    from lupa import lua51
except ImportError:
    sys.exit("lupa is not installed: python3 -m venv .venv && .venv/bin/pip install lupa")

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "Leproc"
TESTS = ROOT / "tests"
ALLOWED_GLOBALS = {"LeprocDB", "LeprocFrame", "LeprocLog", "LeprocMinimapButton", "SLASH_LEPROC1", "SLASH_LEPROC2",
                   "Leproc_OnAddonCompartmentClick"}

failed = False


def fail(msg):
    global failed
    failed = True
    print("FAIL " + msg)


lua = lua51.LuaRuntime(unpack_returned_tuples=True)
compile_chunk = lua.eval("function(src, name) local f, err = loadstring(src, '@' .. name) return f or false, err end")

toc = [line.strip().replace("\\", "/") for line in (ADDON / "Leproc.toc").read_text(encoding="utf-8").splitlines()
       if line.strip().endswith(".lua") and not line.startswith("#")]
on_disk = sorted(str(p.relative_to(ADDON)) for p in ADDON.rglob("*.lua"))
for f in on_disk:
    if f not in toc:
        fail(f"{f} is not in Leproc.toc")
for f in toc:
    if f not in on_disk:
        fail(f"Leproc.toc lists {f}, which doesn't exist")

chunks = []
for name in toc:
    path = ADDON / name
    if not path.exists():
        continue
    chunk, err = compile_chunk(path.read_text(encoding="utf-8"), name)
    if not chunk:
        fail(err)
    else:
        chunks.append((name, chunk))

if not failed:
    lua.globals().WM = lua.execute((TESTS / "wowmock.lua").read_text(encoding="utf-8"))
    before = set(lua.eval("function() local t = {} for k in pairs(_G) do t[#t+1] = k end return t end")().values())
    ns = lua.table()
    for name, chunk in chunks:
        try:
            chunk("Leproc", ns)
        except Exception as e:
            fail(f"loading {name}: {e}")
    after = set(lua.eval("function() local t = {} for k in pairs(_G) do t[#t+1] = k end return t end")().values())
    for g in sorted(after - before - ALLOWED_GLOBALS):
        fail(f"unexpected global {g}")
    lua.globals().ns = ns
    try:
        smoke, err = compile_chunk((TESTS / "smoke.lua").read_text(encoding="utf-8"), "smoke.lua")
        if not smoke:
            raise RuntimeError(err)
        smoke()
    except Exception as e:
        fail(f"smoke.lua: {e}")

# tools/compare_logs.py on the fixtures: made-up logs in the real formats (a combat log with
# your dodged swing, Twin's dodged swing, a parry and a partial block; Leproc's log as copied, and
# as saved in Leproc.lua).
import subprocess

EXPECT = [
    "Player: Kam",
    "== Overpower: available 1 times (1.8 s), Leproc lit 2 times; 1 false glows, 1 misses",
    "FALSE 15:05:20.",
    "MISSED 15:05:10.2 for 0.",
    "in Battle Stance: Boar dodged your swing",
    "MISSED 15:05:30.0 for 0.",
    "you parried Boar",
    "MISSED 15:05:40.0 for 5.0 s, in Defensive Stance: you partly blocked Boar",
    "in Battle Stance: yours; reactive alert yes, highlight no",
    "in Defensive Stance: not yours (Twin); reactive alert no, highlight no",
    "median 0.5",
]
for log in ("leproc-log.txt", "Leproc.lua"):
    run = subprocess.run([sys.executable, str(ROOT / "tools" / "compare_logs.py"), str(TESTS / "fixtures" / log),
                          str(TESTS / "fixtures" / "combatlog.txt")], capture_output=True, text=True)
    if run.returncode != 0:
        fail(f"compare_logs.py on {log}: {run.stderr.strip()}")
        continue
    for want in EXPECT:
        if want not in run.stdout:
            fail(f"compare_logs.py on {log}: no '{want}' in:\n{run.stdout}")

print("FAILED" if failed else "OK: syntax, TOC, globals, smoke scenarios and compare_logs.py")
sys.exit(1 if failed else 0)
