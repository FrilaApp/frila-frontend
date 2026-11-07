package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.dominio.modelo.GeradorComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.rede.TurnoDto
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
private val FORMATO_DATA_HORARIO: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM HH:mm")

/**
 * Mapeia a verificação do check-in a partir do backend (RN06/RN22, migrations 20260925000000 e 20260928160000).
 *
 * Regras do backend:
 * - até 200m: tipo 'geolocalizado', verificacao 'verificado' -> [TipoVerificacaoCheckin.GEOLOCALIZADO]
 * - manual pendente: tipo 'manual', verificacao 'pendente' -> [TipoVerificacaoCheckin.MANUAL_PENDENTE]
 * - manual confirmado: verificacao 'verificado' com tipo 'manual' ou 'checkinConfirmadoEm' preenchido -> [TipoVerificacaoCheckin.MANUAL_CONFIRMADO]
 * - manual sem confirmação até fechamento: verificacao 'nao_verificado' -> [TipoVerificacaoCheckin.NAO_VERIFICADO]
 * - valor desconhecido (backend novo): cai no estado mais conservador ([TipoVerificacaoCheckin.NAO_VERIFICADO]), sem quebrar a tela.
 *
 * A distância calculada não é a fonte da verdade para o status de confirmação.
 */
fun mapearTipoVerificacaoCheckin(
    verificacao: String,
    checkinTipo: String? = null,
    checkinConfirmadoEm: String? = null,
): TipoVerificacaoCheckin {
    return when (verificacao) {
        "verificado" -> {
            when {
                checkinTipo == "manual" -> TipoVerificacaoCheckin.MANUAL_CONFIRMADO
                checkinTipo == "geolocalizado" -> TipoVerificacaoCheckin.GEOLOCALIZADO
                checkinConfirmadoEm != null -> TipoVerificacaoCheckin.MANUAL_CONFIRMADO
                else -> TipoVerificacaoCheckin.GEOLOCALIZADO
            }
        }
        "pendente" -> TipoVerificacaoCheckin.MANUAL_PENDENTE
        "nao_verificado" -> TipoVerificacaoCheckin.NAO_VERIFICADO
        else -> TipoVerificacaoCheckin.NAO_VERIFICADO
    }
}

fun TurnoDto.paraItem(): ItemTurno {
    val comprovanteMapeado: ComprovanteCheckin? = checkinEm?.let { feitoEm ->
        val instanteCheckin = runCatching { Instant.parse(feitoEm) }.getOrDefault(Instant.now())
        val tipoVerificacao = mapearTipoVerificacaoCheckin(
            verificacao = verificacao,
            checkinTipo = checkinTipo,
            checkinConfirmadoEm = checkinConfirmadoEm,
        )
        GeradorComprovanteCheckin.gerar(
            turnoId = id,
            registradoEm = instanteCheckin,
            tipoVerificacao = tipoVerificacao,
        )
    }

    return ItemTurno(
        turnoId = id,
        posicaoId = posicaoId,
        inicio = Instant.parse(vaga.inicioEm),
        fim = runCatching { Instant.parse(vaga.fimEm) }.getOrNull(),
        funcaoNome = vaga.funcao,
        estabelecimentoNome = contraparte.nome,
        dataHorarioFormatado = FORMATO_DATA_HORARIO.withZone(FUSO_BRASILIA).format(Instant.parse(vaga.inicioEm)),
        valorFormatado = Dinheiro(valorAcordadoCentavos).formatado(),
        estado = estado ?: "confirmada",
        podeAvaliar = podeAvaliar,
        avaliacaoResposta = avaliacao?.resposta,
        comprovante = comprovanteMapeado,
    )
}
