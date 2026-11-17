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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import org.koin.core.module.Module
import org.koin.dsl.module

/** Textos da abertura quando o servidor não deixa decidir a tela inicial. */
internal object TextosAbertura {
    const val TITULO_SEM_CONEXAO = "Sem conexão"
    const val SEM_CONEXAO = "Não foi possível abrir o app sem internet. Verifique sua conexão e tente novamente."
    const val TITULO_FALHA = "Não foi possível abrir o app"
    const val FALHA = "Algo deu errado ao carregar sua conta. Tente novamente em instantes."
}

/**
 * Rota de abertura (#782, #783): depois do código e a cada abertura com sessão, pergunta ao servidor quem é a
 * conta e segue para a tela do papel ([DestinoDaConta.rota]). Sem rede e sem destino guardado mostra o erro
 * com "Tentar novamente"; nunca cai em uma tela que a conta não pode usar.
 */
@Composable
internal fun RotaDeAbertura(
    avaliador: AvaliadorDeDestino,
    aoDecidir: (DestinoDaConta) -> Unit,
    aoSessaoVencida: () -> Unit = {},
    aoTerminarDeAvaliar: () -> Unit = {},
) {
    var tentativa by remember { mutableIntStateOf(0) }
    var resultado by remember { mutableStateOf<ResultadoDaAbertura?>(null) }
    LaunchedEffect(tentativa) {
        resultado = null
        val novo = avaliador.avaliar()
        // A rede devolve em outra thread; estado do Compose e navegação só na principal.
        withContext(Dispatchers.Main.immediate) {
            aoTerminarDeAvaliar()
            when (novo) {
                is ResultadoDaAbertura.Destino -> aoDecidir(novo.destino)
                ResultadoDaAbertura.SessaoVencida -> aoSessaoVencida()
                else -> resultado = novo
            }
        }
    }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        when (resultado) {
            null, is ResultadoDaAbertura.Destino, ResultadoDaAbertura.SessaoVencida -> IndicadorCarregando()
            ResultadoDaAbertura.SemConexao -> EstadoErro(
                titulo = TextosAbertura.TITULO_SEM_CONEXAO,
                mensagem = TextosAbertura.SEM_CONEXAO,
                aoTentarNovamente = { tentativa++ },
            )
            ResultadoDaAbertura.Falha -> EstadoErro(
                titulo = TextosAbertura.TITULO_FALHA,
                mensagem = TextosAbertura.FALHA,
                aoTentarNovamente = { tentativa++ },
            )
        }
    }
}

/** Avaliador do destino da conta; entra no grafo pelo fim de `todosOsModulos`. O `ServicoConta` vem de `moduloRede`. */
internal val moduloDestinoDaConta: Module = module {
    single<DestinoGuardado> {
        DestinoGuardadoEmArquivo(
            raiz = getOrNull<android.content.Context>()?.noBackupFilesDir,
            sessao = get(),
        )
    }
    single {
        val conta = get<br.com.frila.core.rede.ServicoConta>()
        val perfil = get<br.com.frila.core.rede.ServicoPerfil>()
        val membros = get<br.com.frila.core.rede.ServicoMembros>()
        avaliadorDeDestinoDaSessao(
            sessao = get(),
            descobrir = {
                avaliarDestinoDaConta(
                    buscarConta = conta::minhaConta,
                    buscarPerfilProfissional = perfil::obterMeuPerfilProfissional,
                    listarCasas = membros::listarMeusEstabelecimentos,
                )
            },
            guardado = get(),
        )
    }
}

/** O avaliador da abertura ligado à sessão do aparelho: um `401` só vira "sessão vencida" se a sessão sumiu. */
internal fun avaliadorDeDestinoDaSessao(
    sessao: br.com.frila.core.seguranca.ArmazenamentoDeSessao,
    descobrir: suspend () -> DestinoDaConta,
    guardado: DestinoGuardado,
): AvaliadorDeDestino =
    AvaliadorDeDestino(descobrir = descobrir, guardado = guardado, sessaoGuardada = sessao::estaAutenticado)
