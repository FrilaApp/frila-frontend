#!/bin/bash

# Divide a suíte do Frila-Local nas duas partes da CI (.github/workflows/ios.yml) a partir de uma
# lista só (Tests/parte-1-da-ci.txt): a parte 1 roda o que está na lista (-only-testing) e a parte 2
# roda o resto (-skip-testing da mesma lista). Classe nova fica fora da lista e cai na parte 2.
#
# Uso:
#   Scripts/partes-dos-testes.sh argumentos 1|2
#       Imprime os argumentos do xcodebuild para a parte, um por linha.
#   Scripts/partes-dos-testes.sh conferir
#       Confere a lista contra o código, sem compilar: cada item é um alvo de teste do Frila-Local
#       ou uma classe XCTestCase desse alvo, sem repetição. Imprime as classes de cada parte; a
#       parte 2 é o complemento da parte 1, então as duas somam a suíte inteira.
#   Scripts/partes-dos-testes.sh conferir-enumeracoes <suite.json> <parte-1.json> <parte-2.json>
#       Confere três enumerações do próprio xcodebuild (-enumerate-tests -test-enumeration-style
#       flat -test-enumeration-format json): a suíte inteira e cada parte com os seus argumentos.
#       Reprova se as partes se cruzam, se algum teste fica fora das duas, se a parte 1 roda teste
#       fora da lista ou se algum item da lista não tem teste. Comando em iOS/Docs/CI.md.
#
# PARTES_LISTA e PARTES_RAIZ trocam a lista e a pasta iOS (usados pelo autoteste).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="${PARTES_RAIZ:-$SCRIPT_DIR/..}"
LISTA="${PARTES_LISTA:-$RAIZ/Tests/parte-1-da-ci.txt}"

# Alvos de teste do esquema Frila-Local e a pasta de código de cada um (project.yml).
ALVOS="FrilaTests=Tests/Unitarios FrilaUITests=Tests/UI"

falhar() {
  echo "ERRO: $*" >&2
  exit 1
}

uso() {
  falhar "uso: $0 argumentos 1|2 | conferir | conferir-enumeracoes <suite.json> <parte-1.json> <parte-2.json>"
}

# Itens da lista, sem comentários nem linhas vazias, já validados no formato.
itens() {
  [[ -f "$LISTA" ]] || falhar "lista da parte 1 não encontrada: $LISTA"
  local linhas
  linhas="$(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$LISTA" | grep -v '^$' || true)"
  [[ -n "$linhas" ]] || falhar "lista da parte 1 vazia: $LISTA"

  local invalidas repetidas
  invalidas="$(printf '%s\n' "$linhas" | grep -vE '^[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)?$' || true)"
  [[ -z "$invalidas" ]] || falhar "item fora do formato Alvo ou Alvo/Classe na lista $LISTA: $invalidas"
  repetidas="$(printf '%s\n' "$linhas" | sort | uniq -d)"
  [[ -z "$repetidas" ]] || falhar "item repetido na lista $LISTA: $repetidas"

  printf '%s\n' "$linhas"
}

argumentos() {
  local opcao
  case "${1:-}" in
    1) opcao="-only-testing" ;;
    2) opcao="-skip-testing" ;;
    *) uso ;;
  esac
  local lista item
  lista="$(itens)"
  while IFS= read -r item; do
    printf '%s:%s\n' "$opcao" "$item"
  done <<< "$lista"
}

