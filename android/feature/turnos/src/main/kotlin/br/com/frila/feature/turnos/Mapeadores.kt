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
    val comprovanteMapeado: ComprovanteCheckin? = checkin?.let { chk ->
        val instanteCheckin = runCatching { Instant.parse(chk.feitoEm) }.getOrDefault(Instant.now())
        val distancia = chk.distanciaMetros
        val tipoVerificacao = if (distancia != null && distancia <= 200.0) {
            TipoVerificacaoCheckin.GEOLOCALIZADO
        } else {
            TipoVerificacaoCheckin.MANUAL_PENDENTE
        }
        GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instanteCheckin,
            tipoVerificacao = tipoVerificacao,
        )
    }

    return ItemTurno(
        turnoId = turnoId,
        posicaoId = posicaoId,
        inicio = Instant.parse(inicioEm),
        fim = runCatching { Instant.parse(fimEm) }.getOrNull(),
        funcaoNome = funcao.nome,
        estabelecimentoNome = contraparte.nome,
        dataHorarioFormatado = FORMATO_DATA_HORARIO.withZone(FUSO_BRASILIA).format(Instant.parse(inicioEm)),
        valorFormatado = Dinheiro(valorCentavos).formatado(),
        estado = estado,
        podeAvaliar = podeAvaliar ?: false,
        avaliacaoResposta = avaliacao?.resposta,
        comprovante = comprovanteMapeado,
    )
}
