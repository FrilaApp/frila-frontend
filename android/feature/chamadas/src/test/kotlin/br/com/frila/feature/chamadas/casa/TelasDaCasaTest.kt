package br.com.frila.feature.chamadas.casa

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ChamadaDto
import br.com.frila.core.rede.ChamadaResumoDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.RegiaoAdministrativaDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoNoPerfilDto
import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Os estados principais das três telas da casa: perfil público, folha de chamar e acompanhar. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class TelasDaCasaTest {

    @get:Rule
    val rule = createComposeRule()

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val garcom = FuncaoDto("f1", "Garçom", "salao")
    private val reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8)

    // --- Perfil público -------------------------------------------------------------------------------

    private val perfil = PerfilPublicoDto(
        id = "p1", tipo = "profissional", nome = "Maria S.", funcoes = listOf("Garçom"), reputacao = reputacao,
        apresentacao = "Dez anos de salão", experienciaFaixa = "de_5_a_10_anos", cursos = listOf("Boas práticas"),
        idiomas = listOf("portugues", "ingles"),
        servicos = listOf(
            ServicoNoPerfilDto(funcao = garcom, unidade = "diaria", valorCentavos = 15000, horasIncluidas = 8),
        ),
        regioes = listOf(RegiaoAdministrativaDto(1, "I", "Plano Piloto")),
        atendeTodoDf = false,
    )

    private fun montarPerfil(estado: EstadoPerfilPublico, aoChamar: ((PerfilPublicoDto) -> Unit)? = null, aoTentar: () -> Unit = {}) {
        rule.setContent {
            FrilaTheme { ConteudoPerfilPublico(estado, aoTentarNovamente = aoTentar, aoVoltar = {}, aoChamar = aoChamar) }
        }
    }

    @Test
    fun perfilMostraNomeServicosComPrecoReputacaoERegioes() {
        montarPerfil(EstadoPerfilPublico.Carregado(perfil))

        rule.onNodeWithText("Maria S.").assertIsDisplayed().assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText("7 de 8 chamariam de novo").assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.SERVICOS_OFERECIDOS).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("R$ 150,00 por diária de 8 h").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Dez anos de salão").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("5 a 10 anos").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Português, Inglês").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Plano Piloto").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun perfilIndisponivelFalhaECarregandoTemCadaUmSeuTexto() {
        montarPerfil(EstadoPerfilPublico.Indisponivel)
        rule.onNodeWithText(TextosChamadaCasa.PERFIL_INDISPONIVEL).assertIsDisplayed()
    }

    @Test
    fun perfilComFalhaOferecerTentarNovamente() {
        var tentou = 0
        montarPerfil(EstadoPerfilPublico.Falha(TextosChamadaCasa.SEM_REDE), aoTentar = { tentou++ })
        rule.onNodeWithText(TextosChamadaCasa.SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText("Tentar novamente").performClick()
        assertEquals(1, tentou)
    }

    @Test
    fun botaoDeChamarSoApareceSeARotaPassarAChaveELevaOPerfil() {
        var chamado: String? = null
        montarPerfil(EstadoPerfilPublico.Carregado(perfil), aoChamar = { chamado = it.id })

        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).performScrollTo().performClick()

        assertEquals("p1", chamado)
    }

    @Test
    fun semAChaveLigadaOBotaoNaoExiste() {
        montarPerfil(EstadoPerfilPublico.Carregado(perfil), aoChamar = null)
        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).assertDoesNotExist()
    }

    // --- Folha de chamar --------------------------------------------------------------------------------

    private fun folha(ajuste: EstadoChamadaDireta.() -> EstadoChamadaDireta = { this }): EstadoChamadaDireta {
        val inicio = agora.plus(Duration.ofHours(24))
        return EstadoChamadaDireta(
            funcoes = listOf(garcom), funcaoId = "f1", local = "SCS Quadra 2", inicio = inicio, fim = inicio.plus(Duration.ofHours(4)),
            responsavel = "Bistrô Ipê", recursoHabilitado = true, agora = agora, pontoDaCasa = CoordenadaDto(-15.79, -47.88),
        ).ajuste()
    }

    private fun montarFolha(tela: EstadoChamadaDireta, acoes: AcoesChamadaDireta = AcoesChamadaDireta()) {
        rule.setContent {
            FrilaTheme {
                ConteudoChamadaDireta(
                    tela = tela, acoes = acoes,
                    inicioMinimo = { agora.plus(Duration.ofHours(2)) },
                    faixaDoTermino = { tela.inicio.plus(Duration.ofHours(2))..tela.inicio.plus(Duration.ofHours(16)) },
                )
            }
        }
    }

    @Test
    fun folhaMostraOsCamposNaOrdemDoIOSEOBotaoDesligadoDizOQueFalta() {
        montarFolha(folha())

        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).assertIsDisplayed()
        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("SCS Quadra 2").assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.INICIO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.TERMINO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.ENVIAR).assertIsNotEnabled()
        rule.onNodeWithText(TextosChamadaCasa.FALTA_VALOR).assertIsDisplayed()
    }

    @Test
    fun folhaCompletaLigaOBotaoEEnvia() {
        var enviou = 0
        montarFolha(folha { copy(valorTexto = "180", totalConfirmado = true) }, AcoesChamadaDireta(aoEnviar = { enviou++ }))

        rule.onNodeWithText(TextosChamadaCasa.ENVIAR).assertIsEnabled().performClick()

        assertEquals(1, enviou)
    }

    @Test
    fun folhaEnviandoNaoDeixaEnviarDeNovoEMostraProgresso() {
        montarFolha(folha { copy(valorTexto = "180", totalConfirmado = true, enviando = true, travado = true) })

        rule.onNodeWithText(TextosChamadaCasa.CARREGANDO).assertIsNotEnabled()
    }

    @Test
    fun folhaMostraOAvisoJ7ComConfirmarECancelar() {
        var confirmou = 0
        var dispensou = 0
        montarFolha(
            folha { copy(valorTexto = "180", totalConfirmado = true, mostrarJ7 = true, travado = true) },
            AcoesChamadaDireta(aoConfirmarJ7 = { confirmou++ }, aoDispensarJ7 = { dispensou++ }),
        )

        rule.onNodeWithText(TextosChamadaCasa.J7_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.J7_MENSAGEM).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.J7_CONFIRMAR).performClick()
        rule.onNodeWithText(TextosChamadaCasa.CANCELAR).performClick()

        assertEquals(1, confirmou)
        assertEquals(1, dispensou)
    }

    @Test
    fun folhaComRecadoLongoMostraOErro() {
        montarFolha(folha { copy(recado = "a".repeat(301)) })
        rule.onNodeWithText(TextosChamadaCasa.RECADO_LONGO).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun folhaComRecursoDesligadoMostraSoOErroETentarNovamente() {
        var tentou = 0
        montarFolha(
            folha { copy(recursoHabilitado = false, erro = TextosChamadaCasa.DESLIGADO) },
            AcoesChamadaDireta(aoTentarNovamente = { tentou++ }),
        )

        rule.onNodeWithText(TextosChamadaCasa.DESLIGADO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.ENVIAR).assertDoesNotExist()
        rule.onNodeWithText(TextosChamadaCasa.TENTAR_NOVAMENTE).performClick()
        assertEquals(1, tentou)
    }

    @Test
    fun folhaEnviadaMostraOResumoOPrazoEOCaminhoParaAcompanhar() {
        var vaga: String? = null
        val chamada = ChamadaDto(
            id = "c1", vagaId = "v1", profissionalId = "p1", estabelecimentoId = "e1", estado = "aberta",
            expiraEm = "2026-11-17T12:00:00Z", criadaEm = "2026-11-16T15:00:00Z",
        )
        montarFolha(
            folha { copy(valorTexto = "180", totalConfirmado = true, resultado = chamada, travado = true) },
            AcoesChamadaDireta(aoAcompanhar = { vaga = it }),
        )

        rule.onNodeWithText(TextosChamadaCasa.SUCESSO).assertIsDisplayed()
        rule.onNodeWithText("O profissional tem até 17/11/2026 09:00 para responder.").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("R$ 180,00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Bistrô Ipê").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.ENVIAR).assertDoesNotExist()
        rule.onNodeWithText(TextosChamadaCasa.ACOMPANHAR_TITULO).performScrollTo().performClick()
        assertEquals("v1", vaga)
    }

    // --- Acompanhar -------------------------------------------------------------------------------------

    private fun resumo(id: String, estado: String, nome: String = "Maria S.", motivo: String? = null) = ChamadaResumoDto(
        id = id, vagaId = "v1", profissionalId = "p1", estabelecimentoId = "e1", estado = estado, motivoRecusa = motivo,
        expiraEm = "2026-11-17T12:00:00Z", criadaEm = "2026-11-16T15:00:00Z", funcao = garcom,
        inicioEm = "2026-11-20T22:00:00Z", fimEm = "2026-11-21T02:00:00Z", valorCentavos = 18000,
        outraParte = PerfilPublicoDto(id = "p1", tipo = "profissional", nome = nome, reputacao = reputacao),
    )

    private class Acompanhar {
        val cancelados = mutableListOf<String>()
        var publicou = 0
        var viuVaga: String? = null
    }

    private fun montarAcompanhar(tela: EstadoAcompanharChamadas, c: Acompanhar = Acompanhar()): Acompanhar {
        rule.setContent {
            FrilaTheme {
                ConteudoAcompanharChamadas(
                    tela = tela, aoCancelar = { c.cancelados += it }, aoPublicarParaTodos = { c.publicou++ },
                    aoVoltar = {}, aoVerVagaPublicada = { c.viuVaga = it },
                )
            }
        }
        return c
    }

    @Test
    fun acompanharMostraEstadoEMotivoDeCadaChamada() {
        montarAcompanhar(
            EstadoAcompanharChamadas(chamadas = listOf(resumo("a", "aberta"), resumo("b", "recusada", "Joana P.", motivo = "valor"))),
        )

        rule.onNodeWithText("Maria S.").assertIsDisplayed()
        rule.onNodeWithText("Aguardando resposta").assertIsDisplayed()
        rule.onNodeWithText("Joana P.").assertIsDisplayed()
        rule.onNodeWithText("Recusada").assertIsDisplayed()
        rule.onNodeWithText("Motivo: Valor proposto").assertIsDisplayed()
    }

    @Test
    fun cancelarPedeConfirmacaoESoDepoisCancela() {
        val c = montarAcompanhar(EstadoAcompanharChamadas(chamadas = listOf(resumo("a", "aberta"))))

        rule.onNodeWithContentDescription("${TextosChamadaCasa.CANCELAR_CHAMADA}: Maria S.").performClick()
        rule.onNodeWithText(TextosChamadaCasa.CONFIRMAR_CANCELAMENTO).assertIsDisplayed()
        assertTrue(c.cancelados.isEmpty())
        rule.onNodeWithText(TextosChamadaCasa.CONFIRMAR_CANCELAMENTO_BOTAO).performClick()

        assertEquals(listOf("a"), c.cancelados)
    }

    @Test
    fun soChamadaAbertaTemBotaoDeCancelar() {
        montarAcompanhar(EstadoAcompanharChamadas(chamadas = listOf(resumo("a", "aceita"))))
        rule.onNodeWithText(TextosChamadaCasa.CANCELAR_CHAMADA).assertDoesNotExist()
    }

    @Test
    fun publicarParaTodosAparecePorQuemTerminouSemAceite() {
        val c = montarAcompanhar(EstadoAcompanharChamadas(chamadas = listOf(resumo("a", "recusada"), resumo("b", "expirada"))))

        rule.onNodeWithText(TextosChamadaCasa.PUBLICAR_PARA_TODOS_EXPLICACAO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.PUBLICAR_PARA_TODOS).performScrollTo().performClick()

        assertEquals(1, c.publicou)
    }

    @Test
    fun publicarParaTodosNaoApareceComChamadaAbertaOuAceita() {
        montarAcompanhar(EstadoAcompanharChamadas(chamadas = listOf(resumo("a", "aberta"), resumo("b", "recusada"))))
        rule.onNodeWithText(TextosChamadaCasa.PUBLICAR_PARA_TODOS).assertDoesNotExist()
    }

    @Test
    fun listaVaziaEVagaPublicadaTemOsSeusAvisos() {
        val c = montarAcompanhar(
            EstadoAcompanharChamadas(vagaPublicadaId = "nova", sucesso = TextosChamadaCasa.VAGA_PUBLICADA_SUCESSO),
        )

        rule.onNodeWithText(TextosChamadaCasa.NENHUMA_CHAMADA).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.VAGA_PUBLICADA_SUCESSO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.VER_VAGA_ABERTA).performScrollTo().performClick()
        assertEquals("nova", c.viuVaga)
    }
}
