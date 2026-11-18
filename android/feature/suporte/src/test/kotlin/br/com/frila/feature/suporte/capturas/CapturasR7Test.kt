package br.com.frila.feature.suporte.capturas

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.MotivoDenuncia
import br.com.frila.core.rede.ItemBloqueioDto
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.feature.suporte.ConteudoBloqueios
import br.com.frila.feature.suporte.ConteudoDenuncia
import br.com.frila.feature.suporte.EstadoBloqueios
import br.com.frila.feature.suporte.EstadoDenuncia
import br.com.frila.feature.suporte.EstadoTelaBloqueios
import br.com.frila.feature.suporte.TextosBloqueios
import br.com.frila.feature.suporte.TextosSuporte
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R7 (denúncia e bloqueios) num Pixel de 411 × 914 dp, no claro. Sem `FRILA_CAPTURAS_DIR` (na CI),
 * cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR7Test {

    @get:Rule
    val compose = createComposeRule()

    private val relato = "O profissional foi grosseiro com a equipe durante o turno e saiu antes do fim."
    private val ana = ItemBloqueioDto("profissional", "a1", "Ana Souza", "2026-11-10T12:00:00Z")
    private val bar = ItemBloqueioDto("estabelecimento", "b1", "Bar do Zé", "2026-11-09T12:00:00Z")
    private val protocolo = ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17")

    @Composable
    private fun denuncia(estado: EstadoDenuncia, turno: Boolean = true) {
        FrilaTheme(temaEscuro = false) {
            ConteudoDenuncia(
                estado = estado,
                associadaAoTurno = turno,
                associadaAChamada = false,
                aoEscolherMotivo = {},
                aoEditarRelato = {},
                aoEnviar = {},
                aoAbrirBloqueio = {},
                aoCancelarBloqueio = {},
                aoConfirmarBloqueio = {},
                aoFechar = {},
                aoLigar = {},
            )
        }
    }

    @Composable
    private fun bloqueios(tela: EstadoTelaBloqueios) {
        FrilaTheme(temaEscuro = false) {
            ConteudoBloqueios(tela = tela, aoTentarNovamente = {}, aoDesbloquear = {}, aoVoltar = {})
        }
    }

    @Test
    fun `denuncia - formulario vazio`() {
        compose.setContent { denuncia(EstadoDenuncia()) }
        compose.capturar("r7-01-denuncia-formulario-vazio")
    }

    @Test
    fun `denuncia - formulario preenchido`() {
        compose.setContent { denuncia(EstadoDenuncia(motivo = MotivoDenuncia.DISCRIMINACAO, relato = relato)) }
        compose.capturar("r7-02-denuncia-formulario-preenchido")
    }

    @Test
    fun `denuncia - enviando`() {
        compose.setContent { denuncia(EstadoDenuncia(relato = relato, enviando = true)) }
        compose.capturar("r7-03-denuncia-enviando")
    }

    @Test
    fun `denuncia - erro no envio`() {
        compose.setContent { denuncia(EstadoDenuncia(relato = relato, erroDenuncia = TextosSuporte.ERRO_SEM_REDE)) }
        compose.capturar("r7-04-denuncia-erro")
    }

    @Test
    fun `denuncia - enviada`() {
        compose.setContent { denuncia(EstadoDenuncia(relato = relato, protocolo = protocolo)) }
        compose.capturar("r7-05-denuncia-enviada")
    }

    @Test
    fun `denuncia - confirmacao do bloqueio`() {
        compose.setContent { denuncia(EstadoDenuncia(relato = relato, dialogoBloqueioAberto = true)) }
        compose.capturar("r7-06-denuncia-confirmar-bloqueio")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `denuncia - fonte do sistema em 200 por cento`() {
        compose.setContent { denuncia(EstadoDenuncia(relato = relato)) }
        compose.capturar("r7-07-denuncia-fonte-200")
    }

    @Test
    fun `bloqueios - com dados`() {
        compose.setContent { bloqueios(EstadoTelaBloqueios(estado = EstadoBloqueios.Conteudo(listOf(ana, bar)))) }
        compose.capturar("r7-08-bloqueios-dados")
    }

    @Test
    fun `bloqueios - desbloqueando`() {
        compose.setContent {
            bloqueios(
                EstadoTelaBloqueios(
                    estado = EstadoBloqueios.Conteudo(listOf(ana, bar)),
                    desbloqueando = "profissional:a1",
                    mensagemErro = TextosBloqueios.ERRO_DESBLOQUEAR,
                ),
            )
        }
        compose.capturar("r7-09-bloqueios-desbloqueando-e-erro")
    }

    @Test
    fun `bloqueios - carregando`() {
        compose.setContent { bloqueios(EstadoTelaBloqueios(estado = EstadoBloqueios.Carregando)) }
        compose.capturar("r7-10-bloqueios-carregando")
    }

    @Test
    fun `bloqueios - vazio`() {
        compose.setContent { bloqueios(EstadoTelaBloqueios(estado = EstadoBloqueios.Vazio)) }
        compose.capturar("r7-11-bloqueios-vazio")
    }

    @Test
    fun `bloqueios - erro`() {
        compose.setContent { bloqueios(EstadoTelaBloqueios(estado = EstadoBloqueios.Erro(TextosBloqueios.ERRO_CARREGAR))) }
        compose.capturar("r7-12-bloqueios-erro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `bloqueios - fonte do sistema em 200 por cento`() {
        compose.setContent { bloqueios(EstadoTelaBloqueios(estado = EstadoBloqueios.Conteudo(listOf(ana, bar)))) }
        compose.capturar("r7-13-bloqueios-fonte-200")
    }
}
