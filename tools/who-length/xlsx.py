"""Minimal xlsx reader: first sheet -> list of rows (strings/floats). Stdlib only."""
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def col_index(ref):
    letters = re.match(r"[A-Z]+", ref).group(0)
    n = 0
    for ch in letters:
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def read(path):
    z = zipfile.ZipFile(path)
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in root.findall("m:si", NS):
            shared.append("".join(t.text or "" for t in si.iter("{%s}t" % NS["m"])))
    sheet = sorted(n for n in z.namelist() if n.startswith("xl/worksheets/sheet"))[0]
    root = ET.fromstring(z.read(sheet))
    rows = []
    for r in root.iter("{%s}row" % NS["m"]):
        row = {}
        for c in r.findall("m:c", NS):
            v = c.find("m:v", NS)
            if v is None:
                continue
            val = v.text
            if c.get("t") == "s":
                val = shared[int(val)]
            else:
                try:
                    val = float(val)
                except ValueError:
                    pass
            row[col_index(c.get("r"))] = val
        if row:
            rows.append([row.get(i) for i in range(max(row) + 1)])
    return rows


if __name__ == "__main__":
    rows = read(sys.argv[1])
    for r in rows[: int(sys.argv[2]) if len(sys.argv) > 2 else 4]:
        print(r)
    print("rows:", len(rows))
