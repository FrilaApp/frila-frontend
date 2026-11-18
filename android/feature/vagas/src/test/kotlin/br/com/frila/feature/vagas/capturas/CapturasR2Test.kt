package br.com.frila.feature.vagas.capturas

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.VagaDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.candidaturas.AcoesMinhasCandidaturas
import br.com.frila.feature.vagas.candidaturas.ConteudoMinhasCandidaturas
import br.com.frila.feature.vagas.candidaturas.DestinoDaCandidatura
import br.com.frila.feature.vagas.candidaturas.DialogoRetirarCandidatura
import br.com.frila.feature.vagas.candidaturas.EstadoMinhasCandidaturas
import br.com.frila.feature.vagas.candidaturas.EstadoRetirarCandidatura
import br.com.frila.feature.vagas.candidaturas.ItemCandidatura
import br.com.frila.feature.vagas.candidaturas.ListaDeCandidaturas
import br.com.frila.feature.vagas.candidaturas.TextosCandidaturas
import br.com.frila.feature.vagas.detalhe.ConteudoAberturaDeVaga
import br.com.frila.feature.vagas.detalhe.ControleSessaoNotificacao
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.detalhe.EstadoAberturaDeVaga
import br.com.frila.feature.vagas.detalhe.ModoPreenchimentoVaga
import br.com.frila.feature.vagas.detalhe.MotivoIndisponibilidadeVaga
import br.com.frila.feature.vagas.detalhe.TelaDetalheVaga
import br.com.frila.feature.vagas.detalhe.TelaVagaIndisponivel
import br.com.frila.feature.vagas.detalhe.TextosAberturaDeVaga
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.TelaFeedVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
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
 * Prints do lote R2 (profissional, vagas): feed, detalhe, abertura, indisponível e candidaturas, no claro, num
 * Pixel de 411 x 914 dp. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR2Test {

    @get:Rule
    val compose = createComposeRule()

    private fun comFonte(escala: Float, conteudo: @Composable () -> Unit): @Composable () -> Unit = {
        CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale = escala)) { conteudo() }
    }

    // ---- Feed ----

    private fun vagaJson(
        id: String,
        funcao: String,
        casa: String,
        distanciaKm: Double,
        valorCentavos: Long,
        modo: String,
    ) = """
        {
          "id": "$id",
          "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "$funcao", "categoria": "Salão"},
          "estabelecimento": {
            "id": "33333333-3333-3333-3333-333333333333",
            "tipo": "estabelecimento",
            "nome": "$casa",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "2026-11-21T21:00:00Z",
          "fim_em": "2026-11-22T03:00:00Z",
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": $distanciaKm,
          "valor_centavos": $valorCentavos,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": true, "exige_material_proprio": false},
          "modo": "$modo"
        }
    """.trimIndent()

    private val tresVagas = "[" + listOf(
        vagaJson("v1", "Bartender", "Bar do Porto", 1.8, 22_000, "urgencia"),
        vagaJson("v2", "Garçom", "Adega Central", 3.4, 16_000, "selecao"),
        vagaJson("v3", "Auxiliar de cozinha", "Bistrô do Cais", 6.0, 14_000, "selecao"),
    ).joinToString(",") + "]"

    private fun viewModelDoFeed(resposta: String, status: HttpStatusCode = HttpStatusCode.OK): FeedVagasViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(resposta, status, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        return FeedVagasViewModel(servicoVagas = ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    private fun feed(viewModel: FeedVagasViewModel, escala: Float = 1f, aoDefinirPontoBase: (() -> Unit)? = null) {
        compose.setContent(
            comFonte(escala) {
                FrilaTheme(temaEscuro = false) {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                        aoAbrirMeusTurnos = {},
                        aoDefinirPontoBase = aoDefinirPontoBase,
                    )
                }
            },
        )
    }

    @Test
    fun `feed - carregando`() {
        feed(viewModelDoFeed("[]"))
        compose.capturar("r2-01-feed-carregando")
    }

    @Test
    fun `feed - com vagas`() {
        val viewModel = viewModelDoFeed(tresVagas)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel)
        compose.capturar("r2-02-feed-com-vagas")
    }

    @Test
    fun `feed - com vagas, fonte 2x`() {
        val viewModel = viewModelDoFeed(tresVagas)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel, escala = 2f)
        compose.capturar("r2-03-feed-com-vagas-fonte-2x")
    }

    @Test
    fun `feed - vazio`() {
        val viewModel = viewModelDoFeed("[]")
        runBlocking { viewModel.carregar().join() }
        feed(viewModel)
        compose.capturar("r2-04-feed-vazio")
    }

    @Test
    fun `feed - erro`() {
        val viewModel = viewModelDoFeed("""{"code":"PGRST500","message":"erro"}""", HttpStatusCode.InternalServerError)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel)
        compose.capturar("r2-05-feed-erro")
    }

    @Test
    fun `feed - sem ponto base`() {
        val semPontoBase = """{"code":"campo_obrigatorio","message":"sem ponto de referência","details":"latitude"}"""
        val viewModel = viewModelDoFeed(semPontoBase, HttpStatusCode.UnprocessableEntity)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel, aoDefinirPontoBase = {})
        compose.capturar("r2-06-feed-sem-ponto-base")
    }

    // ---- Detalhe ----

    private fun vagaAberta(modo: String) = VagaAbertaDto(
        id = "11111111-1111-1111-1111-111111111111",
        funcao = FuncaoDto(id = "f1", nome = "Bartender", categoria = "Salão"),
        estabelecimento = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar do Porto",
            reputacao = ReputacaoDto(positivas = 7, total = 7, taxaComparecimento = 1.0, turnosConsiderados = 7, turnosRealizados = 7),
        ),
        inicioEm = "2026-11-21T21:00:00Z",
        fimEm = "2026-11-22T03:00:00Z",
        local = "CLS 405, Bloco B, Loja 30",
        regiaoAdministrativa = "Asa Sul",
        distanciaKm = 1.8,
        valorCentavos = 22_000,
        posicoesAbertas = 2,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = true, exigeMaterialProprio = false),
        modo = modo,
    )

    private fun viewModelDoDetalhe(
        modo: String,
        resposta: String = "",
        status: HttpStatusCode = HttpStatusCode.OK,
        detalhe: VagaDto? = null,
    ): DetalheVagaViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { respond(resposta, status, headersOf(HttpHeaders.ContentType, "application/json")) },
        )
        return DetalheVagaViewModel(
            vaga = vagaAberta(modo),
            servicoVagas = ServicoVagas(cliente),
            detalhe = detalhe,
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private val vagaDoServidor = VagaDto(
        id = "11111111-1111-1111-1111-111111111111",
        estabelecimento = PerfilPublicoDto(id = "e1", tipo = "estabelecimento", nome = "Bar do Porto", reputacao = ReputacaoDto(7, 8, null, 8, 8)),
        funcao = FuncaoDto(id = "f1", nome = "Bartender", categoria = "salao"),
        inicioEm = "2026-11-21T21:00:00Z",
        fimEm = "2026-11-22T03:00:00Z",
        local = "CLS 405, Bloco B, Loja 30",
        regiaoAdministrativa = "Asa Sul",
        ponto = CoordenadaDto(-15.81, -47.89),
        distanciaKm = 1.8,
        valorCentavos = 22_000,
        posicoes = 3,
        posicoesAbertas = 2,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = true, exigeMaterialProprio = false),
        responsavelLocal = "Procure a gerente no balcão",
        traje = "Camisa preta e calça escura",
        observacoes = "Chegar 15 minutos antes",
        modo = "urgencia",
        estado = "publicada",
        oculta = false,
        publicadoEm = "2026-11-17T12:00:00Z",
    )

    private fun detalhe(viewModel: DetalheVagaViewModel, escala: Float = 1f) {
        ControleSessaoNotificacao.resetarParaTestes()
        compose.setContent(comFonte(escala) { FrilaTheme(temaEscuro = false) { TelaDetalheVaga(viewModel = viewModel, aoVoltar = {}, verificarPermissaoNotificacao = { true }) } })
    }

    @Test
    fun `detalhe - urgencia, lendo`() {
        detalhe(viewModelDoDetalhe("urgencia", detalhe = vagaDoServidor))
        compose.capturar("r2-08-detalhe-urgencia-lendo")
    }

    @Test
    fun `detalhe - selecao, no fim da rolagem`() {
        detalhe(viewModelDoDetalhe("selecao"))
        compose.capturar("r2-09-detalhe-selecao-no-fim")
    }

    @Test
    fun `detalhe - fonte 2x`() {
        detalhe(viewModelDoDetalhe("urgencia", detalhe = vagaDoServidor), escala = 2f)
        compose.capturar("r2-10-detalhe-fonte-2x")
    }

    @Test
    fun `detalhe - erro ao candidatar`() {
        val viewModel = viewModelDoDetalhe(
            "urgencia",
            resposta = """{"code":"posicao_ja_preenchida","message":"x"}""",
            status = HttpStatusCode.Conflict,
        )
        detalhe(viewModel)
        runBlocking { viewModel.candidatar().join() }
        compose.capturar("r2-11-detalhe-erro")
    }

    @Test
    fun `detalhe - candidatura confirmada com contato`() {
        val viewModel = viewModelDoDetalhe(
            "urgencia",
            resposta = """
                {"estado": "confirmada", "candidatura_id": "c1", "posicao_id": "p1", "turno_id": "t1",
                 "contato": {"nome": "Zé da Silva", "telefone": "61988887777"}}
            """.trimIndent(),
        )
        detalhe(viewModel)
        runBlocking { viewModel.candidatar().join() }
        compose.capturar("r2-12-detalhe-confirmada")
    }

    // ---- Abertura pelo id e vaga indisponível ----

    @Test
    fun `abertura - carregando`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoAberturaDeVaga(EstadoAberturaDeVaga.Carregando, aoTentarDeNovo = {}, aoVoltarParaFeed = {}) {}
            }
        }
        compose.capturar("r2-13-abertura-carregando")
    }

    @Test
    fun `abertura - falha`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoAberturaDeVaga(
                    EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.SEM_REDE, podeTentarDeNovo = true),
                    aoTentarDeNovo = {},
                    aoVoltarParaFeed = {},
                ) {}
            }
        }
        compose.capturar("r2-14-abertura-falha")
    }

    @Test
    fun `vaga indisponivel - preenchida`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaVagaIndisponivel(motivo = MotivoIndisponibilidadeVaga.PREENCHIDA, modo = ModoPreenchimentoVaga.URGENCIA, aoVoltarParaFeed = {})
            }
        }
        compose.capturar("r2-15-vaga-indisponivel")
    }

    // ---- Candidaturas ----

    private fun item(id: String, funcao: String, pendente: Boolean, texto: String, destino: DestinoDaCandidatura) = ItemCandidatura(
        id = id, vagaId = "vaga-$id", funcao = funcao, local = "CLS 405 Bloco C", inicio = Instant.parse("2026-11-21T21:00:00Z"),
        fim = Instant.parse("2026-11-22T00:00:00Z"), valorCentavos = 16_000, pendente = pendente, textoDoEstado = texto, destino = destino,
    )

    private fun candidaturas(estado: EstadoMinhasCandidaturas, escala: Float = 1f) {
        compose.setContent(
            comFonte(escala) {
                FrilaTheme(temaEscuro = false) {
                    ConteudoMinhasCandidaturas(estado, AcoesMinhasCandidaturas(aoRetirar = {}))
                }
            },
        )
    }

    @Test
    fun `candidaturas - com dados`() {
        val pendente = item("c1", "Garçom", true, TextosCandidaturas.ESTADO_PENDENTE, DestinoDaCandidatura.Vaga("v1"))
        val aceita = item("c2", "Barman", false, TextosCandidaturas.ESTADO_ACEITA, DestinoDaCandidatura.Turno("t2"))
        val recusada = item("c3", "Auxiliar de cozinha", false, TextosCandidaturas.ESTADO_RECUSADA, DestinoDaCandidatura.Vaga("v3"))
        candidaturas(EstadoMinhasCandidaturas(ListaDeCandidaturas.Carregadas(listOf(pendente), listOf(aceita, recusada))))
        compose.capturar("r2-16-candidaturas-com-dados")
    }

    @Test
    fun `candidaturas - fonte 2x`() {
        val pendente = item("c1", "Garçom", true, TextosCandidaturas.ESTADO_PENDENTE, DestinoDaCandidatura.Vaga("v1"))
        candidaturas(EstadoMinhasCandidaturas(ListaDeCandidaturas.Carregadas(listOf(pendente), emptyList())), escala = 2f)
        compose.capturar("r2-17-candidaturas-fonte-2x")
    }

    @Test
    fun `candidaturas - carregando, vazia e erro`() {
        candidaturas(EstadoMinhasCandidaturas(ListaDeCandidaturas.Carregando))
        compose.capturar("r2-18-candidaturas-carregando")
    }

    @Test
    fun `candidaturas - vazia`() {
        candidaturas(EstadoMinhasCandidaturas(ListaDeCandidaturas.Vazia))
        compose.capturar("r2-19-candidaturas-vazia")
    }

    @Test
    fun `candidaturas - erro`() {
        candidaturas(
            EstadoMinhasCandidaturas(ListaDeCandidaturas.Erro(TextosCandidaturas.ERRO_SEM_REDE, podeTentarDeNovo = true)),
        )
        compose.capturar("r2-20-candidaturas-erro")
    }

    @Test
    fun `candidaturas - retirar, pergunta`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                DialogoRetirarCandidatura(EstadoRetirarCandidatura(), aoConfirmar = {}, aoFechar = {})
            }
        }
        // O diálogo é outra janela: só confere que desenha sem quebrar.
        compose.waitForIdle()
    }
}
