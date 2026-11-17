package br.com.frila.app

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.LeituraDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoChamadaDireta
import br.com.frila.core.rede.ServicoMidia
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.feature.perfil.ApresentacaoERegioesViewModel
import br.com.frila.feature.perfil.PontoBaseViewModel
import br.com.frila.feature.perfil.ConferidorDeRostoDaFoto
import br.com.frila.feature.perfil.EtapaDaFoto
import br.com.frila.feature.perfil.FotoDePerfilViewModel
import br.com.frila.feature.perfil.ResultadoDaVerificacaoLocal
import br.com.frila.feature.turnos.ValidacaoDoCodigoViewModel
import br.com.frila.feature.turnos.contratante.CodigoDaCasaViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.Called
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

/** L1-7a: o grafo real monta os ViewModels do perfil (apresentação, regiões, foto) e do turno (código de chegada), e cada um chega à rota do contrato. */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoPerfilETurnosTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val pedidos = mutableListOf<Triple<HttpMethod, String, String?>>()
    private val turnoId = "44444444-4444-4444-4444-444444444444"
    private val idDaMidia = "33333333-3333-3333-3333-333333333333"

    private fun cliente() = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            pedidos += Triple(request.method, request.url.encodedPath, (request.body as? TextContent)?.text)
            when {
                request.url.encodedPath.endsWith("/solicitar_upload_midia") -> respond(
                    """{"midia_id":"$idDaMidia","upload_url":"https://frila.supabase.co/functions/v1/enviar-midia?midia_id=$idDaMidia&token=T","expira_em":"2026-11-17T05:00:00+00:00"}""",
                    HttpStatusCode.OK,
                    json,
                )
                request.url.encodedPath.endsWith("/confirmar_upload_midia") -> respond(
                    """{"id":"$idDaMidia","tipo":"foto_perfil","estado":"em_analise","pode_pedir_nova_analise":false}""",
                    HttpStatusCode.OK,
                    json,
                )
                request.url.encodedPath.endsWith("/meu_perfil_profissional") ||
                    request.url.encodedPath.endsWith("/atualizar_perfil_profissional") -> respond(
                    """{"id":"p1","usuario_id":"u1","funcoes":[],"ponto_base":null,"disponibilidades":[],""" +
                        """"reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}""",
                    HttpStatusCode.OK,
                    json,
                )
                request.method == HttpMethod.Put -> respond("", HttpStatusCode.OK)
                else -> respond("""{"code":"x","message":"x"}""", HttpStatusCode.BadRequest, json)
            }
        },
    )

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @AfterEach
    fun depois() {
        stopKoin()
        Dispatchers.resetMain()
    }

    private fun iniciar() = startKoin {
        val cliente = cliente()
        modules(
            listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoTeste, moduloFeatures) +
                module {
                    single { ServicoPerfil(cliente) }
                    single { ServicoChamadaDireta(cliente) }
                    single { ServicoTurnos(cliente) }
                    single { ServicoMidia(cliente) }
                    single<ConferidorDeRostoDaFoto> { ConferidorDeRostoDaFoto { ResultadoDaVerificacaoLocal.Liberada } }
                    single<PreparadorDaFotoDePerfil> { PreparadorDaFotoDePerfil { byteArrayOf(1, 2, 3) } }
                },
        )
    }

    private val vaga = Coordenada(-15.7942, -47.8825)

    /** O aparelho está exatamente no ponto da vaga, com boa precisão. */
    private val moduloLocalizacaoDoTeste = module {
        single<ProvedorDeLocalizacao> {
            mockk(relaxed = true) {
                coEvery { temPermissaoDeLocalizacao() } returns true
                coEvery { isGpsAtivado() } returns true
                coEvery { lerParaCheckin() } returns LeituraDeLocalizacao(coordenada = vaga, precisaoMetros = 10f, simulada = false)
            }
        }
    }

    @Test
    fun `grafo resolve os quatro ViewModels do lote com os parametros da rota`() {
        iniciar()
        get<ApresentacaoERegioesViewModel>()
        get<FotoDePerfilViewModel>()
        get<ValidacaoDoCodigoViewModel> { parametersOf(turnoId, null as Coordenada?, null as (() -> Unit)?) }
        get<CodigoDaCasaViewModel> { parametersOf(turnoId, null as (() -> Unit)?) }
    }

    @Test
    fun `apresentacao e regioes leem o perfil detalhado e as regioes`() = runBlocking {
        iniciar()
        get<ApresentacaoERegioesViewModel>().carregar().join()
        val caminhos = pedidos.map { it.second }
        assertTrue("/rest/v1/rpc/meu_perfil_detalhado" in caminhos, caminhos.toString())
        assertTrue("/rest/v1/regiao_administrativa" in caminhos, caminhos.toString())
    }

    @Test
    fun `o ponto base le o perfil e grava so o centro da regiao escolhida, sem tocar o provedor de localizacao`() = runBlocking {
        iniciar()
        val provedor = get<ProvedorDeLocalizacao>()
        val vm = get<PontoBaseViewModel>()
        vm.carregar().join()
        assertEquals(35, vm.estado.value.opcoes.size)
        vm.escolher(vm.estado.value.opcoes.first { it.nome == "Taguatinga" })
        vm.salvar().join()

        assertTrue(vm.estado.value.salvo, vm.estado.value.toString())
        assertEquals(
            listOf("/rest/v1/rpc/meu_perfil_profissional", "/rest/v1/rpc/atualizar_perfil_profissional"),
            pedidos.map { it.second },
        )
        assertEquals("""{"ponto_base":{"latitude":-15.833333,"longitude":-48.056944}}""", pedidos.last().third)
        verify { provedor wasNot Called }
    }

    @Test
    fun `a foto de perfil sobe pelas tres chamadas do contrato`() = runBlocking {
        iniciar()
        val vm = get<FotoDePerfilViewModel>()
        vm.escolher("content://foto/1")
        withTimeout(5_000) { while (vm.etapa.value is EtapaDaFoto.Preparando || vm.etapa.value is EtapaDaFoto.Enviando) kotlinx.coroutines.yield() }
        assertTrue(vm.etapa.value is EtapaDaFoto.Enviada, vm.etapa.value.toString())
        assertEquals(
            listOf("/rest/v1/rpc/solicitar_upload_midia", "/functions/v1/enviar-midia", "/rest/v1/rpc/confirmar_upload_midia"),
            pedidos.map { it.second },
        )
    }

    @Test
    fun `o codigo digitado vai a validar_codigo_checkin com o turno e a distancia medida ate a vaga`() = runBlocking {
        iniciar()
        val vm = get<ValidacaoDoCodigoViewModel> { parametersOf(turnoId, vaga, null as (() -> Unit)?) }
        vm.validar("123456").join()
        val pedido = pedidos.single { it.second == "/rest/v1/rpc/validar_codigo_checkin" }
        assertEquals(HttpMethod.Post, pedido.first)
        assertTrue(pedido.third!!.contains(turnoId) && pedido.third!!.contains("123456") && pedido.third!!.contains("\"distancia_m\":0"), pedido.third)
        assertTrue(!pedido.third!!.contains("-15.79"), "nunca a coordenada, só a distância")
    }

    @Test
    fun `sem o ponto da vaga o codigo nao e enviado, a regra de presenca vale tambem na fiacao`() = runBlocking {
        iniciar()
        val vm = get<ValidacaoDoCodigoViewModel> { parametersOf(turnoId, null as Coordenada?, null as (() -> Unit)?) }
        vm.validar("123456").join()
        assertTrue(pedidos.none { it.second.endsWith("/validar_codigo_checkin") })
    }

    @Test
    fun `o codigo da casa vai a gerar_codigo_checkin com o turno`() = runBlocking {
        iniciar()
        val vm = get<CodigoDaCasaViewModel> { parametersOf(turnoId, null as (() -> Unit)?) }
        vm.carregar()
        val pedido = pedidos.single { it.second == "/rest/v1/rpc/gerar_codigo_checkin" }
        assertTrue(pedido.third!!.contains(turnoId))
    }
}
