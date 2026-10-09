#!/bin/bash

# Exercita o contrato de conferir-movimento.sh com arquivos sintéticos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-movimento.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-movimento.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: script conferir-movimento.sh não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

esperar_aprovacao() {
  local alvo="$1"
  local saida
  if ! saida="$("$SCRIPT" "$alvo" 2>&1)"; then
    echo "FALHA: o caso bom foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: todas as animações respeitam Reduzir Movimento via FrilaMovimento.animacao."* ]] || {
    echo "FALHA: aprovação sem mensagem esperada: $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1"
  local motivo="$2"
  local alvo="$3"
  local saida

  if saida="$("$SCRIPT" "$alvo" 2>&1)"; then
    echo "FALHA: $descricao deveria reprovar" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida" >&2
    exit 1
  }
}

# Caso 1: Código conforme usando FrilaMovimento.animacao
DIR_BOM="$TMPDIR_TESTE/bom"
mkdir -p "$DIR_BOM"
cat <<'SWIFT' > "$DIR_BOM/TelaConforme.swift"
import SwiftUI

struct TelaConforme: View {
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var selecionado = false

    var body: some View {
        Button("Ação") {
            withAnimation(FrilaMovimento.animacao(reduzir: reduzirMovimento)) {
                selecionado.toggle()
            }
            withAnimation(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: reduzirMovimento)) {
                selecionado = true
            }
        }
    }
}
SWIFT

esperar_aprovacao "$DIR_BOM"

# Caso 2: withAnimation solto sem argumento
DIR_RUIM_1="$TMPDIR_TESTE/ruim_sem_args"
mkdir -p "$DIR_RUIM_1"
cat <<'SWIFT' > "$DIR_RUIM_1/TelaRuim1.swift"
import SwiftUI

struct TelaRuim1: View {
    @State private var valor = 0
    var body: some View {
        Button("Trocar") {
            withAnimation {
                valor += 1
            }
        }
    }
}
SWIFT

esperar_reprovacao "withAnimation sem argumentos" "withAnimation direto sem passar por FrilaMovimento.animacao" "$DIR_RUIM_1"

# Caso 3: withAnimation solto com animação direta (ex: .spring())
DIR_RUIM_2="$TMPDIR_TESTE/ruim_com_curva"
mkdir -p "$DIR_RUIM_2"
cat <<'SWIFT' > "$DIR_RUIM_2/TelaRuim2.swift"
import SwiftUI

struct TelaRuim2: View {
    @State private var visivel = false
    var body: some View {
        Button("Animar") {
            withAnimation(.spring()) {
                visivel.toggle()
            }
        }
    }
}
SWIFT

esperar_reprovacao "withAnimation com curva direta" "withAnimation direto sem passar por FrilaMovimento.animacao" "$DIR_RUIM_2"

# Caso 4: Modificador .animation(...) solto
DIR_RUIM_3="$TMPDIR_TESTE/ruim_modificador"
mkdir -p "$DIR_RUIM_3"
cat <<'SWIFT' > "$DIR_RUIM_3/TelaRuim3.swift"
import SwiftUI

struct TelaRuim3: View {
    @State private var ativo = false
    var body: some View {
        Circle()
            .scaleEffect(ativo ? 1.2 : 1.0)
            .animation(.default, value: ativo)
    }
}
SWIFT

esperar_reprovacao "modificador .animation solto" "Modificador .animation(...) solto" "$DIR_RUIM_3"

echo "OK: autoteste de conferir-movimento.sh passou"
