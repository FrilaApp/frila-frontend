package br.com.frila.app

import android.content.Context
import android.content.Intent
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
import androidx.compose.ui.platform.LocalContext
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.feature.equipe.casa.EquipeDaCasaViewModel
import br.com.frila.feature.equipe.casa.TelaEquipeDaCasa
import br.com.frila.feature.equipe.casa.TextosEquipeDaCasa
import kotlinx.coroutines.CancellationException
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/** O que a rota da equipe da casa sabe da casa antes de abrir a tela: o nome e o papel de quem chama. */
internal sealed interface EstadoDaCasaDaRota {
    data object Carregando : EstadoDaCasaDaRota
    data class Pronto(val nome: String, val papel: PapelMembro?) : EstadoDaCasaDaRota
    data object NaoEMembro : EstadoDaCasaDaRota
    data object Falha : EstadoDaCasaDaRota
}

/**
 * Acha a casa da rota em `meus_estabelecimentos`, que traz o nome e o papel. Casa que a conta não tem vira
 * [EstadoDaCasaDaRota.NaoEMembro]; qualquer falha (sem rede, resposta ilegível, sem o serviço) vira [EstadoDaCasaDaRota.Falha],
 * nunca derruba a tela nem deixa o indicador para sempre.
 */
internal suspend fun carregarCasaDaEquipe(servicoMembros: ServicoMembros?, estabelecimentoId: String): EstadoDaCasaDaRota {
    if (servicoMembros == null) return EstadoDaCasaDaRota.Falha
    return try {
        servicoMembros.listarMeusEstabelecimentos().firstOrNull { it.id == estabelecimentoId }
            ?.let { EstadoDaCasaDaRota.Pronto(it.nome, PapelMembro.deChave(it.papel)) }
            ?: EstadoDaCasaDaRota.NaoEMembro
    } catch (erro: CancellationException) {
        throw erro
    } catch (_: Exception) {
        EstadoDaCasaDaRota.Falha
    }
}

/**
 * Rota da equipe da casa (RF21): lê a casa e o papel e só então cria o [EquipeDaCasaViewModel]. Quem não é administrador
 * chega à tela e vê só o aviso, sem botão (o ViewModel nem pede a lista). [aoCompartilhar] abre a folha de compartilhar
 * do sistema com a mensagem do convite.
 */
@Composable
internal fun RotaEquipeDaCasa(
    estabelecimentoId: String,
    servicoMembros: ServicoMembros?,
    aoVoltar: () -> Unit,
    aoCompartilhar: (Context, String) -> Unit = ::compartilharConvite,
) {
    var tentativa by remember { mutableIntStateOf(0) }
    var estado by remember(estabelecimentoId) { mutableStateOf<EstadoDaCasaDaRota>(EstadoDaCasaDaRota.Carregando) }
    LaunchedEffect(estabelecimentoId, tentativa, servicoMembros) {
        estado = EstadoDaCasaDaRota.Carregando
        estado = carregarCasaDaEquipe(servicoMembros, estabelecimentoId)
    }

    when (val atual = estado) {
        EstadoDaCasaDaRota.Carregando -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { IndicadorCarregando() }
        EstadoDaCasaDaRota.Falha -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EstadoErro(
                titulo = TextosEquipeDaCasa.ROTA_TITULO_FALHA,
                mensagem = TextosEquipeDaCasa.ROTA_FALHA,
                aoTentarNovamente = { tentativa++ },
            )
        }
        EstadoDaCasaDaRota.NaoEMembro -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EstadoErro(titulo = TextosEquipeDaCasa.ROTA_TITULO_FALHA, mensagem = TextosEquipeDaCasa.ROTA_NAO_E_MEMBRO, aoTentarNovamente = null)
        }
        is EstadoDaCasaDaRota.Pronto -> {
            val contexto = LocalContext.current
            // Uma instância por casa e papel: o ViewModel guarda o papel com que foi criado.
            val viewModel: EquipeDaCasaViewModel = koinViewModel(
                key = "equipe-da-casa-$estabelecimentoId-${atual.papel?.chave}",
                parameters = { parametersOf(estabelecimentoId, atual.papel) },
            )
            TelaEquipeDaCasa(
                viewModel = viewModel,
                nomeDaCasa = atual.nome,
                aoVoltar = aoVoltar,
                aoCompartilhar = { link -> aoCompartilhar(contexto, link) },
            )
        }
    }
}

/**
 * Entrega a mensagem do convite à folha de compartilhar do sistema (`ACTION_SEND`, texto simples). Só sai do app por
 * escolha de quem toca em "Compartilhar convite".
 */
internal fun compartilharConvite(contexto: Context, link: String) {
    val envio = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, TextosEquipeDaCasa.COMPARTILHAR_TITULO)
        putExtra(Intent.EXTRA_TEXT, link)
    }
    val folha = Intent.createChooser(envio, TextosEquipeDaCasa.COMPARTILHAR)
    if (contexto !is android.app.Activity) folha.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    contexto.startActivity(folha)
}
