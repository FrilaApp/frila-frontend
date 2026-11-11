package br.com.frila.feature.vagas.publicacao

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.NovaVagaDto
import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaPublicarVagaTest {

    @get:Rule
    val rule = createComposeRule()

    private val base: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private class Chamadas {
        var publicacoes = 0
        var voltou = 0
        var recarregouFuncoes = 0
        var inicio: Instant? = null
        var modo: ModoDaVaga? = null
        var refeicao: Boolean? = null
        var maisUma = 0
        var menosUma = 0
    }

    private fun estado(
        inicio: Instant = base.plus(Duration.ofHours(3)),
        mudar: EstadoPublicarVaga.() -> EstadoPublicarVaga = { this },
    ) = EstadoPublicarVaga(
        funcoes = listOf(FuncaoDto("f1", "Garçom", "Salão"), FuncaoDto("f2", "Cozinheiro", "Cozinha")),
        inicio = inicio,
        fim = inicio.plus(Duration.ofHours(3)),
        local = "CLS 408, Bloco B",
        agora = base,
    ).mudar()

    /** O estado vive no teste, como o `StateFlow` do ViewModel vive na tela; as edições o atualizam. */
    private fun montar(inicial: EstadoPublicarVaga = estado(), chamadas: Chamadas = Chamadas()): Chamadas {
        rule.setContent {
            var estado by mutableStateOf(inicial)
            FrilaTheme {
                ConteudoPublicarVaga(
                    estado = estado,
                    acoes = AcoesPublicarVaga(
                        aoCarregarFuncoes = { chamadas.recarregouFuncoes++ },
                        aoEscolherFuncao = { estado = estado.copy(funcaoId = it) },
                        aoEditarInicio = { chamadas.inicio = it },
                        aoEscolherModo = { chamadas.modo = it; estado = estado.copy(modo = it) },
                        aoEditarValor = { estado = estado.copy(valor = it) },
                        aoEditarResponsavel = { estado = estado.copy(responsavelLocal = it) },
                        aoMaisUmaPosicao = { chamadas.maisUma++ },
                        aoMenosUmaPosicao = { chamadas.menosUma++ },
                        aoAlternarRefeicao = { chamadas.refeicao = it; estado = estado.copy(incluiRefeicao = it) },
                        aoPublicar = { chamadas.publicacoes++ },
                        aoVoltar = { chamadas.voltou++ },
                    ),
                )
            }
        }
        return chamadas
    }

    @Test
    fun `mostra o formulario com titulo em cabecalho, secoes e botao de publicar`() {
        montar()

        rule.onNodeWithText(TextosPublicarVaga.TITULO)
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosPublicarVaga.FUNCAO).assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.QUANDO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.MODO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.PUBLICAR).performScrollTo().assertIsEnabled()
    }

    @Test
    fun `mostra data e hora do inicio e do fim no fuso de Brasilia`() {
        montar()

        rule.onNodeWithContentDescription("${TextosPublicarVaga.DATA_DO_INICIO}: 10/11/2026").performScrollTo().assertIsDisplayed()
        rule.onNodeWithContentDescription("${TextosPublicarVaga.HORA_DO_INICIO}: 15:00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithContentDescription("${TextosPublicarVaga.HORA_DO_FIM}: 18:00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Duração: 3 h").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `confirmar o seletor de hora devolve o inicio com a hora escolhida`() {
        val chamadas = montar()

        rule.onNodeWithContentDescription("${TextosPublicarVaga.HORA_DO_INICIO}: 15:00").performClick()
        rule.onNodeWithText(TextosPublicarVaga.CONFIRMAR).performClick()

        assertEquals(base.plus(Duration.ofHours(3)), chamadas.inicio)
    }

    @Test
    fun `confirmar o seletor de data sem mudar o dia devolve o mesmo inicio`() {
        val chamadas = montar()

        rule.onNodeWithContentDescription("${TextosPublicarVaga.DATA_DO_INICIO}: 10/11/2026").performClick()
        rule.onNodeWithText(TextosPublicarVaga.CONFIRMAR).performClick()

        assertEquals(base.plus(Duration.ofHours(3)), chamadas.inicio)
    }

    @Test
    fun `cancelar o seletor de hora nao muda o inicio`() {
        val chamadas = montar()

        rule.onNodeWithContentDescription("${TextosPublicarVaga.HORA_DO_INICIO}: 15:00").performClick()
        rule.onNodeWithText(TextosPublicarVaga.CANCELAR).performClick()

        assertNull(chamadas.inicio)
    }

    @Test
    fun `escolher a funcao no seletor mostra o nome no botao`() {
        montar()

        rule.onNodeWithText(TextosPublicarVaga.FUNCAO_SELECIONAR).performClick()
        rule.onNodeWithText("Cozinheiro").performClick()

        rule.onNodeWithText("Cozinheiro").assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.FUNCAO_SELECIONAR).assertDoesNotExist()
    }

    @Test
    fun `carregando as funcoes mostra o progresso`() {
        montar(estado { copy(funcoes = emptyList(), carregandoFuncoes = true) })

        rule.onNodeWithText(TextosPublicarVaga.FUNCOES_CARREGANDO).assertIsDisplayed()
    }

    @Test
    fun `falha ao carregar as funcoes mostra a mensagem e deixa tentar de novo`() {
        val chamadas = montar(estado { copy(funcoes = emptyList(), falhaAoCarregarFuncoes = true) })

        rule.onNodeWithText(TextosPublicarVaga.FUNCOES_FALHA).assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.TENTAR_NOVAMENTE).performClick()

        assertEquals(1, chamadas.recarregouFuncoes)
    }

    @Test
    fun `selecao fica desabilitada com menos de 24 horas e explica o motivo`() {
        montar()

        rule.onNodeWithText(TextosPublicarVaga.MODO_SELECAO).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithText(TextosPublicarVaga.MODO_SELECAO_SO_COM_ANTECEDENCIA).assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.MODO_URGENCIA)
            .performScrollTo()
            .assertIsSelected()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
    }

    @Test
    fun `selecao com mais de 24 horas pode ser escolhida`() {
        val chamadas = montar(estado(inicio = base.plus(Duration.ofHours(48))))

        rule.onNodeWithText(TextosPublicarVaga.MODO_SELECAO).performScrollTo().assertIsEnabled().performClick()

        assertEquals(ModoDaVaga.SELECAO, chamadas.modo)
        rule.onNodeWithText(TextosPublicarVaga.MODO_SELECAO).assertIsSelected()
        rule.onNodeWithText(TextosPublicarVaga.MODO_SELECAO_EXPLICACAO).assertIsDisplayed()
    }

    @Test
    fun `o total da vaga mostra valor por pessoa vezes as posicoes`() {
        montar(estado { copy(valor = "140", posicoes = "2") })

        rule.onNodeWithText("Total da vaga: R$ 280,00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Soma de 2 pessoas, pago direto a cada uma").assertIsDisplayed()
        rule.onNodeWithText("Cerca de R$ 46,67 por hora").assertIsDisplayed()
    }

    @Test
    fun `digitar o valor atualiza o total`() {
        montar()

        rule.onNodeWithText(TextosPublicarVaga.VALOR).performScrollTo().performTextInput("200")

        rule.onNodeWithText("Total da vaga: R$ 200,00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.TOTAL_SINGULAR).assertIsDisplayed()
    }

    @Test
    fun `mais e menos posicao chamam o ViewModel e tem rotulo de acessibilidade`() {
        val chamadas = montar()

        rule.onNodeWithContentDescription(TextosPublicarVaga.MAIS_UMA_POSICAO).performScrollTo().performClick()
        rule.onNodeWithContentDescription(TextosPublicarVaga.MENOS_UMA_POSICAO).performScrollTo().performClick()

        assertEquals(1, chamadas.maisUma)
        assertEquals(1, chamadas.menosUma)
    }

    @Test
    fun `chave de refeicao e um switch que chama o ViewModel`() {
        val chamadas = montar()

        rule.onNodeWithText(TextosPublicarVaga.REFEICAO)
            .performScrollTo()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Switch))
            .performClick()

        assertEquals(true, chamadas.refeicao)
    }

    @Test
    fun `mais opcoes abre traje, rateio e observacoes`() {
        montar()
        rule.onNodeWithText(TextosPublicarVaga.TRAJE).assertDoesNotExist()

        rule.onNodeWithText(TextosPublicarVaga.MAIS_OPCOES).performScrollTo().performClick()

        rule.onNodeWithText(TextosPublicarVaga.TRAJE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.RATEIO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.OBSERVACOES).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `erros de campo aparecem no proprio campo e o erro global acima do botao`() {
        montar(
            estado {
                copy(
                    errosDeCampo = mapOf(
                        CampoPublicacao.VALOR to TextosPublicarVaga.VALOR_CAMPO,
                        CampoPublicacao.RESPONSAVEL to TextosPublicarVaga.RESPONSAVEL_CAMPO,
                        CampoPublicacao.INICIO to TextosPublicarVaga.HORARIO_INICIO_CAMPO,
                    ),
                    erro = ErroGlobalPublicacao.CONFIRA_CAMPOS,
                )
            },
        )

        rule.onNodeWithText(TextosPublicarVaga.VALOR_CAMPO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.RESPONSAVEL_CAMPO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.HORARIO_INICIO_CAMPO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.ERRO_CONFIRA_CAMPOS).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `erro de conta suspensa e anunciado`() {
        montar(estado { copy(erro = ErroGlobalPublicacao.CONTA_SUSPENSA) })

        rule.onNodeWithText(TextosPublicarVaga.ERRO_CONTA_SUSPENSA).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `publicar chama o ViewModel e voltar tambem`() {
        val chamadas = montar()

        rule.onNodeWithText(TextosPublicarVaga.PUBLICAR).performScrollTo().performClick()
        rule.onNodeWithContentDescription(TextosPublicarVaga.ROTULO_VOLTAR).performClick()

        assertEquals(1, chamadas.publicacoes)
        assertEquals(1, chamadas.voltou)
    }

    @Test
    fun `enquanto envia o botao mostra publicando e desabilita botao, campos e voltar`() {
        montar(estado { copy(enviando = true, valor = "140") })

        rule.onNodeWithText(TextosPublicarVaga.PUBLICANDO).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithText(TextosPublicarVaga.FUNCAO_SELECIONAR).assertIsNotEnabled()
        rule.onNodeWithText(TextosPublicarVaga.RESPONSAVEL).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithContentDescription(TextosPublicarVaga.ROTULO_VOLTAR).assertIsNotEnabled()
    }

    @Test
    fun `com publicacao pendente o botao vira tentar novamente, avisa e trava os campos`() {
        val pendente = NovaVagaDto(
            estabelecimentoId = "e1", funcaoId = "f1", inicioEm = "2026-11-10T18:00:00Z", fimEm = "2026-11-10T21:00:00Z",
            local = "CLS", regiaoAdministrativa = "Plano Piloto", ponto = br.com.frila.core.rede.CoordenadaDto(-15.0, -47.0),
            valorCentavos = 14_000, posicoes = 1, incluiRefeicao = false, incluiTransporte = false, exigeMaterialProprio = false,
            responsavelLocal = "Lia", modo = "urgencia", chave = "chave-1",
        )
        val chamadas = montar(estado { copy(pendente = pendente, erro = ErroGlobalPublicacao.SEM_REDE) })

        rule.onNodeWithText(TextosPublicarVaga.PENDENTE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.ERRO_SEM_REDE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.RESPONSAVEL).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithText(TextosPublicarVaga.TENTAR_NOVAMENTE).performScrollTo().assertIsEnabled().performClick()

        assertEquals(1, chamadas.publicacoes)
    }

    @Test
    fun `vaga publicada mostra a confirmacao e desabilita o botao`() {
        montar(estado { copy(publicada = br.com.frila.core.rede.VagaPublicadaDto("v1", listOf("p1"))) })

        rule.onNodeWithText(TextosPublicarVaga.CONCLUIDA).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosPublicarVaga.PUBLICAR).performScrollTo().assertIsNotEnabled()
    }

    @Test
    fun `alvos de toque do botao e dos switches tem pelo menos o tamanho minimo`() {
        montar()

        rule.onNodeWithText(TextosPublicarVaga.PUBLICAR).performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithText(TextosPublicarVaga.REFEICAO).performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }
}
