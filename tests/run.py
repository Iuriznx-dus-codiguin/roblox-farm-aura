#!/usr/bin/env python3
"""Roda os testes da lógica pura (src/shared) com o CLI `luau`, sem o Roblox.

Junta os módulos num arquivo só, troca os `require(script...)` pelas variáveis locais e
acrescenta tests/shared.spec.luau. Uso: python3 tests/run.py [caminho/do/luau]
"""
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
MODULES = [
    ("Bands", SHARED / "Config" / "Bands.luau"),
    ("Economy", SHARED / "Config" / "Economy.luau"),
    ("Powers", SHARED / "Config" / "Powers.luau"),
    ("AuraMath", SHARED / "AuraMath.luau"),
    ("Format", SHARED / "Format.luau"),
]


def load(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8").replace("--!strict", "")
    for name, _ in MODULES:
        text = text.replace(f"require(script.Parent.Config.{name})", name)
        text = text.replace(f"require(script.Parent.{name})", name)
    return text


def main() -> int:
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    parts = ["Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }"]
    for name, path in MODULES:
        parts.append(f"local {name} = (function()\n{load(path)}\nend)()")
    parts.append((ROOT / "tests" / "shared.spec.luau").read_text(encoding="utf-8"))
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write("\n".join(parts))
    return subprocess.call([luau, f.name])


if __name__ == "__main__":
    sys.exit(main())
