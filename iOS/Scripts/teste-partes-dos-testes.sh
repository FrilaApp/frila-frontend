#!/bin/bash

# Exercita o contrato público de partes-dos-testes.sh com listas, código e enumerações sintéticos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/partes-dos-testes.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-partes.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: script partes-dos-testes.sh não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

RAIZ="$TMPDIR_TESTE/iOS"

# Roda o script com a lista e a raiz sintéticas. Uso: rodar <lista> <argumentos...>
rodar() {
  local lista="$1"
  shift
  PARTES_RAIZ="$RAIZ" PARTES_LISTA="$lista" "$SCRIPT" "$@" 2>&1
}

esperar_saida() {
  local descricao="$1"
  local esperado="$2"
  local lista="$3"
  shift 3
  local saida
  if ! saida="$(rodar "$lista" "$@")"; then
    echo "FALHA: $descricao foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == "$esperado" ]] || {
    printf 'FALHA: %s\nesperado:\n%s\nobtido:\n%s\n' "$descricao" "$esperado" "$saida" >&2
    exit 1
  }
}

esperar_aprovacao() {
  local descricao="$1"
  local trecho="$2"
  local lista="$3"
  shift 3
  local saida
  if ! saida="$(rodar "$lista" "$@")"; then
    echo "FALHA: $descricao foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"$trecho"* ]] || {
    echo "FALHA: $descricao aprovou sem \"$trecho\": $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1"
  local motivo="$2"
  local lista="$3"
  shift 3
  local saida
  if saida="$(rodar "$lista" "$@")"; then
    echo "FALHA: $descricao deveria reprovar: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida" >&2
    exit 1
  }
}

lista() {
  local nome="$1"
  shift
  printf '%s\n' "$@" > "$TMPDIR_TESTE/$nome.txt"
  echo "$TMPDIR_TESTE/$nome.txt"
}

# Código sintético: dois alvos, uma classe de ajuda que não é XCTestCase e uma classe nova
# (CNovaUITests) que ninguém pôs na lista.
mkdir -p "$RAIZ/Tests/UI/Sub" "$RAIZ/Tests/Unitarios"
cat <<'SWIFT' > "$RAIZ/Tests/UI/AUITests.swift"
import XCTest

final class AUITests: XCTestCase {
    func testA() {}
}

final class Ajudante: NSObject {}
SWIFT
cat <<'SWIFT' > "$RAIZ/Tests/UI/Sub/BUITests.swift"
import XCTest

@MainActor
final class BUITests: XCTestCase {
    func testB() {}
}

class CNovaUITests: XCTestCase {
    func testC() {}
}
SWIFT
cat <<'SWIFT' > "$RAIZ/Tests/Unitarios/DominioTests.swift"
import Testing

struct DominioTests {
    @Test func soma() {}
}
SWIFT

# Três partes: seção 1 (unitários), seção 2 (A) e a parte 3 = o resto (B e a classe nova C).
BOA="$(lista boa "# comentário" "" "[parte 1]   # ~14 min" "FrilaTests" "" "[parte 2]" "  FrilaUITests/AUITests   # 4,2 min")"

# Caso 1: total, matriz e argumentos saem da mesma lista, sem comentários nem linhas vazias
esperar_saida "total de partes" "3" "$BOA" total
esperar_saida "matriz" "[1,2,3]" "$BOA" matriz
esperar_saida "argumentos da parte 1" "-only-testing:FrilaTests" "$BOA" argumentos 1
esperar_saida "argumentos da parte 2" "-only-testing:FrilaUITests/AUITests" "$BOA" argumentos 2
esperar_saida "argumentos da última parte" "$(printf '%s\n' "-skip-testing:FrilaTests" "-skip-testing:FrilaUITests/AUITests")" \
  "$BOA" argumentos 3
esperar_saida "duas partes (uma seção)" "$(printf '%s\n' "[1,2]")" \
  "$(lista uma-secao "[parte 1]" "FrilaTests")" matriz

