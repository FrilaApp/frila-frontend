package br.com.frila.feature.vagas.feed

import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.VagaAbertaDto
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
private val FORMATO_HORARIO: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM HH:mm")

/** Converte o DTO cru da API para o item já formatado que o cartão do feed exibe. */
fun VagaAbertaDto.paraItem(): ItemVaga = ItemVaga(
    id = id,
    funcaoNome = funcao.nome,
    estabelecimentoNome = estabelecimento.nome,
    horarioFormatado = FORMATO_HORARIO.withZone(FUSO_BRASILIA).format(Instant.parse(inicioEm)),
    valorFormatado = Dinheiro(valorCentavos).formatado(),
    distanciaKm = distanciaKm,
    modo = modo,
)
