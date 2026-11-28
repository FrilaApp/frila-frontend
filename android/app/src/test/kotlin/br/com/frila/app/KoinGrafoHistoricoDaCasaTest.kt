package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.feature.perfil.EstadoHistorico
import br.com.frila.feature.perfil.FormatoExportacao
import br.com.frila.feature.perfil.HistoricoDeTurnosViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import java.nio.file.Files
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
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

private val moduloLocalizacaoDoGrafoDoHistoricoDaCasa = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/**
 * rUFapFEL: o grafo real liga `HistoricoDeTurnosViewModel` ao id da casa. Com o id como parâmetro, o extrato sai de
 * `meus_turnos?estabelecimento_id=<id>` e só em CSV; sem ele, é o do profissional (`meus_turnos` sem o parâmetro, CSV e PDF).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoHistoricoDaCasaTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val consultas = CopyOnWriteArrayList<String>()

    private val turnoJson = """
        [{"id": "t1", "posicao_id": "posicao-t1",
          "vaga": {"id": "vaga-t1", "funcao": "Garçom", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                   "inicio_em": "__INICIO__", "fim_em": "__INICIO__", "valor_centavos": 16000},
          "contraparte": {"id": "p1", "tipo": "profissional", "nome": "Ana",
                          "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
          "contato_visivel_ate": null, "a_caminho_em": null, "checkin_em": null, "checkin_tipo": null, "checkin_distancia_m": null,
          "checkin_confirmado_em": null, "checkout_em": null, "checkout_distancia_m": null, "verificacao": "verificado",
          "valor_acordado_centavos": 16000, "pode_avaliar": false, "estado": "cumprida", "avaliacao": null, "cancelamento": null}]
    """.trimIndent()

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val cliente = clienteSupabaseDeTeste(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                consultas += request.url.toString()
                // Hoje ao meio-dia em Brasília: sempre dentro de "este mês", qualquer que seja o dia da execução.
                val hoje = java.time.ZonedDateTime.now(java.time.ZoneId.of("America/Sao_Paulo")).withHour(12).withMinute(0).withSecond(0).withNano(0)
                respond(turnoJson.replace("__INICIO__", hoje.toInstant().toString()), HttpStatusCode.OK, json)
            },
        )
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoGrafoDoHistoricoDaCasa, moduloFeatures) +
                    module { single { ServicoTurnos { cliente } } },
            )
        }
    }

    @AfterEach
    fun depois() {
        encerrarOsClientesDoTeste()
        stopKoin()
        Dispatchers.resetMain()
    }

    @Test
    fun `com o id da casa o grafo le meus_turnos pelo estabelecimento_id e so oferece CSV`() {
        val vm = get<HistoricoDeTurnosViewModel> { parametersOf("casa-1") }
        val pasta = Files.createTempDirectory("hist-casa").toFile()
        try {
            vm.escolher(FormatoExportacao.PDF)
            vm.exportar(pasta)
            // `exportar` lança em viewModelScope e a rede simulada responde em outra thread: espera o arquivo ou o fim com erro.
            val limite = System.currentTimeMillis() + 5_000
            while (vm.estado.value.arquivoParaCompartilhar == null && vm.estado.value.estado !is EstadoHistorico.Erro &&
                vm.estado.value.estado != EstadoHistorico.SemTurnos && System.currentTimeMillis() < limite
            ) Thread.sleep(20)

            assertEquals(listOf(FormatoExportacao.CSV), vm.formatosDisponiveis)
            assertTrue(consultas.any { it.contains("meus_turnos") && it.contains("estabelecimento_id=casa-1") }, "esperava estabelecimento_id=casa-1 em $consultas")
            assertTrue(vm.estado.value.arquivoParaCompartilhar?.name?.endsWith(".csv") == true)
        } finally {
            pasta.deleteRecursively()
        }
    }

    @Test
    fun `sem o id o grafo entrega o historico do profissional, CSV e PDF`() {
        val vm = get<HistoricoDeTurnosViewModel>()

        assertEquals(listOf(FormatoExportacao.CSV, FormatoExportacao.PDF), vm.formatosDisponiveis)
    }
}
