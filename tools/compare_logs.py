"""Compares Leproc's log with the game's combat log for the same play session, and reports when
Revenge and Overpower should have been lit, when Leproc lit them, and which signals it had.

Run: python3 tools/compare_logs.py <leproc log> <WoWCombatLog.txt> [--player Kam]

- The Leproc log is what `/leproc log show` copies (paste it into a text file), or the saved
  `WTF/Account/<account>/SavedVariables/Leproc.lua`.
- The combat log is `World of Warcraft/_forever_/Logs/WoWCombatLog-<date>.txt` from `/combatlog`
  (advanced logging on or off). The player is found from the log (the unit flagged as you,
  0x511); --player picks one by name if needed.

The truth comes from the combat log, which names who did what:
- Overpower: your attack (swing, ability or shot) dodged opens it for 5 s.
- Revenge: an attack on you dodged, parried or blocked (a full block, or damage with an amount
  blocked) opens it for 5 s.
- Your cast of either starts its 5 s cooldown; it's available while its window is open and it's
  off cooldown. (The owner's logs showed the game's windows at exactly 5.0 s.)
Times: Leproc's lines carry the clock to the second and the game's timer to a tenth; the clock
offset is pinned from all of a session's lines, then everything is compared on the PC clock, as
the combat log is.
"""
import argparse
import bisect
import csv
import io
import re
import sys

WINDOW = 5.0
COOLDOWN = {"Overpower": 5.0, "Revenge": 5.0}
MISS_TYPES = {"DODGE", "PARRY", "BLOCK", "MISS", "ABSORB", "RESIST", "IMMUNE", "EVADE", "DEFLECT", "REFLECT"}
PAST = {"DODGE": "dodged", "PARRY": "parried", "BLOCK": "blocked"}
SLACK = 0.3       # mismatches shorter than this are timing noise
MATCH_BEFORE = 1.6  # how long before Leproc's trigger report its combat log event may be
MATCH_AFTER = 0.3
SIGNAL_SPAN = 1.5  # a probe line within this of a dodge counts as coming with it

# --------------------------------------------------------------------------------------------
# Leproc's log

LEPROC_LINE = re.compile(r"(\d\d):(\d\d):(\d\d) t(\d+\.\d) (.+)")
QUOTED = re.compile(r'"(\d\d:\d\d:\d\d t\d+\.\d (?:[^"\\]|\\.)*)"')


