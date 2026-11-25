package br.com.frila.feature.chamadas.profissional

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.EspecialidadeDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A fiação da [TelaEditarServicos] ao [EditarServicosViewModel]: o `TelasDoProfissionalTest` prova o
 * [ConteudoEditarServicos] com callbacks soltos; este prova que o botão Salvar da tela montada chega ao servidor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaEditarServicosTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun salvarNaTelaMontadaEnviaOServicoCarregadoAoServidor() {
        val rede = RedeDeTeste().apply {
            val perfil = Fixtures.perfilDetalhadoJson(servicos = listOf(Fixtures.servicoDiariaJson))
            ok("/rpc/meu_perfil_detalhado", perfil)
            ok("/rpc/definir_servicos", perfil)
        }
        val viewModel = EditarServicosViewModel(
            carregarPerfil = rede.servico::meuPerfilDetalhado,
            listarEspecialidades = { funcaoId ->
                listOf(EspecialidadeDto(id = Fixtures.ESPECIALIDADE, funcaoId = funcaoId, nome = "Eventos", ativo = true))
            },
            definir = rede.servico::definirServicos,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme {
                TelaEditarServicos(viewModel = viewModel, aoVoltar = {})
            }
        }
        rule.waitUntil(TIMEOUT_MS) { viewModel.estado.value.carregou }

        rule.onNodeWithTag("salvar-servicos").performClick()
        rule.waitUntil(TIMEOUT_MS) { viewModel.estado.value.sucesso }

        val enviados = rede.doCaminho("/rpc/definir_servicos").single().corpo!!["servicos"]!!.jsonArray
        assertEquals(1, enviados.size)
        val servico = enviados[0].jsonObject
        assertEquals(Fixtures.FUNCAO, servico["funcao_id"]!!.jsonPrimitive.content)
        assertEquals("diaria", servico["unidade"]!!.jsonPrimitive.content)
        assertEquals(15000L, servico["valor_centavos"]!!.jsonPrimitive.content.toLong())
    }

    private companion object {
        const val TIMEOUT_MS = 5_000L
    }
}
