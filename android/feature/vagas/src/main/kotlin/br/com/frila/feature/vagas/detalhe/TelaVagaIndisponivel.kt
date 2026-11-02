package br.com.frila.feature.vagas.detalhe

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
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
    const val TITULO_BARRA = "Vaga"
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
 * candidatura ou trabalho (preenchida, encerrada, cancelada ou expirada).
 */
@OptIn(ExperimentalMaterial3Api::class)
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
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosVagaIndisponivel.TITULO_BARRA,
                        style = MaterialTheme.typography.titleLarge,
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltarParaFeed,
                        modifier = Modifier.sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosVagaIndisponivel.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.grande),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = FrilaEspacamento.enorme),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
            ) {
                // Círculo com ícone de estado de 72dp
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .background(
                            color = MaterialTheme.colorScheme.surfaceContainerHigh,
                            shape = CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = null,
                        modifier = Modifier.size(32.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                Spacer(modifier = Modifier.height(FrilaEspacamento.pequeno))

                // Título com heading de acessibilidade
                Text(
                    text = textos.first,
                    style = MaterialTheme.typography.headlineSmall,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics { heading() },
                )

                // Mensagem explicativa
                Text(
                    text = textos.second,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // Ação de retorno para o feed ou tela de origem
            BotaoSecundario(
                texto = rotuloBotaoVoltar ?: TextosVagaIndisponivel.BOTAO_VOLTAR_PADRAO,
                aoClicar = aoVoltarParaFeed,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = FrilaEspacamento.grande),
            )
        }
    }
}
