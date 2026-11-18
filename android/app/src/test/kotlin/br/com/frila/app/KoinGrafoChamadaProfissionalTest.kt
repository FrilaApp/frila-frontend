package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoChamadaDireta
import br.com.frila.feature.chamadas.profissional.ChamadaRecebidaViewModel
import br.com.frila.feature.chamadas.profissional.EditarServicosViewModel
import br.com.frila.feature.chamadas.profissional.PreferenciasChamadaViewModel
import br.com.frila.feature.chamadas.profissional.ServicoDeEspecialidades
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDoTeste = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/** O grafo real monta o serviço e os três ViewModels do profissional na chamada direta, e a fiação chega à rota certa. */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoChamadaProfissionalTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val caminhos = mutableListOf<String>()

    private fun clienteQueResponde(corpo: String) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            caminhos += request.url.encodedPath
            respond(corpo, HttpStatusCode.OK, json)
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

    @Test
    fun `grafo resolve o servico e os tres ViewModels do profissional`() {
        startKoin { modules(listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoTeste, moduloFeatures)) }

        assertNotNull(get<ServicoChamadaDireta>())
        assertNotNull(get<ServicoDeEspecialidades>())
        assertNotNull(get<EditarServicosViewModel>())
        assertNotNull(get<PreferenciasChamadaViewModel>())
        assertNotNull(get<ChamadaRecebidaViewModel> { parametersOf("44444444-4444-4444-4444-444444444444") })
    }

    @Test
    fun `cada ViewModel chama a rota do contrato que lhe cabe`() {
        val perfil = """{"id":"22222222-2222-2222-2222-222222222222","usuario_id":"88888888-8888-8888-8888-888888888888","funcoes":[{"id":"11111111-1111-1111-1111-111111111111","nome":"Garçom","categoria":"salao"}],"disponibilidades":[],"reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0},"cursos":[],"idiomas":[],"servicos":[],"regioes":[],"atende_todo_df":false,"preferencia_chamadas":{"aceita_de_quem_ja_trabalhou":true,"antecedencia_minima_h":6,"aceita_de":"todos","pendencias_para_busca":[]}}"""
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoTeste, moduloFeatures) +
                    module {
                        single { ServicoChamadaDireta(clienteQueResponde(perfil)) }
                        single { ServicoDeEspecialidades(clienteQueResponde("[]")) }
                    },
            )
        }

        runBlocking {
            val preferencias = get<PreferenciasChamadaViewModel>()
            preferencias.carregar().join()
            assertEquals(listOf("/rest/v1/rpc/meu_perfil_detalhado"), caminhos)
            assertTrue(preferencias.estado.value.carregou)

            caminhos.clear()
            val servicos = get<EditarServicosViewModel>()
            servicos.carregar().join()
            assertEquals(
                listOf("/rest/v1/rpc/meu_perfil_detalhado", "/rest/v1/especialidade"),
                caminhos,
            )
            assertTrue(servicos.estado.value.carregou)
        }
    }
}
