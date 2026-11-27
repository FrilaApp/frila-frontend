package br.com.frila.feature.chamadas.casa

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ChamarProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * O trabalho de uma chamada (RN02: função, horário, local, valor, inclusos, responsável), sem o profissional
 * nem a chave. A folha de chamar monta um e a busca o reaproveita para cada um dos até 3 chamados.
 */
data class TrabalhoDaChamada(
    val funcaoId: String,
    val inicio: Instant,
    val fim: Instant,
    val local: String,
    val regiaoAdministrativa: String,
    val ponto: CoordenadaDto,
    val valorCentavos: Long,
    val incluiRefeicao: Boolean = false,
    val incluiTransporte: Boolean = false,
    val exigeMaterialProprio: Boolean = false,
    val responsavelLocal: String,
) {
    /**
     * O corpo de `chamar_profissional`. [regiaoId] é o da busca (a vaga direta o guarda, 0.2.88);
     * [confirmoRecorrencia] só vai (como `true`) depois de `409 recorrencia_nao_confirmada` (J7, RN45).
     */
    fun paraPedido(
        profissionalId: String,
        estabelecimentoId: String,
        chave: String,
        recado: String? = null,
        regiaoId: Int? = null,
        confirmoRecorrencia: Boolean = false,
    ) = ChamarProfissionalDto(
        chave = chave,
        profissionalId = profissionalId,
        estabelecimentoId = estabelecimentoId,
        funcaoId = funcaoId,
        inicioEm = inicio.truncatedTo(ChronoUnit.SECONDS).toString(),
        fimEm = fim.truncatedTo(ChronoUnit.SECONDS).toString(),
        local = local,
        regiaoAdministrativa = regiaoAdministrativa,
        regiaoId = regiaoId,
        ponto = ponto,
        valorCentavos = valorCentavos,
        incluiRefeicao = incluiRefeicao,
        incluiTransporte = incluiTransporte,
        exigeMaterialProprio = exigeMaterialProprio,
        responsavelLocal = responsavelLocal.trim(),
        recado = recado?.takeIf { it.isNotEmpty() },
        confirmoRecorrencia = if (confirmoRecorrencia) true else null,
    )
}

/** A mensagem de uma recusa de `chamar_profissional`, a mesma do iOS. Nunca carrega o corpo cru (RN15). */
internal fun mensagemDaChamada(erro: ErroDaApi): String = when {
    erro.codigo == CodigoErroAPI.CHAMADA_JA_ABERTA -> TextosChamadaCasa.JA_ABERTA
    erro.codigo == CodigoErroAPI.CHAMADA_INDISPONIVEL ||
        erro.codigo == CodigoErroAPI.PROFISSIONAL_INDISPONIVEL ||
        erro.codigo == CodigoErroAPI.NAO_ENCONTRADO -> TextosChamadaCasa.INDISPONIVEL
    erro.codigo == CodigoErroAPI.LIMITE_DE_CHAMADAS -> TextosChamadaCasa.LIMITE
    recursoDesligado(erro) -> TextosChamadaCasa.DESLIGADO
    else -> TextosChamadaCasa.ERRO
}

/** `403 sem_permissao` com `details: recurso_desligado`: o recurso está desligado no servidor (RN46). */
internal fun recursoDesligado(erro: ErroDaApi): Boolean =
    erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhesComoCodigo == CodigoErroAPI.RECURSO_DESLIGADO

/**
 * `403 sem_permissao` com `details: termos_pendentes` (0.2.90): quem busca não aceitou os Termos 1.1 ou mais novos. O app
 * mostra o aceite, chama `aceitar_termos` e repete a busca.
 */
internal fun termosPendentes(erro: ErroDaApi): Boolean =
    erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhesComoCodigo == CodigoErroAPI.TERMOS_PENDENTES

private val UUID_EM_TEXTO = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

/**
 * O `vaga_id` do trabalho que a casa já tem aberto, no `409 trabalho_ja_aberto` (0.2.95); `null` em outro erro ou quando
 * `details` não traz um uuid.
 */
internal fun vagaDoTrabalhoAberto(erro: ErroDaApi): String? =
    erro.detalhes?.takeIf { erro.codigo == CodigoErroAPI.TRABALHO_JA_ABERTO && UUID_EM_TEXTO.matches(it) }

/**
 * A recusa deixa o resultado incerto (a chamada pode ter sido criada)? Sem rede, resposta ilegível ou
 * código desconhecido: reenviar com a mesma chave devolve a mesma chamada. Qualquer outra recusa é do servidor
 * e definitiva: a próxima tentativa nasce com chave nova.
 */
internal fun resultadoIncerto(erro: ErroDaApi): Boolean =
    erro.codigo == CodigoErroAPI.SEM_REDE ||
        erro.codigo == CodigoErroAPI.RESPOSTA_INVALIDA ||
        erro.codigo == CodigoErroAPI.DESCONHECIDO
