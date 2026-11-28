#!/usr/bin/env python3
"""Guarda contra teste JUnit 5 ignorado em silêncio (cartão IprS09Qm, item 246).

No JUnit 5 um método @Test que não devolve Unit/void NÃO RODA e não avisa: `fun x() = runBlocking { ...; liberar.complete(Unit) }` devolve
Boolean, o teste parece existir e o Gradle fecha verde. Esta guarda compara, por arquivo, os nomes dos @Test (Jupiter) com os `testcase`
dos relatórios e reprova se algum @Test não tem relatório.

Rode DEPOIS dos testes (`./gradlew testDebugUnitTest`, e `test` nos módulos JVM puros). Módulos sem nenhum relatório são pulados (com aviso):
conferir um subconjunto de módulos não reprova por causa dos outros.

Uso:
    python3 android/scripts/conferir-testes-jupiter.py [--android-dir <caminho>]

Limites conhecidos: confere por NOME do método (o relatório grava `nome()` ou, com parâmetros, `nome(File)`; nomes com parênteses, como `x (RN06)`, valem); @ParameterizedTest,
@RepeatedTest e @TestFactory geram vários casos por método e não são conferidos por contagem, só pelo nome; um @Test sem relatório por
qualquer outro motivo (@Disabled, classe privada) também reprova, e isso é de propósito: ninguém deveria ter teste que não roda sem saber.
"""
import argparse
import glob
import os
import re
import sys
from collections import defaultdict


def modulo_de(caminho_relativo: str) -> str:
    return caminho_relativo.split("/src/test/")[0]


def ler_relatorios(android_dir: str):
    """modulo -> classname -> {nomes sem o sufixo de parametros}."""
    por_modulo = defaultdict(lambda: defaultdict(set))
    for xml in glob.glob(os.path.join(android_dir, "**", "build", "test-results", "*", "TEST-*.xml"), recursive=True):
        rel = os.path.relpath(xml, android_dir)
        modulo = rel.split("/build/test-results/")[0]
        texto = open(xml, encoding="utf-8").read()
        for m in re.finditer(r'<testcase name="([^"]*)" classname="([^"]*)"', texto):
            por_modulo[modulo][m.group(2)].add(m.group(1))
    return por_modulo


def rodou(nome: str, casos: set) -> bool:
    """O relatório grava `nome()`, ou `nome(Tipo)` quando o método recebe parâmetros (como @TempDir): em ambos, o nome seguido de `(` e terminado em `)`. O nome pode ter parênteses: `x (RN06)()`."""
    return any(c.startswith(nome + "(") and c.endswith(")") for c in casos)


def testes_do_arquivo(texto: str):
    pacote = re.search(r"^package\s+([\w.]+)", texto, re.M)
    classes = [m.group(1) for m in re.finditer(r"^(?:internal\s+|private\s+|open\s+|abstract\s+)*class\s+(\w+)", texto, re.M)]
    nomes = []
    for t in re.finditer(r"@Test\b", texto):
        f = re.search(r"fun\s+(`[^`]+`|\w+)\s*\(", texto[t.end():t.end() + 400])
        if f:
            nomes.append(f.group(1).strip("`"))
    return (pacote.group(1) if pacote else ""), classes, nomes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--android-dir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    args = ap.parse_args()
    android_dir = os.path.abspath(args.android_dir)

    relatorios = ler_relatorios(android_dir)
    if not relatorios:
        print("ERRO: nenhum relatório de teste em build/test-results; rode os testes antes.", file=sys.stderr)
        return 2

    faltam, pulados, conferidos = [], set(), 0
    for raiz, _, arquivos in os.walk(android_dir):
        caminho_raiz = raiz + "/"
        if "/src/test/" not in caminho_raiz or "/build/" in caminho_raiz:
            continue
        for nome_arquivo in arquivos:
            if not nome_arquivo.endswith(".kt"):
                continue
            caminho = os.path.join(raiz, nome_arquivo)
            texto = open(caminho, encoding="utf-8").read()
            if "org.junit.jupiter.api.Test" not in texto:
                continue
            rel = os.path.relpath(caminho, android_dir)
            modulo = modulo_de(rel)
            if modulo not in relatorios:
                pulados.add(modulo)
                continue
            pacote, classes, nomes = testes_do_arquivo(texto)
            rodaram = set()
            for classe in classes:
                for classname, casos in relatorios[modulo].items():
                    if classname == f"{pacote}.{classe}" or classname.startswith((f"{pacote}.{classe}$", f"{pacote}.{classe}.")):
                        rodaram |= casos
            conferidos += len(nomes)
            for nome in nomes:
                if not rodou(nome, rodaram):
                    faltam.append((rel, nome))

    for modulo in sorted(pulados):
        print(f"AVISO: {modulo} sem relatório, pulado.")
    if faltam:
        print(f"REPROVADO: {len(faltam)} @Test sem relatório (o JUnit 5 ignora em silêncio o método que não devolve Unit):", file=sys.stderr)
        for rel, nome in faltam:
            print(f"  {rel}: {nome}", file=sys.stderr)
        return 1
    print(f"OK: {conferidos} @Test conferidos, todos com relatório.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
