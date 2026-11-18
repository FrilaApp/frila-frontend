package br.com.frila.feature.vagas.detalhe

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.dominio.modelo.EstadoCandidatura

/**
 * Motivo do encerramento ou indisponibilidade da vaga (paridade com `IndisponibilidadeDaVaga` do iOS).
 */
enum class MotivoIndisponibilidadeVaga {
    PREENCHIDA,
    ENCERRADA,
    NAO_ENCONTRADA,
}

/**
 * Modo de preenchimento da vaga (urgência imediata ou seleção pelo estabelecimento).
 */
enum class ModoPreenchimentoVaga {
    URGENCIA,
    SELECAO,
}

/** Textos normativos em português brasileiro (guia de voz Frila / paridade iOS). */
object TextosVagaIndisponivel {
    const val ROTULO_VOLTAR = "Voltar"
    const val BOTAO_VOLTAR_PADRAO = "Ver outras vagas perto de você"

    // Vaga preenchida
    const val PREENCHIDA_TITULO = "Vaga preenchida"
    const val PREENCHIDA_MENSAGEM_URGENCIA =
        "Esta posição acabou de ser preenchida por outro profissional. No modo urgência, quem confirma primeiro fica com a vaga."
    const val PREENCHIDA_MENSAGEM_SELECAO =
        "O estabelecimento já escolheu quem vai trabalhar nesta vaga."

    // Candidatura do profissional recusada ou expirada
    const val RECUSADA_TITULO = "O estabelecimento escolheu outra pessoa"
    const val RECUSADA_MENSAGEM = "A vaga foi preenchida, e a sua candidatura não foi escolhida."
    const val EXPIRADA_TITULO = "A seleção desta vaga foi encerrada"
    const val EXPIRADA_MENSAGEM = "A vaga fechou sem que a sua candidatura fosse escolhida."
    const val CANCELADA_TITULO = "O estabelecimento cancelou esta vaga"
    const val CANCELADA_MENSAGEM = "A sua candidatura foi encerrada junto com a vaga."

    // Vaga encerrada / não encontrada
    const val ENCERRADA_TITULO = "Vaga encerrada"
    const val ENCERRADA_MENSAGEM =
        "Esta vaga foi encerrada, cancelada ou o horário de início já passou."
    const val NAO_ENCONTRADA_MENSAGEM =
        "Esta vaga não está mais disponível. Volte para a lista e escolha outra."

    /**
     * Resolve o par (título, mensagem) de acordo com o motivo e o contexto da candidatura
     * (paridade exata com `TelaVagaIndisponivel.textos(...)` em `DestinosDoAviso.swift:182-197`).
     */
    fun resolverTextos(
        motivo: MotivoIndisponibilidadeVaga,
        candidatura: EstadoCandidatura? = null,
        modo: ModoPreenchimentoVaga? = null,
        vagaCancelada: Boolean = false,
        candidaturaExpirada: Boolean = false,
    ): Pair<String, String> {
        return when {
            candidatura == EstadoCandidatura.RECUSADA -> {
                Pair(RECUSADA_TITULO, RECUSADA_MENSAGEM)
            }
            vagaCancelada && (candidaturaExpirada || candidatura != null) -> {
                Pair(CANCELADA_TITULO, CANCELADA_MENSAGEM)
            }
            candidaturaExpirada -> {
                Pair(EXPIRADA_TITULO, EXPIRADA_MENSAGEM)
            }
            motivo == MotivoIndisponibilidadeVaga.PREENCHIDA -> {
                val mensagem = if (modo == ModoPreenchimentoVaga.SELECAO) {
                    PREENCHIDA_MENSAGEM_SELECAO
                } else {
                    PREENCHIDA_MENSAGEM_URGENCIA
                }
                Pair(PREENCHIDA_TITULO, mensagem)
            }
            motivo == MotivoIndisponibilidadeVaga.ENCERRADA -> {
                Pair(ENCERRADA_TITULO, ENCERRADA_MENSAGEM)
            }
            motivo == MotivoIndisponibilidadeVaga.NAO_ENCONTRADA -> {
                Pair(ENCERRADA_TITULO, NAO_ENCONTRADA_MENSAGEM)
            }
            else -> {
                Pair(ENCERRADA_TITULO, ENCERRADA_MENSAGEM)
            }
        }
    }
}

/**
 * Tela de Vaga Indisponível (Tela 42 do mapa de paridade v1.2 / `DestinosDoAviso.swift:116`).
 * Exibida quando o usuário toca em uma notificação de vaga que não está mais disponível para
 * candidatura ou trabalho (preenchida, encerrada, cancelada ou expirada). Barra de topo só com o voltar:
 * o fato (o título) e a dica (a mensagem) são o conteúdo, e a saída é o botão secundário.
 */
@Composable
fun TelaVagaIndisponivel(
    motivo: MotivoIndisponibilidadeVaga,
    aoVoltarParaFeed: () -> Unit,
    modifier: Modifier = Modifier,
    candidatura: EstadoCandidatura? = null,
    modo: ModoPreenchimentoVaga? = null,
    vagaCancelada: Boolean = false,
    candidaturaExpirada: Boolean = false,
    rotuloBotaoVoltar: String? = null,
) {
    val textos = TextosVagaIndisponivel.resolverTextos(
        motivo = motivo,
        candidatura = candidatura,
        modo = modo,
        vagaCancelada = vagaCancelada,
        candidaturaExpirada = candidaturaExpirada,
    )

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltarParaFeed) },
    ) { preenchimento ->
        EstadoVazio(
            titulo = textos.first,
            mensagem = textos.second,
            textoAcao = rotuloBotaoVoltar ?: TextosVagaIndisponivel.BOTAO_VOLTAR_PADRAO,
            aoClicarAcao = aoVoltarParaFeed,
            modifier = Modifier
                .padding(preenchimento)
                .verticalScroll(rememberScrollState()),
        )
    }
}
