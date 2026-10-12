#!/bin/bash

# Recusa datas literais de 2025/2026 nos tipos de dublê dos testes Swift.
# Uso: Scripts/conferir-datas-fixas.sh [arquivo-ou-diretorio]
# Dublês: tipos Duble/Mock/Fake/Stub/Falso/Simulado ou implementações de ApiCliente.
# Use relogio.agora e deslocamentos relativos para montar os prazos das fixtures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALVO="${1:-$SCRIPT_DIR/../Tests}"
[[ -e "$ALVO" ]] || { echo "FALHA: alvo não encontrado: $ALVO" >&2; exit 1; }

python3 - "$ALVO" <<'PYVERIF'
import re
import sys
from pathlib import Path

alvo = Path(sys.argv[1]).resolve()
arquivos = sorted(alvo.rglob("*.swift")) if alvo.is_dir() else [alvo] if alvo.suffix == ".swift" else []
if not arquivos:
    print(f"FALHA: nenhum arquivo Swift encontrado em: {alvo}", file=sys.stderr)
    sys.exit(1)


abertura_literal = re.compile(r'(#*)("""|")')


def mascarar(texto):
    """Preserva posições; comentários saem das datas e strings saem da estrutura Swift."""
    datas = list(texto)
    estrutura = list(texto)
    literais = []

    def apagar(inicio, fim, destino):
        for posicao in range(inicio, fim):
            if texto[posicao] != "\n":
                destino[posicao] = " "

    i = 0
    while i < len(texto):
        inicio = i
        if texto.startswith("//", i):
            i = texto.find("\n", i)
            if i == -1:
                i = len(texto)
            apagar(inicio, i, datas)
            apagar(inicio, i, estrutura)
        elif texto.startswith("/*", i):
            i += 2
            profundidade = 1
            while i < len(texto) and profundidade:
                if texto.startswith("/*", i):
                    profundidade += 1
                    i += 2
                elif texto.startswith("*/", i):
                    profundidade -= 1
                    i += 2
                else:
                    i += 1
            apagar(inicio, i, datas)
            apagar(inicio, i, estrutura)
        elif abertura := abertura_literal.match(texto, i):
            hashes, aspas = abertura.groups()
            i += len(abertura.group())
            fim = aspas + hashes
            while i < len(texto):
                if texto.startswith("\\" + hashes, i):
                    i += len(hashes) + 2
                elif texto.startswith(fim, i):
                    i += len(fim)
                    break
                else:
                    i += 1
            i = min(i, len(texto))
            literais.append((inicio, i))
            apagar(inicio, i, estrutura)
        else:
            i += 1
    return "".join(datas), "".join(estrutura), literais


declaracao = re.compile(r"\b(class|struct|actor|enum|extension)\s+(\w+)\b([^{};]*?)\{")
nome_de_duble = re.compile(r"duble|mock|fake|stub|falso|simulado", re.I)
implementacao_api = re.compile(r":[^{}]*\bApiCliente(?:Encaminhador)?\b")
iso = re.compile(r"(?<![\w-])202[56]-[01]\d-[0-3]\d(?!\d)")
ano = re.compile(r"\b(?:year|ano)\s*:\s*202[56]\b|\.year\s*=\s*202[56]\b")
conteudos = [(p, *mascarar(p.read_text(encoding="utf-8"))) for p in arquivos]
nomes = set()
for _, _, estrutura, _ in conteudos:
    for m in declaracao.finditer(estrutura):
        _, nome, heranca = m.groups()
        if not nome.endswith("Tests") and (nome_de_duble.search(nome) or implementacao_api.search(heranca)):
            nomes.add(nome)

problemas = []
for caminho, datas, estrutura, literais in conteudos:
    intervalos = []
    for m in declaracao.finditer(estrutura):
        if m.group(2) not in nomes:
            continue
        profundidade = 1
        fim = m.end()
        while fim < len(estrutura) and profundidade:
            profundidade += (estrutura[fim] == "{") - (estrutura[fim] == "}")
            fim += 1
        intervalos.append((m.end(), fim))

    candidatos = list(ano.finditer(estrutura))
    for inicio, fim in literais:
        candidatos.extend(iso.finditer(datas, inicio, fim))
    for m in sorted(candidatos, key=lambda item: item.start()):
        if any(inicio <= m.start() < fim for inicio, fim in intervalos):
            linha = datas.count("\n", 0, m.start()) + 1
            problemas.append((caminho, linha, m.group()))

for caminho, linha, literal in problemas:
    print(f"{caminho}:{linha}: data fixa no dublê: {literal}; use relogio.agora e prazo relativo", file=sys.stderr)
if problemas:
    print(f"FALHA: {len(problemas)} data(s) fixa(s) nos dublês", file=sys.stderr)
    sys.exit(1)
print("OK: dublês sem datas literais de 2025/2026.")
PYVERIF
