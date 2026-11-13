#!/bin/bash

# Divide a suíte do Frila-Local nas N partes da CI (.github/workflows/ios-suite-completa.yml) a partir
# de uma lista só (Tests/partes-da-ci.txt): cada seção `[parte K]` (K = 1 a N-1) roda o que está nela
# (-only-testing) e a última parte (N) roda o resto (-skip-testing de tudo o que está nas seções).
# Classe nova fica fora da lista e cai na última parte. Quantas partes existem = seções + 1.
#
# Uso:
#   Scripts/partes-dos-testes.sh total
#       Imprime N, o número de partes.
#   Scripts/partes-dos-testes.sh matriz
#       Imprime a matriz do GitHub Actions, por exemplo [1,2,3,4].
#   Scripts/partes-dos-testes.sh argumentos 1..N
#       Imprime os argumentos do xcodebuild para a parte, um por linha.
#   Scripts/partes-dos-testes.sh conferir
#       Confere a lista contra o código, sem compilar: cada item é um alvo de teste do Frila-Local
#       ou uma classe XCTestCase desse alvo, sem repetição entre as seções. Imprime as classes de
#       cada parte; a última parte é o complemento das outras, então as N somam a suíte inteira.
#   Scripts/partes-dos-testes.sh conferir-enumeracoes <suite.json> <parte-1.json> ... <parte-N.json>
#       Confere as enumerações do próprio xcodebuild (-enumerate-tests -test-enumeration-style
#       flat -test-enumeration-format json): a suíte inteira e cada parte com os seus argumentos.
#       Reprova se as partes se cruzam, se algum teste fica fora das partes, se uma parte K < N roda
#       teste fora da sua seção ou se algum item da lista não tem teste. Comando em iOS/Docs/CI.md.
#
# PARTES_LISTA e PARTES_RAIZ trocam a lista e a pasta iOS (usados pelo autoteste).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="${PARTES_RAIZ:-$SCRIPT_DIR/..}"
LISTA="${PARTES_LISTA:-$RAIZ/Tests/partes-da-ci.txt}"

# Alvos de teste do esquema Frila-Local e a pasta de código de cada um (project.yml).
ALVOS="FrilaTests=Tests/Unitarios FrilaUITests=Tests/UI"

falhar() {
  echo "ERRO: $*" >&2
  exit 1
}

uso() {
  falhar "uso: $0 total | matriz | argumentos 1..N | conferir | conferir-enumeracoes <suite.json> <parte-1.json> ... <parte-N.json>"
}

# Itens da lista, validados, no formato "K<TAB>item" (K = número da seção). Sem comentários nem
# linhas vazias. Imprime também, na primeira linha, "N<TAB>total" para quem precisa do total.
itens_com_secao() {
  [[ -f "$LISTA" ]] || falhar "lista das partes não encontrada: $LISTA"
  local resultado
  resultado="$(LISTA="$LISTA" python3 - <<'PY'
import os, re, sys

def falhar(mensagem):
    print("ERRO: " + mensagem, file=sys.stderr)
    sys.exit(1)

caminho = os.environ["LISTA"]
secao = None
secoes = []
itens = []
formato = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)?$")
with open(caminho, encoding="utf-8") as arquivo:
    for linha in arquivo:
        linha = re.sub(r"#.*", "", linha).strip()
        if not linha:
            continue
        cabecalho = re.fullmatch(r"\[parte\s+(\d+)\]", linha)
        if cabecalho:
            numero = int(cabecalho.group(1))
            if numero != len(secoes) + 1:
                falhar(f"seção [parte {numero}] fora de ordem na lista {caminho}: esperada [parte {len(secoes) + 1}]")
            secoes.append(numero)
            secao = numero
            continue
        if linha.startswith("["):
            falhar(f"cabeçalho de seção inválido na lista {caminho}: {linha}")
        if secao is None:
            falhar(f"item antes da primeira seção [parte 1] na lista {caminho}: {linha}")
        if not formato.match(linha):
            falhar(f"item fora do formato Alvo ou Alvo/Classe na lista {caminho}: {linha}")
        itens.append((secao, linha))

if not secoes:
    falhar(f"lista das partes vazia, sem seção [parte 1]: {caminho}")
vazias = [str(n) for n in secoes if not any(s == n for s, _ in itens)]
if vazias:
    falhar(f"seção sem item na lista {caminho}: [parte {', '.join(vazias)}]")
vistos = {}
repetidos = []
for s, item in itens:
    if item in vistos:
        repetidos.append(item)
    vistos[item] = s
