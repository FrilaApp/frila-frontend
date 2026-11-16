// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.MeuEstabelecimentoDto
import java.time.Duration
import java.time.Instant

/** O que a folha provisória da busca decide ao tocar em "Enviar chamadas". */
internal sealed interface ResultadoDaFolha {
    data class Pronto(val trabalho: TrabalhoDaChamada, val recado: String?) : ResultadoDaFolha

    /** O primeiro motivo que impede o envio, no texto de [TextosChamadaCasa]. */
    data class Falta(val motivo: String) : ResultadoDaFolha
}

/**
 * Valida os campos da folha com as mesmas regras de [EstadoChamadaDireta] (valor, total confirmado, responsável,
 * início a 2 h ou mais, turno de 2 a 16 h, recado até 300 caracteres) e monta o [TrabalhoDaChamada] de todos os
 * selecionados. O início e o término vêm como o texto "dd/mm/aaaa hh:mm" no fuso do DF.
 */
internal fun validarFolhaDaBusca(
    funcaoId: String?,
    casa: MeuEstabelecimentoDto?,
    valorTexto: String,
    totalConfirmado: Boolean,
    inicioTexto: String,
    fimTexto: String,
    responsavel: String,
    recado: String,
    agora: Instant,
): ResultadoDaFolha {
    if (funcaoId == null || casa == null) return ResultadoDaFolha.Falta(TextosChamadaCasa.BUSCA_SEM_CASA)
    val valor = ValorEmReais.centavos(valorTexto) ?: 0L
    val inicio = lerDataEHora(inicioTexto)
    val fim = lerDataEHora(fimTexto)
    return when {
        valor <= 0 -> ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_VALOR)
        !totalConfirmado -> ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL)
        responsavel.isBlank() -> ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_RESPONSAVEL)
        inicio == null || fim == null -> ResultadoDaFolha.Falta(TextosChamadaCasa.BUSCA_DATA_INVALIDA)
        Duration.between(agora, inicio) < EstadoChamadaDireta.ANTECEDENCIA_MINIMA ->
            ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_ANTECEDENCIA)
        Duration.between(inicio, fim) !in EstadoChamadaDireta.DURACAO_MINIMA..EstadoChamadaDireta.DURACAO_MAXIMA ->
            ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_DURACAO)
        recado.length > EstadoChamadaDireta.TAMANHO_MAXIMO_DO_RECADO -> ResultadoDaFolha.Falta(TextosChamadaCasa.RECADO_LONGO)
        else -> ResultadoDaFolha.Pronto(
            trabalho = TrabalhoDaChamada(
                funcaoId = funcaoId,
                inicio = inicio,
                fim = fim,
                local = casa.endereco,
                regiaoAdministrativa = casa.regiaoAdministrativa,
                ponto = casa.ponto,
                valorCentavos = valor,
                responsavelLocal = responsavel.trim(),
            ),
            recado = recado.trim().takeIf { it.isNotEmpty() },
        )
    }
}
