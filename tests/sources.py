"""Emit a Lua SOURCES table with every module listed in loader.lua (used by the loader test)."""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
loader = (root / "loader.lua").read_text(encoding="utf-8")
paths = re.findall(r'"(src/[^"]+\.lua)"', re.search(r"local MODULES = \{(.*?)\n\}", loader, re.S).group(1))
print("SOURCES = {}")
for path in paths:
    body = (root / path).read_text(encoding="utf-8")
    level = "===="
    while "]" + level + "]" in body:
        level += "="
    print(f'SOURCES["{path}"] = [{level}[{body}]{level}]')
