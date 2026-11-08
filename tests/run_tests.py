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
ALLOWED_GLOBALS = {"LeprocDB", "LeprocFrame", "LeprocMinimapButton", "SLASH_LEPROC1", "SLASH_LEPROC2",
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

print("FAILED" if failed else "OK: syntax, TOC, globals and smoke scenarios")
sys.exit(1 if failed else 0)