# Caso 2: parte que não existe e comandos desconhecidos
esperar_reprovacao "parte 4 de 3" "a lista tem 3 partes; a parte 4 não existe" "$BOA" argumentos 4
esperar_reprovacao "parte 0" "uso:" "$BOA" argumentos 0
esperar_reprovacao "parte sem número" "uso:" "$BOA" argumentos
esperar_reprovacao "comando desconhecido" "uso:" "$BOA" dividir
esperar_reprovacao "total com argumento" "uso:" "$BOA" total extra

# Caso 3: lista quebrada reprova antes de gerar argumento
esperar_reprovacao "item repetido na mesma seção" "item repetido" \
  "$(lista repetida "[parte 1]" "FrilaUITests/AUITests" "FrilaUITests/AUITests")" argumentos 1
esperar_reprovacao "item repetido em seções diferentes" "item repetido" \
  "$(lista repetida-secoes "[parte 1]" "FrilaUITests/AUITests" "[parte 2]" "FrilaUITests/AUITests")" argumentos 1
esperar_reprovacao "item com a opção do xcodebuild" "fora do formato" \
  "$(lista opcao "[parte 1]" "-only-testing:FrilaUITests/AUITests")" argumentos 1
esperar_reprovacao "item com método" "fora do formato" \
  "$(lista metodo "[parte 1]" "FrilaUITests/AUITests/testA")" argumentos 2
esperar_reprovacao "item antes da primeira seção" "item antes da primeira seção" \
  "$(lista sem-secao "FrilaUITests/AUITests" "[parte 1]" "FrilaTests")" argumentos 1
esperar_reprovacao "seções fora de ordem" "fora de ordem" \
  "$(lista fora-de-ordem "[parte 2]" "FrilaTests")" argumentos 1
esperar_reprovacao "seção pulada" "fora de ordem" \
  "$(lista pulada "[parte 1]" "FrilaTests" "[parte 3]" "FrilaUITests/AUITests")" argumentos 1
esperar_reprovacao "seção vazia" "seção sem item" \
  "$(lista secao-vazia "[parte 1]" "FrilaTests" "[parte 2]" "# nada")" argumentos 1
esperar_reprovacao "cabeçalho inválido" "cabeçalho de seção inválido" \
  "$(lista cabecalho "[outra coisa]" "FrilaTests")" argumentos 1
esperar_reprovacao "lista só com comentários" "sem seção [parte 1]" \
  "$(lista vazia "# nada" "")" argumentos 1
esperar_reprovacao "lista inexistente" "não encontrada" "$TMPDIR_TESTE/nao-existe.txt" argumentos 1

# Caso 4: conferência contra o código; a classe nova cai sozinha na última parte
esperar_aprovacao "conferência da lista boa" \
  "OK: as 3 partes somam os alvos FrilaTests, FrilaUITests inteiros, sem repetição; dividido por classe: FrilaUITests (3 classes)." \
  "$BOA" conferir
esperar_aprovacao "classe nova na última parte" "FrilaUITests: 2 classes: BUITests, CNovaUITests" "$BOA" conferir
esperar_aprovacao "alvo inteiro numa seção" "FrilaTests: alvo inteiro" "$BOA" conferir
esperar_aprovacao "alvo fora da lista vai inteiro para a última parte" \
  "Parte 2 (-skip-testing de todas as seções, todo o resto):
  FrilaTests: alvo inteiro" "$(lista so-ui "[parte 1]" "FrilaUITests/AUITests")" conferir
esperar_reprovacao "classe renomeada" "classe FrilaUITests/ZUITests da lista não existe" \
  "$(lista renomeada "[parte 1]" "FrilaUITests/ZUITests")" conferir
esperar_reprovacao "classe de ajuda que não é XCTestCase" "classe FrilaUITests/Ajudante da lista não existe" \
  "$(lista ajudante "[parte 1]" "FrilaUITests/Ajudante")" conferir
esperar_reprovacao "alvo desconhecido" "alvo FrilaSnapshotTests da lista não é alvo de teste" \
  "$(lista alvo "[parte 1]" "FrilaSnapshotTests")" conferir
