package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.qualifier.named
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get
import java.util.Collections
import kotlin.reflect.full.memberProperties
import kotlin.reflect.jvm.isAccessible

/**
 * #789 (risco alto: sessão). Com o grafo de produção: a conta A entra, sai pelo caminho real do app
 * ("Sair" do perfil, exclusão concluída), a conta B entra no mesmo processo. Toda chamada depois da
 * saída usa só o token de B, e o que era da sessão de A (cliente Ktor, corrotinas da sessão) some.
 * Só o motor HTTP é trocado por um [MockEngine], para ler o cabeçalho `Authorization` de cada pedido.
 */
class SairDaContaTrocaDeContaTest : KoinTest {

    private val autorizacoes: MutableList<String?> = Collections.synchronizedList(mutableListOf())

    private val moduloLocalizacaoFalso = module {
        single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
        single<GerenciadorGeofencingTurnos> { mockk(relaxed = true) }
    }

    /** O mesmo gestor do `moduloRede`, só com o motor falso. Carregado depois, sobrescreve o de produção. */
    private val moduloMotorFalso = module {
        single {
            GestorClienteKtor {
                ClienteSupabase(
                    baseUrl = "https://frila.supabase.co",
                    apiKey = "chave-anonima-de-teste",
                    armazenamentoDeSessao = get(),
                    engine = MockEngine { pedido ->
                        autorizacoes += pedido.headers[HttpHeaders.Authorization]
                        respond("{}", HttpStatusCode.OK)
                    },
                )
            }
        }
    }

    private fun iniciar() {
        startKoin {
            allowOverride(true)
            modules(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoFalso, moduloFeatures, moduloMotorFalso, moduloDestinoDaConta)
        }
    }

    private fun sessao(conta: String) = Sessao(
        accessToken = "access-$conta",
        refreshToken = "refresh-$conta",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = null,
    )

    private suspend fun chamarApi() {
        val cliente = get<ClienteSupabase>()
        cliente.http.get(cliente.urlRpc("minha_conta"))
    }

    @AfterEach
    fun depoisDeCada() {
        stopKoin()
    }

    @Test
    fun `sair do perfil e entrar com outra conta manda so o token da nova conta`() = runBlocking {
        iniciar()
        val sessao = get<ArmazenamentoDeSessao>()
        sessao.salvarSessao(sessao("A"))
        chamarApi()
        val clienteDeA = get<GestorClienteKtor>().clienteAtual
        val tarefaDaSessaoDeA = get<CoroutineScope>(named(ESCOPO_DA_SESSAO)).launch { delay(60_000) }

        get<PerfilViewModel>().aoDeslogar()

        assertNull(sessao.obterSessao())
        assertTrue(clienteDeA.estaFechado, "o cliente Ktor da conta A tem de ser fechado no Sair")
        tarefaDaSessaoDeA.join()
        assertTrue(tarefaDaSessaoDeA.isCancelled, "as corrotinas da sessão de A têm de parar no Sair")

        sessao.salvarSessao(sessao("B"))
        chamarApi()
        chamarApi()

        assertEquals(listOf("Bearer access-A", "Bearer access-B", "Bearer access-B"), autorizacoes.toList())
    }

    @Test
    fun `exclusao de conta concluida limpa o cliente da conta que saiu`() = runBlocking {
        iniciar()
        val sessao = get<ArmazenamentoDeSessao>()
        sessao.salvarSessao(sessao("A"))
        chamarApi()
        val clienteDeA = get<GestorClienteKtor>().clienteAtual

        // `aoConcluir` é o que a tela roda depois do 202 do servidor (ver ExclusaoDeContaViewModel).
        val viewModel = get<ExclusaoDeContaViewModel>()
        @Suppress("UNCHECKED_CAST")
        val aoConcluir = ExclusaoDeContaViewModel::class.memberProperties
            .single { it.name == "aoConcluir" }
            .apply { isAccessible = true }
            .call(viewModel) as () -> Unit
        aoConcluir()

        assertNull(sessao.obterSessao())
        assertTrue(clienteDeA.estaFechado, "o cliente Ktor da conta excluída tem de ser fechado")
        sessao.salvarSessao(sessao("B"))
        chamarApi()
        assertEquals(listOf("Bearer access-A", "Bearer access-B"), autorizacoes.toList())
    }
}
