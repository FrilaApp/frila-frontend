package br.com.frila.feature.equipe.casa

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.AdministracaoTransferidaDto
import br.com.frila.core.rede.ConviteMembroDto
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MembroAdicionadoDto
import br.com.frila.core.rede.MembroDoEstabelecimentoDto
import br.com.frila.core.rede.MembroRemovidoDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Caminho feliz das telas da equipe da casa, do convite e de trocar de casa, com fakes no lugar da rede. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelasDaEquipeDaCasaTest {

    @get:Rule
    val rule = createComposeRule()

    private val casa = "11111111-1111-4111-8111-111111111111"
    private val token = "cd".repeat(32)

    private val membros = mutableListOf(
        MembroDoEstabelecimentoDto("m-ana", "Ana Souza", "administrador", "2026-10-01T12:00:00Z", true),
        MembroDoEstabelecimentoDto("m-beto", "Beto Lima", "operador", "2026-11-02T09:30:00Z", false),
    )
    private val remocoes = mutableListOf<String>()
    private val transferencias = mutableListOf<String>()
    private val convites = mutableListOf<Triple<String, String, String>>()
    private val compartilhados = mutableListOf<String>()
    private var voltou = 0

    private fun viewModel(papel: PapelMembro?) = EquipeDaCasaViewModel(
        estabelecimentoId = casa,
        papel = papel,
        listar = { membros.toList() },
        convidar = { id, email, papelConvidado ->
            convites += Triple(id, email, papelConvidado)
            ConviteMembroDto("c1", token, "2026-11-25T15:00:00Z", id, email, papelConvidado)
        },
        remover = { id, membro ->
            remocoes += membro
            membros.removeAll { it.membroId == membro }
            MembroRemovidoDto("membro_removido", true, id, membro)
        },
        transferir = { id, novo ->
            transferencias += novo
            AdministracaoTransferidaDto("administracao_transferida", id, novo, null, "administrador")
        },
        montarLink = { "https://frilabr.com/app/convite#$it" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun montarEquipe(papel: PapelMembro?) {
        val vm = viewModel(papel)
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaEquipeDaCasa(viewModel = vm, nomeDaCasa = "Bar da Lia", aoVoltar = { voltou++ }, aoCompartilhar = { compartilhados += it })
            }
        }
    }

    // ---- Equipe da casa ----

    @Test
    fun `administrador ve a lista, convida, compartilha o link e remove com confirmacao`() {
        montarEquipe(PapelMembro.ADMINISTRADOR)

        rule.onNodeWithText("Ana Souza").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Administrador · ${TextosEquipeDaCasa.VOCE}").performScrollTo().assertIsDisplayed()
        // Quem é "você" não tem ações; o operador tem as duas.
        rule.onAllNodesWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Ana Souza")).assertCountEquals(0)
        rule.onNodeWithContentDescription(TextosEquipeDaCasa.TRANSFERIR_DE.format("Beto Lima")).performScrollTo().assertIsEnabled()

        rule.onNodeWithText(TextosEquipeDaCasa.EMAIL).performTextInput("novo@bar.com")
        rule.onNodeWithText(TextosEquipeDaCasa.PAPEL_ADMINISTRADOR).performScrollTo().performClick()
        rule.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().performClick()

        assertEquals(listOf(Triple(casa, "novo@bar.com", "administrador")), convites)
        val link = "https://frilabr.com/app/convite#$token"
        rule.onNodeWithText(link).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.COMPARTILHAR).performScrollTo().performClick()
        assertEquals(
            listOf(
                "Bar da Lia convidou você para a equipe da casa no Frila, como administrador. " +
                    "Para aceitar, abra o link abaixo e entre no Frila com o e-mail novo@bar.com. " +
                    "O convite vale uma vez, até 25/11 às 12:00. " +
                    "O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. " +
                    "Política de Privacidade: https://frilabr.com/privacidade\n" +
                    link,
            ),
            compartilhados,
        )

        rule.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Beto Lima")).performScrollTo().performClick()
        rule.onNodeWithText(TextosEquipeDaCasa.CONFIRMAR_REMOCAO).assertIsDisplayed()
        assertTrue(remocoes.isEmpty())
        rule.onNodeWithText(TextosEquipeDaCasa.CONFIRMAR).performClick()

        assertEquals(listOf("m-beto"), remocoes)
        rule.onNodeWithText(TextosEquipeDaCasa.REMOVIDA).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithText("Beto Lima").assertCountEquals(0)
    }

    @Test
    fun `compartilhar convite sem prazo e como operador manda a mensagem curta com email aparado`() {
        val compartilhadosSemPrazo = mutableListOf<String>()
        val vm = EquipeDaCasaViewModel(
            estabelecimentoId = casa,
            papel = PapelMembro.ADMINISTRADOR,
            listar = { membros.toList() },
            convidar = { id, email, papelConvidado ->
                ConviteMembroDto("c1", token, "", id, email, papelConvidado)
            },
            remover = { _, _ -> error("não deveria") },
            transferir = { _, _ -> error("não deveria") },
            montarLink = { "https://frilabr.com/app/convite#$it" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaEquipeDaCasa(viewModel = vm, nomeDaCasa = "Bar da Lia", aoVoltar = {}, aoCompartilhar = { compartilhadosSemPrazo += it })
            }
        }

        rule.onNodeWithText(TextosEquipeDaCasa.EMAIL).performTextInput("  op@bar.com  ")
        rule.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().performClick()
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_PRONTO_SEM_PRAZO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.COMPARTILHAR).performScrollTo().performClick()

        val link = "https://frilabr.com/app/convite#$token"
        assertEquals(
            listOf(
                "Bar da Lia convidou você para a equipe da casa no Frila, como operador. " +
                    "Para aceitar, abra o link abaixo e entre no Frila com o e-mail op@bar.com. " +
                    "O convite vale uma vez. " +
                    "O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. " +
                    "Política de Privacidade: https://frilabr.com/privacidade\n" +
                    link,
            ),
            compartilhadosSemPrazo,
        )
    }

    @Test
    fun `tornar administrador pede confirmacao e cancelar nao faz nada`() {
        montarEquipe(PapelMembro.ADMINISTRADOR)

        rule.onNodeWithContentDescription(TextosEquipeDaCasa.TRANSFERIR_DE.format("Beto Lima")).performScrollTo().performClick()
        rule.onNodeWithText(TextosEquipeDaCasa.CONFIRMAR_TRANSFERENCIA).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.CANCELAR).performClick()
        assertTrue(transferencias.isEmpty())

        rule.onNodeWithContentDescription(TextosEquipeDaCasa.TRANSFERIR_DE.format("Beto Lima")).performScrollTo().performClick()
        rule.onNodeWithText(TextosEquipeDaCasa.CONFIRMAR).performClick()
        assertEquals(listOf("m-beto"), transferencias)
        rule.onNodeWithText(TextosEquipeDaCasa.TRANSFERIDA).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `membro comum so ve o aviso, sem lista, convite nem botao de administrador`() {
        montarEquipe(PapelMembro.OPERADOR)

        rule.onNodeWithText(TextosEquipeDaCasa.SO_ADMINISTRADOR).assertIsDisplayed()
        rule.onAllNodesWithText(TextosEquipeDaCasa.GERAR_CONVITE).assertCountEquals(0)
        rule.onAllNodesWithText(TextosEquipeDaCasa.REMOVER).assertCountEquals(0)
        rule.onAllNodesWithText(TextosEquipeDaCasa.TRANSFERIR).assertCountEquals(0)
        rule.onAllNodesWithText("Beto Lima").assertCountEquals(0)
    }

    @Test
    fun `depois de um 403 ao convidar o botao de convidar e as acoes de administrador somem da tela`() {
        val vm = EquipeDaCasaViewModel(
            estabelecimentoId = casa,
            papel = PapelMembro.ADMINISTRADOR,
            listar = { membros.toList() },
            convidar = { _, _, _ -> throw br.com.frila.core.rede.ErroDaApi(br.com.frila.core.dominio.modelo.CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", null, "x") },
            remover = { _, _ -> error("não deveria") },
            transferir = { _, _ -> error("não deveria") },
            montarLink = { "https://frilabr.com/app/convite#$it" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme(temaEscuro = false) { TelaEquipeDaCasa(viewModel = vm, nomeDaCasa = "Bar da Lia", aoVoltar = {}, aoCompartilhar = {}) }
        }

        rule.onNodeWithText(TextosEquipeDaCasa.EMAIL).performTextInput("novo@bar.com")
        rule.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().performClick()

        rule.onNodeWithText(TextosEquipeDaCasa.SO_ADMINISTRADOR).assertIsDisplayed()
        rule.onAllNodesWithText(TextosEquipeDaCasa.GERAR_CONVITE).assertCountEquals(0)
        rule.onAllNodesWithText(TextosEquipeDaCasa.REMOVER).assertCountEquals(0)
        rule.onAllNodesWithText("Beto Lima").assertCountEquals(0)
    }

    @Test
    fun `e-mail invalido mostra o erro no campo e nao gera convite`() {
        montarEquipe(PapelMembro.ADMINISTRADOR)

        rule.onNodeWithText(TextosEquipeDaCasa.EMAIL).performTextInput("sem-arroba")
        rule.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().performClick()

        rule.onNodeWithText(TextosEquipeDaCasa.EMAIL_INVALIDO).assertIsDisplayed()
        assertTrue(convites.isEmpty())
    }

    @Test
    fun `os botoes tem alvo de pelo menos 48 dp`() {
        montarEquipe(PapelMembro.ADMINISTRADOR)

        rule.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Beto Lima")).performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    @Config(sdk = [35], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `com a fonte do sistema em 200 por cento a equipe segue acessivel`() {
        montarEquipe(PapelMembro.ADMINISTRADOR)

        rule.onNodeWithText(TextosEquipeDaCasa.GERAR_CONVITE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Beto Lima")).performScrollTo().assertIsDisplayed()
    }

    // ---- Tenho um convite ----

    private fun montarConvite(aceitos: MutableList<String>, abertas: MutableList<String?>, falhar: Boolean = false) {
        val vm = TenhoUmConviteViewModel(
            aceitar = {
                aceitos += it
                if (falhar) throw br.com.frila.core.rede.ErroDaApi(br.com.frila.core.dominio.modelo.CodigoErroAPI.CONVITE_INVALIDO, "convite_invalido", null, "x")
                MembroAdicionadoDto("membro_adicionado", "m1", "casa-7", "u1", "operador")
            },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaTenhoUmConvite(viewModel = vm, aoVoltar = { voltou++ }, aoAbrirCasa = { abertas += it })
            }
        }
    }

    @Test
    fun `colar o link aceita o convite e leva a abrir a casa`() {
        val aceitos = mutableListOf<String>()
        val abertas = mutableListOf<String?>()
        montarConvite(aceitos, abertas)

        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).assertIsNotEnabled()
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_CAMPO).performTextInput("https://frilabr.com/app/convite#$token")
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).assertIsEnabled().performClick()

        assertEquals(listOf(token), aceitos)
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITO.format("operador")).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ABRIR_CASA).performClick()
        assertEquals(listOf<String?>("casa-7"), abertas)
    }

    @Test
    fun `convite recusado mostra a mensagem junto ao botao e deixa tentar de novo`() {
        val aceitos = mutableListOf<String>()
        montarConvite(aceitos, mutableListOf(), falhar = true)

        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_CAMPO).performTextInput(token)
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).performClick()

        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_INVALIDO).assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).assertIsEnabled().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        assertEquals(1, aceitos.size)
    }

    @Test
    fun `convite de outro e-mail (403) mostra a mensagem certa junto ao botao`() {
        val vm = TenhoUmConviteViewModel(
            aceitar = {
                throw br.com.frila.core.rede.ErroDaApi(
                    br.com.frila.core.dominio.modelo.CodigoErroAPI.CONVITE_DE_OUTRO_EMAIL,
                    "convite_de_outro_email",
                    null,
                    "x",
                )
            },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaTenhoUmConvite(viewModel = vm, aoVoltar = {}, aoAbrirCasa = {})
            }
        }

        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_CAMPO).performTextInput(token)
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).performClick()

        rule.onNodeWithText("Este convite foi feito para outro e-mail. Entre com o e-mail que recebeu o convite.").assertIsDisplayed()
        rule.onNodeWithText(TextosEquipeDaCasa.CONVITE_ACEITAR).assertIsEnabled()
    }

    // ---- Trocar de casa ----

    @Test
    fun `trocar de casa marca a casa em uso e escolhe outra`() {
        val vm = TrocarDeCasaViewModel(
            listar = { listOf(EstabelecimentoDaContaDto("c1", "Bar da Lia", "administrador"), EstabelecimentoDaContaDto("c2", "Buffet Sol", "operador")) },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        val escolhidas = mutableListOf<String>()
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaTrocarDeCasa(viewModel = vm, casaEmUsoId = "c1", aoEscolher = { escolhidas += it.id }, aoVoltar = { voltou++ })
            }
        }

        rule.onNodeWithText("Bar da Lia").assertIsDisplayed()
        rule.onNodeWithText("Buffet Sol").assertIsDisplayed().performClick()

        assertEquals(listOf("c2"), escolhidas)
        // Tocar na casa que já está em uso só volta.
        rule.onNodeWithText("Bar da Lia").performClick()
        assertEquals(1, voltou)
    }

    // ---- Papel nulo ou desconhecido (cWQE4YiY) ----

    @Test
    fun `na equipe o papel que este app nao conhece aparece como Outro papel, e o seu proprio tambem`() {
        membros += MembroDoEstabelecimentoDto("m-carla", "Carla Dias", "supervisora", "2026-11-03T09:30:00Z", false)
        membros += MembroDoEstabelecimentoDto("m-davi", "Davi Reis", "", "2026-11-04T09:30:00Z", false)
        montarEquipe(PapelMembro.ADMINISTRADOR)

        rule.onNodeWithText("Carla Dias").performScrollTo().assertIsDisplayed()
        // Sem ação sobre quem tem papel desconhecido ou em branco (iOS `papelConhecido`); quem tem papel conhecido segue com as suas.
        rule.onAllNodesWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Carla Dias")).assertCountEquals(0)
        rule.onAllNodesWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Davi Reis")).assertCountEquals(0)
        rule.onAllNodesWithContentDescription(TextosEquipeDaCasa.TRANSFERIR_DE.format("Carla Dias")).assertCountEquals(0)
        rule.onNodeWithContentDescription(TextosEquipeDaCasa.REMOVER_DE.format("Beto Lima")).performScrollTo().assertIsDisplayed()
        // A pessoa não some nem fica sem papel: "Outro papel" (iOS `papelDesconhecido`), duas vezes (o papel desconhecido e o em branco).
        rule.onAllNodesWithText("Outro papel").assertCountEquals(2)
        rule.onNodeWithText("Administrador · ${TextosEquipeDaCasa.VOCE}").performScrollTo().assertIsDisplayed()
        // Os papéis que o app conhece seguem com o rótulo de sempre (o "Operador" também está no seletor do convite, por isso o nome do membro).
        rule.onNodeWithText("Beto Lima").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `quem e voce e tem papel desconhecido ve Outro papel e Voce`() {
        membros.clear()
        membros += MembroDoEstabelecimentoDto("m-ana", "Ana Souza", "supervisora", "2026-10-01T12:00:00Z", true)
        montarEquipe(PapelMembro.ADMINISTRADOR)

        rule.onNodeWithText("Outro papel · ${TextosEquipeDaCasa.VOCE}").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `em trocar de casa o papel desconhecido ou em branco aparece como Outro papel`() {
        val vm = TrocarDeCasaViewModel(
            listar = {
                listOf(
                    EstabelecimentoDaContaDto("c1", "Bar da Lia", "administrador"),
                    EstabelecimentoDaContaDto("c2", "Buffet Sol", "supervisora"),
                    EstabelecimentoDaContaDto("c3", "Casa Nova", ""),
                )
            },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaTrocarDeCasa(viewModel = vm, casaEmUsoId = "c1", aoEscolher = {}, aoVoltar = {})
            }
        }

        rule.onNodeWithText("Buffet Sol").assertIsDisplayed()
        rule.onNodeWithText("Casa Nova").assertIsDisplayed()
        rule.onAllNodesWithText("Outro papel").assertCountEquals(2)
        rule.onNodeWithText("Administrador").assertIsDisplayed()
    }

    @Test
    fun `o rotulo do papel e o texto ou Outro papel`() {
        assertEquals("Administrador", rotuloDoPapelOuDesconhecido(PapelMembro.ADMINISTRADOR))
        assertEquals("Operador", rotuloDoPapelOuDesconhecido(PapelMembro.OPERADOR))
        assertEquals("Outro papel", rotuloDoPapelOuDesconhecido(null))
    }
}
