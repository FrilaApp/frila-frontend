#!/bin/bash

# Exercita o contrato público de testes-de-interface-do-pr.sh com código, mapa e fumaça sintéticos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/testes-de-interface-do-pr.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-escolher.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: script testes-de-interface-do-pr.sh não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

RAIZ="$TMPDIR_TESTE/iOS"
mkdir -p "$RAIZ/Docs" "$RAIZ/Tests/UI" "$RAIZ/Tests/Unitarios" "$RAIZ/Sources/Fluxos/A" "$RAIZ/Sources/Fluxos/B" "$RAIZ/Sources/App" "$RAIZ/Sources/Solto"
touch "$RAIZ/Docs/Um.md" "$RAIZ/Sources/Fluxos/A/TelaA.swift" "$RAIZ/Sources/Fluxos/A/TelaAExtra.swift" "$RAIZ/Sources/Fluxos/B/TelaB.swift" \
  "$RAIZ/Sources/App/App.swift" "$RAIZ/Sources/Solto/Solto.swift" "$RAIZ/project.yml" "$RAIZ/Textos.xcstrings"
cat <<'SWIFT' > "$RAIZ/Tests/UI/AUITests.swift"
import XCTest

final class AUITests: XCTestCase {
    func testA1() {}
    func testA2() {}
}

final class A2UITests: XCTestCase {
    func testA3() {}
}
SWIFT
cat <<'SWIFT' > "$RAIZ/Tests/UI/BUITests.swift"
import XCTest

@MainActor
final class BUITests: XCTestCase {
    func testB1() {}
}
SWIFT
cat <<'SWIFT' > "$RAIZ/Tests/UI/VisualUITests.swift"
import XCTest

final class VisualUITests: XCTestCase {
    func testV() {}
}
SWIFT
cat <<'SWIFT' > "$RAIZ/Tests/UI/NoturnaUITests.swift"
import XCTest

final class NoturnaUITests: XCTestCase {
    func testN() {}
}
SWIFT
cat <<'SWIFT' > "$RAIZ/Tests/UI/Esperas.swift"
import XCTest

extension XCUIElement {}
SWIFT

