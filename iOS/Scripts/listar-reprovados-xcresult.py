#!/usr/bin/env python3
"""
Lista, um por linha, os testes que terminaram reprovados num .xcresult (depois das repetições do
-retry-tests-on-failure), no formato Suite/teste. Usado pela noturna para dizer o que falhou na issue.

Uso: listar-reprovados-xcresult.py <caminho.xcresult>
Sai com 0 mesmo quando não consegue ler o resultado (a saída fica vazia): quem chama decide o que fazer.
"""

import json
import os
import subprocess
import sys


def reprovados(nos, suites=()):
    """Percorre a árvore de testNodes do xcresulttool e devolve os Test Case com resultado Failed."""
    achados = []
    if isinstance(nos, list):
        for no in nos:
            achados.extend(reprovados(no, suites))
    elif isinstance(nos, dict):
        tipo = nos.get("nodeType")
        nome = nos.get("name", "")
        if tipo == "Test Case":
            if str(nos.get("result", "")).lower() == "failed":
                achados.append("/".join([*suites[-1:], nome]))
            return achados
        proximas = suites + (nome,) if tipo == "Test Suite" else suites
        achados.extend(reprovados(nos.get("children", []), proximas))
    return achados


def main():
    if len(sys.argv) != 2:
        print("uso: listar-reprovados-xcresult.py <caminho.xcresult>", file=sys.stderr)
        sys.exit(2)
    caminho = sys.argv[1]
    if not os.path.exists(caminho):
        print(f"resultado não encontrado: {caminho}", file=sys.stderr)
        sys.exit(0)
    try:
        saida = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", caminho],
            capture_output=True, text=True, timeout=120)
        dados = json.loads(saida.stdout)
    except Exception as erro:  # noqa: BLE001 - qualquer falha de leitura vira saída vazia
        print(f"não foi possível ler o resultado: {erro}", file=sys.stderr)
        sys.exit(0)
    for nome in sorted(set(reprovados(dados.get("testNodes", [])))):
        print(nome)


if __name__ == "__main__":
    main()
