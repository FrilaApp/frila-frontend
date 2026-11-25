package br.com.frila.feature.chamadas.profissional

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate

/**
 * A fiação da [TelaPreferenciasDeChamada] ao [PreferenciasChamadaViewModel]: o `TelasDoProfissionalTest` prova o
 * [ConteudoPreferenciasDeChamada] com callbacks soltos; este prova que o botão Salvar da tela montada chega ao servidor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaPreferenciasDeChamadaTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun salvarNaTelaMontadaEnviaAAntecedenciaEscolhidaAoServidor() {
        val rede = RedeDeTeste().apply {
            ok("/rpc/meu_perfil_detalhado", Fixtures.perfilDetalhadoJson(preferencia = Fixtures.preferenciaJson(antecedencia = 6)))
            ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(antecedencia = 24))
        }
        val viewModel = PreferenciasChamadaViewModel(
            carregarPerfil = rede.servico::meuPerfilDetalhado,
            definirPreferencias = rede.servico::definirPreferenciaChamadas,
            hoje = { LocalDate.of(2026, 11, 16) },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme {
                TelaPreferenciasDeChamada(viewModel = viewModel, aoVoltar = {}, buscaProfissionaisHabilitada = true)
            }
        }
        rule.waitUntil(TIMEOUT_MS) { viewModel.estado.value.carregou }

        rule.onNodeWithText(TextosChamadaProfissional.ANTECEDENCIA_24H).performScrollTo().performClick()
        rule.onNodeWithTag("salvar-preferencias-chamada").performClick()
        rule.waitUntil(TIMEOUT_MS) { viewModel.estado.value.sucesso }

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals(24, corpo["antecedencia_minima_h"]!!.jsonPrimitive.int)
    }

    private companion object {
        const val TIMEOUT_MS = 5_000L
    }
}
