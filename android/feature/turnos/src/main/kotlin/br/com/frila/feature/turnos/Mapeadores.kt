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

fun TurnoDto.paraItem(): ItemTurno {
    val comprovanteMapeado: ComprovanteCheckin? = checkinEm?.let { feitoEm ->
        val instanteCheckin = runCatching { Instant.parse(feitoEm) }.getOrDefault(Instant.now())
        val distancia = checkinDistanciaM?.toDouble()
        val tipoVerificacao = if (distancia != null && distancia <= 200.0) {
            TipoVerificacaoCheckin.GEOLOCALIZADO
        } else {
            TipoVerificacaoCheckin.MANUAL_PENDENTE
        }
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
