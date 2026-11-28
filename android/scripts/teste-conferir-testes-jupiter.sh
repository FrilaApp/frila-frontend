#!/bin/bash
# Exercita a guarda conferir-testes-jupiter.py com um módulo sintético: o caso conforme, o @Test ignorado e o sufixo de parâmetros.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-testes-jupiter.py"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-jupiter-teste.XXXXXX")"
trap 'rm -rf "$TMPDIR_TESTE"' EXIT
ANDROID="$TMPDIR_TESTE/android"
FONTE="$ANDROID/core/exemplo/src/test/kotlin/br/com/frila/exemplo"
RELATORIOS="$ANDROID/core/exemplo/build/test-results/test"
mkdir -p "$FONTE" "$RELATORIOS"

cat > "$FONTE/ExemploTest.kt" <<'KT'
package br.com.frila.exemplo

import org.junit.jupiter.api.Test

class ExemploTest {
    @Test
    fun `roda e passa`() {
    }

    @Test
    fun `roda`() {
    }

    @Test
    fun `recebe um diretorio`(dir: java.io.File) {
    }

    @Test
    fun `tem parenteses no nome (RN06)`() {
    }

    @Test
    fun `devolve Boolean e e ignorado`() = kotlinx.coroutines.runBlocking {
        true
    }
}
KT

relatorio() {
  printf '<testsuite name="br.com.frila.exemplo.ExemploTest">\n%s\n</testsuite>\n' "$1" > "$RELATORIOS/TEST-br.com.frila.exemplo.ExemploTest.xml"
}
caso() { printf '<testcase name="%s" classname="br.com.frila.exemplo.ExemploTest" time="0.01"/>' "$1"; }

# 1. O @Test que devolve Boolean não tem relatório: reprova e diz qual.
relatorio "$(caso 'roda e passa()')$(caso 'recebe um diretorio(File)')$(caso 'tem parenteses no nome (RN06)()')"
if saida="$(python3 "$SCRIPT" --android-dir "$ANDROID" 2>&1)"; then
  echo "FALHA: o @Test ignorado deveria reprovar: $saida" >&2; exit 1
fi
[[ "$saida" == *"devolve Boolean e e ignorado"* ]] || { echo "FALHA: não apontou o teste ignorado: $saida" >&2; exit 1; }
# `roda` é prefixo de `roda e passa`, que rodou: o prefixo não pode contar como relatório de `roda`.
grep -qE ': roda$' <<<"$saida" || { echo "FALHA: não apontou o teste que é prefixo de outro: $saida" >&2; exit 1; }
[[ "$saida" != *"recebe um diretorio"* ]] || { echo "FALHA: o sufixo (File) deveria ser tolerado: $saida" >&2; exit 1; }
[[ "$saida" != *"tem parenteses"* ]] || { echo "FALHA: parenteses no nome do teste deveriam valer: $saida" >&2; exit 1; }

# 2. Com os três relatórios, aprova.
relatorio "$(caso 'roda e passa()')$(caso 'roda()')$(caso 'recebe um diretorio(File)')$(caso 'tem parenteses no nome (RN06)()')$(caso 'devolve Boolean e e ignorado()')"
saida="$(python3 "$SCRIPT" --android-dir "$ANDROID" 2>&1)" || { echo "FALHA: o caso conforme foi reprovado: $saida" >&2; exit 1; }
[[ "$saida" == *"OK: 5 @Test conferidos"* ]] || { echo "FALHA: aprovação sem a mensagem esperada: $saida" >&2; exit 1; }

# 3. Sem nenhum relatório, não aprova em silêncio.
rm -rf "$ANDROID/core/exemplo/build"
if saida="$(python3 "$SCRIPT" --android-dir "$ANDROID" 2>&1)"; then
  echo "FALHA: sem relatórios deveria falhar: $saida" >&2; exit 1
fi
[[ "$saida" == *"rode os testes antes"* ]] || { echo "FALHA: mensagem de ausência de relatórios: $saida" >&2; exit 1; }

echo "OK: guarda dos testes JUnit 5 ignorados"