esperar_reprovacao "alvo inteiro e classe dele em seções diferentes" "a lista tem o alvo FrilaUITests inteiro e também classes dele" \
  "$(lista inteiro-e-classe "[parte 1]" "FrilaUITests" "[parte 2]" "FrilaUITests/AUITests")" conferir
esperar_reprovacao "conferir com argumento" "uso:" "$BOA" conferir extra

# Caso 5: conferência pelas enumerações do xcodebuild
enumeracao() {
  local nome="$1"
  shift
  python3 - "$TMPDIR_TESTE/$nome.json" "$@" <<'PY'
import json, sys
caminho, *ids = sys.argv[1:]
erros = []
if ids and ids[0] == "--erro":
    erros, ids = ["falha simulada"], ids[1:]
json.dump({"errors": erros, "values": [{"disabledTests": [], "testPlan": "Frila-Local",
           "enabledTests": [{"identifier": i} for i in ids]}]}, open(caminho, "w"))
PY
  echo "$TMPDIR_TESTE/$nome.json"
}

UNIT="FrilaTests/DominioTests/soma()"
A="FrilaUITests/AUITests/testA()"
B="FrilaUITests/BUITests/testB()"
C="FrilaUITests/CNovaUITests/testC()"
SUITE="$(enumeracao suite "$UNIT" "$A" "$B" "$C")"
P1="$(enumeracao p1 "$UNIT")"
P2="$(enumeracao p2 "$A")"
P3="$(enumeracao p3 "$B" "$C")"

esperar_aprovacao "enumerações boas" \
  "OK: a parte 1 com 1, a parte 2 com 1, a parte 3 com 2; somam os 4 testes da suíte, sem repetição." \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$P2" "$P3"
esperar_reprovacao "poucas enumerações" "com 3 partes, são necessárias 4 enumerações" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$P2"
esperar_reprovacao "teste fora das partes" "1 teste(s) da suíte fora das partes: $C" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$P2" "$(enumeracao p3-so-b "$B")"
esperar_reprovacao "teste em duas partes" "1 teste(s) nas partes 2 e 3: $A" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$P2" "$(enumeracao p3-com-a "$A" "$B" "$C")"
esperar_reprovacao "teste nas partes e não na suíte" "nas partes e não na suíte" \
  "$BOA" conferir-enumeracoes "$(enumeracao suite-curta "$UNIT" "$A" "$B")" "$P1" "$P2" "$P3"
esperar_reprovacao "parte intermediária com teste fora da sua seção" "1 teste(s) na parte 1 fora da sua seção: $A" \
  "$BOA" conferir-enumeracoes "$SUITE" "$(enumeracao p1-com-a "$UNIT" "$A")" "$(enumeracao p2-nada)" "$P3"
esperar_reprovacao "item da lista sem teste" "item da lista sem teste na parte 2 (renomeado ou apagado?): FrilaUITests/AUITests" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$(enumeracao p2-zero)" "$(enumeracao p3-com-tudo "$A" "$B" "$C")"
esperar_reprovacao "erro na enumeração" "erro na enumeração" \
  "$BOA" conferir-enumeracoes "$(enumeracao suite-erro --erro "$UNIT")" "$P1" "$P2" "$P3"
esperar_reprovacao "suíte vazia" "não tem nenhum teste" \
  "$BOA" conferir-enumeracoes "$(enumeracao suite-vazia)" "$(enumeracao p1-nada)" "$(enumeracao p2-nada2)" "$(enumeracao p3-nada)"
esperar_reprovacao "enumeração inexistente" "enumeração não encontrada" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$P2" "$TMPDIR_TESTE/nao-existe.json"
printf 'nao e json' > "$TMPDIR_TESTE/quebrada.json"
esperar_reprovacao "enumeração ilegível" "enumeração ilegível" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$P2" "$TMPDIR_TESTE/quebrada.json"

echo "OK: autoteste de partes-dos-testes.sh passou."
