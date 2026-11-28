package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.dominio.modelo.GeradorComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.TurnoDto
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
private val FORMATO_DATA_HORARIO: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM HH:mm")
private val FORMATO_HORARIO: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

/**
 * v1SJQkm7: o intervalo do turno no fuso de Brasília, como o `FormatadorFrila.intervalo` do iOS: "20/11 18:00 – 23:00", e com o dia
 * do fim quando ele passa da meia-noite ("20/11 22:00 – 21/11 02:00"). Sem fim legível, só o início.
 */
internal fun intervaloDoTurno(inicio: Instant, fim: Instant?): String {
    val inicioLocal = inicio.atZone(FUSO_BRASILIA)
    val textoInicio = FORMATO_DATA_HORARIO.format(inicioLocal)
    val fimLocal = fim?.atZone(FUSO_BRASILIA) ?: return textoInicio
    val formatoDoFim = if (fimLocal.toLocalDate() == inicioLocal.toLocalDate()) FORMATO_HORARIO else FORMATO_DATA_HORARIO
    return "$textoInicio – ${formatoDoFim.format(fimLocal)}"
}

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
        // `checkin_em` não nulo: o check-in foi feito. Se a hora não lê, o comprovante existe (a tela segue em "presença marcada", com o
        // check-out disponível) e a hora fica desconhecida; nunca "agora", que mostraria um horário que ninguém registrou. Só
        // `checkin_em` nulo é "sem check-in".
        val instanteCheckin = runCatching { instanteDoServidor(feitoEm) }.getOrNull()
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

    val inicio = instanteDoServidor(vaga.inicioEm)
    val fim = runCatching { instanteDoServidor(vaga.fimEm) }.getOrNull()
    return ItemTurno(
        turnoId = id,
        posicaoId = posicaoId,
        inicio = inicio,
        fim = fim,
        funcaoNome = vaga.funcao,
        estabelecimentoNome = contraparte.nome,
        dataHorarioFormatado = intervaloDoTurno(inicio, fim),
        valorFormatado = Dinheiro(valorAcordadoCentavos).formatado(),
        estado = estado ?: "confirmada",
        podeAvaliar = podeAvaliar,
        avaliacaoResposta = avaliacao?.resposta,
        comprovante = comprovanteMapeado,
        pontoDaVaga = vaga.ponto?.let { Coordenada(latitude = it.latitude, longitude = it.longitude) },
        local = vaga.local,
        contraparteId = contraparte.id,
        checkoutEm = checkoutEm?.let { runCatching { instanteDoServidor(it) }.getOrNull() },
        aCaminhoEm = aCaminhoEm?.let { runCatching { instanteDoServidor(it) }.getOrNull() },
        vagaId = vaga.id,
    )
}
