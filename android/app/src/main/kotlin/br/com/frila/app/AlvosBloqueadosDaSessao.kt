package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.rede.PerfilPublicoDto
import kotlinx.coroutines.flow.MutableStateFlow
import org.koin.compose.getKoin

/**
 * Quem a pessoa bloqueou nesta sessão (`BloqueiosDaSessao`), como estado: a rota que o lê recompõe quando alguém é bloqueado ou
 * desbloqueado, e a tela que ela monta esconde ou volta a mostrar o perfil sem recarregar. Um grafo sem o conjunto registrado (testes e
 * rotas que montam o Koin à mão) vale como ninguém bloqueado, em vez de falhar.
 */
@Composable
internal fun alvosBloqueadosDaSessao(): Set<AlvoBloqueado> {
    val koin = getKoin()
    val fluxo = remember(koin) { koin.getOrNull<BloqueiosDaSessao>()?.alvos ?: MutableStateFlow(emptySet()) }
    val alvos by fluxo.collectAsStateWithLifecycle()
    return alvos
}

/** Este perfil, como a tela o mostra (tipo e id do `PerfilPublico`), está no conjunto? */
internal fun Set<AlvoBloqueado>.bloqueia(perfil: PerfilPublicoDto): Boolean = AlvoBloqueado(tipoDeAlvoDe(perfil), perfil.id) in this