if repetidos:
    falhar(f"item repetido na lista {caminho}: {', '.join(sorted(set(repetidos)))}")

print(f"N\t{len(secoes) + 1}")
for s, item in itens:
    print(f"{s}\t{item}")
PY
)" || exit 1
  printf '%s\n' "$resultado"
}

total() {
  local saida
  saida="$(itens_com_secao)" || exit 1
  printf '%s\n' "$saida" | awk -F'\t' '$1 == "N" { print $2 }'
}

matriz() {
  local n i saida=""
  n="$(total)" || exit 1
  for ((i = 1; i <= n; i++)); do
    saida+="${saida:+,}$i"
  done
  printf '[%s]\n' "$saida"
}

argumentos() {
  local parte="${1:-}"
  [[ "$parte" =~ ^[1-9][0-9]*$ ]] || uso
  local dados n
  dados="$(itens_com_secao)" || exit 1
  n="$(printf '%s\n' "$dados" | awk -F'\t' '$1 == "N" { print $2 }')"
  (( parte <= n )) || falhar "a lista tem $n partes; a parte $parte não existe"
  if (( parte < n )); then
    printf '%s\n' "$dados" | awk -F'\t' -v p="$parte" '$1 == p { print "-only-testing:" $2 }'
  else
    printf '%s\n' "$dados" | awk -F'\t' '$1 != "N" { print "-skip-testing:" $2 }'
  fi
}

