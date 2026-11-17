#!/bin/bash
# Exercita o portão de contrato Android (conferir-contrato-android.py) com mutações sintéticas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-contrato-android.py"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTRATO_OFICIAL="$REPO_ROOT/android/contrato/openapi.yaml"
ANDROID_DIR="$REPO_ROOT/android"

TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-contrato-android-teste.XXXXXX")"
trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || { echo "FALHA: validador não executável: $SCRIPT" >&2; exit 1; }

esperar_aprovacao() {
  local saida
  if ! saida="$(python3 "$SCRIPT" "$@" 2>&1)"; then
    echo "FALHA: o caso conforme foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: conformidade total de DTOs Android com contrato OpenAPI"* ]] || {
    echo "FALHA: aprovação sem mensagem esperada: $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1" motivo="$2"
  shift 2
  local saida
  if saida="$(python3 "$SCRIPT" "$@" 2>&1)"; then
    echo "FALHA: $descricao deveria reprovar, mas passou: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida (esperava conter: '$motivo')" >&2
    exit 1
  }
}

# 1. Caso base: repositório atual em conformidade
esperar_aprovacao --contrato "$CONTRATO_OFICIAL" --android-dir "$ANDROID_DIR"

# Prepara ambiente temporário para mutações
mkdir -p "$TMPDIR_TESTE/android/core/rede/src/main/kotlin/br/com/frila/core/rede"
DTOS_FILE="$TMPDIR_TESTE/android/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt"
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"

# 2. Mutação 1: Campo obrigatório do Turno ausente (ex: id removido)
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read().replace('@SerialName(\"id\") val id: String,\n', '')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "TurnoDto sem id obrigatório" "não mapeia campos obrigatórios (required) do schema 'Turno': ['id']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"

