package br.com.frila.feature.turnos.capturas

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.DialogoCancelamentoTurno
import br.com.frila.feature.turnos.DialogoDefensivoLocalizacao
import br.com.frila.feature.turnos.EstadoCancelamentoTurno
import br.com.frila.feature.turnos.EstadoCheckin
import br.com.frila.feature.turnos.EstadoMeusTurnos
import br.com.frila.feature.turnos.ErroDoACaminho
import br.com.frila.feature.turnos.ItemTurno
import br.com.frila.feature.turnos.LocalCriarValidacaoDoCodigo
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.AbaDeTurnos
import br.com.frila.feature.turnos.StatusCheckin
import br.com.frila.feature.turnos.StatusMeusTurnos
import br.com.frila.feature.turnos.TelaMeusTurnos
import br.com.frila.feature.turnos.ValidacaoDoCodigoViewModel
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R3 (Profissional · Turnos) num Pixel de 411 × 914 dp, no claro. Sem `FRILA_CAPTURAS_DIR` (na CI),
 * cada teste só confere que a tela desenha sem quebrar. Os dados são sintéticos.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR3Test {

    @get:Rule
    val compose = createComposeRule()

    // 18:00 às 00:00 em Brasília.
    private val inicio = Instant.parse("2026-11-14T21:00:00Z")
    private val fim = Instant.parse("2026-11-15T03:00:00Z")

    private fun turno(
        id: String = "t1",
        estado: String = "confirmada",
        funcao: String = "Bartender",
        casa: String = "Bar do Porto",
        comprovante: ComprovanteCheckin? = null,
        aCaminhoEm: Instant? = null,
        podeAvaliar: Boolean = false,
        avaliacao: Boolean? = null,
        checkoutEm: Instant? = null,
        data: String = "Sáb 14/11, 18:00 às 00:00",
    ) = ItemTurno(
        turnoId = id,
        posicaoId = "p-$id",
        inicio = inicio,
        fim = fim,
        funcaoNome = funcao,
        estabelecimentoNome = casa,
        dataHorarioFormatado = data,
        valorFormatado = "R$ 220,00",
        estado = estado,
        podeAvaliar = podeAvaliar,
        avaliacaoResposta = avaliacao,
        comprovante = comprovante,
        contraparteId = "casa-1",
        checkoutEm = checkoutEm,
        aCaminhoEm = aCaminhoEm,
    )

    private fun comprovante(tipo: TipoVerificacaoCheckin) = ComprovanteCheckin(
        turnoId = "t1",
        registradoEm = Instant.parse("2026-11-14T20:50:00Z"),
        tipoVerificacao = tipo,
        codigoAutenticacao = "A1B2C3D4",
    )

    private fun viewModelDeTurnos(estado: EstadoMeusTurnos): MeusTurnosViewModel {
        val vm = mockk<MeusTurnosViewModel>(relaxed = true)
        every { vm.estado } returns MutableStateFlow(estado)
        return vm
    }

    private fun viewModelDeCheckin(estado: EstadoCheckin = EstadoCheckin()): CheckinViewModel {
        val vm = mockk<CheckinViewModel>(relaxed = true)
        every { vm.estado } returns MutableStateFlow(estado)
        return vm
    }

    private fun validacaoQueErra(): ValidacaoDoCodigoViewModel = ValidacaoDoCodigoViewModel(
        turnoId = "t1",
        validar = { _, _, _ ->
            Result.failure(ErroDaApi(CodigoErroAPI.DESCONHECIDO, "codigo_invalido", null, "x"))
        },
        medirDistancia = { 20 },
        escopo = CoroutineScope(Dispatchers.Default),
    )

    private fun validacaoParada(): ValidacaoDoCodigoViewModel = ValidacaoDoCodigoViewModel(
        turnoId = "t1",
        validar = { _, _, _ -> Result.failure(IllegalStateException("não usado")) },
        escopo = CoroutineScope(Dispatchers.Default),
    )

    private fun tela(
        estado: EstadoMeusTurnos,
        agora: Instant,
        checkin: EstadoCheckin = EstadoCheckin(),
        aCaminho: Boolean = false,
        validacao: ValidacaoDoCodigoViewModel? = null,
    ) {
        val vm = viewModelDeTurnos(estado)
        val vmCheckin = viewModelDeCheckin(checkin)
        val criador: (@androidx.compose.runtime.Composable (ItemTurno) -> ValidacaoDoCodigoViewModel)? =
            validacao?.let { v -> { _ -> v } }
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                CompositionLocalProvider(LocalCriarValidacaoDoCodigo provides criador) {
                    TelaMeusTurnos(
                        viewModel = vm,
                        criarCheckinViewModel = { vmCheckin },
                        relogio = { agora },
                        aoDenunciarEstabelecimento = { _, _ -> },
                        aoAvisarACaminho = if (aCaminho) { _ -> } else null,
                    )
                }
            }
        }
    }

    private fun agendados(vararg itens: ItemTurno, extra: EstadoMeusTurnos.() -> EstadoMeusTurnos = { this }) =
        EstadoMeusTurnos(status = StatusMeusTurnos.SUCESSO, agendados = itens.toList()).extra()

    private val cincoHorasAntes = inicio.minusSeconds(5 * 3600)
    private val duasHorasAntes = inicio.minusSeconds(2 * 3600)
    private val quarentaECincoAntes = inicio.minusSeconds(45 * 60)
    private val noMeioDoTurno = inicio.plusSeconds(3 * 3600)

    @Test
    fun `01 carregando`() {
        tela(EstadoMeusTurnos(status = StatusMeusTurnos.CARREGANDO), agora = inicio)
        compose.capturar("r3-01-turnos-carregando")
    }

    @Test
    fun `02 vazio`() {
        tela(EstadoMeusTurnos(status = StatusMeusTurnos.VAZIO), agora = inicio)
        compose.capturar("r3-02-turnos-vazio")
    }

    @Test
    fun `03 erro`() {
        tela(EstadoMeusTurnos(status = StatusMeusTurnos.ERRO, mensagemErro = "Não foi possível carregar seus turnos."), agora = inicio)
        compose.capturar("r3-03-turnos-erro")
    }

    @Test
    fun `04 agendado antes da janela, com cancelar`() {
        tela(agendados(turno()), agora = cincoHorasAntes)
        compose.capturar("r3-04-turno-antes-da-janela")
    }

    @Test
    fun `05 estou a caminho oferecido`() {
        tela(agendados(turno()), agora = duasHorasAntes, aCaminho = true)
        compose.capturar("r3-05-turno-estou-a-caminho")
    }

    @Test
    fun `06 estou a caminho com recusa`() {
        tela(
            agendados(turno()) { copy(erroACaminho = ErroDoACaminho("t1", "Sem conexão. Tente de novo quando a internet voltar.")) },
            agora = duasHorasAntes,
            aCaminho = true,
        )
        compose.capturar("r3-06-turno-a-caminho-recusa")
    }

    @Test
    fun `07 a caminho avisado e check-in aberto`() {
        tela(
            agendados(turno(aCaminhoEm = Instant.parse("2026-11-14T20:10:00Z"))),
            agora = quarentaECincoAntes,
            aCaminho = true,
        )
        compose.capturar("r3-07-turno-checkin-aberto")
    }

    @Test
    fun `08 a caminho e check-in oferecidos juntos`() {
        tela(agendados(turno()), agora = quarentaECincoAntes, aCaminho = true)
        compose.capturar("r3-08-turno-a-caminho-e-checkin")
    }

    @Test
    fun `09 check-in registrando`() {
        tela(agendados(turno()), agora = quarentaECincoAntes, checkin = EstadoCheckin(status = StatusCheckin.REGISTRANDO))
        compose.capturar("r3-09-turno-checkin-registrando")
    }

    @Test
    fun `10 check-in com erro`() {
        tela(
            agendados(turno()),
            agora = quarentaECincoAntes,
            checkin = EstadoCheckin(status = StatusCheckin.ERRO, mensagemErro = "Sem conexão. Verifique sua internet e tente de novo."),
        )
        compose.capturar("r3-10-turno-checkin-erro")
    }

    @Test
    fun `11 check-in manual pendente com o codigo da casa`() {
        tela(
            agendados(turno(comprovante = comprovante(TipoVerificacaoCheckin.MANUAL_PENDENTE))),
            agora = quarentaECincoAntes,
            checkin = EstadoCheckin(status = StatusCheckin.MANUAL_PENDENTE),
            validacao = validacaoParada(),
        )
        compose.onNodeWithTag("campo-do-codigo").performTextInput("0492")
        compose.capturar("r3-11-turno-codigo-da-casa")
    }

    @Test
    fun `12 codigo errado`() {
        tela(
            agendados(turno(comprovante = comprovante(TipoVerificacaoCheckin.MANUAL_PENDENTE))),
            agora = quarentaECincoAntes,
            checkin = EstadoCheckin(status = StatusCheckin.MANUAL_PENDENTE),
            validacao = validacaoQueErra(),
        )
        compose.onNodeWithTag("campo-do-codigo").performTextInput("049215")
        compose.onNodeWithText("Confirmar código").performClick()
        compose.waitUntil(5_000) {
            compose.onAllNodesWithTextSize("Código incorreto. Confira os 6 números e tente de novo.") > 0
        }
        compose.capturar("r3-12-turno-codigo-errado")
    }

    @Test
    fun `13 presenca marcada com check-out`() {
        tela(
            agendados(turno(aCaminhoEm = Instant.parse("2026-11-14T20:10:00Z"), comprovante = comprovante(TipoVerificacaoCheckin.GEOLOCALIZADO))),
            agora = noMeioDoTurno,
            checkin = EstadoCheckin(status = StatusCheckin.VERIFICADO),
        )
        compose.capturar("r3-13-turno-presenca-e-checkout")
    }

    @Test
    fun `14 historico`() {
        val estado = EstadoMeusTurnos(
            status = StatusMeusTurnos.SUCESSO,
            abaSelecionada = AbaDeTurnos.HISTORICO,
            historicoCompleto = listOf(
                turno(id = "h1", estado = "cumprida", podeAvaliar = true, data = "Sáb 07/11, 18:00 às 00:00"),
                turno(id = "h2", estado = "cumprida", casa = "Adega Central", funcao = "Garçom", avaliacao = true, data = "Sex 06/11, 19:00 às 23:00"),
                turno(id = "h3", estado = "cancelada", casa = "Bistrô do Cais", funcao = "Cozinheiro", data = "Qui 05/11, 12:00 às 16:00"),
            ),
        )
        tela(estado, agora = noMeioDoTurno)
        compose.capturar("r3-14-turnos-historico")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `15 check-in aberto com fonte em 200 por cento`() {
        tela(
            agendados(turno(aCaminhoEm = Instant.parse("2026-11-14T20:10:00Z"))),
            agora = quarentaECincoAntes,
            aCaminho = true,
        )
        compose.capturar("r3-15-turno-checkin-fonte-200")
    }

    @Test
    fun `16 dialogo de cancelamento`() {
        val turno = turno()
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                DialogoCancelamentoTurno(
                    estado = EstadoCancelamentoTurno(turno, contaComoFalta = true),
                    aoConfirmar = {},
                    aoVoltar = {},
                )
            }
        }
        compose.capturar("r3-16-dialogo-cancelamento", daJanela = true)
    }

    @Test
    fun `17 dialogo de permissao de localizacao`() {
        tela(
            agendados(turno()),
            agora = quarentaECincoAntes,
            checkin = EstadoCheckin(dialogoDefensivo = DialogoDefensivoLocalizacao.PERMISSAO_NEGADA),
        )
        compose.capturar("r3-17-dialogo-permissao", daJanela = true)
    }

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTextSize(texto: String): Int =
        onAllNodesWithText(texto).fetchSemanticsNodes().size
}
