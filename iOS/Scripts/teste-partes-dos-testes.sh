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

BOA="$(lista boa "# comentário" "" "FrilaTests" "  FrilaUITests/AUITests   # 4,2 min" "FrilaUITests/BUITests")"

# Caso 1: argumentos das duas partes saem da mesma lista, sem comentários nem linhas vazias
esperar_saida "argumentos da parte 1" "$(printf '%s\n' \
  "-only-testing:FrilaTests" "-only-testing:FrilaUITests/AUITests" "-only-testing:FrilaUITests/BUITests")" \
  "$BOA" argumentos 1
esperar_saida "argumentos da parte 2" "$(printf '%s\n' \
  "-skip-testing:FrilaTests" "-skip-testing:FrilaUITests/AUITests" "-skip-testing:FrilaUITests/BUITests")" \
  "$BOA" argumentos 2

# Caso 2: parte que não existe
esperar_reprovacao "parte 3" "uso:" "$BOA" argumentos 3
esperar_reprovacao "comando desconhecido" "uso:" "$BOA" dividir

# Caso 3: lista quebrada reprova antes de gerar argumento
esperar_reprovacao "item repetido" "item repetido" \
  "$(lista repetida "FrilaUITests/AUITests" "FrilaUITests/AUITests")" argumentos 1
esperar_reprovacao "item com a opção do xcodebuild" "fora do formato" \
  "$(lista opcao "-only-testing:FrilaUITests/AUITests")" argumentos 1
esperar_reprovacao "item com método" "fora do formato" \
  "$(lista metodo "FrilaUITests/AUITests/testA")" argumentos 2
esperar_reprovacao "lista só com comentários" "lista da parte 1 vazia" \
  "$(lista vazia "# nada" "")" argumentos 1
esperar_reprovacao "lista inexistente" "não encontrada" "$TMPDIR_TESTE/nao-existe.txt" argumentos 1

# Caso 4: conferência contra o código; a classe nova cai sozinha na parte 2
esperar_aprovacao "conferência da lista boa" \
  "OK: as duas partes somam os alvos FrilaTests, FrilaUITests inteiros, sem repetição; dividido por classe: FrilaUITests (3 classes)." \
  "$BOA" conferir
esperar_aprovacao "classe nova na parte 2" "FrilaUITests: 1 classe: CNovaUITests" "$BOA" conferir
esperar_aprovacao "alvo inteiro na parte 1" "FrilaTests: alvo inteiro" "$BOA" conferir
esperar_aprovacao "alvo fora da lista vai inteiro para a parte 2" \
  "Parte 2 (-skip-testing da lista, todo o resto):
  FrilaTests: alvo inteiro" "$(lista so-ui "FrilaUITests/AUITests")" conferir
esperar_reprovacao "classe renomeada" "classe FrilaUITests/ZUITests da lista não existe" \
  "$(lista renomeada "FrilaUITests/ZUITests")" conferir
esperar_reprovacao "classe de ajuda que não é XCTestCase" "classe FrilaUITests/Ajudante da lista não existe" \
  "$(lista ajudante "FrilaUITests/Ajudante")" conferir
esperar_reprovacao "alvo desconhecido" "alvo FrilaSnapshotTests da lista não é alvo de teste" \
  "$(lista alvo "FrilaSnapshotTests")" conferir
esperar_reprovacao "alvo inteiro e classe dele" "a lista tem o alvo FrilaUITests inteiro e também classes dele" \
  "$(lista inteiro-e-classe "FrilaUITests" "FrilaUITests/AUITests")" conferir
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
P1="$(enumeracao p1 "$UNIT" "$A" "$B")"
P2="$(enumeracao p2 "$C")"

esperar_aprovacao "enumerações boas" \
  "OK: parte 1 com 3 testes e parte 2 com 1; somam os 4 testes da suíte, sem repetição." \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$P2"
esperar_reprovacao "teste fora das duas partes" "1 teste(s) da suíte fora das duas partes: $C" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$(enumeracao p2-vazia)"
esperar_reprovacao "teste nas duas partes" "1 teste(s) nas duas partes: $B" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$(enumeracao p2-com-b "$B" "$C")"
esperar_reprovacao "teste nas partes e não na suíte" "nas partes e não na suíte" \
  "$BOA" conferir-enumeracoes "$(enumeracao suite-curta "$UNIT" "$A" "$B")" "$P1" "$P2"
esperar_reprovacao "parte 1 com teste fora da lista" "1 teste(s) na parte 1 fora da lista: $C" \
  "$BOA" conferir-enumeracoes "$SUITE" "$(enumeracao p1-com-c "$UNIT" "$A" "$B" "$C")" "$(enumeracao p2-nada)"
esperar_reprovacao "item da lista sem teste" "item da lista sem teste na parte 1 (renomeado ou apagado?): FrilaUITests/BUITests" \
  "$BOA" conferir-enumeracoes "$SUITE" "$(enumeracao p1-sem-b "$UNIT" "$A")" "$(enumeracao p2-com-b-c "$B" "$C")"
esperar_reprovacao "erro na enumeração" "erro na enumeração" \
  "$BOA" conferir-enumeracoes "$(enumeracao suite-erro --erro "$UNIT")" "$P1" "$P2"
esperar_reprovacao "suíte vazia" "não tem nenhum teste" \
  "$BOA" conferir-enumeracoes "$(enumeracao suite-vazia)" "$(enumeracao p1-nada)" "$(enumeracao p2-zero)"
esperar_reprovacao "enumeração inexistente" "enumeração não encontrada" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$TMPDIR_TESTE/nao-existe.json"
printf 'nao e json' > "$TMPDIR_TESTE/quebrada.json"
esperar_reprovacao "enumeração ilegível" "enumeração ilegível" \
  "$BOA" conferir-enumeracoes "$SUITE" "$P1" "$TMPDIR_TESTE/quebrada.json"

echo "OK: autoteste de partes-dos-testes.sh passou."
