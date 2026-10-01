#!/bin/bash

# Confere se os textos da Apresentação usam o bundle correto, sem LocalizedStringKey
# solto ou sem bundle, sem fontes de tamanho fixo e sem cores fora dos tokens.
# Uso: Scripts/conferir-textos.sh [caminho-ou-diretorio]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PADRAO_DIR="$SCRIPT_DIR/../Sources/Apresentacao"
ALVO="${1:-$PADRAO_DIR}"

[[ -e "$ALVO" ]] || {
  echo "FALHA: alvo não encontrado: $ALVO" >&2
  exit 1
}

python3 - "$ALVO" <<'PYVERIF'
import os
import re
import sys

alvo = sys.argv[1]

if os.path.isfile(alvo):
    arquivos = [alvo] if alvo.endswith(".swift") else []
else:
    arquivos = []
    for root, dirs, files in os.walk(alvo):
        for f in sorted(files):
            if f.endswith(".swift"):
                arquivos.append(os.path.join(root, f))

if not arquivos:
    print(f"FALHA: nenhum arquivo Swift encontrado em: {alvo}", file=sys.stderr)
    sys.exit(1)

problemas = []

def extrair_chamada_balanceada(texto, inicio):
    parens = 1
    i = inicio
    while i < len(texto) and parens > 0:
        c = texto[i]
        if c == '(':
            parens += 1
        elif c == ')':
            parens -= 1
        elif c == '"':
            i += 1
            while i < len(texto) and texto[i] != '"':
                if texto[i] == '\\':
                    i += 1
                i += 1
        i += 1
    return texto[inicio:i-1], i

for caminho in arquivos:
    with open(caminho, "r", encoding="utf-8") as arq:
        conteudo = arq.read()
    
    linhas = conteudo.splitlines()

    # 1. String(localized:) sem bundle:
    for m in re.finditer(r'String\s*\(\s*localized\s*:', conteudo):
        args, fim = extrair_chamada_balanceada(conteudo, m.end())
        if "bundle:" not in args:
            num_linha = conteudo[:m.start()].count('\n') + 1
            trecho = conteudo[m.start():fim].replace('\n', ' ').strip()
            problemas.append((caminho, num_linha, f"String(localized:) sem bundle: '{trecho}'"))

    # 2. LocalizedStringKey(...)
    for m in re.finditer(r'\bLocalizedStringKey\s*\(', conteudo):
        num_linha = conteudo[:m.start()].count('\n') + 1
        linha = linhas[num_linha - 1].strip()
        problemas.append((caminho, num_linha, f"LocalizedStringKey embrulhada: '{linha}'"))

    # 3. Text(...) com LocalizedStringKey sem bundle:
    for m in re.finditer(r'\bText\s*\(', conteudo):
        args, fim = extrair_chamada_balanceada(conteudo, m.end())
        if "bundle:" in args or "verbatim:" in args:
            continue
        num_linha = conteudo[:m.start()].count('\n') + 1
        trecho = conteudo[m.start():fim].replace('\n', ' ').strip()
        problemas.append((caminho, num_linha, f"Text() sem bundle e sem verbatim: '{trecho}'"))

    # 4. Fonte de tamanho fixo (.system(size: ...))
    for m in re.finditer(r'\.system\s*\(\s*size\s*:', conteudo):
        num_linha = conteudo[:m.start()].count('\n') + 1
        linha = linhas[num_linha - 1].strip()
        problemas.append((caminho, num_linha, f"Fonte de tamanho fixo: '{linha}'"))

    # 5. Cores fora dos tokens de design (FrilaCor)
    if not caminho.endswith("DesignTokens.swift"):
        padrao_cor = re.compile(r'\.(foregroundStyle|foregroundColor|background)\s*\(\s*\.(red|green|blue|orange|yellow|pink|purple|teal|indigo|mint|cyan|secondary|primary)\b')
        for m in padrao_cor.finditer(conteudo):
            num_linha = conteudo[:m.start()].count('\n') + 1
            linha = linhas[num_linha - 1].strip()
            problemas.append((caminho, num_linha, f"Cor fora dos tokens: '{linha}'"))

if problemas:
    for arq, linha, desc in problemas:
        print(f"{arq}:{linha}: {desc}", file=sys.stderr)
    print(f"\nFALHA: {len(problemas)} problema(s) de textos ou tokens encontrado(s).", file=sys.stderr)
    sys.exit(1)

print("OK: textos no bundle da Apresentação e tokens em conformidade.")
PYVERIF
