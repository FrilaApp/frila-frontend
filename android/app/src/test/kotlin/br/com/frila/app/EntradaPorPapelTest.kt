package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Issues #782 e #783 (QA Android no dev, 16/11/2026): o app Android não olha o servidor para saber
 * quem é a conta, então (#782) conta que já existe cai em "Complete seu cadastro" depois do código e
 * (#783) a casa (contratante) abre o feed do profissional (`/rpc/vagas_abertas`), que o contrato
 * recusa com `422 perfil_incompativel`.
 *
 * O servidor aqui é um [MockEngine] que responde como o contrato (`iOS/Contrato/openapi.yaml`):
 * `minha_conta` 200 (ou 404 sem conta), `vagas_abertas` e `meu_perfil_profissional` com
 * `422 perfil_incompativel` para contratante, `meus_estabelecimentos` com `422 perfil_incompativel`
 * para profissional. As rotas vêm do grafo real ([AppNavegacao]); só os ViewModels de tela são
 * montados à mão. O destino da conta é decidido pelo servidor, como no iOS (`DestinoDaConta.avaliar`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class EntradaPorPapelTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var nav: NavHostController

    private enum class Papel { PROFISSIONAL, CONTRATANTE, SEM_CONTA }

    /** Caminhos pedidos ao "servidor", na ordem. */
    private val chamadas = CopyOnWriteArrayList<String>()

    private val usuario = """{"id":"11111111-1111-4111-8111-111111111111","perfil":"%s","nome":"Conta Teste","telefone":"61999990000","email":"conta@exemplo.com","nascimento":"1990-01-01","estado":"ativa"}"""
    private val perfilProfissional = """{"id":"22222222-2222-4222-8222-222222222222","usuario_id":"11111111-1111-4111-8111-111111111111","funcoes":[],"disponibilidades":[],"reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}"""
    private val casa = """[{"id":"33333333-3333-4333-8333-333333333333","nome":"Bar Teste","papel":"administrador"}]"""

    private fun erro(codigo: String, status: HttpStatusCode) =
        """{"code":"$codigo","message":"$codigo","details":null}""" to status

    private fun servidor(papel: Papel) = MockEngine { requisicao ->
        val caminho = requisicao.url.encodedPath
        chamadas += caminho
        val (corpo, status) = when {
            caminho == "/auth/v1/verify" ->
                """{"access_token":"tok","refresh_token":"ref","token_type":"bearer","expires_in":3600}""" to HttpStatusCode.OK
            caminho.endsWith("/rpc/minha_conta") -> when (papel) {
                Papel.SEM_CONTA -> erro("nao_encontrado", HttpStatusCode.NotFound)
                Papel.PROFISSIONAL -> usuario.format("profissional") to HttpStatusCode.OK
                Papel.CONTRATANTE -> usuario.format("contratante") to HttpStatusCode.OK
            }
            caminho.endsWith("/rpc/situacao_da_conta") -> """{"estado":"ativa"}""" to HttpStatusCode.OK
            caminho.endsWith("/rpc/meu_perfil_profissional") -> when (papel) {
                Papel.PROFISSIONAL -> perfilProfissional to HttpStatusCode.OK
                Papel.CONTRATANTE -> erro("perfil_incompativel", HttpStatusCode.UnprocessableEntity)
                Papel.SEM_CONTA -> erro("nao_encontrado", HttpStatusCode.NotFound)
            }
            caminho.endsWith("/rpc/meus_estabelecimentos") -> when (papel) {
                Papel.CONTRATANTE -> casa to HttpStatusCode.OK
                else -> erro("perfil_incompativel", HttpStatusCode.UnprocessableEntity)
            }
            caminho.endsWith("/rpc/vagas_abertas") -> when (papel) {
                Papel.PROFISSIONAL -> "[]" to HttpStatusCode.OK
                // Contrato (`/rpc/vagas_abertas`): "conta de contratante recebe `422 perfil_incompativel`".
                else -> erro("perfil_incompativel", HttpStatusCode.UnprocessableEntity)
            }
            else -> erro("nao_encontrado", HttpStatusCode.NotFound)
        }
        respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
    }

    private val semLocalizacao = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao() = false
        override fun isGpsAtivado() = false
    }

    private fun montar(papel: Papel, comSessaoGuardada: Boolean) {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = servidor(papel))
        val sessao = ArmazenamentoDeSessaoEmMemoria()
        if (comSessaoGuardada) sessao.salvarSessao(Sessao("tok", "ref", "bearer", 3600))
        val servicoMembros = ServicoMembros(cliente)
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<br.com.frila.core.seguranca.ArmazenamentoDeSessao> { sessao }
                        single { ServicoVagas(cliente) }
                        single { ServicoPerfil(cliente) }
                        single { servicoMembros }
                        viewModel { EntradaViewModel(ServicoAutenticacao(cliente), CoroutineScope(Dispatchers.Default)) }
                        viewModel { (email: String) ->
                            CodigoViewModel(email, ServicoAutenticacao(cliente), sessao, CoroutineScope(Dispatchers.Default))
                        }
                        viewModel { CadastroViewModel() }
                        viewModel { FeedVagasViewModel(ServicoVagas(cliente), semLocalizacao) }
                        viewModel { (id: String, nome: String?, recente: String?) ->
                            MinhasVagasViewModel(
                                estabelecimentoId = id,
                                nomeEstabelecimento = nome,
                                vagaRecemPublicadaId = recente,
                                buscarPainel = { estabelecimentoId, _, _ -> Result.success(PainelDto(estabelecimentoId, emptyList(), emptyList())) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    servicoMembros = servicoMembros,
                )
            }
        }
    }

    private fun rotaAtual(): String? {
        var rota: String? = null
        rule.runOnIdle { rota = nav.currentDestination?.route }
        return rota
    }

    /** Espera até [prazoMs] pela condição; devolve se ela ficou verdadeira (sem lançar). */
    private fun aguardar(prazoMs: Long = 4_000, condicao: () -> Boolean): Boolean =
        runCatching { rule.waitUntil(prazoMs) { condicao() } }.isSuccess

    /** Entra pela tela de código, como a pessoa faz, e espera o app sair dela. */
    private fun entrarComCodigo(): String? {
        rule.runOnIdle { nav.navigate(Rotas.codigo("conta@exemplo.com")) }
        rule.onNodeWithText("Código de 6 dígitos").performTextInput("123456")
        rule.onNodeWithText("Confirmar código").performClick()
        aguardar { rotaAtual() != Rotas.CODIGO }
        // Dá tempo de uma decisão que dependa do servidor terminar de rotear.
        aguardar(1_500) { rotaAtual() != Rotas.CADASTRO && rotaAtual() != Rotas.CODIGO }
        return rotaAtual()
    }

    // ───────────────────────── #782: depois do código ─────────────────────────

    @Test
    fun `controle - conta sem cadastro no servidor continua indo para o cadastro`() {
        montar(Papel.SEM_CONTA, comSessaoGuardada = false)

        val rota = entrarComCodigo()

        assertEquals(Rotas.CADASTRO, rota)
    }

    @Test
    fun `782 - profissional que ja tem conta nao cai em Complete seu cadastro depois do codigo`() {
        montar(Papel.PROFISSIONAL, comSessaoGuardada = false)

        val rota = entrarComCodigo()

        assertTrue(
            "o app nunca perguntou ao servidor se a conta existe (chamadas: $chamadas)",
            chamadas.any { it.endsWith("/rpc/minha_conta") },
        )
        assertNotEquals("conta existente caiu no cadastro local", Rotas.CADASTRO, rota)
        assertEquals(Rotas.FEED, rota)
    }

    @Test
    fun `782 - casa que ja tem conta nao cai em Complete seu cadastro depois do codigo`() {
        montar(Papel.CONTRATANTE, comSessaoGuardada = false)

        val rota = entrarComCodigo()

        assertNotEquals("conta existente caiu no cadastro local", Rotas.CADASTRO, rota)
    }

    // ───────────────────── #783: tela inicial por papel ─────────────────────

    @Test
    fun `783 - casa com sessao guardada abre a tela da casa e nao o feed do profissional`() {
        montar(Papel.CONTRATANTE, comSessaoGuardada = true)

        // rotaInicial(): sessão válida sem biometria abre FEED para qualquer papel.
        aguardar(3_000) { chamadas.any { it.endsWith("/rpc/vagas_abertas") } || rotaAtual() != Rotas.FEED }

        assertFalse(
            "a casa pediu /rpc/vagas_abertas e recebeu 422 perfil_incompativel (chamadas: $chamadas)",
            chamadas.any { it.endsWith("/rpc/vagas_abertas") },
        )
        assertNotEquals(Rotas.FEED, rotaAtual())
    }

    @Test
    fun `controle - profissional com sessao guardada abre o feed e le as vagas`() {
        montar(Papel.PROFISSIONAL, comSessaoGuardada = true)

        val leu = aguardar(3_000) { chamadas.any { it.endsWith("/rpc/vagas_abertas") } }

        assertTrue("o feed do profissional deveria ler as vagas (chamadas: $chamadas)", leu)
        assertEquals(Rotas.FEED, rotaAtual())
    }
}
