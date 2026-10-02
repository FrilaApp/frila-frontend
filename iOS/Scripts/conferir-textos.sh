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
                    resultado.append('  ')
                    i += 2
                    prof += 1
                elif codigo[i:i+2] == '*/':
                    resultado.append('  ')
                    i += 2
                    prof -= 1
                else:
                    if codigo[i] == '\n':
                        resultado.append('\n')
                    else:
                        resultado.append(' ')
                    i += 1
        elif codigo[i] == '"':
            resultado.append('"')
            i += 1
            while i < n and codigo[i] != '"':
                if codigo[i] == '\\':
                    resultado.append(codigo[i])
                    if i + 1 < n:
                        resultado.append(codigo[i+1])
                    i += 2
                else:
                    resultado.append(codigo[i])
                    i += 1
            if i < n:
                resultado.append('"')
                i += 1
        else:
            resultado.append(codigo[i])
            i += 1
    return "".join(resultado)

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

def tem_letra(texto):
    return bool(re.search(r'[a-zA-Z\u00C0-\u00FF]', texto))

def string_literal_tem_palavra_fora_interpolacao(s):
    s = s.strip()
    if s.startswith('"') and s.endswith('"') and len(s) >= 2:
        conteudo = s[1:-1]
    else:
        conteudo = s
    sem_interp = []
    i = 0
    while i < len(conteudo):
        if conteudo[i:i+2] == r'\(':
            i += 2
            p = 1
            while i < len(conteudo) and p > 0:
                if conteudo[i] == '(':
                    p += 1
                elif conteudo[i] == ')':
                    p -= 1
                i += 1
        else:
            sem_interp.append(conteudo[i])
            i += 1
    resto = "".join(sem_interp)
    return tem_letra(resto)

def primeiro_argumento(args):
    i = 0
    p = 0
    while i < len(args):
        ch = args[i]
        if ch == '"':
            i += 1
            while i < len(args) and args[i] != '"':
                if args[i] == '\\':
                    i += 1
                i += 1
        elif ch in '([{':
            p += 1
        elif ch in ')]}':
            p -= 1
        elif ch == ',' and p == 0:
            return args[:i].strip()
        i += 1
    return args.strip()

