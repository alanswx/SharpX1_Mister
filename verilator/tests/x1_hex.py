"""Convert whitespace-separated ROM hex into an explicit binary analysis artifact."""
import argparse
import hashlib
import pathlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
args = parser.parse_args()
data = bytes(int(token, 16) for token in args.source.read_text().split())
args.output.write_bytes(data)
print(f"{len(data)} bytes SHA256 {hashlib.sha256(data).hexdigest()}")