conferir() {
  [[ $# -eq 0 ]] || uso
  local lista
  lista="$(itens)"

  LISTA_ITENS="$lista" RAIZ="$RAIZ" ALVOS="$ALVOS" python3 - <<'PY'
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

parte1 = {alvo: set() for alvo in suite}
inteiros = set()
for item in os.environ["LISTA_ITENS"].split("\n"):
    alvo, _, classe = item.partition("/")
    if alvo not in suite:
        falhar(f"alvo {alvo} da lista não é alvo de teste do Frila-Local ({', '.join(sorted(suite))})")
    if not classe:
        inteiros.add(alvo)
    elif classe not in suite[alvo]:
        falhar(f"classe {item} da lista não existe em {alvo} (renomeada ou apagada?)")
    else:
        parte1[alvo].add(classe)

for alvo in sorted(inteiros):
    if parte1[alvo]:
        falhar(f"a lista tem o alvo {alvo} inteiro e também classes dele: {', '.join(sorted(parte1[alvo]))}")

# A parte 2 é o complemento da parte 1, alvo por alvo: o alvo inteiro na lista sai todo da
# parte 2; o alvo fora da lista vai todo para ela; o alvo com classes listadas fica dividido.
parte2_inteiros = {alvo for alvo in suite if alvo not in inteiros and not parte1[alvo]}
parte2 = {alvo: suite[alvo] - parte1[alvo]
          for alvo in suite if alvo not in inteiros and parte1[alvo]}

def descrever(inteiros, classes_por_alvo):
    linhas = [f"{alvo}: alvo inteiro" for alvo in sorted(inteiros)]
    for alvo in sorted(classes_por_alvo):
        classes = classes_por_alvo[alvo]
        if classes:
            rotulo = "classe" if len(classes) == 1 else "classes"
            linhas.append(f"{alvo}: {len(classes)} {rotulo}: {', '.join(sorted(classes))}")
    return "\n  ".join(linhas) if linhas else "nada"

print(f"Parte 1 (-only-testing da lista):\n  {descrever(inteiros, parte1)}")
print(f"Parte 2 (-skip-testing da lista, todo o resto):\n  {descrever(parte2_inteiros, parte2)}")
divididos = ", ".join(f"{alvo} ({len(suite[alvo])} classes)" for alvo in sorted(parte2))
print(f"OK: as duas partes somam os alvos {', '.join(sorted(suite))} inteiros, sem repetição"
      + (f"; dividido por classe: {divididos}." if divididos else "."))
PY
}

conferir_enumeracoes() {
  [[ $# -eq 3 ]] || uso
  local arquivo lista
  for arquivo in "$@"; do
    [[ -f "$arquivo" ]] || falhar "enumeração não encontrada: $arquivo"
  done
  lista="$(itens)"

  LISTA_ITENS="$lista" python3 - "$@" <<'PY'
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

itens = os.environ["LISTA_ITENS"].split("\n")
suite, parte1, parte2 = (testes(caminho) for caminho in sys.argv[1:4])

if not suite:
    falhar("a enumeração da suíte inteira não tem nenhum teste")
cruzados = parte1 & parte2
if cruzados:
    falhar(f"{len(cruzados)} teste(s) nas duas partes: {mostrar(cruzados)}")
fora = suite - parte1 - parte2
if fora:
    falhar(f"{len(fora)} teste(s) da suíte fora das duas partes: {mostrar(fora)}")
estranhos = (parte1 | parte2) - suite
if estranhos:
    falhar(f"{len(estranhos)} teste(s) nas partes e não na suíte: {mostrar(estranhos)}")
fora_da_lista = {teste for teste in parte1 if not coberto(teste, itens)}
if fora_da_lista:
    falhar(f"{len(fora_da_lista)} teste(s) na parte 1 fora da lista: {mostrar(fora_da_lista)}")
vazios = [item for item in itens if not any(coberto(teste, [item]) for teste in parte1)]
if vazios:
    falhar("item da lista sem teste na parte 1 (renomeado ou apagado?): " + ", ".join(vazios))

print(f"OK: parte 1 com {len(parte1)} testes e parte 2 com {len(parte2)}; "
      f"somam os {len(suite)} testes da suíte, sem repetição.")
PY
}

case "${1:-}" in
  argumentos) shift; argumentos "$@" ;;
  conferir) shift; conferir "$@" ;;
  conferir-enumeracoes) shift; conferir_enumeracoes "$@" ;;
  *) uso ;;
esac