# 3. Mutação 2: Campo inventado no TurnoDto (ex: turno_id na raiz)
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read().replace('@SerialName(\"id\") val id: String,', '@SerialName(\"id\") val id: String,\n    @SerialName(\"turno_id\") val turnoId: String,')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "TurnoDto com campo inventado turno_id" "possui campos inventados ausentes no schema 'Turno': ['turno_id']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa o ramo de parâmetros de query: campo inventado em EstabelecimentoParametrosDto
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read().replace('@SerialName(\"estabelecimento_id\") val estabelecimentoId: String,\n)\n\n/** Schema', '@SerialName(\"estabelecimento_id\") val estabelecimentoId: String,\n    @SerialName(\"pagina\") val pagina: Int,\n)\n\n/** Schema')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "EstabelecimentoParametrosDto com parâmetro inventado" "possui parâmetros ausentes em '/rpc/equipe_de_confianca': ['pagina']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa o cadastro de estabelecimento: campo obrigatório de NovoEstabelecimentoDto ausente
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read().replace('data class NovoEstabelecimentoDto(\n    @SerialName(\"nome\") val nome: String,\n    @SerialName(\"documento\") val documento: String,\n', 'data class NovoEstabelecimentoDto(\n    @SerialName(\"nome\") val nome: String,\n')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "NovoEstabelecimentoDto sem documento obrigatório" "não mapeia campos obrigatórios (required) do schema 'NovoEstabelecimento': ['documento']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa a leitura do estabelecimento: campo obrigatório de MeuEstabelecimentoDto ausente
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
alvo = 'data class MeuEstabelecimentoDto(\n    @SerialName(\"id\") val id: String,\n    @SerialName(\"nome\") val nome: String,\n    @SerialName(\"tipo\") val tipo: String,\n    @SerialName(\"endereco\") val endereco: String,\n'
assert c.count(alvo) == 1
c = c.replace(alvo, 'data class MeuEstabelecimentoDto(\n    @SerialName(\"id\") val id: String,\n    @SerialName(\"nome\") val nome: String,\n    @SerialName(\"tipo\") val tipo: String,\n')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "MeuEstabelecimentoDto sem endereco obrigatório" "não mapeia campos obrigatórios (required) do schema 'MeuEstabelecimento': ['endereco']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa a publicação de vaga: campo obrigatório de NovaVagaDto ausente
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
alvo = '    @SerialName(\"valor_centavos\") val valorCentavos: Long,\n    @SerialName(\"posicoes\") val posicoes: Int,\n    @SerialName(\"inclui_refeicao\")'
assert c.count(alvo) == 1
c = c.replace(alvo, '    @SerialName(\"posicoes\") val posicoes: Int,\n    @SerialName(\"inclui_refeicao\")')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "NovaVagaDto sem valor_centavos obrigatório" "não mapeia campos obrigatórios (required) do schema 'NovaVaga': ['valor_centavos']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa a escolha de candidato: campo obrigatório de ResultadoConfirmacaoDto ausente
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
alvo = '    @SerialName(\"turno_id\") val turnoId: String,\n    @SerialName(\"contato\") val contato: ContatoDto? = null,\n)'
assert c.count(alvo) == 1
c = c.replace(alvo, '    @SerialName(\"contato\") val contato: ContatoDto? = null,\n)')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "ResultadoConfirmacaoDto sem turno_id obrigatório" "não mapeia campos obrigatórios (required) do schema 'ResultadoConfirmacao': ['turno_id']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa o painel do estabelecimento: campo obrigatório de PainelDto ausente
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
alvo = '    @SerialName(\"vagas\") val vagas: List<VagaNoPainelDto>,\n    @SerialName(\"checkins_pendentes\") val checkinsPendentes: List<String>,\n'
assert c.count(alvo) == 1
c = c.replace(alvo, '    @SerialName(\"vagas\") val vagas: List<VagaNoPainelDto>,\n')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "PainelDto sem checkins_pendentes obrigatório" "não mapeia campos obrigatórios (required) do schema 'Painel': ['checkins_pendentes']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa a confirmação do check-in manual: campo obrigatório de ConfirmarCheckinManualDto ausente
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
alvo = 'data class ConfirmarCheckinManualDto(\n    @SerialName(\"turno_id\") val turnoId: String,\n)'
assert c.count(alvo) == 1
c = c.replace(alvo, 'data class ConfirmarCheckinManualDto(\n    @SerialName(\"vaga_id\") val vagaId: String,\n)')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "ConfirmarCheckinManualDto com campo trocado" "não mapeia campos obrigatórios (required) de '/rpc/confirmar_checkin_manual': ['turno_id']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# Restaura e testa o objeto inline que aceita nulo (`SituacaoDaConta.suspensao`, oneOf de objeto e null): campo trocado em
# SuspensaoDaContaDto reprova pelos dois lados (falta o obrigatório do contrato e sobra o inventado).
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"
python3 -c "
with open('$DTOS_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
alvo = 'data class SuspensaoDaContaDto(\n    @SerialName(\"motivo\") val motivo: String,\n'
assert c.count(alvo) == 1
c = c.replace(alvo, 'data class SuspensaoDaContaDto(\n    @SerialName(\"razao\") val razao: String,\n')
with open('$DTOS_FILE', 'w', encoding='utf-8') as f:
    f.write(c)
"
esperar_reprovacao "SuspensaoDaContaDto sem motivo obrigatório" "não mapeia campos obrigatórios (required) de 'SituacaoDaConta.suspensao': ['motivo']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"
esperar_reprovacao "SuspensaoDaContaDto com campo inventado razao" "possui campos inventados ausentes em 'SituacaoDaConta.suspensao': ['razao']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

# 3b. O portão lê todos os `Dtos*.kt` de core/rede, não só o `Dtos.kt` (DtosCheckin.kt, DtosValidarCodigo.kt e DtosPerfil.kt
# ficaram de fora e nada acusava). Os casos abaixo usam um segundo arquivo, `DtosExtra.kt`.
DIR_REDE="$TMPDIR_TESTE/android/core/rede/src/main/kotlin/br/com/frila/core/rede"
EXTRA_FILE="$DIR_REDE/DtosExtra.kt"
cp "$ANDROID_DIR/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt" "$DTOS_FILE"

cat > "$EXTRA_FILE" <<'KT'
package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class OrfaoDto(
    @SerialName("x") val x: String,
)
KT
esperar_reprovacao "DTO sem schema em outro arquivo Dtos*.kt" "DTO 'OrfaoDto' não possui schema correspondente 'Orfao'" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

cat > "$EXTRA_FILE" <<'KT'
package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CodigoDeCheckinDto(
    @SerialName("turno_id") val turnoId: String,
    @SerialName("codigo") val codigo: String,
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("segundos_restantes") val segundosRestantes: Int,
    @SerialName("campo_a_mais") val campoAMais: String,
)
KT
esperar_reprovacao "campo inventado em outro arquivo Dtos*.kt" "possui campos inventados ausentes no schema 'CodigoDeCheckin': ['campo_a_mais']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

cat > "$EXTRA_FILE" <<'KT'
package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CodigoDeCheckinDto(
    @SerialName("turno_id") val turnoId: String,
)
KT
esperar_reprovacao "campo obrigatório ausente em outro arquivo Dtos*.kt" "não mapeia campos obrigatórios (required) do schema 'CodigoDeCheckin': ['codigo', 'expira_em', 'segundos_restantes']" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

cat > "$EXTRA_FILE" <<'KT'
package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TurnoDto(
    @SerialName("id") val id: String,
)
KT
esperar_reprovacao "mesma classe em dois arquivos Dtos*.kt" "DTO 'TurnoDto' declarado em mais de um arquivo" --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"

cat > "$EXTRA_FILE" <<'KT'
package br.com.frila.core.rede

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CodigoDeCheckinDto(
    @SerialName("turno_id") val turnoId: String,
    @SerialName("codigo") val codigo: String,
    @SerialName("expira_em") val expiraEm: String,
    @SerialName("segundos_restantes") val segundosRestantes: Int,
)
KT
esperar_aprovacao --contrato "$CONTRATO_OFICIAL" --android-dir "$TMPDIR_TESTE/android"
rm -f "$EXTRA_FILE"

# 4. Mutação 3: contrato alterado sem regravar a soma
mkdir -p "$TMPDIR_TESTE/contrato"
cp "$CONTRATO_OFICIAL" "$TMPDIR_TESTE/contrato/openapi.yaml"
cp "$CONTRATO_OFICIAL.sha256" "$TMPDIR_TESTE/contrato/openapi.yaml.sha256"
esperar_aprovacao --contrato "$TMPDIR_TESTE/contrato/openapi.yaml" --android-dir "$ANDROID_DIR"
printf '\n# adulterado\n' >> "$TMPDIR_TESTE/contrato/openapi.yaml"
esperar_reprovacao "contrato adulterado sem regravar a soma" "mudou sem atualizar a soma" --contrato "$TMPDIR_TESTE/contrato/openapi.yaml" --android-dir "$ANDROID_DIR"

echo "OK: todos os testes de mutação do portão Android passaram com sucesso!"
