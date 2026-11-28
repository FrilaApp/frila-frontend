package br.com.frila.feature.vagas.escala

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.EscalaPublicadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.ModoDaVaga
import br.com.frila.feature.vagas.publicacao.TextosPublicarVaga
import java.time.Instant
import java.time.LocalDate
import java.util.TimeZone
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão uKOCIOiR (item 227): na escala, a vaga em seleção mostra o prazo exato de escolha ("Você terá até 16/11/2026 às 18:00 para
 * escolher..."), como o iOS (`TelaPublicarEscala.swift:342-347`, de `prazoDeEscolha`) e como a publicação de uma vaga só (#1250). O prazo é
 * 24 h antes do início, no fuso de São Paulo, e some fora do modo seleção. Fora: o aviso de prazo curto, que o iOS não mostra na escala.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaEscalaDePrazoDeEscolhaTest {

    @get:Rule
    val rule = createComposeRule()

    private val fusoDoAparelho = TimeZone.getDefault()

    // O aparelho em UTC: com o fuso do aparelho no lugar do de SP, a hora mostrada muda e o teste cai.
    @Before fun aparelhoEmUtc() = TimeZone.setDefault(TimeZone.getTimeZone("UTC"))

    @After fun devolveOFuso() = TimeZone.setDefault(fusoDoAparelho)

    /** Quarta-feira, 12h em Brasília: o evento nasce em 17/11, a vaga às 18h; o prazo é 16/11 às 18:00. */
    private var agora: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private fun viewModel() = EscalaDeEventoViewModel(
        estabelecimento = EstabelecimentoDaVaga("e1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822)),
        buscarFuncoes = { listOf(FuncaoDto("f1", "Garçom", "Salão")) },
        enviarEscala = { EscalaPublicadaDto("ev1", emptyList()) },
        relogio = { agora },
        novaChave = { "chave-1" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun montar(vm: EscalaDeEventoViewModel) {
        rule.setContent { FrilaTheme(temaEscuro = false) { TelaEscalaDeEvento(viewModel = vm, aoConcluir = {}, aoVoltar = {}) } }
    }

    private fun prazo(dataEHora: String) = TextosPublicarVaga.modoSelecaoPrazo(dataEHora)

    @Test
    fun `vaga em selecao mostra ate quando a casa escolhe, 24 h antes do inicio, na hora de Sao Paulo`() {
        val vm = viewModel()
        vm.escolherModo(vm.estado.value.itens.single().id, ModoDaVaga.SELECAO)
        montar(vm)

        rule.onNodeWithText(prazo("16/11/2026 às 18:00")).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `vaga em urgencia nao mostra prazo de escolha`() {
        val vm = viewModel()
        montar(vm)

        rule.onNodeWithText(prazo("16/11/2026 às 18:00")).assertDoesNotExist()
    }

    @Test
    fun `cada vaga em selecao mostra o prazo do seu proprio inicio`() {
        val vm = viewModel()
        val primeira = vm.estado.value.itens.single().id
        vm.escolherModo(primeira, ModoDaVaga.SELECAO)
        vm.adicionarVaga()
        val segunda = vm.estado.value.itens.last().id
        vm.editarInicio(segunda, Instant.parse("2026-11-19T13:00:00Z")) // 19/11, 10h de Brasília
        vm.escolherModo(segunda, ModoDaVaga.SELECAO)
        montar(vm)

        rule.onNodeWithText(prazo("16/11/2026 às 18:00")).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(prazo("18/11/2026 às 10:00")).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `mudar o dia do evento muda o prazo mostrado`() {
        val vm = viewModel()
        vm.escolherModo(vm.estado.value.itens.single().id, ModoDaVaga.SELECAO)
        vm.editarData(LocalDate.of(2026, 11, 20))
        montar(vm)

        rule.onNodeWithText(prazo("19/11/2026 às 18:00")).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithText(prazo("16/11/2026 às 18:00")).assertCountEquals(0)
    }

    @Test
    fun `seleção cujo prazo passou enquanto a tela estava aberta nao mostra mais o prazo`() {
        val vm = viewModel()
        vm.escolherModo(vm.estado.value.itens.single().id, ModoDaVaga.SELECAO)
        // O relógio andou: faltam 23 h para o início (17/11 21:00Z), então as 24 h de antecedência já acabaram. Uma edição renova o relógio do estado.
        agora = Instant.parse("2026-11-16T22:00:00Z")
        vm.editarNome("Formatura de Direito")
        montar(vm)

        rule.onAllNodesWithText(prazo("16/11/2026 às 18:00")).assertCountEquals(0)
    }

    @Test
    fun `o aviso de prazo curto nao aparece na escala, como no iOS`() {
        // Seleção com início a 24 h e 1 min: o prazo (início - 24 h) fica a 1 min de agora, bem abaixo das 12 h do aviso de prazo curto.
        agora = Instant.parse("2026-11-10T20:58:00Z")
        val vm = viewModel()
        val id = vm.estado.value.itens.single().id
        vm.editarData(LocalDate.of(2026, 11, 11)) // 11/11 às 18h de Brasília = 21:00Z
        vm.escolherModo(id, ModoDaVaga.SELECAO)
        montar(vm)

        rule.onNodeWithText(prazo("10/11/2026 às 18:00")).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithText(TextosPublicarVaga.MODO_SELECAO_PRAZO_CURTO).assertCountEquals(0)
    }
}
