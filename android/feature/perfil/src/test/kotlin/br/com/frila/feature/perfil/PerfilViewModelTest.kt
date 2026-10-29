package br.com.frila.feature.perfil

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Mesma ressalva de `MockEngine` + escopo próprio documentada em `MeusTurnosViewModelTest` e em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`: o teste espera o `Job` com `.join()`.
 */
class PerfilViewModelTest {

    private val perfilJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "usuario_id": "22222222-2222-2222-2222-222222222222",
          "funcoes": [{"id": "f1", "nome": "garçom", "categoria": "Salão"}],
          "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
          "disponibilidades": [],
          "reputacao": {
            "positivas": 7, "total": 7, "taxa_comparecimento": 0.95,
            "turnos_considerados": 8, "turnos_realizados": 8
          }
        }
    """.trimIndent()

    private fun turnoJson(id: String, estado: String, valorAcordadoCentavos: Long) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "garçom",
            "local": "SQN 108",
            "regiao_administrativa": "Asa Norte",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": $valorAcordadoCentavos
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": null,
          "checkin_em": null,
          "checkin_tipo": null,
          "checkin_distancia_m": null,
          "checkin_confirmado_em": null,
          "checkout_em": null,
          "checkout_distancia_m": null,
          "verificacao": "pendente",
          "valor_acordado_centavos": $valorAcordadoCentavos,
          "pode_avaliar": false,
          "estado": "$estado",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    private fun viewModelComEngine(
        engine: MockEngine,
        armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true),
        engineTurnos: MockEngine = MockEngine { respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
    ): PerfilViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val clienteTurnos = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engineTurnos)
        return PerfilViewModel(
            servicoPerfil = ServicoPerfil(cliente),
            servicoTurnos = ServicoTurnos(clienteTurnos),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `carregar com sucesso resulta em status SUCESSO com o perfil`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.carregar().join()

        assertEquals(StatusPerfil.SUCESSO, viewModel.estado.value.status)
        assertEquals(7, viewModel.estado.value.perfil?.reputacao?.positivas)
        assertEquals("garçom", viewModel.estado.value.perfil?.funcoes?.first()?.nome)
    }

    @Test
    fun `aoDeslogar limpa a sessao em ArmazenamentoDeSessao`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) }, armazenamento)

        viewModel.aoDeslogar()

        verify(exactly = 1) { armazenamento.limparSessao() }
    }

    @Test
    fun `carregar com erro da API resulta em status ERRO com mensagem amigavel`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"nao_encontrado","message":"perfil nao existe"}""",
                    status = HttpStatusCode.NotFound,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusPerfil.ERRO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `status comeca CARREGANDO antes da resposta chegar`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        assertEquals(StatusPerfil.CARREGANDO, viewModel.estado.value.status)
    }

    @Test
    fun `confirmarExclusao com sucesso chama a API, limpa a sessao e vai para SUCESSO`() = runBlocking {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        val engine = MockEngine {
            respond(
                content = """
                    {
                      "perfil_removido_em": "2026-11-02T10:00:00Z",
                      "dados_apagados_ate": "2026-11-17",
                      "turnos_cancelados": 1
                    }
                """.trimIndent(),
                status = HttpStatusCode.Accepted,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val viewModel = viewModelComEngine(engine, armazenamento)

        viewModel.abrirDialogoExclusao()
        viewModel.confirmarExclusao().join()

        assertEquals(StatusExclusao.SUCESSO, viewModel.estado.value.statusExclusao)
        assertEquals(1, viewModel.estado.value.resultadoExclusao?.turnosCancelados)
        verify(exactly = 1) { armazenamento.limparSessao() }
    }

    @Test
    fun `cancelarExclusao volta o statusExclusao para OCIOSO sem chamar a API`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        viewModel.abrirDialogoExclusao()
        assertEquals(StatusExclusao.DIALOGO_ABERTO, viewModel.estado.value.statusExclusao)

        viewModel.cancelarExclusao()

        assertEquals(StatusExclusao.OCIOSO, viewModel.estado.value.statusExclusao)
    }

    @Test
    fun `confirmarExclusao com administrador_unico mantem a sessao e define mensagem de erro`() = runBlocking {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        val engine = MockEngine {
            respond(
                content = """{"code":"administrador_unico","message":"transfira a administracao antes"}""",
                status = HttpStatusCode.Conflict,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val viewModel = viewModelComEngine(engine, armazenamento)

        viewModel.abrirDialogoExclusao()
        viewModel.confirmarExclusao().join()

        assertEquals(StatusExclusao.ERRO, viewModel.estado.value.statusExclusao)
        assertNotNull(viewModel.estado.value.mensagemErroExclusao)
        verify(exactly = 0) { armazenamento.limparSessao() }
    }

    @Test
    fun `atualizarBioEmEdicao rejeita texto acima de 280 caracteres mantendo o texto anterior`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })
        viewModel.iniciarEdicaoBio()

        val texto280 = "A".repeat(280)
        viewModel.atualizarBioEmEdicao(texto280)
        assertEquals(texto280, viewModel.estado.value.bioEmEdicao)
        assertEquals(0, viewModel.estado.value.caracteresRestantesBio)

        val texto281 = "A".repeat(281)
        viewModel.atualizarBioEmEdicao(texto281)
        // Bloqueio de caracteres excedentes: mantém os 280 anteriores
        assertEquals(texto280, viewModel.estado.value.bioEmEdicao)
        assertEquals(0, viewModel.estado.value.caracteresRestantesBio)
    }

    @Test
    fun `atualizarBioEmEdicao aceita texto de ate 280 caracteres e calcula caracteres restantes corretamente`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })
        viewModel.iniciarEdicaoBio()

        val texto50 = "Bartender com experiência em coquetelaria clássica."
        viewModel.atualizarBioEmEdicao(texto50)

        assertEquals(texto50, viewModel.estado.value.bioEmEdicao)
        assertEquals(280 - texto50.length, viewModel.estado.value.caracteresRestantesBio)
    }

    @Test
    fun `iniciarEdicaoBio copia a bio atual para bioEmEdicao e ativa modo edicao`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        viewModel.iniciarEdicaoBio()
        assertTrue(viewModel.estado.value.estaEditandoBio)
        assertEquals("", viewModel.estado.value.bioEmEdicao)
    }

    @Test
    fun `salvarBio persiste bioEmEdicao trimada em bio e encerra modo edicao`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        viewModel.iniciarEdicaoBio()
        viewModel.atualizarBioEmEdicao("   Garçom bilíngue para eventos VIP   ")
        viewModel.salvarBio()

        assertFalse(viewModel.estado.value.estaEditandoBio)
        assertEquals("Garçom bilíngue para eventos VIP", viewModel.estado.value.bio)
    }

    @Test
    fun `cancelarEdicaoBio restaura bioEmEdicao com o valor de bio e encerra modo edicao`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        viewModel.iniciarEdicaoBio()
        viewModel.atualizarBioEmEdicao("Bio inicial")
        viewModel.salvarBio()

        viewModel.iniciarEdicaoBio()
        viewModel.atualizarBioEmEdicao("Texto que sera descartado")
        viewModel.cancelarEdicaoBio()

        assertFalse(viewModel.estado.value.estaEditandoBio)
        assertEquals("Bio inicial", viewModel.estado.value.bio)
        assertEquals("Bio inicial", viewModel.estado.value.bioEmEdicao)
    }

    @Test
    fun `alternarEspecialidade adiciona especialidade nao selecionada e remove especialidade ja selecionada`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK) })

        assertTrue(viewModel.estado.value.especialidadesSelecionadas.isEmpty())

        viewModel.alternarEspecialidade("Coquetelaria clássica")
        assertTrue(viewModel.estado.value.especialidadesSelecionadas.contains("Coquetelaria clássica"))
        assertEquals(1, viewModel.estado.value.especialidadesSelecionadas.size)

        viewModel.alternarEspecialidade("Vinhos e sommellerie")
        assertTrue(viewModel.estado.value.especialidadesSelecionadas.contains("Coquetelaria clássica"))
        assertTrue(viewModel.estado.value.especialidadesSelecionadas.contains("Vinhos e sommellerie"))
        assertEquals(2, viewModel.estado.value.especialidadesSelecionadas.size)

        // Remove ao alternar de novo
        viewModel.alternarEspecialidade("Coquetelaria clássica")
        assertFalse(viewModel.estado.value.especialidadesSelecionadas.contains("Coquetelaria clássica"))
        assertTrue(viewModel.estado.value.especialidadesSelecionadas.contains("Vinhos e sommellerie"))
        assertEquals(1, viewModel.estado.value.especialidadesSelecionadas.size)
    }

    @Test
    fun `resumoFinanceiro soma cumpridas e confirmadas descartando canceladas (RF16, RN12)`() = runBlocking {
        val turnosJson = "[" + listOf(
            turnoJson(id = "a", estado = "cumprida", valorAcordadoCentavos = 10_000L),
            turnoJson(id = "b", estado = "cumprida", valorAcordadoCentavos = 15_000L),
            turnoJson(id = "c", estado = "confirmada", valorAcordadoCentavos = 20_000L),
            turnoJson(id = "d", estado = "cancelada", valorAcordadoCentavos = 99_999L),
        ).joinToString(",") + "]"
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
            engineTurnos = MockEngine { respond(content = turnosJson, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.carregar().join()

        val resumo = viewModel.estado.value.resumoFinanceiro
        assertNotNull(resumo)
        assertEquals(25_000L, resumo!!.totalConcluidoCentavos)
        assertEquals(20_000L, resumo.totalPendenteCentavos)
        assertEquals(45_000L, resumo.totalGeralCentavos)
        assertEquals(2, resumo.turnosCumpridosQtd)
        assertEquals(1, resumo.turnosAgendadosQtd)
        // NumberFormat pt-BR usa espaço não quebrável entre "R$" e o valor (mesma ressalva de
        // DinheiroTest) — comparar só o valor numérico evita depender desse detalhe de locale.
        assertTrue(resumo.totalConcluidoFormatado.contains("250,00"))
        assertTrue(resumo.totalPendenteFormatado.contains("200,00"))
        assertTrue(resumo.totalGeralFormatado.contains("450,00"))
        assertEquals(3, viewModel.estado.value.turnosExtrato.size)
    }

    @Test
    fun `exportarExtratoPdf devolve nulo se resumo nao possuir historico`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
            engineTurnos = MockEngine { respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )
        viewModel.carregar().join()
        assertEquals(false, viewModel.estado.value.resumoFinanceiro?.temHistorico)

        val arquivo = viewModel.exportarExtratoPdf(java.io.File("/tmp"), "Teste")

        assertEquals(null, arquivo)
    }

    // "exportarExtratoPdf gera arquivo fisico quando ha historico" (caminho feliz, que desenha o
    // PDF via android.graphics.pdf.PdfDocument) NAO é coberto por teste automatizado nenhum nesta
    // suíte — MEDIDO (achado do Shisui): Robolectric lança IllegalStateException em
    // PdfDocument.startPage em qualquer sdk/GraphicsMode testado (33, 35, LEGACY, NATIVE), então
    // esse caminho só roda de verdade em dispositivo/emulador real. GeradorExtratoPdfTest testa
    // só a lógica pura e determinística — dividirEmPaginas, quebrarEmLinhas, nomeArquivo — que não
    // depende de android.graphics.

    @Test
    fun `resumoFinanceiro sem turnos tem temHistorico falso`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
            engineTurnos = MockEngine { respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.carregar().join()

        val resumo = viewModel.estado.value.resumoFinanceiro
        assertNotNull(resumo)
        assertFalse(resumo!!.temHistorico)
        assertEquals(0L, resumo.totalGeralCentavos)
    }

    @Test
    fun `falha em servicoTurnos nao quebra o carregamento do perfil, resumo cai para vazio`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = perfilJson, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
            engineTurnos = MockEngine {
                respond(
                    content = """{"code":"500","message":"erro interno"}""",
                    status = HttpStatusCode.InternalServerError,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusPerfil.SUCESSO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.perfil)
        val resumo = viewModel.estado.value.resumoFinanceiro
        assertNotNull(resumo)
        assertFalse(resumo!!.temHistorico)
        assertEquals(ResumoFinanceiroPerfil.VAZIO, resumo)
    }

    private fun viewModelComCompressor(
        obterAvatarSalvo: (android.content.Context) -> java.io.File? = { null },
        comprimirFoto: (android.content.Context, android.net.Uri) -> java.io.File,
    ): PerfilViewModel {
        val engineVazio = MockEngine { respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engineVazio)
        return PerfilViewModel(
            servicoPerfil = ServicoPerfil(cliente),
            servicoTurnos = ServicoTurnos(cliente),
            armazenamentoDeSessao = mockk(relaxed = true),
            escopo = CoroutineScope(Dispatchers.Default),
            comprimirFoto = comprimirFoto,
            obterAvatarSalvo = obterAvatarSalvo,
        )
    }

    @Test
    fun `selecionarFoto com sucesso resulta em status SUCESSO com o caminho do avatar`() = runBlocking {
        val arquivoEsperado = java.io.File("/caminho/falso/avatar_perfil.jpg")
        val viewModel = viewModelComCompressor { _, _ -> arquivoEsperado }

        viewModel.selecionarFoto(mockk(relaxed = true), mockk(relaxed = true)).join()

        assertEquals(StatusFotoPerfil.SUCESSO, viewModel.estado.value.statusFoto)
        assertEquals(arquivoEsperado.absolutePath, viewModel.estado.value.fotoLocalPath)
        assertEquals(null, viewModel.estado.value.mensagemErroFoto)
    }

    @Test
    fun `selecionarFoto com falha de decodificacao resulta em status ERRO e preserva avatar anterior`() = runBlocking {
        val arquivoAnterior = java.io.File("/caminho/falso/avatar_antigo.jpg")
        var chamadas = 0
        val viewModel = viewModelComCompressor { _, _ ->
            chamadas++
            if (chamadas == 1) arquivoAnterior else throw IllegalStateException("Não foi possível decodificar a imagem selecionada.")
        }

        viewModel.selecionarFoto(mockk(relaxed = true), mockk(relaxed = true)).join()
        assertEquals(arquivoAnterior.absolutePath, viewModel.estado.value.fotoLocalPath)

        viewModel.selecionarFoto(mockk(relaxed = true), mockk(relaxed = true)).join()

        assertEquals(StatusFotoPerfil.ERRO, viewModel.estado.value.statusFoto)
        assertNotNull(viewModel.estado.value.mensagemErroFoto)
        // Rollback: avatar anterior continua valendo, a falha não apaga a referência que funcionava.
        assertEquals(arquivoAnterior.absolutePath, viewModel.estado.value.fotoLocalPath)
    }

    @Test
    fun `duas trocas seguidas de foto atualizam fotoLocalPath nas duas vezes`() = runBlocking {
        val primeiroArquivo = java.io.File("/caminho/falso/avatar_perfil_1.jpg")
        val segundoArquivo = java.io.File("/caminho/falso/avatar_perfil_2.jpg")
        var chamadas = 0
        val viewModel = viewModelComCompressor { _, _ ->
            chamadas++
            if (chamadas == 1) primeiroArquivo else segundoArquivo
        }

        viewModel.selecionarFoto(mockk(relaxed = true), mockk(relaxed = true)).join()
        assertEquals(primeiroArquivo.absolutePath, viewModel.estado.value.fotoLocalPath)

        viewModel.selecionarFoto(mockk(relaxed = true), mockk(relaxed = true)).join()
        assertEquals(segundoArquivo.absolutePath, viewModel.estado.value.fotoLocalPath)
        assertNotEquals(primeiroArquivo.absolutePath, viewModel.estado.value.fotoLocalPath)
    }

    @Test
    fun `carregarAvatarSalvo sem avatar em disco nao altera fotoLocalPath`() = runBlocking {
        val viewModel = viewModelComCompressor(comprimirFoto = { _, _ -> error("não usado neste teste") }, obterAvatarSalvo = { null })

        viewModel.carregarAvatarSalvo(mockk(relaxed = true)).join()

        assertEquals(null, viewModel.estado.value.fotoLocalPath)
    }

    @Test
    fun `carregarAvatarSalvo com avatar em disco preenche fotoLocalPath ao reabrir a tela`() = runBlocking {
        val arquivoSalvo = java.io.File("/caminho/falso/avatar_perfil_antigo.jpg")
        val viewModel = viewModelComCompressor(
            comprimirFoto = { _, _ -> error("não usado neste teste") },
            obterAvatarSalvo = { arquivoSalvo },
        )

        viewModel.carregarAvatarSalvo(mockk(relaxed = true)).join()

        assertEquals(arquivoSalvo.absolutePath, viewModel.estado.value.fotoLocalPath)
    }
}