MAPA_BOM="$TMPDIR_TESTE/mapa.txt"
cat <<'MAPA' > "$MAPA_BOM"
# mapa sintético
@visual = VisualUITests
@so-noturna = NoturnaUITests
Sources/App/ = @completa
project.yml = @completa
Tests/UI/Esperas.swift = @completa
Sources/Fluxos/A/ = AUITests
Sources/Fluxos/A/TelaAExtra.swift = A2UITests
Sources/Fluxos/B/*.swift = BUITests, @visual
Textos.xcstrings = @fumaca
Docs/ = @fumaca
Tests/Unitarios/ = @fumaca
MAPA
FUMACA_BOA="$TMPDIR_TESTE/fumaca.txt"
cat <<'FUMACA' > "$FUMACA_BOA"
# fumaça sintética
FrilaUITests/AUITests/testA1
FrilaUITests/BUITests
FUMACA

rodar() {
  ESCOLHER_RAIZ="$RAIZ" ESCOLHER_MAPA="${MAPA:-$MAPA_BOM}" ESCOLHER_FUMACA="${FUMACA:-$FUMACA_BOA}" "$SCRIPT" "$@" 2>&1
}

# Só stdout (a saída de erro traz o motivo de cada arquivo)
escolher() {
  local arquivos="$TMPDIR_TESTE/arquivos.txt"
  printf '%s\n' "$@" > "$arquivos"
  ESCOLHER_RAIZ="$RAIZ" ESCOLHER_MAPA="${MAPA:-$MAPA_BOM}" ESCOLHER_FUMACA="${FUMACA:-$FUMACA_BOA}" "$SCRIPT" escolher --arquivos "$arquivos" 2>/dev/null
}

esperar_escolha() {
  local descricao="$1" esperado="$2"
  shift 2
  local saida
  saida="$(escolher "$@")" || { echo "FALHA: $descricao reprovou" >&2; exit 1; }
  [[ "$saida" == "$esperado" ]] || {
    printf 'FALHA: %s\nesperado:\n%s\nobtido:\n%s\n' "$descricao" "$esperado" "$saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1" motivo="$2"
  shift 2
  local saida
  if saida="$(rodar "$@")"; then
    echo "FALHA: $descricao deveria reprovar: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida" >&2
    exit 1
  }
}

esperar_aprovacao() {
  local descricao="$1" trecho="$2"
  shift 2
  local saida
  saida="$(rodar "$@")" || { echo "FALHA: $descricao reprovou: $saida" >&2; exit 1; }
  [[ "$saida" == *"$trecho"* ]] || { echo "FALHA: $descricao aprovou sem \"$trecho\": $saida" >&2; exit 1; }
}

FUMACA_SO="-only-testing:FrilaUITests/AUITests/testA1
-only-testing:FrilaUITests/BUITests"

# Caso 1: só documento, unitário, texto ou fora de iOS/ → só a fumaça
esperar_escolha "doc" "$FUMACA_SO" iOS/Docs/Um.md
esperar_escolha "unitário" "$FUMACA_SO" iOS/Tests/Unitarios/XTests.swift
esperar_escolha "texto" "$FUMACA_SO" iOS/Textos.xcstrings
esperar_escolha "fora de iOS" "$FUMACA_SO" .github/workflows/ios.yml
esperar_escolha "diff vazio" "$FUMACA_SO"

# Caso 2: pasta mapeada soma as classes; a fumaça de método some quando a classe vem inteira
esperar_escolha "pasta A" "-only-testing:FrilaUITests/AUITests
-only-testing:FrilaUITests/BUITests" iOS/Sources/Fluxos/A/TelaA.swift
# o arquivo específico ganha da pasta dele
esperar_escolha "arquivo específico ganha da pasta" "-only-testing:FrilaUITests/A2UITests
-only-testing:FrilaUITests/AUITests/testA1
-only-testing:FrilaUITests/BUITests" iOS/Sources/Fluxos/A/TelaAExtra.swift
# glob com marcador @visual
esperar_escolha "glob com @visual" "-only-testing:FrilaUITests/AUITests/testA1
-only-testing:FrilaUITests/BUITests
-only-testing:FrilaUITests/VisualUITests" iOS/Sources/Fluxos/B/TelaB.swift

# Caso 3: arquivo de teste de interface alterado roda as classes dele
esperar_escolha "arquivo de teste" "-only-testing:FrilaUITests/A2UITests
-only-testing:FrilaUITests/AUITests
-only-testing:FrilaUITests/BUITests" iOS/Tests/UI/AUITests.swift
esperar_escolha "dois arquivos juntos" "-only-testing:FrilaUITests/A2UITests
-only-testing:FrilaUITests/AUITests
-only-testing:FrilaUITests/BUITests
-only-testing:FrilaUITests/NoturnaUITests" iOS/Tests/UI/AUITests.swift iOS/Tests/UI/NoturnaUITests.swift

# Caso 4: suíte inteira (mapa explícito e caminho sem mapa)
esperar_escolha "Sources/App" "-only-testing:FrilaUITests" iOS/Sources/App/App.swift
esperar_escolha "project.yml" "-only-testing:FrilaUITests" iOS/project.yml
esperar_escolha "Esperas" "-only-testing:FrilaUITests" iOS/Tests/UI/Esperas.swift
esperar_escolha "caminho de Sources sem mapa" "-only-testing:FrilaUITests" iOS/Sources/Solto/Solto.swift
esperar_escolha "completa vence o resto" "-only-testing:FrilaUITests" iOS/Docs/Um.md iOS/Sources/Solto/Solto.swift iOS/Sources/Fluxos/A/TelaA.swift

# Caso 5: o motivo de cada arquivo vai para a saída de erro
motivo="$(printf 'iOS/Sources/Solto/Solto.swift\n' | ESCOLHER_RAIZ="$RAIZ" ESCOLHER_MAPA="$MAPA_BOM" ESCOLHER_FUMACA="$FUMACA_BOA" "$SCRIPT" escolher --arquivos - 2>&1 >/dev/null)"
[[ "$motivo" == *"nenhum prefixo do mapa cobre este caminho: suíte inteira"* ]] || {
  echo "FALHA: a saída de erro não explica a suíte inteira: $motivo" >&2
  exit 1
}

# Caso 6: git diff contra uma base de verdade
REPO="$TMPDIR_TESTE"
git -C "$REPO" init -q -b main
git -C "$REPO" -c user.name=t -c user.email=t@example.com add -A
git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -m base
git -C "$REPO" checkout -q -b pr
printf '// mudou\n' >> "$RAIZ/Sources/Fluxos/B/TelaB.swift"
git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -am pr
saida="$(ESCOLHER_RAIZ="$RAIZ" ESCOLHER_REPO="$REPO" ESCOLHER_MAPA="$MAPA_BOM" ESCOLHER_FUMACA="$FUMACA_BOA" "$SCRIPT" escolher main 2>/dev/null)"
[[ "$saida" == "-only-testing:FrilaUITests/AUITests/testA1
-only-testing:FrilaUITests/BUITests
-only-testing:FrilaUITests/VisualUITests" ]] || {
  echo "FALHA: escolher por git diff: $saida" >&2
  exit 1
}

# Caso 7: conferir
esperar_aprovacao "conferir bom" "OK: 9 prefixos, 2 entradas de fumaça e as 5 classes de FrilaUITests cobertas." conferir
MAPA="$TMPDIR_TESTE/m1.txt"
sed 's#^Sources/Fluxos/A/ = AUITests#Sources/Fluxos/Z/ = AUITests#' "$MAPA_BOM" > "$MAPA"
esperar_reprovacao "prefixo que não existe" "prefixo do mapa que não existe no disco: iOS/Sources/Fluxos/Z/" conferir
sed 's#^Sources/Fluxos/A/ = AUITests#Sources/Fluxos/A/ = ZUITests#' "$MAPA_BOM" > "$MAPA"
esperar_reprovacao "classe que não existe" "classe ZUITests (linha de iOS/Sources/Fluxos/A/) não existe" conferir
sed 's#^Sources/Fluxos/A/ = AUITests#Sources/Fluxos/A/ = @nada#' "$MAPA_BOM" > "$MAPA"
esperar_reprovacao "destino desconhecido" "destino desconhecido na linha de iOS/Sources/Fluxos/A/: @nada" conferir
sed 's#^Sources/Fluxos/B/\*.swift#Sources/Fluxos/B/*.kt#' "$MAPA_BOM" > "$MAPA"
esperar_reprovacao "glob sem arquivo" "prefixo do mapa que não existe no disco: iOS/Sources/Fluxos/B/*.kt" conferir
sed 's#^@so-noturna = NoturnaUITests#@so-noturna = AUITests#' "$MAPA_BOM" > "$MAPA"
esperar_reprovacao "classe de interface fora do mapa" "fora do mapa, da fumaça e de @so-noturna" conferir
grep -v '^@visual' "$MAPA_BOM" > "$MAPA"
esperar_reprovacao "marcador sem definição" "falta a definição de @visual" conferir
{ cat "$MAPA_BOM"; echo "Textos.xcstrings = @fumaca"; } > "$MAPA"
esperar_reprovacao "prefixo repetido" "prefixo repetido: Textos.xcstrings" conferir
unset MAPA
FUMACA="$TMPDIR_TESTE/f1.txt"
printf 'FrilaUITests/AUITests/testZZ\n' > "$FUMACA"
esperar_reprovacao "método que não existe" "método AUITests/testZZ da fumaça não existe no código" conferir
printf 'FrilaUITests/ZUITests\n' > "$FUMACA"
esperar_reprovacao "classe da fumaça que não existe" "classe ZUITests da fumaça não existe" conferir
printf 'AUITests/testA1\n' > "$FUMACA"
esperar_reprovacao "fumaça fora do formato" "fora do formato FrilaUITests/Classe[/metodo]" conferir
printf '# nada\n' > "$FUMACA"
esperar_reprovacao "fumaça vazia" "fumaça vazia" conferir
unset FUMACA
esperar_reprovacao "comando desconhecido" "uso:" dividir
esperar_reprovacao "conferir com argumento" "uso:" conferir extra

echo "OK: autoteste de testes-de-interface-do-pr.sh passou."
