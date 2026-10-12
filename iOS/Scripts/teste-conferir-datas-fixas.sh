#!/bin/bash

# Exercita o contrato público de conferir-datas-fixas.sh com fixtures sintéticas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-datas-fixas.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-datas-fixas.XXXXXX")"
trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || { echo "FALHA: verificador não executável: $SCRIPT" >&2; exit 1; }

esperar_aprovacao() {
  local saida
  if ! saida="$("$SCRIPT" "$1" 2>&1)"; then
    echo "FALHA: o caso bom foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: dublês sem datas literais de 2025/2026."* ]] || {
    echo "FALHA: aprovação sem mensagem esperada: $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1" motivo="$2" alvo="$3" saida
  if saida="$("$SCRIPT" "$alvo" 2>&1)"; then
    echo "FALHA: $descricao deveria reprovar" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida" >&2
    exit 1
  }
}

# Prazos relativos, comentários, datas de contrato e relógios fixos fora do dublê.
mkdir -p "$TMPDIR_TESTE/bom/aninhado"
cat <<'SWIFT' > "$TMPDIR_TESTE/bom/aninhado/Conforme.swift"
final class MockApi {
    let prazo = relogio.agora.addingTimeInterval(3600)
    // DateComponents(year: 2026), "2025-10-10T12:00:00Z"
    /* "2026-10-10" /* DateComponents(year: 2025) */ */
    let url = "https://frila.app/{fixture}"
    let json = #"{"prazo":"relativo"}"#
}
final class ContratoTests {
    let data = "2026-10-10T12:00:00Z"
    let relogio = DateComponents(year: 2025, month: 10, day: 10)
}
final class ExclusaoDubleComplementarTests {
    let formato = "2026-10-10"
}
SWIFT
esperar_aprovacao "$TMPDIR_TESTE/bom"
esperar_aprovacao "$TMPDIR_TESTE/bom/aninhado/Conforme.swift"

cat <<'SWIFT' > "$TMPDIR_TESTE/OutrosAnos.swift"
struct StubHistorico {
    let passado = "2024-10-10T12:00:00Z"
    let futuro = DateComponents(year: 2027, month: 10, day: 10)
}
SWIFT
esperar_aprovacao "$TMPDIR_TESTE/OutrosAnos.swift"

# ISO, DataCivil e DateComponents: ambos os anos, nomes e protocolos de dublê.
cat <<'SWIFT' > "$TMPDIR_TESTE/ISO.swift"
final class DubleApi {
    let data = ISO8601DateFormatter().date(from: "2025-10-10T12:00:00Z")
}
SWIFT
esperar_reprovacao "ISO de 2025" "ISO.swift:2: data fixa no dublê: 2025-10-10" "$TMPDIR_TESTE/ISO.swift"

cat <<'SWIFT' > "$TMPDIR_TESTE/JSON.swift"
actor FakeApi {
    let json = Data("{\"gerado_em\":\"2026-10-02T12:00:00Z\"}".utf8)
}
SWIFT
esperar_reprovacao "JSON escapado" "JSON.swift:2: data fixa no dublê: 2026-10-02" "$TMPDIR_TESTE/JSON.swift"

cat <<'SWIFT' > "$TMPDIR_TESTE/Civil.swift"
final class ServicoDeTeste: ApiClienteEncaminhador, Sendable {
    let prazo = try! DataCivil("2026-10-16")
}
SWIFT
esperar_reprovacao "implementação de ApiClienteEncaminhador" "Civil.swift:2: data fixa no dublê: 2026-10-16" "$TMPDIR_TESTE/Civil.swift"

cat <<'SWIFT' > "$TMPDIR_TESTE/Date.swift"
struct StubRelogio {
    let data = Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 10))
    var componentes: DateComponents { var c = DateComponents(); c.year = 2026; return c }
}
SWIFT
esperar_reprovacao "DateComponents" "Date.swift:2: data fixa no dublê: year: 2025" "$TMPDIR_TESTE/Date.swift"
esperar_reprovacao "atribuição de year" "Date.swift:3: data fixa no dublê: .year = 2026" "$TMPDIR_TESTE/Date.swift"

cat <<'SWIFT' > "$TMPDIR_TESTE/Multilinha.swift"
enum MockResposta {
    static let json = #"""
    {"url":"https://frila.app", "prazo":"2026-10-16"}
    """#
}
SWIFT
esperar_reprovacao "string raw multilinha com URL e chaves" "Multilinha.swift:3: data fixa no dublê: 2026-10-16" "$TMPDIR_TESTE/Multilinha.swift"

# Extensões em outro arquivo também pertencem ao tipo que implementa a API.
mkdir -p "$TMPDIR_TESTE/extensao/aninhado"
cat <<'SWIFT' > "$TMPDIR_TESTE/extensao/Servico.swift"
final class ServicoDeTeste: ApiCliente {}
SWIFT
cat <<'SWIFT' > "$TMPDIR_TESTE/extensao/aninhado/Extensao.swift"
extension ServicoDeTeste {
    let data = DateComponents(year: 2026, month: 10, day: 10)
}
SWIFT
esperar_reprovacao "extensão e busca recursiva" "Extensao.swift:2: data fixa no dublê: year: 2026" "$TMPDIR_TESTE/extensao"

# Entrada inválida não pode produzir uma aprovação vazia.
mkdir -p "$TMPDIR_TESTE/vazio"
esperar_reprovacao "pasta vazia" "nenhum arquivo Swift encontrado" "$TMPDIR_TESTE/vazio"
esperar_reprovacao "alvo ausente" "alvo não encontrado" "$TMPDIR_TESTE/ausente"

echo "OK: autoteste de conferir-datas-fixas.sh (12 verificações)."
