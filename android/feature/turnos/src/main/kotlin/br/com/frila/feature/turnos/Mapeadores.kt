package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.TurnoDto
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
private val FORMATO_DATA_HORARIO: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM HH:mm")

fun TurnoDto.paraItem(): ItemTurno = ItemTurno(
    turnoId = turnoId,
    funcaoNome = funcao.nome,
    estabelecimentoNome = contraparte.nome,
    dataHorarioFormatado = FORMATO_DATA_HORARIO.withZone(FUSO_BRASILIA).format(Instant.parse(inicioEm)),
    valorFormatado = Dinheiro(valorCentavos).formatado(),
    estado = estado,
    podeAvaliar = podeAvaliar ?: false,
    avaliacaoResposta = avaliacao?.resposta,
)
