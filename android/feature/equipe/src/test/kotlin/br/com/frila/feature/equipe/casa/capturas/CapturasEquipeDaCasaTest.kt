package br.com.frila.feature.equipe.casa.capturas

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.AdministracaoTransferidaDto
import br.com.frila.core.rede.ConviteMembroDto
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MembroAdicionadoDto
import br.com.frila.core.rede.MembroDoEstabelecimentoDto
import br.com.frila.core.rede.MembroRemovidoDto
import br.com.frila.feature.equipe.casa.EquipeDaCasaViewModel
import br.com.frila.feature.equipe.casa.TelaEquipeDaCasa
import br.com.frila.feature.equipe.casa.TelaTenhoUmConvite
import br.com.frila.feature.equipe.casa.TelaTrocarDeCasa
import br.com.frila.feature.equipe.casa.TenhoUmConviteViewModel
import br.com.frila.feature.equipe.casa.TextosEquipeDaCasa
import br.com.frila.feature.equipe.casa.TrocarDeCasaViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints da equipe da casa, do convite e de trocar de casa (pedido 18-02) num Pixel de 411 × 914 dp, no claro, no tamanho
 * padrão e com a fonte do sistema em 200%. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasEquipeDaCasaTest {

    @get:Rule
    val compose = createComposeRule()

    private val casa = "11111111-1111-4111-8111-111111111111"
    private val token = "cd".repeat(32)

    private fun equipe(papel: PapelMembro, falhaDaAcao: Boolean = false) = EquipeDaCasaViewModel(
        estabelecimentoId = casa,
        papel = papel,
        listar = {
            listOf(
                MembroDoEstabelecimentoDto("m-ana", "Ana Souza", "administrador", "2026-10-01T12:00:00Z", true),
                MembroDoEstabelecimentoDto("m-carla", "Carla Dias", "administrador", "2026-10-15T09:30:00Z", false),
                MembroDoEstabelecimentoDto("m-beto", "Beto Lima", "operador", "2026-11-02T09:30:00Z", false),
            )
        },
        convidar = { id, email, p -> ConviteMembroDto("c1", token, "2026-11-25T15:00:00Z", id, email, p) },
        remover = { id, membro ->
            if (falhaDaAcao) throw br.com.frila.core.rede.ErroDaApi(br.com.frila.core.dominio.modelo.CodigoErroAPI.ULTIMO_ADMINISTRADOR, "ultimo_administrador", null, "x")
            MembroRemovidoDto("membro_removido", true, id, membro)
        },
        transferir = { id, novo -> AdministracaoTransferidaDto("administracao_transferida", id, novo, null, "administrador") },
        montarLink = { "https://frilabr.com/app/convite#$it" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun montarEquipe(vm: EquipeDaCasaViewModel) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaEquipeDaCasa(vm, nomeDaCasa = "Bar da Lia", aoVoltar = {}, aoCompartilhar = {})
            }
        }
    }

    @Test
    fun `equipe do administrador - claro`() {
        montarEquipe(equipe(PapelMembro.ADMINISTRADOR))
        compose.capturar("equipe-01-administrador-claro")
    }

    @Test
    fun `equipe com a lista, depois de gerar o convite - claro`() {
        montarEquipe(equipe(PapelMembro.ADMINISTRADOR))
        compose.onNodeWithText(TextosEquipeDaCasa.EMAIL).performTextInput("novo@bar.com")
        compose.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().performClick()
        compose.onNodeWithText(TextosEquipeDaCasa.COMPARTILHAR).performScrollTo()
        compose.capturar("equipe-02-convite-pronto-claro")
        compose.onNodeWithText("Ana Souza").performScrollTo()
        compose.capturar("equipe-03-lista-claro")
    }

    @Test
    fun `equipe com a confirmacao de remover aberta - claro`() {
        montarEquipe(equipe(PapelMembro.ADMINISTRADOR))
        compose.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Beto Lima")).performScrollTo().performClick()
        compose.capturarJanela("equipe-04-confirmar-remocao-claro", janela = 1)
    }

    @Test
    fun `equipe com erro de ultimo administrador - claro`() {
        montarEquipe(equipe(PapelMembro.ADMINISTRADOR, falhaDaAcao = true))
        compose.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Carla Dias")).performScrollTo().performClick()
        compose.onNodeWithText(TextosEquipeDaCasa.CONFIRMAR).performClick()
        compose.onNodeWithText(TextosEquipeDaCasa.LISTA).performScrollTo()
        compose.capturar("equipe-05-erro-ultimo-administrador-claro")
    }

    @Test
    fun `equipe do membro comum - claro`() {
        montarEquipe(equipe(PapelMembro.OPERADOR))
        compose.capturar("equipe-06-membro-comum-claro")
    }

    private fun montarConvite(erro: Boolean = false, aceito: Boolean = false): TenhoUmConviteViewModel {
        val vm = TenhoUmConviteViewModel(
            aceitar = {
                if (erro) throw br.com.frila.core.rede.ErroDaApi(br.com.frila.core.dominio.modelo.CodigoErroAPI.CONVITE_INVALIDO, "convite_invalido", null, "x")
                MembroAdicionadoDto("membro_adicionado", "m1", "casa-7", "u1", "operador")
            },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaTenhoUmConvite(vm, aoVoltar = {}, aoAbrirCasa = {}) } }
        return vm
    }

    @Test
    fun `tenho um convite vazio - claro`() {
        montarConvite()
        compose.capturar("convite-01-vazio-claro")
    }

    @Test
    fun `tenho um convite com o link colado e a recusa do servidor - claro`() {
        montarConvite(erro = true)
        compose.onNodeWithText(TextosEquipeDaCasa.CONVITE_CAMPO).performTextInput("https://frilabr.com/app/convite#$token")
        compose.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).performClick()
        compose.capturar("convite-02-recusado-claro")
    }

    @Test
    fun `tenho um convite aceito - claro`() {
        montarConvite()
        compose.onNodeWithText(TextosEquipeDaCasa.CONVITE_CAMPO).performTextInput(token)
        compose.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).performClick()
        compose.capturar("convite-03-aceito-claro")
    }

    @Test
    fun `trocar de casa - claro`() {
        val vm = TrocarDeCasaViewModel(
            listar = { listOf(EstabelecimentoDaContaDto("c1", "Bar da Lia", "administrador"), EstabelecimentoDaContaDto("c2", "Buffet Sol", "operador")) },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaTrocarDeCasa(vm, casaEmUsoId = "c1", aoEscolher = {}, aoVoltar = {}) } }
        compose.capturar("trocar-01-casas-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `equipe do administrador com fonte em 200 por cento`() {
        montarEquipe(equipe(PapelMembro.ADMINISTRADOR))
        compose.capturar("equipe-07-fonte-200-topo")
        compose.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Beto Lima")).performScrollTo()
        compose.capturar("equipe-08-fonte-200-lista")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `confirmacao de remover com fonte em 200 por cento`() {
        montarEquipe(equipe(PapelMembro.ADMINISTRADOR))
        compose.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Beto Lima")).performScrollTo().performClick()
        compose.capturarJanela("equipe-09-confirmar-fonte-200", janela = 1)
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `tenho um convite com fonte em 200 por cento`() {
        montarConvite(erro = true)
        compose.onNodeWithText(TextosEquipeDaCasa.CONVITE_CAMPO).performTextInput("https://frilabr.com/app/convite#$token")
        compose.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).performClick()
        compose.capturar("convite-04-recusado-fonte-200")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `trocar de casa com fonte em 200 por cento`() {
        val vm = TrocarDeCasaViewModel(
            listar = { listOf(EstabelecimentoDaContaDto("c1", "Bar da Lia", "administrador"), EstabelecimentoDaContaDto("c2", "Buffet Sol", "operador")) },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaTrocarDeCasa(vm, casaEmUsoId = "c1", aoEscolher = {}, aoVoltar = {}) } }
        compose.capturar("trocar-02-casas-fonte-200")
    }
}
