#!/usr/bin/env python3
"""Validação determinística das fixtures versionadas do contrato, sem dependências externas."""

from __future__ import annotations

import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "Resources" / "Fixtures"


def main() -> int:
    schemas = json.loads((FIXTURES / "fixture-schemas.json").read_text(encoding="utf-8"))
    failures: list[str] = []
    for name, schema in schemas.items():
        value = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
        expected = list if schema["root"] == "array" else dict
        if not isinstance(value, expected):
            failures.append(f"{name}: raiz deve ser {schema['root']}")
            continue
        records = value if isinstance(value, list) else [value]
        for index, record in enumerate(records):
            missing = [key for key in schema["required"] if key not in record]
            if missing:
                failures.append(f"{name}[{index}]: faltam {', '.join(missing)}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"{len(schemas)} fixtures válidas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
