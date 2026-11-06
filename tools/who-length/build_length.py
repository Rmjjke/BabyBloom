"""Build the WHO length-for-age node table for WHOGrowthStandard.

Usage (from the repo root; DL = a fresh, empty download folder):
    B=https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/length-height-for-age/expandable-tables
    curl -sSL -o $DL/boys-p.xlsx  "$B/lhfa-boys-percentiles-expanded-tables.xlsx"
    curl -sSL -o $DL/girls-p.xlsx "$B/lhfa-girls-percentiles-expanded-tables.xlsx"
    curl -sSL -o $DL/boys-z.xlsx  "$B/lhfa-boys-zscore-expanded-tables.xlsx"
    curl -sSL -o $DL/girls-z.xlsx "$B/lhfa-girls-zscore-expanded-tables.xlsx"
    curl -sSL -o $DL/lenanthro.txt https://raw.githubusercontent.com/WorldHealthOrganization/anthro/master/data-raw/growthstandards/lenanthro.txt
    python3 -I -B tools/who-length/build_length.py tools/who-length $DL > nodes.swift 2> reference.txt
    cat tools/who-length/length-head.swift nodes.swift > BabyBloom/Core/Growth/WHOGrowthStandard+Length.swift
    echo "}" >> BabyBloom/Core/Growth/WHOGrowthStandard+Length.swift
reference.txt carries the cross-check result, the grid's measured error and
the P3/P50/P97 and SD reference points used by WHOLengthStandardTests.

- reads WHO's expanded LMS tables (xlsx) for days 0...730;
- cross-checks them row by row against WHO anthro's lenanthro.txt;
- thins the daily rows to the length grid and measures its worst percentile
  error over z in [-3, 3] against the full daily table;
- prints the Swift node arrays and the test reference points.
"""
import math
import sys

sys.path.insert(0, sys.argv[1])
import xlsx  # noqa: E402

DL = sys.argv[2]


def daily(path):
    rows = xlsx.read(path)
    head = rows[0]
    out = {}
    for r in rows[1:]:
        d = int(r[0])
        if d > 730:
            break
        out[d] = dict(zip(head, r))
    return out


tables = {True: daily(f"{DL}/boys-p.xlsx"), False: daily(f"{DL}/girls-p.xlsx")}
ztables = {True: daily(f"{DL}/boys-z.xlsx"), False: daily(f"{DL}/girls-z.xlsx")}
assert all(len(t) == 731 for t in ztables.values())
# The z-score file must carry the same LMS rows as the percentile file.
for male in (True, False):
    for d in range(731):
        p, z = tables[male][d], ztables[male][d]
        assert (p["L"], p["M"], p["S"]) == (z["L"], z["M"], z["S"]), (male, d)
assert all(len(t) == 731 for t in tables.values())

# Cross-check against anthro.
anthro = {}
for line in open(f"{DL}/lenanthro.txt").read().splitlines()[1:]:
    sex, age, l, m, s, loh = line.split("\t")
    anthro[(sex == "1", int(age))] = (float(l), float(m), float(s), loh)
for male, t in tables.items():
    for d, r in t.items():
        a = anthro[(male, d)]
        assert (r["L"], r["M"], r["S"]) == a[:3], (male, d, r, a)
        assert a[3] == "L", (male, d)
        assert r["L"] == 1.0
print("// LMS: WHO xlsx == anthro lenanthro.txt for days 0...730, both sexes; L == 1 everywhere; all rows recumbent length", file=sys.stderr)

# Length grid: daily to 30 days, every 3 days to 182, weekly to 730, plus 730.
# Measured with the error loop below: the weight table's grid reaches 0.31
# percentile at the median, where one z moves the percentile most; this one
# stays under 0.022.
days = sorted(set(list(range(0, 31)) + list(range(30, 183, 3)) + list(range(182, 731, 7)) + [730]))
print("// test days that are nodes:", [d for d in (0, 45, 183, 365, 730) if d in days], file=sys.stderr)


def interp(t, d):
    if d in t_grid:
        r = t[d]
        return r["M"], r["S"]
    lo = max(x for x in t_grid if x < d)
    hi = min(x for x in t_grid if x > d)
    f = (d - lo) / (hi - lo)
    return (t[lo]["M"] + (t[hi]["M"] - t[lo]["M"]) * f,
            t[lo]["S"] + (t[hi]["S"] - t[lo]["S"]) * f)


t_grid = set(days)
worst = (0, None)
for male, t in tables.items():
    for d in range(731):
        m, s = interp(t, d)
        tm, ts = t[d]["M"], t[d]["S"]
        for zi in range(-30, 31):
            z = zi / 10
            x = tm * (1 + ts * z)
            zz = (x / m - 1) / s
            err = abs(50 * (math.erf(zz / math.sqrt(2)) - math.erf(z / math.sqrt(2))))
            if err > worst[0]:
                worst = (err, (male, d, z))
print(f"// grid: {len(days)} nodes per sex; worst percentile error {worst[0]:.4f} at {worst[1]}", file=sys.stderr)


def fmt(v):
    s = repr(v)
    return s[:-2] if s.endswith(".0") else s


for male, name in ((True, "lengthBoys"), (False, "lengthGirls")):
    print(f"    private static let {name}: [Node] = [")
    for d in days:
        r = tables[male][d]
        print(f"        Node(day: {d}, l: 1, m: {fmt(r['M'])}, s: {fmt(r['S'])}),")
    print("    ]")
    if male:
        print()

# Test reference: P3 / P50 / P97 at birth, 6, 12, 24 months (days 0, 183, 365, 730)
# plus day 45; and the SD lines -3/-2/0/+2 at the same days. Which of them
# are grid nodes is printed above.
print("// percentile reference", file=sys.stderr)
for male in (True, False):
    for d in (0, 45, 183, 365, 730):
        r = tables[male][d]
        print(f"        ({d}, {str(male).lower()}, 3, {r['P3']}), ({d}, {str(male).lower()}, 50, {r['P50']}), ({d}, {str(male).lower()}, 97, {r['P97']}),", file=sys.stderr)
print("// z reference", file=sys.stderr)
for male in (True, False):
    for d in (0, 45, 183, 365, 730):
        r = ztables[male][d]
        print(f"        ({d}, {str(male).lower()}, -3, {r['SD3neg']}), ({d}, {str(male).lower()}, -2, {r['SD2neg']}), ({d}, {str(male).lower()}, 0, {r['SD0']}), ({d}, {str(male).lower()}, 2, {r['SD2']}),", file=sys.stderr)
