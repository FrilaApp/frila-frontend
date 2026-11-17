package br.com.frila.feature.chamadas.casa

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import android.graphics.Bitmap
import androidx.compose.ui.graphics.asImageBitmap
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CartaoProfissionalDto
import br.com.frila.core.rede.ChamadaDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import br.com.frila.core.rede.RegiaoAdministrativaDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoNoPerfilDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** A tela provisória da busca: estados, seleção de até 3, chamar e o caminho do "Publicar para todos". */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaBuscaDeProfissionaisTest {

    @get:Rule
    val rule = createComposeRule()

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val garcom = FuncaoDto("f1", "Garçom", "salao")
    private val casa = MeuEstabelecimentoDto(
        id = "c1", nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )

    private fun cartao(id: String, nome: String, disponivel: Boolean? = null, fotoUrl: String? = null) = CartaoProfissionalDto(
        id = id, nome = nome,
        servico = ServicoNoPerfilDto(funcao = garcom, unidade = "diaria", valorCentavos = 15000, horasIncluidas = 8),
        regioes = listOf(RegiaoAdministrativaDto(1, "I", "Plano Piloto")),
        distanciaFaixa = "ate_5_km",
        reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8),
        disponivelNoHorario = disponivel,
        fotoUrl = fotoUrl,
        fotoId = fotoUrl?.let { "foto-$id" },
    )

    private val resultados = listOf(cartao("p1", "Maria S.", true), cartao("p2", "João P.", false), cartao("p3", "Ana L."), cartao("p4", "Rui T."))

    private fun comResultados(selecionados: List<String> = emptyList(), extra: (EstadoBusca) -> EstadoBusca = { it }) = extra(
        EstadoBusca(
            funcoes = listOf(garcom), funcaoId = garcom.id, casa = casa, estado = EstadoDaBusca.Resultados,
            resultados = resultados, selecionados = selecionados,
            filtroDaBusca = RascunhoDeVagaDaBusca("c1", garcom.id),
        ),
    )

    private class Chamadas {
        var funcao: String? = "nada"
        var regiao: Int? = -1
        var buscou = 0
        var carregouMais = 0
        val alternou = mutableListOf<String>()
        val perfis = mutableListOf<String>()
        var rascunho: RascunhoDeVagaDaBusca? = null
        var chamou: Pair<TrabalhoDaChamada, String?>? = null
        var confirmouJ7 = 0
        var reenviou = 0
        var horario: HorarioDaBusca? = null
        val fotosPedidas = mutableListOf<String>()
        var abriuTermos = 0
        var aceitou = 0
        var confirmouTermosDaVaga = 0
        var cancelouTermosDaVaga = 0
    }

    private val chamadas = Chamadas()
    private var estado by mutableStateOf(EstadoBusca())

    private fun montar(inicial: EstadoBusca) {
        estado = inicial
        rule.setContent {
            FrilaTheme {
                ConteudoBuscaDeProfissionais(
                    estado = estado,
                    aoVoltar = {},
                    aoEscolherFuncao = { chamadas.funcao = it },
                    aoEscolherRegiao = { chamadas.regiao = it },
                    aoDefinirHorario = { chamadas.horario = it },
                    aoBuscar = { chamadas.buscou++ },
                    aoCarregarMais = { chamadas.carregouMais++ },
                    aoTentarCatalogosDeNovo = {},
                    aoAlternarSelecao = { chamadas.alternou += it },
                    aoAbrirPerfil = { chamadas.perfis += it },
                    aoPublicarParaTodos = { chamadas.rascunho = it },
                    aoChamar = { trabalho, recado -> chamadas.chamou = trabalho to recado },
                    aoReenviar = { chamadas.reenviou++ },
                    aoConfirmarJ7 = { chamadas.confirmouJ7++ },
                    relogio = { agora },
                    aoAbrirTermos = { chamadas.abriuTermos++ },
                    aoAceitarTermos = { chamadas.aceitou++ },
                    carregarFoto = { url ->
                        chamadas.fotosPedidas += url
                        if (url.contains("excecao")) error("404") else if (url.contains("quebrada")) null else Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888).asImageBitmap()
                    },
                    aoConfirmarTermosDaVaga = { chamadas.confirmouTermosDaVaga++ },
                    aoCancelarTermosDaVaga = { chamadas.cancelouTermosDaVaga++ },
                )
            }
        }
    }

    /** Itens fora da tela nem existem na lista preguiçosa: rola até o item antes de procurar nele. */
    private fun rolarAteTag(tag: String) = rule.onNodeWithTag("busca-lista").performScrollToNode(hasTestTag(tag))
    private fun rolarAteTexto(texto: String) = rule.onNodeWithTag("busca-lista").performScrollToNode(hasText(texto))

    // --- Filtros e estados ----------------------------------------------------------------------------

    @Test
    fun buscarSoLiberaComServicoEEscolherNoMenuDevolveOId() {
        montar(EstadoBusca(funcoes = listOf(garcom), regioes = listOf(RegiaoAdministrativaDto(1, "I", "Plano Piloto"))))
        rule.onNodeWithTag("busca-buscar").assertIsNotEnabled()

        rule.onNodeWithTag("busca-funcao").performClick()
        rule.onNodeWithText("Garçom").performClick()
        assertEquals("f1", chamadas.funcao)

        rule.onNodeWithTag("busca-regiao").performClick()
        rule.onNodeWithText("Plano Piloto").performClick()
        assertEquals(1, chamadas.regiao)
    }

    @Test
    fun termosPendentesMostramOAceiteEBloqueiamABusca() {
        montar(EstadoBusca(funcoes = listOf(garcom), funcaoId = "f1", estado = EstadoDaBusca.TermosPendentes()))

        rule.onNodeWithTag("busca-termos-pendentes").assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_TERMOS_EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithTag("busca-buscar").assertIsNotEnabled()
        rule.onAllNodesWithTag("busca-termos-erro").assertCountEquals(0)

        rule.onNodeWithTag("busca-termos-ler").performClick()
        rule.onNodeWithTag("busca-termos-aceitar").assertIsEnabled().performClick()
        assertEquals(1, chamadas.abriuTermos)
        assertEquals(1, chamadas.aceitou)
    }

    @Test
    fun aceitandoDesligaOBotaoEErroDoAceiteAparece() {
        montar(EstadoBusca(funcoes = listOf(garcom), funcaoId = "f1", estado = EstadoDaBusca.TermosPendentes(aceitando = true)))
        rule.onNodeWithTag("busca-termos-aceitar").assertIsNotEnabled()
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_TERMOS_ACEITANDO).assertIsDisplayed()

        estado = estado.copy(estado = EstadoDaBusca.TermosPendentes(erro = TextosChamadaCasa.BUSCA_TERMOS_ERRO))
        rule.waitForIdle()

        rule.onNodeWithTag("busca-termos-erro").assertIsDisplayed()
        rule.onNodeWithTag("busca-termos-aceitar").assertIsEnabled()
        rule.onNodeWithTag("busca-buscar").assertIsNotEnabled()
    }

    @Test
    fun cartaoComFotoMostraAFotoECartaoSemFotoMostraAInicialDoNome() {
        val comFoto = cartao("p1", "Maria S.", fotoUrl = "https://frila.supabase.co/functions/v1/ler-midia?midia_id=x&token=t")
        val semFoto = cartao("p2", "joão P.")
        montar(comResultados { it.copy(resultados = listOf(comFoto, semFoto)) })
        rule.waitForIdle()

        rolarAteTag("busca-foto-p1")
        rule.onNodeWithTag("busca-foto-p1").assertIsDisplayed()
        rule.onAllNodesWithTag("busca-inicial-p1").assertCountEquals(0)
        rolarAteTag("busca-inicial-p2")
        rule.onNodeWithTag("busca-inicial-p2").assertIsDisplayed()
        rule.onNodeWithTag("busca-inicial-p2").assert(hasAnyDescendant(hasText("J")))
        rule.onAllNodesWithTag("busca-foto-p2").assertCountEquals(0)
        assertEquals(listOf("https://frila.supabase.co/functions/v1/ler-midia?midia_id=x&token=t"), chamadas.fotosPedidas)
    }

    @Test
    fun fotoQueNaoCarregaCaiNaInicialSemQuebrarOCartao() {
        val quebrada = cartao("p1", "Maria S.", fotoUrl = "https://frila.supabase.co/quebrada")
        montar(comResultados { it.copy(resultados = listOf(quebrada)) })
        rule.waitForIdle()

        rolarAteTag("busca-inicial-p1")
        rule.onNodeWithTag("busca-inicial-p1").assert(hasAnyDescendant(hasText("M")))
        rule.onAllNodesWithTag("busca-foto-p1").assertCountEquals(0)
        rule.onNodeWithText("Maria S.").assertIsDisplayed()
    }

    @Test
    fun fotoQueFalhaComErroMostraAInicialSemMensagemDeErro() {
        val comErro = cartao("p1", "Maria S.", fotoUrl = "https://frila.supabase.co/excecao")
        montar(comResultados { it.copy(resultados = listOf(comErro)) })
        rule.waitForIdle()

        rolarAteTag("busca-inicial-p1")
        rule.onNodeWithTag("busca-inicial-p1").assert(hasAnyDescendant(hasText("M")))
        rule.onAllNodesWithTag("busca-foto-p1").assertCountEquals(0)
        rule.onAllNodesWithText("404", substring = true).assertCountEquals(0)
        rule.onAllNodesWithTag("busca-erro").assertCountEquals(0)
    }

    @Test
    fun buscarComServicoChamaABusca() {
        montar(EstadoBusca(funcoes = listOf(garcom), funcaoId = "f1"))
        rule.onNodeWithTag("busca-buscar").assertIsEnabled().performClick()
        assertEquals(1, chamadas.buscou)
    }

    @Test
    fun filtroDeHorarioPreencheAmanhaEPassaOHorarioAoViewModel() {
        montar(EstadoBusca(funcoes = listOf(garcom), funcaoId = "f1"))

        rule.onNodeWithTag("busca-usar-horario").performClick()

        rule.waitForIdle()
        val horario = chamadas.horario
        assertNotNull(horario)
        assertEquals(Instant.parse("2026-11-17T15:00:00Z"), horario!!.inicio)
        assertEquals(Instant.parse("2026-11-17T19:00:00Z"), horario.fim)
    }

    @Test
    fun horarioIlegivelOuInvertidoDesligaABuscaComOAviso() {
        montar(EstadoBusca(funcoes = listOf(garcom), funcaoId = "f1"))
        rule.onNodeWithTag("busca-usar-horario").performClick()

        rule.onNodeWithTag("busca-fim").performTextClearance()
        rule.onNodeWithTag("busca-fim").performTextInput("amanhã")
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_DATA_INVALIDA).assertIsDisplayed()
        rule.onNodeWithTag("busca-buscar").assertIsNotEnabled()

        rule.onNodeWithTag("busca-fim").performTextClearance()
        rule.onNodeWithTag("busca-fim").performTextInput("17/11/2026 12:00")
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_HORARIO_INVALIDO).assertIsDisplayed()
        rule.onNodeWithTag("busca-buscar").assertIsNotEnabled()
        assertEquals(false, chamadas.horario?.valido)
    }

    @Test
    fun carregandoIndisponivelEErroTemCadaUmSeuTexto() {
        montar(EstadoBusca(estado = EstadoDaBusca.Carregando))
        rolarAteTexto(TextosChamadaCasa.CARREGANDO)
        rule.onNodeWithText(TextosChamadaCasa.CARREGANDO).assertIsDisplayed()

        estado = EstadoBusca(estado = EstadoDaBusca.Indisponivel)
        rolarAteTag("busca-indisponivel")
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_INDISPONIVEL).assertIsDisplayed()

        estado = EstadoBusca(funcoes = listOf(garcom), funcaoId = "f1", estado = EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS))
        rolarAteTag("busca-erro")
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.TENTAR_NOVAMENTE).performClick()
        assertEquals(1, chamadas.buscou)
    }

    @Test
    fun buscaVaziaOferecePublicarParaTodosComORascunho() {
        val rascunho = RascunhoDeVagaDaBusca("c1", "f1", regiaoId = 7)
        montar(EstadoBusca(estado = EstadoDaBusca.Vazio, filtroDaBusca = rascunho))
        rolarAteTag("busca-publicar-para-todos")
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_VAZIO).assertIsDisplayed()

        rule.onNodeWithTag("busca-publicar-para-todos").performClick()

        assertEquals(rascunho, chamadas.rascunho)
    }

    // --- Lista ----------------------------------------------------------------------------------------

    @Test
    fun cartaoMostraNomeServicoERegiaoESoQuemEstaDisponivelGanhaOSelo() {
        montar(comResultados())

        rolarAteTag("busca-cartao-p1")
        rule.onNodeWithText("Maria S.").assertIsDisplayed()
        rule.onNode(hasTestTag("busca-cartao-p1") and hasAnyDescendant(hasText("Garçom: R$ 150,00 por diária de 8 h"))).assertExists()
        rule.onNode(hasTestTag("busca-cartao-p1") and hasAnyDescendant(hasText("Plano Piloto"))).assertExists()
        // O selo só aparece no cartão com disponivel_no_horario = true.
        val selo = hasAnyDescendant(hasText(TextosChamadaCasa.BUSCA_DISPONIVEL))
        rule.onNode(hasTestTag("busca-cartao-p1") and selo).assertExists()
        rolarAteTag("busca-cartao-p2")
        rule.onNode(hasTestTag("busca-cartao-p2") and selo).assertDoesNotExist()
        rolarAteTag("busca-cartao-p3")
        rule.onNode(hasTestTag("busca-cartao-p3") and selo).assertDoesNotExist()
    }

    @Test
    fun tocarNoNomeAbreOPerfilPublicoETocarNaCaixaSelecionaOutroGesto() {
        montar(comResultados())

        rolarAteTag("busca-cartao-p3")
        rule.onNodeWithText("Ana L.").performClick()
        rule.onNodeWithTag("busca-selecionar-p3").performClick()

        assertEquals(listOf("p3"), chamadas.perfis)
        assertEquals(listOf("p3"), chamadas.alternou)
    }

    @Test
    fun ateTresSelecionadosEOAvisoDoQuartoAparece() {
        montar(comResultados(selecionados = listOf("p1", "p2", "p3")) { it.copy(avisoDeLimiteDeSelecao = TextosChamadaCasa.BUSCA_LIMITE_DE_SELECAO) })

        rolarAteTag("busca-chamar")
        rule.onNodeWithText(TextosChamadaCasa.BUSCA_LIMITE_DE_SELECAO).assertIsDisplayed()
        rule.onNodeWithText("3 selecionados de 3").assertIsDisplayed()
        rule.onNodeWithTag("busca-chamar").assertIsEnabled()
    }

    @Test
    fun semSelecaoOBotaoDeChamarFicaDesligado() {
        montar(comResultados())
        rolarAteTag("busca-chamar")
        rule.onNodeWithTag("busca-chamar").assertIsNotEnabled()
    }

    @Test
    fun carregarMaisSoApareceComProximaPagina() {
        montar(comResultados { it.copy(temMais = true) })
        rolarAteTag("busca-carregar-mais")
        rule.onNodeWithTag("busca-carregar-mais").performClick()
        assertEquals(1, chamadas.carregouMais)

        estado = comResultados()
        rolarAteTag("busca-chamar")
        assertEquals(0, rule.onAllNodesWithText(TextosChamadaCasa.BUSCA_CARREGAR_MAIS).fetchSemanticsNodes().size)
    }

    // --- Folha de chamar --------------------------------------------------------------------------------

    private fun abrirFolha(inicial: EstadoBusca) {
        montar(inicial)
        rolarAteTag("busca-chamar")
        rule.onNodeWithTag("busca-chamar").performClick()
    }

    @Test
    fun folhaSemOsCamposObrigatoriosMostraOPrimeiroMotivoENaoEnvia() {
        abrirFolha(comResultados(selecionados = listOf("p1")))

        rule.onNodeWithTag("folha-enviar").performScrollTo().performClick()
        rule.onNodeWithText(TextosChamadaCasa.FALTA_VALOR).assertIsDisplayed()

        rule.onNodeWithTag("folha-valor").performTextInput("180")
        rule.onNodeWithTag("folha-enviar").performScrollTo().performClick()
        rule.onNodeWithText(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL).assertIsDisplayed()
        assertNull(chamadas.chamou)
    }

    @Test
    fun folhaCompletaEnviaOTrabalhoDaCasaEORecado() {
        abrirFolha(comResultados(selecionados = listOf("p1", "p3")))

        rule.onNodeWithTag("folha-valor").performTextInput("180,50")
        rule.onNodeWithTag("folha-confirmar-total").performClick()
        rule.onNodeWithTag("folha-recado").performScrollTo().performTextInput("Traga avental")
        rule.onNodeWithTag("folha-enviar").performScrollTo().performClick()

        val (trabalho, recado) = chamadas.chamou!!
        assertEquals("f1", trabalho.funcaoId)
        assertEquals(18050L, trabalho.valorCentavos)
        assertEquals("SCS Quadra 2", trabalho.local)
        assertEquals("Plano Piloto", trabalho.regiaoAdministrativa)
        assertEquals("Bistrô Ipê", trabalho.responsavelLocal)
        assertEquals(Instant.parse("2026-11-17T15:00:00Z"), trabalho.inicio)
        assertEquals(Instant.parse("2026-11-17T19:00:00Z"), trabalho.fim)
        assertEquals("Traga avental", recado)
    }

    @Test
    fun folhaMostraOResultadoDeCadaPessoaEOJ7ReenviaOMesmoTrabalho() {
        abrirFolha(comResultados(selecionados = listOf("p1", "p2", "p3")))
        rule.onNodeWithTag("folha-valor").performTextInput("180")
        rule.onNodeWithTag("folha-confirmar-total").performClick()
        rule.onNodeWithTag("folha-enviar").performScrollTo().performClick()
        assertNotNull(chamadas.chamou)

        val chamada = ChamadaDto("c", "v", "p1", "c1", "aberta", expiraEm = "2026-11-17T03:00:00Z", criadaEm = "2026-11-16T15:00:00Z")
        estado = comResultados(selecionados = listOf("p1", "p2", "p3")) {
            it.copy(
                resultadosDaChamada = mapOf(
                    "p1" to ResultadoDaChamadaDaBusca.Enviada(chamada),
                    "p2" to ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia,
                    "p3" to ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.INDISPONIVEL),
                ),
                mostrarJ7 = true,
            )
        }

        rule.onNodeWithText("Maria S.: ${TextosChamadaCasa.BUSCA_RESULTADO_ENVIADA}").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("João P.: ${TextosChamadaCasa.BUSCA_RESULTADO_J7}").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Ana L.: ${TextosChamadaCasa.INDISPONIVEL}").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.J7_TITULO).performScrollTo().assertIsDisplayed()

        rule.onNodeWithTag("folha-confirmar-j7").performScrollTo().performClick()

        assertEquals(1, chamadas.confirmouJ7)
        rule.onNodeWithTag("folha-fechar").performScrollTo().performClick()
        rolarAteTag("busca-chamar")
        rule.onNodeWithTag("busca-chamar").assertExists()
        assertTrue(chamadas.confirmouJ7 == 1)
    }

    @Test
    fun folhaComTermosDaVagaAbertaConfirmaCancelaEFecharValeCancelar() {
        abrirFolha(comResultados(selecionados = listOf("p1", "p2")))
        val termos = TermosDaVagaAberta("v-aberta", 15000, incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = true)
        val esperando = ResultadoDaChamadaDaBusca.PedeConfirmacaoDosTermos(termos)
        estado = comResultados(selecionados = listOf("p1", "p2")) {
            it.copy(resultadosDaChamada = mapOf("p1" to esperando, "p2" to esperando), termosParaConfirmar = termos)
        }

        rule.onNodeWithTag("folha-termos-da-vaga").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("folha-termos-confirmar").performScrollTo().performClick()
        assertEquals(1, chamadas.confirmouTermosDaVaga)
        rule.onNodeWithTag("folha-termos-cancelar").performScrollTo().performClick()
        assertEquals(1, chamadas.cancelouTermosDaVaga)

        // Fechar com os termos por confirmar vale Cancelar: com eles pendentes o "Chamar" fica desligado e não reabre a folha.
        rule.onNodeWithTag("folha-fechar").performScrollTo().performClick()
        assertEquals(2, chamadas.cancelouTermosDaVaga)
        assertEquals(1, chamadas.confirmouTermosDaVaga)
    }

    @Test
    fun folhaComEnvioIncertoMostraNaoEnviadosEOBotaoDeTentarDeNovoReenviaOMesmoTrabalho() {
        abrirFolha(comResultados(selecionados = listOf("p1", "p2")))
        rule.onNodeWithTag("folha-valor").performTextInput("180")
        rule.onNodeWithTag("folha-confirmar-total").performClick()
        rule.onNodeWithTag("folha-enviar").performScrollTo().performClick()
        assertNotNull(chamadas.chamou)

        estado = comResultados(selecionados = listOf("p1", "p2")) {
            it.copy(
                resultadosDaChamada = mapOf(
                    "p1" to ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true),
                    "p2" to ResultadoDaChamadaDaBusca.NaoEnviada,
                ),
            )
        }

        rule.onNodeWithText("João P.: ${TextosChamadaCasa.BUSCA_RESULTADO_NAO_ENVIADA}").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("folha-reenviar").performScrollTo().performClick()

        // O reenvio usa o trabalho que o ViewModel guardou: a folha reaberta não precisa dele.
        assertEquals(1, chamadas.reenviou)
    }

    @Test
    fun comEnvioIncertoPendenteOConfirmarDoJ7FicaDesligadoComOAviso() {
        abrirFolha(comResultados(selecionados = listOf("p1", "p2", "p3")))
        rule.onNodeWithTag("folha-valor").performTextInput("180")
        rule.onNodeWithTag("folha-confirmar-total").performClick()
        rule.onNodeWithTag("folha-enviar").performScrollTo().performClick()

        estado = comResultados(selecionados = listOf("p1", "p2", "p3")) {
            it.copy(
                resultadosDaChamada = mapOf(
                    "p1" to ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia,
                    "p2" to ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true),
                    "p3" to ResultadoDaChamadaDaBusca.NaoEnviada,
                ),
                mostrarJ7 = true,
            )
        }

        rule.onNodeWithText(TextosChamadaCasa.BUSCA_CONFIRMAR_DEPOIS).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("folha-confirmar-j7").performScrollTo().assertIsNotEnabled()

        // Resolvido o envio pendente, o Confirmar volta.
        estado = estado.copy(resultadosDaChamada = estado.resultadosDaChamada + ("p2" to ResultadoDaChamadaDaBusca.Enviada(
            ChamadaDto("c", "v", "p2", "c1", "aberta", expiraEm = "2026-11-17T03:00:00Z", criadaEm = "2026-11-16T15:00:00Z"),
        )) + ("p3" to ResultadoDaChamadaDaBusca.Enviada(
            ChamadaDto("c3", "v", "p3", "c1", "aberta", expiraEm = "2026-11-17T03:00:00Z", criadaEm = "2026-11-16T15:00:00Z"),
        )))
        rule.onNodeWithTag("folha-confirmar-j7").performScrollTo().assertIsEnabled()
    }

    @Test
    fun comEnvioPendenteASelecaoFicaTravadaEABuscaDesligadaComOAviso() {
        val pendente = comResultados(selecionados = listOf("p1", "p2")) {
            it.copy(
                resultadosDaChamada = mapOf(
                    "p1" to ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true),
                    "p2" to ResultadoDaChamadaDaBusca.NaoEnviada,
                ),
            )
        }
        montar(pendente.copy(funcoes = listOf(garcom), funcaoId = "f1"))

        rule.onNodeWithTag("busca-envio-pendente").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("busca-buscar").assertIsNotEnabled()
        rolarAteTag("busca-selecionar-p3")
        rule.onNodeWithTag("busca-selecionar-p3").assertIsNotEnabled()
        rolarAteTag("busca-selecionar-p1")
        rule.onNodeWithTag("busca-selecionar-p1").assertIsNotEnabled()

        // Resolvido o envio, a seleção e a busca voltam.
        estado = estado.copy(resultadosDaChamada = emptyMap())
        rule.onNodeWithTag("busca-lista").performScrollToIndex(0)
        rule.onNodeWithTag("busca-buscar").assertIsEnabled()
        rolarAteTag("busca-selecionar-p3")
        rule.onNodeWithTag("busca-selecionar-p3").assertIsEnabled()
    }

    @Test
    fun comEnvioPendenteELimiteDeBuscaAListaEmErroAindaOferecePrecisaVerOEnvioPendente() {
        montar(
            EstadoBusca(
                funcoes = listOf(garcom), funcaoId = "f1", casa = casa,
                estado = EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS),
                resultados = resultados, selecionados = listOf("p1"),
                resultadosDaChamada = mapOf("p1" to ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true)),
                filtroDaBusca = RascunhoDeVagaDaBusca("c1", garcom.id),
            ),
        )

        rolarAteTag("busca-ver-envio-pendente")
        rule.onNodeWithTag("busca-ver-envio-pendente").assertIsEnabled().performClick()

        // A folha abre mesmo com a lista em erro, e dali sai o "Tentar de novo".
        rule.onNodeWithTag("folha-reenviar").performScrollTo().performClick()
        assertEquals(1, chamadas.reenviou)
    }

    @Test
    fun semEnvioPendenteAListaEmErroNaoMostraOBotaoDeEnvioPendente() {
        montar(EstadoBusca(funcoes = listOf(garcom), funcaoId = "f1", estado = EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_ERRO)))
        rolarAteTag("busca-erro")
        rule.onAllNodesWithTag("busca-ver-envio-pendente").assertCountEquals(0)
    }

    @Test
    fun folhaDaBuscaComHorarioNoFiltroJaSaiComEleEMostraAvisoSeFaltaCasa() {
        val horario = HorarioDaBusca(Instant.parse("2026-11-20T22:00:00Z"), Instant.parse("2026-11-21T02:00:00Z"))
        abrirFolha(comResultados(selecionados = listOf("p1")) { it.copy(horario = horario, casa = null) })

        rule.onNodeWithText(TextosChamadaCasa.BUSCA_SEM_CASA).assertIsDisplayed()
        rule.onNodeWithTag("folha-inicio").assert(hasText("20/11/2026 19:00"))
    }
}
