#!/bin/bash

# Confere se todas as animações em Sources respeitam a preferência de Reduzir Movimento (#71.4),
# passando pelo ponto único FrilaMovimento.animacao.
# Uso: Scripts/conferir-movimento.sh [caminho-ou-diretorio]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PADRAO_DIR="$SCRIPT_DIR/../Sources"
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

# Lista de exceções autorizadas para animações que NÃO são deslocamento (ex.: opacidade ou cor pura).
# Cada exceção deve documentar explicitamente o arquivo e o motivo ao lado.
EXCECOES_NAO_DESLOCAMENTO = {
    # Exemplo futuro se aplicável:
    # "TelaExemplo.swift:42": "Transição exclusiva de opacidade (.opacity), não causa deslocamento espacial."
}

problemas = []

def remover_comentarios(codigo):
    resultado = []
    i = 0
    n = len(codigo)
    while i < n:
        if codigo[i:i+2] == '//':
            resultado.append('  ')
            i += 2
            while i < n and codigo[i] != '\n':
                resultado.append(' ')
                i += 1
        elif codigo[i:i+2] == '/*':
            resultado.append('  ')
            i += 2
            prof = 1
            while i < n and prof > 0:
                if codigo[i:i+2] == '/*':
                    prof += 1
                    resultado.append('  ')
                    i += 2
                elif codigo[i:i+2] == '*/':
                    prof -= 1
                    resultado.append('  ')
                    i += 2
                else:
                    resultado.append(' ' if codigo[i] != '\n' else '\n')
                    i += 1
        elif codigo[i] == '"':
            # Ignora strings literais simples
            resultado.append('"')
            i += 1
            while i < n and codigo[i] != '"':
                if codigo[i:i+2] == '\\"':
                    resultado.append('  ')
                    i += 2
                else:
                    resultado.append(' ' if codigo[i] != '\n' else '\n')
                    i += 1
            if i < n:
                resultado.append('"')
                i += 1
        else:
            resultado.append(codigo[i])
            i += 1
    return ''.join(resultado)

def encontrar_chamadas_with_animation(limpo):
    chamadas = []
    # Encontra qualquer ocorrência de withAnimation como identificador
    for m in re.finditer(r'\bwithAnimation\b', limpo):
        pos = m.end()
        n = len(limpo)
        while pos < n and limpo[pos].isspace():
            pos += 1
        
        argumentos = ""
        if pos < n and limpo[pos] == '(':
            ini_args = pos + 1
            nivel = 1
            pos += 1
            while pos < n and nivel > 0:
                if limpo[pos] == '(':
                    nivel += 1
                elif limpo[pos] == ')':
                    nivel -= 1
                pos += 1
            if nivel == 0:
                argumentos = limpo[ini_args:pos-1]
            while pos < n and limpo[pos].isspace():
                pos += 1

        if pos < n and limpo[pos] == '{':
            chamadas.append((m.start(), argumentos))
    return chamadas

padrao_animation_modifier = re.compile(r'\.animation\s*\(')

for caminho in arquivos:
    with open(caminho, encoding="utf-8") as f:
        conteudo = f.read()

    limpo = remover_comentarios(conteudo)
    linhas = conteudo.splitlines()

    # 1. Checagem de withAnimation
    for inicio_match, argumentos in encontrar_chamadas_with_animation(limpo):
        num_linha = conteudo[:inicio_match].count('\n') + 1
        nome_arquivo = os.path.basename(caminho)
        chave_excecao = f"{nome_arquivo}:{num_linha}"

        # Se usa FrilaMovimento.animacao, está em conformidade com o critério 71.4
        if "FrilaMovimento.animacao" in argumentos:
            continue

        if chave_excecao in EXCECOES_NAO_DESLOCAMENTO:
            continue

        linha_codigo = linhas[num_linha - 1].strip()
        problemas.append((
            caminho,
            num_linha,
            f"withAnimation direto sem passar por FrilaMovimento.animacao: '{linha_codigo}'. Para respeitar Reduzir Movimento (#71.4), use withAnimation(FrilaMovimento.animacao(..., reduzir: reduzirMovimento)) ou adicione à lista de exceções com justificativa."
        ))

    # 2. Checagem de .animation(...) modificador direto
    for m in padrao_animation_modifier.finditer(limpo):
        num_linha = conteudo[:m.start()].count('\n') + 1
        nome_arquivo = os.path.basename(caminho)
        chave_excecao = f"{nome_arquivo}:{num_linha}"

        if chave_excecao in EXCECOES_NAO_DESLOCAMENTO:
            continue

        linha_codigo = linhas[num_linha - 1].strip()
        problemas.append((
            caminho,
            num_linha,
            f"Modificador .animation(...) solto: '{linha_codigo}'. Evite animações implícitas descontroladas que violam Reduzir Movimento (#71.4)."
        ))

if problemas:
    for arq, linha, desc in problemas:
        print(f"{arq}:{linha}: {desc}", file=sys.stderr)
    print(f"\nFALHA: {len(problemas)} violação(ões) de Reduzir Movimento encontrada(s).", file=sys.stderr)
    sys.exit(1)

print("OK: todas as animações respeitam Reduzir Movimento via FrilaMovimento.animacao.")
PYVERIF
