#!/bin/bash

# Exercita o contrato público de conferir-textos.sh com arquivos e pastas sintéticos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-textos.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-textos.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: script conferir-textos.sh não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

esperar_aprovacao() {
  local alvo="$1"
  local saida
  if ! saida="$("$SCRIPT" "$alvo" 2>&1)"; then
    echo "FALHA: o caso bom foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: textos no bundle da Apresentação e tokens em conformidade."* ]] || {
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

# Caso 1: código 100% conforme
DIR_BOM="$TMPDIR_TESTE/bom"
mkdir -p "$DIR_BOM"
cat <<'SWIFT' > "$DIR_BOM/TelaBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaBoa: View {
    let titulo = String(localized: "Título", bundle: bundleLocal)
    var body: some View {
        VStack {
            Text("Constante", bundle: bundleLocal).font(.largeTitle.bold())
            Text(verbatim: titulo).foregroundStyle(FrilaCor.primaria)
            Text(verbatim: "1 vaga aberta")
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM"

# Caso 2: String(localized:) sem bundle
DIR_RUIM_STRING="$TMPDIR_TESTE/ruim_string"
mkdir -p "$DIR_RUIM_STRING"
cat <<'SWIFT' > "$DIR_RUIM_STRING/TelaSemBundle.swift"
import SwiftUI

struct TelaSemBundle: View {
    let texto = String(localized: "Texto sem bundle")
    var body: some View {
        Text(verbatim: texto)
    }
}
SWIFT
esperar_reprovacao "String(localized:) sem bundle" "String(localized:) sem bundle" "$DIR_RUIM_STRING"

# Caso 3: LocalizedStringKey embrulhada
DIR_RUIM_KEY="$TMPDIR_TESTE/ruim_key"
mkdir -p "$DIR_RUIM_KEY"
cat <<'SWIFT' > "$DIR_RUIM_KEY/TelaKey.swift"
import SwiftUI

struct TelaKey: View {
    let chave = LocalizedStringKey("chave")
    var body: some View {
        EmptyView()
    }
}
SWIFT
esperar_reprovacao "LocalizedStringKey embrulhada" "LocalizedStringKey embrulhada" "$DIR_RUIM_KEY"

# Caso 4: Text() sem bundle e sem verbatim
DIR_RUIM_TEXT="$TMPDIR_TESTE/ruim_text"
mkdir -p "$DIR_RUIM_TEXT"
cat <<'SWIFT' > "$DIR_RUIM_TEXT/TelaText.swift"
import SwiftUI

struct TelaText: View {
    let texto: String
    var body: some View {
        Text(texto)
    }
}
SWIFT
esperar_reprovacao "Text() sem bundle e sem verbatim" "Text() sem bundle e sem verbatim" "$DIR_RUIM_TEXT"

# Caso 5: Fonte de tamanho fixo
DIR_RUIM_FONTE="$TMPDIR_TESTE/ruim_fonte"
mkdir -p "$DIR_RUIM_FONTE"
cat <<'SWIFT' > "$DIR_RUIM_FONTE/TelaFonte.swift"
import SwiftUI

struct TelaFonte: View {
    var body: some View {
        Text(verbatim: "Exemplo").font(.system(size: 42))
    }
}
SWIFT
esperar_reprovacao "fonte de tamanho fixo" "Fonte de tamanho fixo" "$DIR_RUIM_FONTE"

# Caso 6: Cor fora dos tokens
DIR_RUIM_COR="$TMPDIR_TESTE/ruim_cor"
mkdir -p "$DIR_RUIM_COR"
cat <<'SWIFT' > "$DIR_RUIM_COR/TelaCor.swift"
import SwiftUI

struct TelaCor: View {
    var body: some View {
        Text(verbatim: "Exemplo").foregroundStyle(.red)
    }
}
SWIFT
esperar_reprovacao "cor fora dos tokens" "Cor fora dos tokens" "$DIR_RUIM_COR"

echo "OK: autoteste de conferir-textos.sh passou"
