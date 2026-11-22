#!/usr/bin/env python3
"""Sinh requirements lock tu uv.lock (chi resolve, khong build).
Phan biet lock full va lock ap dung duoc tren Android."""
import re
import tomllib
from pathlib import Path

AGENT = Path("/data/local/hermes-agent")
OUT = Path("/data/local/hermes-home/backups")

lock = tomllib.loads((AGENT / "uv.lock").read_text())
pkgs, deps, src = {}, {}, {}
for p in lock.get("package", []):
    n = p["name"]
    pkgs[n] = p["version"]
    deps[n] = [d["name"] for d in p.get("dependencies", [])]
    src[n] = p.get("source", {})

py = tomllib.loads((AGENT / "pyproject.toml").read_text())
base = []
for spec in py["project"]["dependencies"]:
    m = re.match(r"\s*([A-Za-z0-9_.\-]+)", spec)
    if m:
        base.append(m.group(1))

seen, stack = set(), list(base)
while stack:
    n = stack.pop()
    if n in seen or n not in deps:
        continue
    seen.add(n)
    stack.extend(deps[n])

# Chi ap dung tren Android: loai package chi cho Windows / nemo-relay (loai tru android)
WINDOWS_ONLY = {
    "tzdata", "pywinpty", "pywin32", "concurrent-log-handler",
    "winrt-windows-applicationmodel", "winrt-windows-foundation",
    "winrt-windows-foundation-collections", "winrt-windows-services-store",
    "winrt-runtime",
}
ANDROID_EXCLUDE = WINDOWS_ONLY | {"nemo-relay", "uvloop"}

def emit(path, names, extra_header=""):
    names = sorted(names)
    lines = [
        f"# {extra_header}",
        f"# generated from uv.lock (resolve only, no build) - {len(names)} packages",
        "",
    ]
    for n in names:
        if n == "psutil" and "git" in src.get("psutil", {}):
            commit = src["psutil"]["git"].split("#")[-1]
            lines.append(f"psutil @ git+https://github.com/giampaolo/psutil.git@{commit}")
        else:
            lines.append(f"{n}=={pkgs[n]}")
    Path(path).write_text("\n".join(lines) + "\n")
    return len(names)

full_n = emit(OUT / "venv-requirements.full.lock", set(pkgs), "FULL lock (moi extras, moi nen tang)")
and_n = emit(OUT / "venv-requirements.android.lock", set(seen) - ANDROID_EXCLUDE, "ANDROID core lock (base deps + transitive, da loc nen Windows)")

print(f"base deps        : {len(base)}")
print(f"core closure     : {len(seen)}")
print(f"full lock        : {full_n}")
print(f"android lock     : {and_n}")
print("boi android      :", ", ".join(sorted(ANDROID_EXCLUDE & set(seen))))
print("psutil source    :", src.get("psutil"))
