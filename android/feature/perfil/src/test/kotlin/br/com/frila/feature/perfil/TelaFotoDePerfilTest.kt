package br.com.frila.feature.perfil

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.MidiaDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** L1-3b: a tela PROVISÓRIA da foto de perfil (escolher, aviso de "sem rosto", andamento e resultado). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaFotoDePerfilTest {

    @get:Rule
    val rule = createComposeRule()

    private val toques = mutableListOf<String>()

    private fun mostrar(etapa: EtapaDaFoto, situacao: SituacaoDaFoto = SituacaoDaFoto()) {
        toques.clear()
        rule.setContent {
            FrilaTheme {
                TelaFotoDePerfil(
                    etapa = etapa,
                    aoEscolherFoto = { toques += "escolher" },
                    aoEnviarMesmoAssim = { toques += "mesmo-assim" },
                    aoEscolherOutra = { toques += "outra" },
                    aoTentarDeNovo = { toques += "de-novo" },
                    situacao = situacao,
                    aoPedirNovaAnalise = { toques += "nova-analise" },
                )
            }
        }
    }

    @Test
    fun paradaMostraTituloExplicacaoEOBotaoDeEscolher() {
        mostrar(EtapaDaFoto.Parada)
        rule.onNodeWithText("Foto de perfil").assertIsDisplayed()
        rule.onNodeWithText(TextosDaFotoDePerfil.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithText("Escolher foto").assertIsDisplayed().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        assertEquals(listOf("escolher"), toques)
    }

    @Test
    fun avisoSemRostoTemOTextoDoIosEOsDoisBotoes() {
        mostrar(EtapaDaFoto.AvisoSemRosto)
        rule.onNodeWithText("Não achei seu rosto. Tente com mais luz e de frente").assertIsDisplayed()
        rule.onNodeWithText("Enviar mesmo assim").assertIsDisplayed().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.onNodeWithText("Escolher outra foto").assertIsDisplayed().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        assertEquals(listOf("mesmo-assim", "outra"), toques)
    }

    @Test
    fun bloqueioDeVariosRostosNaoOfereceEnviarMesmoAssim() {
        mostrar(EtapaDaFoto.Bloqueada(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS))
        rule.onNodeWithText("Escolha uma foto em que apareça apenas você.").assertIsDisplayed()
        rule.onNodeWithText("Tentar outra foto").assertIsDisplayed().performClick()
        rule.onNodeWithText("Enviar mesmo assim").assertDoesNotExist()
        assertEquals(listOf("outra"), toques)
    }

    @Test
    fun preparandoEEnviandoMostramSoOAndamento() {
        mostrar(EtapaDaFoto.Preparando)
        rule.onNodeWithText("Preparando a foto…").assertIsDisplayed()
        rule.onNodeWithText("Escolher foto").assertDoesNotExist()
    }

    @Test
    fun enviandoMostraOAndamentoSemBotoes() {
        mostrar(EtapaDaFoto.Enviando)
        rule.onNodeWithText("Conferindo e enviando a foto…").assertIsDisplayed()
        rule.onNodeWithText("Escolher foto").assertDoesNotExist()
        rule.onNodeWithText("Enviar mesmo assim").assertDoesNotExist()
    }

    @Test
    fun enviadaDizQueEstaEmAnalise() {
        mostrar(EtapaDaFoto.Enviada(MidiaDto(id = "m", tipo = "foto_perfil", estado = "em_analise", podePedirNovaAnalise = false)))
        rule.onNodeWithText("Foto em análise").assertIsDisplayed()
        rule.onNodeWithText(TextosDaFotoDePerfil.TEXTO_EM_ANALISE).assertIsDisplayed()
    }

    @Test
    fun falhaMostraAMensagemETentarDeNovo() {
        mostrar(EtapaDaFoto.Falhou(TextosDaFotoDePerfil.ERRO_SEM_REDE))
        rule.onNodeWithText(TextosDaFotoDePerfil.ERRO_SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText("Tentar de novo").assertIsDisplayed().performClick()
        rule.onNodeWithText("Escolher outra foto").assertIsDisplayed().performClick()
        assertEquals(listOf("de-novo", "outra"), toques)
    }

    // ---- Foto recusada ou não publicada (cartão 1dRm7FAH, fatia 1) ----

    private fun midia(estado: String, motivo: String? = null, podePedir: Boolean = true) =
        MidiaDto(id = "m1", tipo = "foto_perfil", estado = estado, motivoRecusa = motivo, podePedirNovaAnalise = podePedir)

    @Test
    fun recusadaMostraOEstadoOMotivoEOsDoisBotoes() {
        mostrar(EtapaDaFoto.Parada, SituacaoDaFoto(midia = midia("recusada", motivo = "texto_ou_dado_pessoal")))

        rule.onNodeWithText("Foto não publicada").assertIsDisplayed()
        rule.onNodeWithText("Use uma foto sem texto, telefone, Pix, QR code ou documento.").assertIsDisplayed()
        rule.onNodeWithText("Tentar outra foto").assertIsDisplayed().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.onNodeWithText("Pedir nova análise").assertIsDisplayed().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        assertEquals(listOf("escolher", "nova-analise"), toques)
    }

    @Test
    fun naoPublicadaTemOTextoProprioEOsDoisBotoes() {
        mostrar(EtapaDaFoto.Parada, SituacaoDaFoto(midia = midia("nao_publicada")))

        rule.onNodeWithText("Foto não publicada").assertIsDisplayed()
        rule.onNodeWithText("Não conseguimos analisar sua foto agora. Peça uma nova análise ou tente outra foto.").assertIsDisplayed()
        rule.onNodeWithText("Pedir nova análise").assertIsDisplayed()
    }

    @Test
    fun semPermissaoDoServidorNaoOferecePedirNovaAnalise() {
        mostrar(EtapaDaFoto.Parada, SituacaoDaFoto(midia = midia("recusada", podePedir = false)))

        rule.onNodeWithText("Tentar outra foto").assertIsDisplayed()
        rule.onNodeWithText("Pedir nova análise").assertDoesNotExist()
    }

    @Test
    fun novaAnaliseJaPedidaTrocaOTextoENaoOfereceDeNovo() {
        mostrar(EtapaDaFoto.Parada, SituacaoDaFoto(midia = midia("recusada", motivo = "foto_inadequada"), novaAnaliseJaPedida = true))

        rule.onNodeWithText("A nova análise já foi pedida. Se a foto continuar sem aparecer, tente outra foto.").assertIsDisplayed()
        rule.onNodeWithText("Pedir nova análise").assertDoesNotExist()
        rule.onNodeWithText("Tentar outra foto").assertIsDisplayed()
    }

    @Test
    fun depoisDoPedidoAFotoEstaEmAnalise() {
        mostrar(EtapaDaFoto.Parada, SituacaoDaFoto(midia = midia("em_analise", podePedir = false), novaAnaliseJaPedida = true))

        rule.onNodeWithText("Foto em análise").assertIsDisplayed()
        rule.onNodeWithText(TextosDaFotoDePerfil.TEXTO_EM_ANALISE).assertIsDisplayed()
        rule.onNodeWithText("Pedir nova análise").assertDoesNotExist()
    }

    @Test
    fun falhaDoPedidoAparecePerto() {
        mostrar(EtapaDaFoto.Parada, SituacaoDaFoto(midia = midia("recusada"), aviso = TextosDaFotoDePerfil.ERRO_SEM_REDE))

        rule.onNodeWithText(TextosDaFotoDePerfil.ERRO_SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText("Pedir nova análise").assertIsDisplayed()
    }

    @Test
    fun semFotoRecusadaATelaSegueComoSempre() {
        mostrar(EtapaDaFoto.Parada, SituacaoDaFoto(midia = midia("aprovada")))

        rule.onNodeWithText(TextosDaFotoDePerfil.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithText("Escolher foto").assertIsDisplayed()
        rule.onNodeWithText("Pedir nova análise").assertDoesNotExist()
    }
}
