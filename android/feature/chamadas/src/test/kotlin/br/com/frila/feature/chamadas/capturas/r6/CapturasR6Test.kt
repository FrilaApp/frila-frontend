package br.com.frila.feature.chamadas.capturas.r6

import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CartaoProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import br.com.frila.core.rede.RegiaoAdministrativaDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoNoPerfilDto
import br.com.frila.feature.chamadas.casa.ConteudoBuscaDeProfissionais
import br.com.frila.feature.chamadas.casa.EstadoBusca
import br.com.frila.feature.chamadas.casa.EstadoDaBusca
import br.com.frila.feature.chamadas.casa.TextosChamadaCasa
import java.time.Instant
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R6 no módulo de chamadas: busca de profissionais, folha de chamar, perfil público, chamada direta e
 * acompanhar chamadas. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR6Test {

    @get:Rule
    val compose = createComposeRule()

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val garcom = FuncaoDto("f1", "Garçom", "salao")
    private val barman = FuncaoDto("f2", "Barman", "salao")
    private val reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8)
    private val casa = MeuEstabelecimentoDto(
        id = "c1", nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )

    private fun cartao(id: String, nome: String, disponivel: Boolean? = null) = CartaoProfissionalDto(
        id = id, nome = nome,
        servico = ServicoNoPerfilDto(funcao = garcom, unidade = "diaria", valorCentavos = 15000, horasIncluidas = 8),
        regioes = listOf(RegiaoAdministrativaDto(1, "I", "Plano Piloto"), RegiaoAdministrativaDto(2, "II", "Asa Norte")),
        distanciaFaixa = "ate_5_km", reputacao = reputacao, disponivelNoHorario = disponivel,
    )

    private val tresPessoas = listOf(cartao("p1", "Maria S.", true), cartao("p2", "João P.", false), cartao("p3", "Ana L."))

    private fun base(ajuste: EstadoBusca.() -> EstadoBusca = { this }) = EstadoBusca(
        funcoes = listOf(garcom, barman), funcaoId = garcom.id, casa = casa,
        regioes = listOf(RegiaoAdministrativaDto(1, "I", "Plano Piloto")),
    ).ajuste()

    private fun busca(estado: EstadoBusca) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoBuscaDeProfissionais(
                    estado = estado, aoVoltar = {}, aoEscolherFuncao = {}, aoEscolherRegiao = {}, aoDefinirHorario = {},
                    aoBuscar = {}, aoCarregarMais = {}, aoTentarCatalogosDeNovo = {}, aoAlternarSelecao = {},
                    aoAbrirPerfil = {}, aoPublicarParaTodos = {}, aoChamar = { _, _ -> }, aoReenviar = {}, aoConfirmarJ7 = {},
                    relogio = { agora }, carregarFoto = { null },
                )
            }
        }
    }

    @Test
    fun `busca ociosa com os filtros - claro`() {
        busca(base())
        compose.capturar("r6-20-busca-filtros-claro")
    }

    @Test
    fun `busca com o filtro de horario ligado - claro`() {
        busca(base())
        compose.onNodeWithTag("busca-usar-horario").performClick()
        compose.capturar("r6-21-busca-horario-claro")
    }

    @Test
    fun `busca com resultados e selecionados - claro`() {
        busca(base { copy(estado = EstadoDaBusca.Resultados, resultados = tresPessoas, selecionados = listOf("p1", "p3"), temMais = true) })
        compose.capturar("r6-22-busca-resultados-claro")
    }

    @Test
    fun `busca com resultados e o aviso do limite - claro`() {
        busca(
            base {
                copy(
                    estado = EstadoDaBusca.Resultados, resultados = tresPessoas, selecionados = listOf("p1", "p2", "p3"),
                    avisoDeLimiteDeSelecao = TextosChamadaCasa.BUSCA_LIMITE_DE_SELECAO,
                )
            },
        )
        compose.capturar("r6-23-busca-limite-claro")
    }

    @Test
    fun `busca carregando - claro`() {
        busca(base { copy(estado = EstadoDaBusca.Carregando) })
        compose.capturar("r6-24-busca-carregando-claro")
    }

    @Test
    fun `busca vazia com publicar para todos - claro`() {
        busca(base { copy(estado = EstadoDaBusca.Vazio, filtroDaBusca = br.com.frila.feature.chamadas.casa.RascunhoDeVagaDaBusca("c1", "f1")) })
        compose.capturar("r6-25-busca-vazia-claro")
    }

    @Test
    fun `busca com erro - claro`() {
        busca(base { copy(estado = EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_ERRO)) })
        compose.capturar("r6-26-busca-erro-claro")
    }

    @Test
    fun `busca com o aceite dos termos - claro`() {
        busca(base { copy(estado = EstadoDaBusca.TermosPendentes(erro = TextosChamadaCasa.BUSCA_TERMOS_ERRO)) })
        compose.capturar("r6-27-busca-termos-claro")
    }

    @Test
    fun `busca indisponivel - claro`() {
        busca(base { copy(estado = EstadoDaBusca.Indisponivel) })
        compose.capturar("r6-28-busca-indisponivel-claro")
    }

    @Test
    fun `folha de chamar - claro`() {
        busca(base { copy(estado = EstadoDaBusca.Resultados, resultados = tresPessoas, selecionados = listOf("p1", "p3")) })
        compose.onNodeWithTag("busca-chamar").performClick()
        compose.capturarJanela("r6-29-folha-de-chamar-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `busca com resultados - fonte do sistema em 200 por cento`() {
        busca(base { copy(estado = EstadoDaBusca.Resultados, resultados = tresPessoas, selecionados = listOf("p1")) })
        compose.capturar("r6-30-busca-resultados-fonte-200")
    }
}
