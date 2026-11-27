package br.com.frila.feature.chamadas.casa

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CartaoProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import br.com.frila.core.rede.RegiaoAdministrativaDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoNoPerfilDto
import java.time.Instant
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão Qs5i1FNd: os textos da busca da casa que o iOS (`TextosBuscaDeProfissionais.swift`) escreveu depois e que as duas telas dizem do
 * mesmo jeito. Cada teste afirma o texto exato e que o texto antigo não aparece mais. As diferenças que NÃO foram alinhadas (campos de
 * data digitados, "Qualquer região", a busca vazia com o botão de publicar, o retry do envio incerto) ficam descritas no PR.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class BuscaComOTextoDoIosTest {

    @get:Rule
    val rule = createComposeRule()

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val garcom = FuncaoDto("f1", "Garçom", "salao")
    private val casa = MeuEstabelecimentoDto(
        id = "c1", nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )

    private fun cartao(id: String, nome: String) = CartaoProfissionalDto(
        id = id, nome = nome,
        servico = ServicoNoPerfilDto(funcao = garcom, unidade = "diaria", valorCentavos = 15000, horasIncluidas = 8),
        regioes = listOf(RegiaoAdministrativaDto(1, "I", "Plano Piloto")),
        distanciaFaixa = "ate_5_km",
        reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8),
    )

    private val resultados = listOf(cartao("p1", "Maria S."), cartao("p2", "João P."))

    private fun comResultados(selecionados: List<String> = emptyList(), extra: (EstadoBusca) -> EstadoBusca = { it }) = extra(
        EstadoBusca(
            funcoes = listOf(garcom), funcaoId = garcom.id, casa = casa, estado = EstadoDaBusca.Resultados,
            resultados = resultados, selecionados = selecionados,
            filtroDaBusca = RascunhoDeVagaDaBusca("c1", garcom.id),
        ),
    )

    private var estado by mutableStateOf(EstadoBusca())

    private fun montar(inicial: EstadoBusca) {
        estado = inicial
        rule.setContent {
            FrilaTheme {
                ConteudoBuscaDeProfissionais(
                    estado = estado,
                    aoVoltar = {},
                    aoEscolherFuncao = {},
                    aoEscolherRegiao = {},
                    aoDefinirHorario = {},
                    aoBuscar = {},
                    aoCarregarMais = {},
                    aoTentarCatalogosDeNovo = {},
                    aoAlternarSelecao = {},
                    aoAbrirPerfil = {},
                    aoPublicarParaTodos = {},
                    aoChamar = { _, _ -> },
                    aoReenviar = {},
                    aoConfirmarJ7 = {},
                    relogio = { agora },
                    aoAbrirTermos = {},
                    aoAbrirPolitica = {},
                    aoAceitarTermos = {},
                    carregarFoto = { null },
                    aoConfirmarTermosDaVaga = {},
                    aoCancelarTermosDaVaga = {},
                )
            }
        }
    }

    private fun rolarAteTexto(texto: String) = rule.onNodeWithTag("busca-lista").performScrollToNode(hasText(texto))

    @Test
    fun `o filtro de horario se chama Buscar por horario, como no iOS`() {
        montar(EstadoBusca(funcoes = listOf(garcom), casa = casa))

        rolarAteTexto("Buscar por horário")
        rule.onNodeWithText("Buscar por horário").assertIsDisplayed()
        rule.onNodeWithText("Filtrar por horário").assertDoesNotExist()
    }

    @Test
    fun `o seletor de servico pede Escolha um servico, como no iOS`() {
        montar(EstadoBusca(funcoes = listOf(garcom), casa = casa))

        rule.onNodeWithText("Escolha um serviço").assertIsDisplayed()
        rule.onNodeWithText("Escolha o serviço").assertDoesNotExist()
    }

    @Test
    fun `a falha dos catalogos fala de servicos e regioes, como no iOS`() {
        montar(EstadoBusca(falhaDeCatalogos = true))

        rule.onNodeWithText("Não foi possível carregar os serviços e as regiões agora. Verifique sua conexão e tente de novo.").assertIsDisplayed()
        rule.onNodeWithText("Não foi possível carregar os filtros. Verifique sua conexão e tente novamente.").assertDoesNotExist()
    }

    @Test
    fun `a folha de chamada se chama Chamar profissionais, como no iOS`() {
        montar(comResultados(selecionados = listOf("p1")))

        rule.onNodeWithTag("busca-chamar").performClick()

        rule.onNodeWithText("Chamar profissionais").assertIsDisplayed()
        rule.onNodeWithText("Chamar selecionados").assertDoesNotExist()
    }

    @Test
    fun `a recorrencia pendente diz que falta confirmar o aviso da chamada recorrente, como no iOS`() {
        montar(comResultados(selecionados = listOf("p1", "p2")))
        rule.onNodeWithTag("busca-chamar").performClick()
        rule.onNodeWithTag("folha-valor").performTextInput("180")
        rule.onNodeWithTag("folha-confirmar-total").performClick()
        rule.onNodeWithTag("folha-enviar").performScrollTo().performClick()

        estado = comResultados(selecionados = listOf("p1", "p2")) {
            it.copy(resultadosDaChamada = mapOf("p2" to ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia), mostrarJ7 = true)
        }

        rule.onNodeWithText("João P.: Falta confirmar o aviso da chamada recorrente").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("João P.: Aguardando a sua confirmação do aviso").assertDoesNotExist()
    }
}