for caminho in arquivos:
    with open(caminho, "r", encoding="utf-8") as arq:
        conteudo = arq.read()
    
    limpo = remover_comentarios(conteudo)
    linhas = conteudo.splitlines()

    # 1. String(localized:) sem bundle:
    for m in re.finditer(r'String\s*\(\s*localized\s*:', limpo):
        args, fim = extrair_chamada_balanceada(limpo, m.end())
        if "bundle:" not in args:
            num_linha = conteudo[:m.start()].count('\n') + 1
            trecho = conteudo[m.start():fim].replace('\n', ' ').strip()
            problemas.append((caminho, num_linha, f"String(localized:) sem bundle: '{trecho}'"))

    # 2. LocalizedStringKey(...)
    for m in re.finditer(r'\bLocalizedStringKey\s*\(', limpo):
        num_linha = conteudo[:m.start()].count('\n') + 1
        linha = linhas[num_linha - 1].strip()
        problemas.append((caminho, num_linha, f"LocalizedStringKey embrulhada: '{linha}'"))

    # 3. Text(...) com LocalizedStringKey sem bundle:
    for m in re.finditer(r'\bText\s*\(', limpo):
        args, fim = extrair_chamada_balanceada(limpo, m.end())
        if "bundle:" in args or "verbatim:" in args:
            continue
        num_linha = conteudo[:m.start()].count('\n') + 1
        trecho = conteudo[m.start():fim].replace('\n', ' ').strip()
        problemas.append((caminho, num_linha, f"Text() sem bundle e sem verbatim: '{trecho}'"))

    # 4. verbatim: só aceito com variável, chamada ou interpolações e pontuação
    for m in re.finditer(r'\bverbatim\s*:\s*', limpo):
        args_rest, fim = extrair_chamada_balanceada(limpo, m.end())
        arg = primeiro_argumento(args_rest)
        if arg.startswith('"'):
            m_str = re.match(r'^(".*?[^\\]"|"")', arg)
            lit = m_str.group(1) if m_str else arg
            if string_literal_tem_palavra_fora_interpolacao(lit):
                num_linha = conteudo[:m.start()].count('\n') + 1
                linha = linhas[num_linha - 1].strip()
                problemas.append((caminho, num_linha, f"verbatim com palavra fora de interpolação: '{linha}'"))

    # 5. Modificadores de acessibilidade e navegação com string literal sem bundle
    mods = [
        (r'\.accessibilityLabel\s*\(', '.accessibilityLabel'),
        (r'\.accessibilityHint\s*\(', '.accessibilityHint'),
        (r'\.accessibilityValue\s*\(', '.accessibilityValue'),
        (r'\.navigationTitle\s*\(', '.navigationTitle')
    ]
    for padrao, nome_mod in mods:
        for m in re.finditer(padrao, limpo):
            args, fim = extrair_chamada_balanceada(limpo, m.end())
            if "bundle:" in args or "verbatim:" in args:
                continue
            strings = re.findall(r'"(?:\\.|[^"\\])*"', args)
            if any(tem_letra(s) for s in strings):
                num_linha = conteudo[:m.start()].count('\n') + 1
                trecho = conteudo[m.start():fim].replace('\n', ' ').strip()
                problemas.append((caminho, num_linha, f"{nome_mod}() sem bundle: '{trecho}'"))

    # 6. Controles SwiftUI com primeiro argumento string literal sem bundle
    controles = [
        (r'\bLabel\s*\(', 'Label'),
        (r'\bButton\s*\(', 'Button'),
        (r'\bTextField\s*\(', 'TextField'),
        (r'\bToggle\s*\(', 'Toggle'),
        (r'\bPicker\s*\(', 'Picker'),
        (r'\bSection\s*\(', 'Section')
    ]
    for padrao, nome_ctrl in controles:
        for m in re.finditer(padrao, limpo):
            args, fim = extrair_chamada_balanceada(limpo, m.end())
            if "bundle:" in args or "verbatim:" in args:
                continue
            arg1 = primeiro_argumento(args)
            if arg1.startswith('"'):
                num_linha = conteudo[:m.start()].count('\n') + 1
                trecho = conteudo[m.start():fim].replace('\n', ' ').strip()
                problemas.append((caminho, num_linha, f"{nome_ctrl}() com texto sem bundle: '{trecho}'"))
            elif nome_ctrl == 'TextField':
                m_prompt = re.search(r'\bprompt\s*:\s*("(?:\\.|[^"\\])*")', args)
                if m_prompt and tem_letra(m_prompt.group(1)):
                    num_linha = conteudo[:m.start()].count('\n') + 1
                    trecho = conteudo[m.start():fim].replace('\n', ' ').strip()
                    problemas.append((caminho, num_linha, f"TextField() com prompt sem bundle: '{trecho}'"))

    # 7. Fonte de tamanho fixo (.system(size: ...))
    for m in re.finditer(r'\.system\s*\(\s*size\s*:', limpo):
        num_linha = conteudo[:m.start()].count('\n') + 1
        linha = linhas[num_linha - 1].strip()
        problemas.append((caminho, num_linha, f"Fonte de tamanho fixo: '{linha}'"))

    # 8. Cores fora dos tokens de design (FrilaCor)
    if not caminho.endswith("DesignTokens.swift"):
        padrao_cor = re.compile(r'\.(foregroundStyle|foregroundColor|background)\s*\(\s*\.(red|green|blue|orange|yellow|pink|purple|teal|indigo|mint|cyan|secondary|primary)\b')
        for m in padrao_cor.finditer(limpo):
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
