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
import br.com.frila.core.rede.ChamadaDto
import br.com.frila.core.rede.ChamadaResumoDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.feature.chamadas.casa.AcoesChamadaDireta
import br.com.frila.feature.chamadas.casa.ConteudoAcompanharChamadas
import br.com.frila.feature.chamadas.casa.ConteudoChamadaDireta
import br.com.frila.feature.chamadas.casa.ConteudoPerfilPublico
import br.com.frila.feature.chamadas.casa.EstadoAcompanharChamadas
import br.com.frila.feature.chamadas.casa.EstadoChamadaDireta
import br.com.frila.feature.chamadas.casa.EstadoPerfilPublico
import java.time.Duration
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

    // --- Perfil público ---------------------------------------------------------------------------------

    private val perfil = PerfilPublicoDto(
        id = "p1", tipo = "profissional", nome = "Maria S.", funcoes = listOf("Garçom"), reputacao = reputacao,
        apresentacao = "Dez anos de salão", experienciaFaixa = "de_5_a_10_anos", cursos = listOf("Boas práticas"),
        idiomas = listOf("portugues", "ingles"),
        servicos = listOf(ServicoNoPerfilDto(funcao = garcom, unidade = "diaria", valorCentavos = 15000, horasIncluidas = 8)),
        regioes = listOf(RegiaoAdministrativaDto(1, "I", "Plano Piloto")),
        atendeTodoDf = false,
    )

    private fun perfilPublico(estado: EstadoPerfilPublico, comChamar: Boolean = true) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoPerfilPublico(estado, aoTentarNovamente = {}, aoVoltar = {}, aoChamar = if (comChamar) ({ }) else null)
            }
        }
    }

    @Test
    fun `perfil publico carregado - claro`() {
        perfilPublico(EstadoPerfilPublico.Carregado(perfil))
        compose.capturar("r6-40-perfil-publico-claro")
    }

    @Test
    fun `perfil publico carregando - claro`() {
        perfilPublico(EstadoPerfilPublico.Carregando)
        compose.capturar("r6-41-perfil-publico-carregando-claro")
    }

    @Test
    fun `perfil publico indisponivel - claro`() {
        perfilPublico(EstadoPerfilPublico.Indisponivel)
        compose.capturar("r6-42-perfil-publico-indisponivel-claro")
    }

    @Test
    fun `perfil publico com falha - claro`() {
        perfilPublico(EstadoPerfilPublico.Falha(TextosChamadaCasa.SEM_REDE))
        compose.capturar("r6-43-perfil-publico-falha-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `perfil publico carregado - fonte do sistema em 200 por cento`() {
        perfilPublico(EstadoPerfilPublico.Carregado(perfil))
        compose.capturar("r6-44-perfil-publico-fonte-200")
    }

    // --- Chamar profissional ------------------------------------------------------------------------------

    private fun formulario(ajuste: EstadoChamadaDireta.() -> EstadoChamadaDireta = { this }): EstadoChamadaDireta {
        val inicio = agora.plus(Duration.ofHours(24))
        return EstadoChamadaDireta(
            funcoes = listOf(garcom, barman), funcaoId = "f1", local = "SCS Quadra 2", inicio = inicio, fim = inicio.plus(Duration.ofHours(4)),
            responsavel = "Bistrô Ipê", recursoHabilitado = true, agora = agora,
        ).ajuste()
    }

    private fun chamadaDireta(tela: EstadoChamadaDireta) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoChamadaDireta(
                    tela = tela, acoes = AcoesChamadaDireta(aoAcompanhar = { }),
                    inicioMinimo = { agora.plus(Duration.ofHours(2)) },
                    faixaDoTermino = { tela.inicio.plus(Duration.ofHours(2))..tela.inicio.plus(Duration.ofHours(16)) },
                )
            }
        }
    }

    @Test
    fun `chamada direta com o botao desligado e o que falta - claro`() {
        chamadaDireta(formulario())
        compose.capturar("r6-50-chamada-direta-vazia-claro")
    }

    @Test
    fun `chamada direta pronta para enviar - claro`() {
        chamadaDireta(formulario { copy(valorTexto = "180", totalConfirmado = true, refeicao = true, recado = "Traga avental") })
        compose.capturar("r6-51-chamada-direta-pronta-claro")
    }

    @Test
    fun `chamada direta enviando - claro`() {
        chamadaDireta(formulario { copy(valorTexto = "180", totalConfirmado = true, enviando = true, travado = true) })
        compose.capturar("r6-52-chamada-direta-enviando-claro")
    }

    @Test
    fun `chamada direta com recado longo - claro`() {
        chamadaDireta(formulario { copy(valorTexto = "180", totalConfirmado = true, recado = "a".repeat(301)) })
        compose.capturar("r6-53-chamada-direta-recado-longo-claro")
    }

    @Test
    fun `chamada direta enviada com o resumo - claro`() {
        val chamada = ChamadaDto(
            id = "c1", vagaId = "v1", profissionalId = "p1", estabelecimentoId = "e1", estado = "aberta",
            expiraEm = "2026-11-17T12:00:00Z", criadaEm = "2026-11-16T15:00:00Z",
        )
        chamadaDireta(formulario { copy(valorTexto = "180", totalConfirmado = true, resultado = chamada, travado = true) })
        compose.capturar("r6-54-chamada-direta-enviada-claro")
    }

    @Test
    fun `chamada direta com o recurso desligado - claro`() {
        chamadaDireta(formulario { copy(recursoHabilitado = false, erro = TextosChamadaCasa.DESLIGADO) })
        compose.capturar("r6-55-chamada-direta-desligada-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `chamada direta pronta para enviar - fonte do sistema em 200 por cento`() {
        chamadaDireta(formulario { copy(valorTexto = "180", totalConfirmado = true) })
        compose.capturar("r6-56-chamada-direta-fonte-200")
    }

    // --- Acompanhar chamadas ------------------------------------------------------------------------------

    private fun resumo(id: String, estado: String, nome: String, motivo: String? = null) = ChamadaResumoDto(
        id = id, vagaId = "v1", profissionalId = "p1", estabelecimentoId = "e1", estado = estado, motivoRecusa = motivo,
        expiraEm = "2026-11-17T12:00:00Z", criadaEm = "2026-11-16T15:00:00Z", funcao = garcom,
        inicioEm = "2026-11-20T22:00:00Z", fimEm = "2026-11-21T02:00:00Z", valorCentavos = 18000,
        outraParte = PerfilPublicoDto(id = "p1", tipo = "profissional", nome = nome, reputacao = reputacao),
    )

    private fun acompanhar(tela: EstadoAcompanharChamadas) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoAcompanharChamadas(tela = tela, aoCancelar = {}, aoPublicarParaTodos = {}, aoVoltar = {}, aoVerVagaPublicada = {})
            }
        }
    }

    @Test
    fun `acompanhar chamadas com os estados - claro`() {
        acompanhar(
            EstadoAcompanharChamadas(
                chamadas = listOf(
                    resumo("a", "aberta", "Maria S."),
                    resumo("b", "aceita", "Joana P."),
                    resumo("c", "recusada", "Ana L.", motivo = "valor"),
                    resumo("d", "expirada", "Rui T."),
                ),
            ),
        )
        compose.capturar("r6-60-acompanhar-estados-claro")
    }

    @Test
    fun `acompanhar chamadas terminadas sem aceite com publicar para todos - claro`() {
        acompanhar(EstadoAcompanharChamadas(chamadas = listOf(resumo("a", "recusada", "Maria S.", "agenda"), resumo("b", "expirada", "Ana L."))))
        compose.capturar("r6-61-acompanhar-publicar-claro")
    }

    @Test
    fun `acompanhar chamadas vazio com vaga publicada - claro`() {
        acompanhar(EstadoAcompanharChamadas(vagaPublicadaId = "nova", sucesso = TextosChamadaCasa.VAGA_PUBLICADA_SUCESSO))
        compose.capturar("r6-62-acompanhar-vazio-claro")
    }

    @Test
    fun `acompanhar chamadas carregando - claro`() {
        acompanhar(EstadoAcompanharChamadas(carregando = true))
        compose.capturar("r6-63-acompanhar-carregando-claro")
    }

    @Test
    fun `acompanhar chamadas com erro - claro`() {
        acompanhar(EstadoAcompanharChamadas(erro = TextosChamadaCasa.ERRO_GENERICO, chamadas = listOf(resumo("a", "aberta", "Maria S."))))
        compose.capturar("r6-64-acompanhar-erro-claro")
    }
}
