package br.com.frila.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.PublicarVagaViewModel
import br.com.frila.feature.vagas.publicacao.TelaPublicarVaga
import kotlinx.coroutines.CancellationException
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/** Textos da carga do estabelecimento antes do formulário de publicação. */
internal object TextosPublicarVagaDaRota {
    const val CARREGANDO = "Carregando o estabelecimento…"
    const val TITULO_FALHA = "Não foi possível abrir a publicação"
    const val FALHA = "Não foi possível carregar os dados do estabelecimento. Verifique sua conexão e tente novamente."
    const val SEM_PERMISSAO = "Você não é membro deste estabelecimento, então não pode publicar vagas nele."
}

/** O que o perfil sabe sobre as casas da conta, para decidir quais atalhos de contratante mostrar. */
internal sealed interface CasasDaConta {
    /** Não foi possível saber (profissional, sem rede, sem o serviço): nenhum atalho de contratante. */
    data object Desconhecidas : CasasDaConta

    /** Contratante sem estabelecimento: pode cadastrar o primeiro. */
    data object Nenhuma : CasasDaConta

    /** Primeira casa por nome, para a equipe e a publicação. */
    data class Primeira(val id: String) : CasasDaConta
}

/**
 * Casas da conta (a lista vem ordenada por nome). Qualquer falha (conta de profissional recebe `422
 * perfil_incompativel`, sem rede, resposta ilegível, sem o serviço no grafo) é [CasasDaConta.Desconhecidas]:
 * o perfil nunca quebra por causa disso, e conta de profissional nunca é convidada a cadastrar uma casa.
 */
internal suspend fun buscarCasasDaConta(servicoMembros: ServicoMembros?): CasasDaConta = try {
    servicoMembros?.listarMeusEstabelecimentos()?.firstOrNull()?.id
        ?.let { CasasDaConta.Primeira(it) }
        ?: if (servicoMembros == null) CasasDaConta.Desconhecidas else CasasDaConta.Nenhuma
} catch (erro: CancellationException) {
    throw erro
} catch (_: Exception) {
    CasasDaConta.Desconhecidas
}

internal sealed interface EstadoDoEstabelecimentoDaRota {
    data object Carregando : EstadoDoEstabelecimentoDaRota
    data class Pronto(val estabelecimento: EstabelecimentoDaVaga) : EstadoDoEstabelecimentoDaRota
    data class Falha(val semPermissao: Boolean) : EstadoDoEstabelecimentoDaRota
}

/** Lê `meu_estabelecimento`; qualquer falha vira [EstadoDoEstabelecimentoDaRota.Falha], nunca derruba a tela. */
internal suspend fun carregarEstabelecimentoDaVaga(
    servicoMembros: ServicoMembros?,
    estabelecimentoId: String,
): EstadoDoEstabelecimentoDaRota {
    if (servicoMembros == null) return EstadoDoEstabelecimentoDaRota.Falha(semPermissao = false)
    return try {
        val casa = servicoMembros.meuEstabelecimento(estabelecimentoId)
        EstadoDoEstabelecimentoDaRota.Pronto(
            EstabelecimentoDaVaga(
                id = casa.id,
                endereco = casa.endereco,
                regiaoAdministrativa = casa.regiaoAdministrativa,
                ponto = casa.ponto,
            ),
        )
    } catch (erro: CancellationException) {
        throw erro
    } catch (erro: ErroDaApi) {
        EstadoDoEstabelecimentoDaRota.Falha(semPermissao = erro.codigo == CodigoErroAPI.SEM_PERMISSAO)
    } catch (_: Exception) {
        // Corpo que não é JSON ou campo ausente escapam do ErroDaApi; sem isto o spinner ficaria para sempre.
        EstadoDoEstabelecimentoDaRota.Falha(semPermissao = false)
    }
}

/**
 * Rota de publicação de vaga: lê o estabelecimento da rota e só então cria o [PublicarVagaViewModel]
 * (que precisa do endereço, da Região Administrativa e do ponto, não só do id). Falha de carga mostra
 * o erro com "Tentar novamente"; quem não é membro (`403 sem_permissao`) vê o motivo, sem retentativa.
 * A confirmação "Vaga publicada." fica na própria tela, e o contratante sai por "Voltar".
 */
@Composable
internal fun RotaPublicarVaga(
    estabelecimentoId: String,
    servicoMembros: ServicoMembros?,
    aoVoltar: () -> Unit,
) {
    var tentativa by remember { mutableIntStateOf(0) }
    var estado by remember(estabelecimentoId) { mutableStateOf<EstadoDoEstabelecimentoDaRota>(EstadoDoEstabelecimentoDaRota.Carregando) }
    LaunchedEffect(estabelecimentoId, tentativa, servicoMembros) {
        estado = EstadoDoEstabelecimentoDaRota.Carregando
        estado = carregarEstabelecimentoDaVaga(servicoMembros, estabelecimentoId)
    }

    when (val atual = estado) {
        EstadoDoEstabelecimentoDaRota.Carregando -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            IndicadorCarregando()
        }
        is EstadoDoEstabelecimentoDaRota.Falha -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EstadoErro(
                titulo = TextosPublicarVagaDaRota.TITULO_FALHA,
                mensagem = if (atual.semPermissao) TextosPublicarVagaDaRota.SEM_PERMISSAO else TextosPublicarVagaDaRota.FALHA,
                aoTentarNovamente = if (atual.semPermissao) null else { { tentativa++ } },
            )
        }
        is EstadoDoEstabelecimentoDaRota.Pronto -> {
            val viewModel: PublicarVagaViewModel = koinViewModel(parameters = { parametersOf(atual.estabelecimento) })
            TelaPublicarVaga(viewModel = viewModel, aoPublicar = { }, aoVoltar = aoVoltar)
        }
    }
}
