package br.com.frila.feature.conta.capturas.r1

import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.feature.conta.AcoesContestacaoDaSuspensao
import br.com.frila.feature.conta.ConteudoContestarDespacho
import br.com.frila.feature.conta.ConteudoExclusaoDeConta
import br.com.frila.feature.conta.EstadoContaSuspensa
import br.com.frila.feature.conta.EstadoContestarDespacho
import br.com.frila.feature.conta.EstadoExclusaoDeConta
import br.com.frila.feature.conta.ProtocoloExibido
import br.com.frila.feature.conta.SecaoContestacaoDaSuspensao
import br.com.frila.feature.conta.TelaContaSuspensa
import br.com.frila.feature.conta.TextosContaSuspensa
import br.com.frila.feature.conta.TextosContestarDespacho
import br.com.frila.feature.conta.TextosExclusaoDeConta
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Prints do lote R1 (conta suspensa, contestação e exclusão de conta), no claro. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR1ContaTest {

    @get:Rule
    val compose = createComposeRule()

    private val email = "suporte@frilabr.com"
    private val protocolo = ProtocoloExibido("6F1C2A4E", "17/11/2026", "24/11/2026", prazo = null)

    private fun suspensa(estado: EstadoContaSuspensa) = compose.setContent {
        FrilaTheme(temaEscuro = false) {
            TelaContaSuspensa(emailSuporte = email, aoContatarSuporte = {}, aoSair = {}, motivo = estado.motivo, desde = estado.desde) {
                SecaoContestacaoDaSuspensao(estado, email, AcoesContestacaoDaSuspensao())
            }
        }
    }

    @Test
    fun `01 conta suspensa - motivo e contestar`() {
        suspensa(EstadoContaSuspensa(motivo = "Faltas sem aviso em dois turnos seguidos.", desde = "10/11/2026"))
        compose.capturar("r1-12-conta-suspensa")
    }

    @Test
    fun `02 conta suspensa - formulario com erro`() {
        suspensa(
            EstadoContaSuspensa(
                motivo = "Faltas sem aviso em dois turnos seguidos.",
                desde = "10/11/2026",
                formularioAberto = true,
                relato = "Não reconheço",
                mensagemErro = TextosContaSuspensa.RELATO_MINIMO,
            ),
        )
        compose.capturar("r1-13-conta-suspensa-formulario")
    }

    @Test
    fun `03 conta suspensa - protocolo em analise`() {
        suspensa(EstadoContaSuspensa(motivo = "Faltas sem aviso.", desde = "10/11/2026", protocolo = protocolo, emAnalise = true))
        compose.capturar("r1-14-conta-suspensa-protocolo")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `04 conta suspensa - fonte em 200 por cento`() {
        suspensa(EstadoContaSuspensa(motivo = "Faltas sem aviso.", desde = "10/11/2026", formularioAberto = true))
        compose.capturar("r1-15-conta-suspensa-fonte-200")
    }

    private fun despacho(estado: EstadoContestarDespacho) = compose.setContent {
        FrilaTheme(temaEscuro = false) {
            ConteudoContestarDespacho(estado, aoMudarRelato = {}, aoEnviar = {}, aoVoltar = {})
        }
    }

    @Test
    fun `05 contestar despacho - formulario com erro`() {
        despacho(EstadoContestarDespacho(mensagemErro = TextosContestarDespacho.RELATO_OBRIGATORIO))
        compose.capturar("r1-16-despacho-formulario")
    }

    @Test
    fun `06 contestar despacho - enviado`() {
        despacho(EstadoContestarDespacho(protocolo = protocolo))
        compose.capturar("r1-17-despacho-enviado")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `07 contestar despacho - fonte em 200 por cento`() {
        despacho(EstadoContestarDespacho(relato = "Eu estava no horário."))
        compose.capturar("r1-18-despacho-fonte-200")
    }

    private fun exclusao(estado: EstadoExclusaoDeConta) = compose.setContent {
        FrilaTheme(temaEscuro = false) {
            ConteudoExclusaoDeConta(estado, aoAlterarConfirmacao = {}, aoExcluir = {}, aoVoltar = {})
        }
    }

    @Test
    fun `08 exclusao - leitura`() {
        exclusao(EstadoExclusaoDeConta())
        compose.capturar("r1-19-exclusao-leitura")
    }

    @Test
    fun `09 exclusao - confirmada com erro`() {
        exclusao(EstadoExclusaoDeConta(confirmouConsequencias = true, mensagemErro = TextosExclusaoDeConta.ERRO_ADMIN_UNICO))
        compose.capturar("r1-20-exclusao-erro")
    }

    @Test
    fun `10 exclusao - concluida`() {
        exclusao(EstadoExclusaoDeConta(resultado = ExclusaoDeContaDto("2026-11-10T12:00:00Z", "2026-11-25", 2)))
        compose.capturar("r1-21-exclusao-concluida")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `11 exclusao - fonte em 200 por cento`() {
        exclusao(EstadoExclusaoDeConta(confirmouConsequencias = true))
        compose.capturar("r1-22-exclusao-fonte-200")
    }
}
