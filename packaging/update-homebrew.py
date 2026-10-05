#!/usr/bin/env python3
"""Update the stable Git source without moving HEAD or downgrading the tap."""
import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument("tag")
parser.add_argument("commit")
parser.add_argument("--formula", type=Path, default=Path("Formula/twin-commander.rb"))
args = parser.parse_args()
if not re.fullmatch(r"v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", args.tag):
    parser.error("tag must be vX.Y.Z")
if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
    parser.error("commit must be a full Git SHA")
source = args.formula.read_text()
pattern = r'  url "[^"\n]+",\n      tag: "v[^"\n]+",\n      revision: "[0-9a-f]{40}"\n  version "([^"\n]+)"\n'
match = re.search(pattern, source)
if not match:
    parser.error("stable source block is missing or has an unexpected format")
version = args.tag[1:]
if tuple(map(int, version.split("."))) < tuple(map(int, match[1].split("."))):
    parser.error("refusing to downgrade the stable formula")
replacement = (f'  url "https://github.com/PushUpek/twin-commander.git",\n'
               f'      tag: "{args.tag}",\n'
               f'      revision: "{args.commit}"\n'
               f'  version "{version}"\n')
args.formula.write_text(source[:match.start()] + replacement + source[match.end():])
