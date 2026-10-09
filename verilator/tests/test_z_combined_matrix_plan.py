"""Fast enumeration checks, not pixel execution."""
from collections import Counter
from test_z_combined_matrix import cases

matrix = cases()
assert len(matrix) == 120
assert len({c["name"] for c in matrix}) == 120
assert Counter(c["group"] for c in matrix) == {
    "graphics": 24, "paired-graphics": 24, "paired-text": 24,
    "single-text": 32, "internal8": 4, "reverse": 12}
assert sum("--warm" in c["flags"] for c in matrix) == 60
assert sum("--custom" in c["flags"] for c in matrix) == 60
for c in matrix:
    f = c["flags"]
    assert ("--text" in f) == (c["group"] in ("paired-text", "single-text", "reverse"))
    assert ("--reverse" in f) == (c["group"] == "reverse")
    if c["group"] == "single-text":
        assert int(f[f.index("--priority") + 1], 0) & 0x10 == 0
print("PASS: combined plan enumerates 120 unique diagnostic cases (not execution)")