conferir() {
  [[ $# -eq 0 ]] || uso
  local dados
  dados="$(itens_com_secao)" || exit 1

  LISTA_DADOS="$dados" RAIZ="$RAIZ" ALVOS="$ALVOS" python3 - <<'PY'
import os, re, sys

def falhar(mensagem):
    print("ERRO: " + mensagem, file=sys.stderr)
    sys.exit(1)

declaracao = re.compile(
    r"^\s*(?:@\w+\s+)*(?:(?:public|internal|open|final)\s+)*class\s+(\w+)\s*:\s*XCTestCase\b", re.M)

suite = {}
for par in os.environ["ALVOS"].split():
    alvo, pasta = par.split("=", 1)
    caminho = os.path.join(os.environ["RAIZ"], pasta)
    if not os.path.isdir(caminho):
        falhar(f"pasta do alvo {alvo} não encontrada: {caminho}")
    classes = set()
    for diretorio, _, arquivos in os.walk(caminho):
        for nome in arquivos:
            if nome.endswith(".swift"):
                with open(os.path.join(diretorio, nome), encoding="utf-8") as arquivo:
                    classes.update(declaracao.findall(arquivo.read()))
    suite[alvo] = classes

linhas = [linha.split("\t") for linha in os.environ["LISTA_DADOS"].split("\n")]
total = int(linhas[0][1])
partes = {k: {"inteiros": set(), "classes": {alvo: set() for alvo in suite}} for k in range(1, total)}
inteiros_global = set()
classes_global = {alvo: set() for alvo in suite}
for secao, item in linhas[1:]:
    k = int(secao)
    alvo, _, classe = item.partition("/")
    if alvo not in suite:
        falhar(f"alvo {alvo} da lista não é alvo de teste do Frila-Local ({', '.join(sorted(suite))})")
    if not classe:
        partes[k]["inteiros"].add(alvo)
        inteiros_global.add(alvo)
    elif classe not in suite[alvo]:
        falhar(f"classe {item} da lista não existe em {alvo} (renomeada ou apagada?)")
    else:
        partes[k]["classes"][alvo].add(classe)
        classes_global[alvo].add(classe)

for alvo in sorted(inteiros_global):
    if classes_global[alvo]:
        falhar(f"a lista tem o alvo {alvo} inteiro e também classes dele: {', '.join(sorted(classes_global[alvo]))}")

# A última parte é o complemento das outras, alvo por alvo: o alvo inteiro em alguma seção sai todo
# dela; o alvo fora da lista vai todo para ela; o alvo com classes listadas fica dividido.
ultima_inteiros = {alvo for alvo in suite if alvo not in inteiros_global and not classes_global[alvo]}
ultima_classes = {alvo: suite[alvo] - classes_global[alvo]
                  for alvo in suite if alvo not in inteiros_global and classes_global[alvo]}

def descrever(inteiros, classes_por_alvo):
    texto = [f"{alvo}: alvo inteiro" for alvo in sorted(inteiros)]
    for alvo in sorted(classes_por_alvo):
        classes = classes_por_alvo[alvo]
        if classes:
            rotulo = "classe" if len(classes) == 1 else "classes"
            texto.append(f"{alvo}: {len(classes)} {rotulo}: {', '.join(sorted(classes))}")
    return "\n  ".join(texto) if texto else "nada"

for k in range(1, total):
    print(f"Parte {k} (-only-testing da seção [parte {k}]):\n  {descrever(partes[k]['inteiros'], partes[k]['classes'])}")
print(f"Parte {total} (-skip-testing de todas as seções, todo o resto):\n  {descrever(ultima_inteiros, ultima_classes)}")
divididos = ", ".join(f"{alvo} ({len(suite[alvo])} classes)" for alvo in sorted(ultima_classes))
print(f"OK: as {total} partes somam os alvos {', '.join(sorted(suite))} inteiros, sem repetição"
      + (f"; dividido por classe: {divididos}." if divididos else "."))
PY
}

conferir_enumeracoes() {
  local dados n
  dados="$(itens_com_secao)" || exit 1
  n="$(printf '%s\n' "$dados" | awk -F'\t' '$1 == "N" { print $2 }')"
  [[ $# -eq $((n + 1)) ]] || falhar "com $n partes, são necessárias $((n + 1)) enumerações (suíte e partes 1 a $n); recebi $#"
  local arquivo
  for arquivo in "$@"; do
    [[ -f "$arquivo" ]] || falhar "enumeração não encontrada: $arquivo"
  done

  LISTA_DADOS="$dados" python3 - "$@" <<'PY'
import json, os, sys

def falhar(mensagem):
    print("ERRO: " + mensagem, file=sys.stderr)
    sys.exit(1)

def testes(caminho):
    try:
        with open(caminho, encoding="utf-8") as arquivo:
            dados = json.load(arquivo)
    except (OSError, ValueError) as erro:
        falhar(f"enumeração ilegível em {caminho}: {erro}")
    if dados.get("errors"):
        falhar(f"erro na enumeração {caminho}: {dados['errors']}")
    return {teste["identifier"]
            for valor in dados.get("values", [])
            for teste in valor.get("enabledTests", [])}

def coberto(identificador, itens):
    return any(identificador == item or identificador.startswith(item + "/") for item in itens)

def mostrar(conjunto, limite=10):
    amostra = sorted(conjunto)[:limite]
    resto = len(conjunto) - len(amostra)
    return ", ".join(amostra) + (f" e mais {resto}" if resto > 0 else "")

linhas = [linha.split("\t") for linha in os.environ["LISTA_DADOS"].split("\n")]
total = int(linhas[0][1])
itens_da_secao = {k: [] for k in range(1, total)}
for secao, item in linhas[1:]:
    itens_da_secao[int(secao)].append(item)

suite = testes(sys.argv[1])
partes = {k: testes(sys.argv[1 + k]) for k in range(1, total + 1)}

if not suite:
    falhar("a enumeração da suíte inteira não tem nenhum teste")
for k in range(1, total + 1):
    for j in range(k + 1, total + 1):
        cruzados = partes[k] & partes[j]
        if cruzados:
            falhar(f"{len(cruzados)} teste(s) nas partes {k} e {j}: {mostrar(cruzados)}")
uniao = set().union(*partes.values())
fora = suite - uniao
if fora:
    falhar(f"{len(fora)} teste(s) da suíte fora das partes: {mostrar(fora)}")
estranhos = uniao - suite
if estranhos:
    falhar(f"{len(estranhos)} teste(s) nas partes e não na suíte: {mostrar(estranhos)}")
for k in range(1, total):
    fora_da_secao = {teste for teste in partes[k] if not coberto(teste, itens_da_secao[k])}
    if fora_da_secao:
        falhar(f"{len(fora_da_secao)} teste(s) na parte {k} fora da sua seção: {mostrar(fora_da_secao)}")
    vazios = [item for item in itens_da_secao[k] if not any(coberto(teste, [item]) for teste in partes[k])]
    if vazios:
        falhar(f"item da lista sem teste na parte {k} (renomeado ou apagado?): " + ", ".join(vazios))

contagem = ", ".join(f"a parte {k} com {len(partes[k])}" for k in range(1, total + 1))
print(f"OK: {contagem}; somam os {len(suite)} testes da suíte, sem repetição.")
PY
}

case "${1:-}" in
  total) shift; [[ $# -eq 0 ]] || uso; total ;;
  matriz) shift; [[ $# -eq 0 ]] || uso; matriz ;;
  argumentos) shift; [[ $# -eq 1 ]] || uso; argumentos "$@" ;;
  conferir) shift; conferir "$@" ;;
  conferir-enumeracoes) shift; conferir_enumeracoes "$@" ;;
  *) uso ;;
esac