def read_leproc(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    lines = []
    for raw in text.splitlines():
        # In Leproc.lua (SavedVariables) each line is a Lua string: take what's inside the quotes.
        q = QUOTED.search(raw)
        if q:
            raw = q.group(1).replace('\\"', '"').replace("\\\\", "\\")
        m = LEPROC_LINE.search(raw)
        if not m:
            continue
        hh, mm, ss, t, rest = m.groups()
        rest = rest.rstrip()
        lines.append({"clock": int(hh) * 3600 + int(mm) * 60 + int(ss), "t": float(t), "text": rest})
    return lines


def pin_clock(lines):
    """Gives each line `wall`, seconds since midnight on the PC clock: t + C, where C is pinned per
    session (the game's timer restarts with the client) from every line's clock second."""
    sessions = []
    lo = hi = None
    for ln in lines:
        a, b = ln["clock"] - ln["t"] - 0.05, ln["clock"] + 1 - ln["t"] + 0.05
        if lo is not None and (a > hi + 1.5 or b < lo - 1.5):
            sessions.append((lo, hi))
            lo = hi = None
        lo, hi = (a, b) if lo is None else (max(lo, a), min(hi, b))
        if lo > hi:  # a clock change mid-session: keep the newest
            lo, hi = a, b
        ln["session"] = len(sessions)
    if lo is not None:
        sessions.append((lo, hi))
    for ln in lines:
        s_lo, s_hi = sessions[ln["session"]]
        ln["wall"] = ln["t"] + (s_lo + s_hi) / 2
    return sessions


GLOW = re.compile(r"^(.+?) glow (ON|off) \((.+)\)$")
TRIGGER = re.compile(r"^(your target dodged|you blocked|you dodged|you parried) \(([^)]*)\) -> (.*)$")
ALERT = re.compile(r"^game: reactive alert \(SPELL_ACTIVE\) for (.+), in (.+)$")
HIGHLIGHT = re.compile(r"^game: (button highlight|screen proc alert) (ON|off) for (.+), in (.+)$")
STANCE = re.compile(r"^stance: (.+)$")


def leproc_events(lines):
    ev = {"glows": {}, "triggers": [], "alerts": [], "highlights": [], "stances": []}
    for ln in lines:
        text, w = ln["text"], ln["wall"]
        m = GLOW.match(text)
        if m:
            ev["glows"].setdefault(m.group(1), []).append((w, m.group(2) == "ON", m.group(3)))
            continue
        m = TRIGGER.match(text)
        if m:
            ev["triggers"].append({"wall": w, "what": m.group(1), "raw": m.group(2), "result": m.group(3), "text": text})
            continue
        m = ALERT.match(text)
        if m:
            ev["alerts"].append((w, m.group(1), m.group(2)))
            continue
        m = HIGHLIGHT.match(text)
        if m:
            ev["highlights"].append((w, m.group(1), m.group(2) == "ON", m.group(3), m.group(4)))
            continue
        m = STANCE.match(text)
        if m:
            ev["stances"].append((w, m.group(1)))
    return ev


def intervals_from_glows(glows):
    out, start = [], None
    for w, on, _ in glows:
        if on and start is None:
            start = w
        elif not on and start is not None:
            out.append((start, w))
            start = None
    if start is not None:
        out.append((start, start + WINDOW))
    return out


def stance_at(stances, w):
    i = bisect.bisect_right([s[0] for s in stances], w) - 1
    return stances[i][1] if i >= 0 else "?"


# --------------------------------------------------------------------------------------------
# The combat log

CL_LINE = re.compile(r"^(\d+)/(\d+)(?:/\d+)?\s+(\d+):(\d+):(\d+\.\d+)(?:[-+]\d+)?\s+(.*)$")


def base_name(name):
    return name.split("-")[0] if name else name


def read_combat_log(path, player=None):
    rows = []
    for raw in open(path, encoding="utf-8", errors="replace"):
        m = CL_LINE.match(raw.rstrip("\n"))
        if not m:
            continue
        _, _, hh, mm, ss, rest = m.groups()
        try:
            fields = next(csv.reader(io.StringIO(rest)))
        except (StopIteration, csv.Error):
            continue
        rows.append((int(hh) * 3600 + int(mm) * 60 + float(ss), fields))
    if player is None:
        counts = {}
        for _, f in rows:
            if len(f) > 3 and f[3].lower() == "0x511":
                counts[f[2]] = counts.get(f[2], 0) + 1
        player = base_name(max(counts, key=counts.get)) if counts else None
    return rows, player


def is_player(name, player):
    return base_name(name) == player


def miss_type(fields, start):
    for v in fields[start:]:
        if v in MISS_TYPES:
            return v
    return None


def blocked_amount(event, fields):
    """The amount blocked on a damage event: the 6th suffix param (amount, baseAmount, overkill,
    school, resisted, blocked), after the base 8, the spell's 3 for SPELL_, and 17 advanced."""
    start = 9 + (3 if event.startswith(("SPELL_", "RANGE_")) else 0) + 17
    try:
        return float(fields[start + 5])
    except (IndexError, ValueError):
        return 0.0


def truth(rows, player):
    """Every event that opens a window, every cast that starts a cooldown, and every dodge on
    anyone (for matching Leproc's "your target dodged")."""
    opens = {"Overpower": [], "Revenge": []}
    casts = {"Overpower": [], "Revenge": []}
    dodges = []  # (time, attacker, defender)
    for w, f in rows:
        if len(f) < 9:
            continue
        event, src, dst = f[0], f[2], f[6]
        if event.endswith("_MISSED"):
            mt = miss_type(f, 9 + (3 if event.startswith(("SPELL_", "RANGE_")) else 0))
            if mt == "DODGE":
                dodges.append((w, base_name(src), base_name(dst)))
                if is_player(src, player):
                    opens["Overpower"].append((w, f"{base_name(dst)} dodged your {'swing' if event.startswith('SWING') else f[10]}"))
            if mt in ("DODGE", "PARRY", "BLOCK") and is_player(dst, player):
                opens["Revenge"].append((w, f"you {PAST[mt]} {base_name(src)}"))
        elif event in ("SWING_DAMAGE", "SPELL_DAMAGE", "RANGE_DAMAGE") and is_player(dst, player):
            if blocked_amount(event, f) > 0:
                opens["Revenge"].append((w, f"you partly blocked {base_name(src)}"))
        elif event == "SPELL_CAST_SUCCESS" and is_player(src, player) and len(f) > 10 and f[10] in casts:
            casts[f[10]].append(w)
    return opens, casts, dodges


def available(opens, casts, ability):
    """Intervals when the ability was available: a window open (5 s from each opening event) and
    off cooldown (from your casts)."""
    windows = []
    for w, why in sorted(opens):
        if windows and w <= windows[-1][1]:
            windows[-1] = (windows[-1][0], w + WINDOW, windows[-1][2])
        else:
            windows.append((w, w + WINDOW, why))
    cds = [(c, c + COOLDOWN[ability]) for c in sorted(casts)]
    out = []
    for a, b, why in windows:
        pieces = [(a, b)]
        for c0, c1 in cds:
            nxt = []
            for p0, p1 in pieces:
                if c1 <= p0 or c0 >= p1:
                    nxt.append((p0, p1))
                else:
                    if p0 < c0:
                        nxt.append((p0, c0))
                    if c1 < p1:
                        nxt.append((c1, p1))
            pieces = nxt
        out.extend((p0, p1, why) for p0, p1 in pieces if p1 - p0 > 0.05)
    return out


def minus(xs, ys):
    """Parts of intervals xs not covered by ys."""
    out = []
    for a, b, *rest in xs:
        pieces = [(a, b)]
        for c, d, *_ in ys:
            nxt = []
            for p0, p1 in pieces:
                if d <= p0 or c >= p1:
                    nxt.append((p0, p1))
                else:
                    if p0 < c:
                        nxt.append((p0, c))
                    if d < p1:
                        nxt.append((d, p1))
            pieces = nxt
        out.extend((p0, p1, *rest) for p0, p1 in pieces if p1 - p0 > SLACK)
    return out


def clock(w):
    w %= 86400
    return f"{int(w // 3600):02d}:{int(w % 3600 // 60):02d}:{w % 60:04.1f}"


def near(items, w, before, after):
    """Items (tuples starting with a time, or dicts with "wall") within before/after of w."""
    def when(x):
        return x["wall"] if isinstance(x, dict) else x[0]
    return [x for x in items if w - before <= when(x) <= w + after]


# --------------------------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("leproc")
    ap.add_argument("combatlog")
    ap.add_argument("--player")
    args = ap.parse_args()

    lines = read_leproc(args.leproc)
    if not lines:
        sys.exit("No Leproc log lines found in " + args.leproc)
    sessions = pin_clock(lines)
    ev = leproc_events(lines)
    rows, player = read_combat_log(args.combatlog, args.player)
    if not rows or not player:
        sys.exit("No combat log events (or no player) found in " + args.combatlog)
    opens, casts, dodges = truth(rows, player)

    span = (lines[0]["wall"], lines[-1]["wall"])
    cl_span = (rows[0][0], rows[-1][0])
    lo, hi = max(span[0], cl_span[0]), min(span[1], cl_span[1])
    print(f"Player: {player}")
    print(f"Leproc log: {len(lines)} lines, {clock(span[0])}-{clock(span[1])}, {len(sessions)} session(s), "
          f"clock pinned to +/-{max((s[1] - s[0]) / 2 for s in sessions):.2f} s")
    print(f"Combat log: {len(rows)} events, {clock(cl_span[0])}-{clock(cl_span[1])}")
    if lo >= hi:
        sys.exit("The two logs don't overlap in time.")
    print(f"Compared: {clock(lo)}-{clock(hi)}\n")

    for ability in ("Overpower", "Revenge"):
        truth_iv = [iv for iv in available(opens[ability], casts[ability], ability) if iv[1] > lo and iv[0] < hi]
        lit = [iv for iv in intervals_from_glows(ev["glows"].get(ability, [])) if iv[1] > lo and iv[0] < hi]
        false_lit = minus([(a, b, "lit") for a, b in lit], truth_iv)
        missed = minus(truth_iv, [(a, b) for a, b in lit])
        total = sum(b - a for a, b, _ in truth_iv)
        print(f"== {ability}: available {len(truth_iv)} times ({total:.1f} s), Leproc lit {len(lit)} times; "
              f"{len(false_lit)} false glows, {len(missed)} misses")
        for a, b, _ in false_lit:
            causes = near(ev["triggers"], a, WINDOW + 0.5, 0.2)
            why = causes[-1]["text"] if causes else "no trigger line before it"
            print(f"  FALSE {clock(a)} for {b - a:.1f} s, in {stance_at(ev['stances'], a)}: after \"{why}\"")
        for a, b, why in missed:
            print(f"  MISSED {clock(a)} for {b - a:.1f} s, in {stance_at(ev['stances'], a)}: {why}")
        print()

    # Every "your target dodged" Leproc saw: whose attack it was, and which probes came with it.
    print("== Your target dodged: whose attack, and the probes")
    stats = {}
    delays = []
    for tr in ev["triggers"]:
        if tr["what"] != "your target dodged" or not (lo <= tr["wall"] <= hi):
            continue
        cands = [d for d in dodges if tr["wall"] - MATCH_BEFORE <= d[0] <= tr["wall"] + MATCH_AFTER]
        mine = [d for d in cands if d[1] == player]
        if mine:
            who = "yours"
            delays.append(tr["wall"] - mine[-1][0])
        elif cands:
            who = "not yours (" + ", ".join(sorted({d[1] for d in cands})) + ")"
        else:
            who = "no matching dodge in the combat log"
        alert = bool(near(ev["alerts"], tr["wall"], SIGNAL_SPAN, SIGNAL_SPAN))
        hl = [h for h in near(ev["highlights"], tr["wall"], SIGNAL_SPAN, SIGNAL_SPAN) if h[2]]
        stance = stance_at(ev["stances"], tr["wall"])
        key = ("yours" if mine else "others", stance)
        s = stats.setdefault(key, [0, 0, 0])
        s[0] += 1
        s[1] += alert
        s[2] += bool(hl)
        print(f"  {clock(tr['wall'])} in {stance}: {who}; reactive alert {'yes' if alert else 'no'}, highlight {'yes' if hl else 'no'}")
    print("\nSummary (target dodges: count, with a reactive alert, with a highlight):")
    for (whose, stance), (n, a, h) in sorted(stats.items()):
        print(f"  {whose:6s} in {stance}: {n}, alert {a}, highlight {h}")
    if delays:
        delays.sort()
        print(f"\nReport delay for your own dodged attacks (Leproc's report minus the combat log): "
              f"median {delays[len(delays) // 2]:.2f} s, range {delays[0]:.2f}-{delays[-1]:.2f} s")


if __name__ == "__main__":
    main()
