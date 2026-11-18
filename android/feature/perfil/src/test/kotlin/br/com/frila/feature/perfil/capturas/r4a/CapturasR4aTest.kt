package br.com.frila.feature.perfil.capturas.r4a

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.VerificacaoIdentidade
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoEmMemoria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MidiaDto
import br.com.frila.feature.perfil.ConteudoPontoBase
import br.com.frila.feature.perfil.DisponibilidadeBiometrica
import br.com.frila.feature.perfil.EstadoPontoBase
import br.com.frila.feature.perfil.EtapaDaFoto
import br.com.frila.feature.perfil.MotivoDeBloqueioLocal
import br.com.frila.feature.perfil.OpcaoDePontoBase
import br.com.frila.feature.perfil.TelaAjudaPerfil
import br.com.frila.feature.perfil.TelaFotoDePerfil
import br.com.frila.feature.perfil.TextosDaFotoDePerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.TelaPerfil
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R4a (perfil do profissional e telas ligadas a ele) num Pixel de 411 × 914 dp, no claro. Sem
 * `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar. As capturas "completo" usam
 * uma tela alta para mostrar a rolagem inteira de uma vez.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR4aTest {

    @get:Rule
    val compose = createComposeRule()

    private val perfilJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "usuario_id": "22222222-2222-2222-2222-222222222222",
          "funcoes": [
            {"id": "f1", "nome": "Garçom", "categoria": "Salão"},
            {"id": "f2", "nome": "Bartender", "categoria": "Bar"}
          ],
          "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
          "disponibilidades": [],
          "reputacao": {
            "positivas": 7, "total": 8, "taxa_comparecimento": 0.95,
            "turnos_considerados": 8, "turnos_realizados": 8
          }
        }
    """.trimIndent()

    // Dado sintético: nenhuma pessoa real.
    private val contaJson =
        """{"id":"u1","perfil":"profissional","nome":"Juliana Ramos","telefone":"61999990000","email":"j@exemplo.com","nascimento":"1990-01-01","estado":"ativa"}"""

    private fun cliente(corpo: String, status: HttpStatusCode = HttpStatusCode.OK) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine {
            respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        },
    )

    private fun criarViewModel(
        perfil: String = perfilJson,
        status: HttpStatusCode = HttpStatusCode.OK,
        conta: String = contaJson,
    ) = PerfilViewModel(
        servicoPerfil = ServicoPerfil(cliente(perfil, status)),
        servicoTurnos = ServicoTurnos(cliente("[]")),
        armazenamentoDeSessao = mockk(relaxed = true),
        escopo = CoroutineScope(Dispatchers.Default),
        preferenciasNotificacao = GerenciadorPreferenciasNotificacaoEmMemoria(),
        obterAvatarSalvo = { null },
        servicoConta = ServicoConta(cliente(conta)),
    )

    @Composable
    private fun Perfil(
        viewModel: PerfilViewModel,
        verificacao: VerificacaoIdentidade? = null,
        podeSolicitarSelo: Boolean = false,
    ) {
        TelaPerfil(
            viewModel = viewModel,
            aoDeslogar = {},
            aoAbrirAjuda = {},
            aoAbrirEquipe = null,
            aoAbrirChamadasDiretas = {},
            aoAbrirApresentacao = {},
            aoAbrirFotoDePerfil = {},
            aoAbrirPontoBase = {},
            recursoSeloHabilitado = true,
            verificacaoIdentidade = verificacao,
            podeSolicitarSelo = podeSolicitarSelo,
            verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.SEM_HARDWARE },
            verificarNotificacoesDoSistema = { true },
        )
    }

    private fun aprovada() = VerificacaoIdentidade(StatusVerificacaoIdentidade.APROVADA, identidadeVerificada = true)

    @Test
    fun `perfil - carregando`() {
        val viewModel = criarViewModel()
        compose.setContent { FrilaTheme(temaEscuro = false) { Perfil(viewModel) } }
        compose.capturar("r4a-perfil-01-carregando")
    }

    @Test
    fun `perfil - erro`() {
        val viewModel = criarViewModel(perfil = """{"code":"erro","message":"falhou"}""", status = HttpStatusCode.InternalServerError)
        runBlocking { viewModel.carregar().join() }
        compose.setContent { FrilaTheme(temaEscuro = false) { Perfil(viewModel) } }
        compose.capturar("r4a-perfil-02-erro")
    }

    @Test
    fun `perfil - com dados`() {
        val viewModel = criarViewModel()
        runBlocking { viewModel.carregar().join() }
        compose.setContent { FrilaTheme(temaEscuro = false) { Perfil(viewModel, verificacao = aprovada()) } }
        compose.capturar("r4a-perfil-03-com-dados")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h2600dp-xxhdpi")
    fun `perfil - completo`() {
        val viewModel = criarViewModel()
        runBlocking { viewModel.carregar().join() }
        compose.setContent { FrilaTheme(temaEscuro = false) { Perfil(viewModel, verificacao = aprovada()) } }
        compose.capturar("r4a-perfil-04-completo")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h2600dp-xxhdpi")
    fun `perfil - convite do selo e biografia em edicao`() {
        val viewModel = criarViewModel()
        runBlocking { viewModel.carregar().join() }
        viewModel.iniciarEdicaoBio()
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                Perfil(
                    viewModel,
                    verificacao = VerificacaoIdentidade(StatusVerificacaoIdentidade.NAO_EXIGIDA, identidadeVerificada = false),
                    podeSolicitarSelo = true,
                )
            }
        }
        compose.capturar("r4a-perfil-05-convite-e-bio-em-edicao")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h2600dp-xxhdpi", fontScale = 2f)
    fun `perfil - fonte 2x`() {
        val viewModel = criarViewModel()
        runBlocking { viewModel.carregar().join() }
        compose.setContent { FrilaTheme(temaEscuro = false) { Perfil(viewModel, verificacao = aprovada()) } }
        compose.capturar("r4a-perfil-06-fonte-2x")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h2600dp-xxhdpi")
    fun `perfil - escuro`() {
        val viewModel = criarViewModel()
        runBlocking { viewModel.carregar().join() }
        compose.setContent { FrilaTheme(temaEscuro = true) { Perfil(viewModel, verificacao = aprovada()) } }
        compose.capturar("r4a-perfil-07-escuro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h1400dp-xxhdpi")
    fun `perfil - da casa`() {
        val viewModel = criarViewModel(
            perfil = """{"code":"nao_encontrado","message":"perfil nao encontrado"}""",
            status = HttpStatusCode.NotFound,
            conta = contaJson.replace("profissional", "contratante").replace("Juliana Ramos", "Casa Exemplo"),
        )
        runBlocking { viewModel.carregar().join() }
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaPerfil(
                    viewModel = viewModel,
                    aoDeslogar = {},
                    aoAbrirEquipe = {},
                    aoMinhasVagas = {},
                    aoPublicarVaga = {},
                    aoEncontrarProfissional = {},
                    verificarNotificacoesDoSistema = { true },
                )
            }
        }
        compose.capturar("r4a-perfil-08-da-casa")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h1400dp-xxhdpi")
    fun `perfil - erro com atalhos da casa`() {
        val viewModel = criarViewModel(perfil = """{"code":"erro","message":"falhou"}""", status = HttpStatusCode.InternalServerError)
        runBlocking { viewModel.carregar().join() }
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaPerfil(
                    viewModel = viewModel,
                    aoDeslogar = {},
                    aoAbrirEquipe = {},
                    aoMinhasVagas = {},
                    aoPublicarVaga = {},
                    manterAtalhosDeContratanteNoErro = true,
                )
            }
        }
        compose.capturar("r4a-perfil-09-erro-com-atalhos")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h2600dp-xxhdpi")
    fun `perfil - notificacoes do sistema desligadas`() {
        val viewModel = criarViewModel()
        runBlocking { viewModel.carregar().join() }
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaPerfil(
                    viewModel = viewModel,
                    aoDeslogar = {},
                    aoAbrirApresentacao = {},
                    aoAbrirFotoDePerfil = {},
                    aoAbrirPontoBase = {},
                    aoAbrirChamadasDiretas = {},
                    verificarNotificacoesDoSistema = { false },
                )
            }
        }
        compose.capturar("r4a-perfil-10-notificacoes-desligadas")
    }

    // ---- Foto de perfil ----

    @Composable
    private fun Foto(etapa: EtapaDaFoto) = TelaFotoDePerfil(
        etapa = etapa,
        aoEscolherFoto = {},
        aoEnviarMesmoAssim = {},
        aoEscolherOutra = {},
        aoTentarDeNovo = {},
        aoVoltar = {},
    )

    @Test
    fun `foto - parada`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Foto(EtapaDaFoto.Parada) } }
        compose.capturar("r4a-foto-01-parada")
    }

    @Test
    fun `foto - aviso sem rosto`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Foto(EtapaDaFoto.AvisoSemRosto) } }
        compose.capturar("r4a-foto-02-sem-rosto")
    }

    @Test
    fun `foto - enviando`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Foto(EtapaDaFoto.Enviando) } }
        compose.capturar("r4a-foto-03-enviando")
    }

    @Test
    fun `foto - em analise`() {
        val midia = MidiaDto(id = "m", tipo = "foto_perfil", estado = "em_analise", podePedirNovaAnalise = false)
        compose.setContent { FrilaTheme(temaEscuro = false) { Foto(EtapaDaFoto.Enviada(midia)) } }
        compose.capturar("r4a-foto-04-em-analise")
    }

    @Test
    fun `foto - falha`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Foto(EtapaDaFoto.Falhou(TextosDaFotoDePerfil.ERRO_SEM_REDE)) } }
        compose.capturar("r4a-foto-05-falha")
    }

    @Test
    fun `foto - bloqueada`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) { Foto(EtapaDaFoto.Bloqueada(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS)) }
        }
        compose.capturar("r4a-foto-06-bloqueada")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `foto - fonte 2x`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Foto(EtapaDaFoto.AvisoSemRosto) } }
        compose.capturar("r4a-foto-07-fonte-2x")
    }

    // ---- Ponto base ----

    private val regioes = listOf("Plano Piloto", "Gama", "Taguatinga", "Brazlândia", "Sobradinho", "Planaltina", "Guará", "Ceilândia")
        .map { OpcaoDePontoBase(it, Coordenada(-15.79, -47.88)) }

    @Composable
    private fun PontoBase(estado: EstadoPontoBase) = ConteudoPontoBase(
        estado = estado,
        aoEscolher = {},
        aoAlternarFuncao = {},
        aoSalvar = {},
        aoVoltar = {},
    )

    @Test
    fun `ponto base - com perfil`() {
        val estado = EstadoPontoBase(opcoes = regioes, escolhida = regioes[2], temPontoBaseSalvo = true)
        compose.setContent { FrilaTheme(temaEscuro = false) { PontoBase(estado) } }
        compose.capturar("r4a-pontobase-01-com-perfil")
    }

    @Test
    fun `ponto base - sem perfil, com funcoes e erro`() {
        val funcoes = listOf("Garçom", "Barman", "Cozinheiro", "Auxiliar de cozinha", "Caixa", "Copeiro")
            .mapIndexed { i, nome -> FuncaoDto("f$i", nome, "Cat") }
        val estado = EstadoPontoBase(
            opcoes = regioes,
            semPerfil = true,
            funcoes = funcoes,
            funcoesEscolhidas = setOf("f1"),
            erro = "Informe o ponto base.",
        )
        compose.setContent { FrilaTheme(temaEscuro = false) { PontoBase(estado) } }
        compose.capturar("r4a-pontobase-02-sem-perfil-erro")
    }

    @Test
    fun `ponto base - salvando`() {
        val estado = EstadoPontoBase(opcoes = regioes, escolhida = regioes[0], salvando = true)
        compose.setContent { FrilaTheme(temaEscuro = false) { PontoBase(estado) } }
        compose.capturar("r4a-pontobase-03-salvando")
    }

    @Test
    fun `ponto base - carregando`() {
        val estado = EstadoPontoBase(opcoes = regioes, carregando = true)
        compose.setContent { FrilaTheme(temaEscuro = false) { PontoBase(estado) } }
        compose.capturar("r4a-pontobase-04-carregando")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `ponto base - fonte 2x`() {
        val estado = EstadoPontoBase(opcoes = regioes, escolhida = regioes[2], temPontoBaseSalvo = true)
        compose.setContent { FrilaTheme(temaEscuro = false) { PontoBase(estado) } }
        compose.capturar("r4a-pontobase-05-fonte-2x")
    }

    // ---- Ajuda ----

    @Test
    fun `ajuda`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaAjudaPerfil(aoVoltar = {}) } }
        compose.capturar("r4a-ajuda-01")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `ajuda - fonte 2x`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaAjudaPerfil(aoVoltar = {}) } }
        compose.capturar("r4a-ajuda-02-fonte-2x")
    }
}
