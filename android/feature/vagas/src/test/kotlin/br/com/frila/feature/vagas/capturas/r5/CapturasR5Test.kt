package br.com.frila.feature.vagas.capturas.r5

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.feature.vagas.candidatos.AcoesCandidatosDaVaga
import br.com.frila.feature.vagas.candidatos.ConteudoCandidatosDaVaga
import br.com.frila.feature.vagas.candidatos.EstadoCandidatosDaVaga
import br.com.frila.feature.vagas.candidatos.EstadoDosCandidatos
import br.com.frila.feature.vagas.candidatos.FalhaDaEscolha
import br.com.frila.feature.vagas.candidatos.ResultadoDaEscolha
import br.com.frila.feature.vagas.painel.AcoesMinhasVagas
import br.com.frila.feature.vagas.painel.ConteudoCancelarVaga
import br.com.frila.feature.vagas.painel.ConteudoRepublicarVaga
import br.com.frila.feature.vagas.painel.DialogoRepublicarPosicoesRestantes
import br.com.frila.feature.vagas.painel.EstadoCancelarVaga
import br.com.frila.feature.vagas.painel.EstadoRepublicarPosicoesRestantes
import br.com.frila.feature.vagas.painel.EstadoRepublicarVaga
import br.com.frila.feature.vagas.painel.MotivoDeCancelamentoDaVaga
import br.com.frila.feature.vagas.painel.TextosCancelarVaga
import br.com.frila.feature.vagas.painel.TextosRepublicarVaga
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.feature.vagas.painel.ConteudoMinhasVagas
import br.com.frila.feature.vagas.painel.EstadoMinhasVagas
import br.com.frila.feature.vagas.painel.ErroMinhasVagas
import br.com.frila.feature.vagas.painel.ItemMinhaVaga
import br.com.frila.feature.vagas.painel.ListaMinhasVagas
import br.com.frila.feature.vagas.painel.SecaoMinhasVagas
import br.com.frila.feature.vagas.painel.TurnoDoItem
import br.com.frila.feature.vagas.publicacao.AcoesPublicarVaga
import br.com.frila.feature.vagas.publicacao.CampoPublicacao
import br.com.frila.feature.vagas.publicacao.ConteudoPublicarVaga
import br.com.frila.feature.vagas.publicacao.ErroGlobalPublicacao
import br.com.frila.feature.vagas.publicacao.EstadoPublicarVaga
import br.com.frila.feature.vagas.publicacao.ModoDaVaga
import br.com.frila.feature.vagas.publicacao.TextosPublicarVaga
import br.com.frila.core.rede.FuncaoDto
import java.time.Duration
import java.time.Instant
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints das telas da casa no lote R5 (Minhas vagas, publicar, candidatos, cancelar e republicar) num Pixel
 * de 411 × 914 dp, no claro. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR5Test {

    @get:Rule
    val compose = createComposeRule()

    private fun item(
        id: String,
        funcao: String = "Garçom",
        secao: SecaoMinhasVagas = SecaoMinhasVagas.PROXIMAS,
        inicio: String = "2026-11-12T21:00:00Z",
        fim: String = "2026-11-13T03:00:00Z",
        total: Int = 3,
        confirmadas: Int = 1,
        pendentes: Int = 0,
        selecao: Boolean = false,
        oculta: Boolean = false,
        emAtraso: Int = 0,
        podeVerCandidatos: Boolean = false,
        recemPublicada: Boolean = false,
        comecaEm: Duration? = null,
        turnos: List<TurnoDoItem> = emptyList(),
        acoes: Boolean = false,
    ) = ItemMinhaVaga(
        id = id, funcao = funcao, local = "SQN 108, Asa Norte", inicio = Instant.parse(inicio), fim = Instant.parse(fim),
        valorCentavos = 16_000, selecao = selecao, oculta = oculta, alertaVagaVazia = secao == SecaoMinhasVagas.EM_ALERTA,
        candidatosPendentes = pendentes, totalPosicoes = total, confirmadas = confirmadas, posicoesAbertas = total - confirmadas,
        emAtraso = emAtraso, secao = secao, recemPublicada = recemPublicada, podeVerCandidatos = podeVerCandidatos,
        comecaEm = comecaEm, turnos = turnos, podeCancelar = acoes, podeRepublicar = acoes, republicavelEmUrgencia = if (acoes) 2 else 0,
    )

    private val vagas = listOf(
        item("v1", "Garçom", SecaoMinhasVagas.EM_ALERTA, comecaEm = Duration.ofMinutes(135), pendentes = 2, emAtraso = 1, podeVerCandidatos = true, selecao = true),
        item("v2", "Barman", SecaoMinhasVagas.HOJE, total = 1, confirmadas = 1, turnos = listOf(TurnoDoItem("p1", "Ana Souza")), recemPublicada = true),
        item("v3", "Cozinheiro", SecaoMinhasVagas.PROXIMAS, oculta = true, acoes = true),
        item("v4", "Auxiliar de cozinha", SecaoMinhasVagas.ENCERRADAS, confirmadas = 3, acoes = true),
    )

    private fun montar(estado: EstadoMinhasVagas, nome: String? = "Bar da Lia") {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoMinhasVagas(
                    estado = estado,
                    nomeEstabelecimento = nome,
                    acoes = AcoesMinhasVagas(aoCancelarVaga = {}, aoRepublicarVaga = {}, aoRepublicarPosicoesRestantes = {}),
                )
            }
        }
    }

    @Test
    fun `minhas vagas com dados - claro`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Sucesso(vagas)))
        compose.capturar("minhas-01-com-dados-claro")
    }

    @Test
    fun `minhas vagas, vaga com acoes - claro`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Sucesso(vagas.drop(2))))
        compose.capturar("minhas-02-acoes-da-vaga-claro")
    }

    @Test
    fun `minhas vagas vazio - claro`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Vazio))
        compose.capturar("minhas-03-vazio-claro")
    }

    @Test
    fun `minhas vagas carregando - claro`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Carregando))
        compose.capturar("minhas-04-carregando-claro")
    }

    @Test
    fun `minhas vagas com erro - claro`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Erro(ErroMinhasVagas.SEM_REDE)))
        compose.capturar("minhas-05-erro-claro")
    }

    @Test
    fun `minhas vagas com lista desatualizada - claro`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Sucesso(vagas.take(2)), desatualizada = true))
        compose.capturar("minhas-06-desatualizada-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `minhas vagas com fonte do sistema em 200 por cento`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Sucesso(vagas)))
        compose.capturar("minhas-07-fonte-200-claro")
    }

    // ---- Publicar vaga ----

    private val base: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private fun estadoDePublicar(mudar: EstadoPublicarVaga.() -> EstadoPublicarVaga = { this }) = EstadoPublicarVaga(
        funcoes = listOf(FuncaoDto("f1", "Garçom", "Salão"), FuncaoDto("f2", "Cozinheiro", "Cozinha"), FuncaoDto("f3", "Barman", "Bar")),
        inicio = base.plus(Duration.ofHours(48)),
        fim = base.plus(Duration.ofHours(54)),
        local = "CLS 408, Bloco B",
        agora = base,
    ).mudar()

    private fun montarPublicar(estado: EstadoPublicarVaga) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) { ConteudoPublicarVaga(estado = estado, acoes = AcoesPublicarVaga()) }
        }
    }

    @Test
    fun `publicar vaga vazio - claro`() {
        montarPublicar(estadoDePublicar())
        compose.capturar("publicar-01-vazio-claro")
    }

    @Test
    fun `publicar vaga preenchido, meio do formulario - claro`() {
        montarPublicar(estadoDePublicar { copy(funcaoId = "f1", valor = "140", posicoes = "2", incluiRefeicao = true, modo = ModoDaVaga.SELECAO) })
        compose.onNodeWithText(TextosPublicarVaga.VALOR).performScrollTo()
        compose.capturar("publicar-02-preenchido-meio-claro")
    }

    @Test
    fun `publicar vaga, posicoes e total - claro`() {
        montarPublicar(estadoDePublicar { copy(funcaoId = "f1", valor = "140", posicoes = "2", errosDeCampo = mapOf(CampoPublicacao.POSICOES to TextosPublicarVaga.POSICOES_CAMPO)) })
        compose.onNodeWithText("Total da vaga: R$\u00A0280,00").performScrollTo()
        compose.capturar("publicar-09-posicoes-e-total-claro")
    }

    @Test
    fun `publicar vaga, inclusos e mais opcoes - claro`() {
        montarPublicar(estadoDePublicar { copy(funcaoId = "f1", valor = "140", incluiRefeicao = true, incluiTransporte = true, participaRateio = true) })
        compose.onNodeWithText(TextosPublicarVaga.MAIS_OPCOES).performScrollTo().performClick()
        compose.onNodeWithText(TextosPublicarVaga.OBSERVACOES).performScrollTo()
        compose.capturar("publicar-03-inclusos-mais-opcoes-claro")
    }

    @Test
    fun `publicar vaga com erros de campo e erro global - claro`() {
        montarPublicar(
            estadoDePublicar {
                copy(
                    errosDeCampo = mapOf(
                        CampoPublicacao.FUNCAO to TextosPublicarVaga.FUNCAO_CAMPO,
                        CampoPublicacao.VALOR to TextosPublicarVaga.VALOR_CAMPO,
                        CampoPublicacao.RESPONSAVEL to TextosPublicarVaga.RESPONSAVEL_CAMPO,
                    ),
                    erro = ErroGlobalPublicacao.CONFIRA_CAMPOS,
                )
            },
        )
        compose.capturar("publicar-04-erros-claro")
    }

    @Test
    fun `publicar vaga enviando - claro`() {
        montarPublicar(estadoDePublicar { copy(funcaoId = "f1", valor = "140", responsavelLocal = "Lia", enviando = true) })
        compose.capturar("publicar-05-enviando-claro")
    }

    @Test
    fun `publicar vaga carregando as funcoes e falha - claro`() {
        montarPublicar(estadoDePublicar { copy(funcoes = emptyList(), falhaAoCarregarFuncoes = true) })
        compose.capturar("publicar-06-funcoes-falha-claro")
    }

    @Test
    fun `publicar vaga com a folha de funcao aberta - claro`() {
        montarPublicar(estadoDePublicar { copy(funcaoId = "f2") })
        compose.onNodeWithText("Cozinheiro").performClick()
        compose.capturarJanela("publicar-07-funcao-aberta-claro", janela = 1)
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `publicar vaga com fonte do sistema em 200 por cento`() {
        montarPublicar(estadoDePublicar { copy(funcaoId = "f1", valor = "140", posicoes = "2") })
        compose.onNodeWithText(TextosPublicarVaga.VALOR).performScrollTo()
        compose.capturar("publicar-08-fonte-200-claro")
    }

    // ---- Candidatos da vaga ----

    private fun candidato(id: String, nome: String, daEquipe: Boolean = false, funcoes: List<String>? = listOf("garçom", "barman"), total: Int = 5) =
        CandidatoDto(
            candidaturaId = id,
            profissional = PerfilPublicoDto(
                id = "p-$id", tipo = "profissional", nome = nome, funcoes = funcoes,
                reputacao = ReputacaoDto(positivas = 4, total = total, taxaComparecimento = if (total == 0) null else 0.9, turnosConsiderados = total, turnosRealizados = total),
                fotoUrl = null,
            ),
            criadaEm = "2026-11-10T12:00:00Z",
            daEquipe = daEquipe,
        )

    private val ana = candidato("c1", "Ana Souza", daEquipe = true)
    private val beto = candidato("c2", "Beto Lima", total = 0, funcoes = null)

    private fun montarCandidatos(estado: EstadoCandidatosDaVaga) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) { ConteudoCandidatosDaVaga(estado = estado, acoes = AcoesCandidatosDaVaga()) }
        }
    }

    private fun estadoDeCandidatos(
        lista: EstadoDosCandidatos = EstadoDosCandidatos.Carregados(listOf(ana, beto, candidato("c3", "Carla Dias"))),
        mudar: EstadoCandidatosDaVaga.() -> EstadoCandidatosDaVaga = { this },
    ) = EstadoCandidatosDaVaga(lista = lista, agora = base).mudar()

    @Test
    fun `candidatos com dados e prazo - claro`() {
        montarCandidatos(estadoDeCandidatos { copy(prazoDeEscolha = Instant.parse("2026-11-11T18:00:00Z")) })
        compose.capturar("candidatos-01-com-dados-claro")
    }

    @Test
    fun `candidatos com escolha em voo e resultado - claro`() {
        montarCandidatos(estadoDeCandidatos { copy(escolhendo = "c1", resultado = ResultadoDaEscolha("Ana Souza", vagaPreenchida = false), desatualizada = true) })
        compose.capturar("candidatos-02-escolhendo-resultado-claro")
    }

    @Test
    fun `candidatos vazio - claro`() {
        montarCandidatos(estadoDeCandidatos(lista = EstadoDosCandidatos.Vazio))
        compose.capturar("candidatos-03-vazio-claro")
    }

    @Test
    fun `candidatos carregando - claro`() {
        montarCandidatos(estadoDeCandidatos(lista = EstadoDosCandidatos.Carregando))
        compose.capturar("candidatos-04-carregando-claro")
    }

    @Test
    fun `candidatos com erro - claro`() {
        montarCandidatos(estadoDeCandidatos(lista = EstadoDosCandidatos.SemConexao))
        compose.capturar("candidatos-05-sem-conexao-claro")
    }

    @Test
    fun `candidatos com falha da escolha - claro`() {
        montarCandidatos(estadoDeCandidatos { copy(falha = FalhaDaEscolha.TurnoSobreposto("Ana Souza")) })
        compose.capturar("candidatos-06-falha-claro")
    }

    @Test
    fun `candidatos com a confirmacao aberta - claro`() {
        montarCandidatos(estadoDeCandidatos { copy(emConfirmacao = ana, posicoesAbertas = 1) })
        compose.capturarJanela("candidatos-07-confirmacao-claro", janela = 1)
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `candidatos com fonte do sistema em 200 por cento`() {
        montarCandidatos(estadoDeCandidatos())
        compose.capturar("candidatos-08-fonte-200-claro")
    }

    // ---- Cancelar vaga ----

    private val motivos = MotivoDeCancelamentoDaVaga.entries

    private fun montarCancelar(estado: EstadoCancelarVaga) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) { ConteudoCancelarVaga(estado, motivos, {}, {}, {}, {}) }
        }
    }

    private val avisoDoCancelamento = "Faltam 5 h para o início. ${TextosCancelarVaga.EFEITO}"

    @Test
    fun `cancelar vaga sem motivo - claro`() {
        montarCancelar(EstadoCancelarVaga(aviso = avisoDoCancelamento))
        compose.capturar("cancelar-01-sem-motivo-claro")
    }

    @Test
    fun `cancelar vaga com motivo e recusa - claro`() {
        montarCancelar(
            EstadoCancelarVaga(aviso = avisoDoCancelamento, motivo = MotivoDeCancelamentoDaVaga.OUTRO, detalhes = "Obra no salão", erro = TextosCancelarVaga.VAGA_JA_FECHADA),
        )
        compose.capturar("cancelar-02-com-motivo-recusa-claro")
    }

    @Test
    fun `cancelar vaga enviando - claro`() {
        montarCancelar(EstadoCancelarVaga(aviso = avisoDoCancelamento, motivo = MotivoDeCancelamentoDaVaga.MOVIMENTO_MENOR, enviando = true))
        compose.capturar("cancelar-03-enviando-claro")
    }

    @Test
    fun `cancelar vaga concluida - claro`() {
        montarCancelar(EstadoCancelarVaga(aviso = avisoDoCancelamento, concluida = true))
        compose.capturar("cancelar-04-concluida-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `cancelar vaga com fonte do sistema em 200 por cento`() {
        montarCancelar(EstadoCancelarVaga(aviso = avisoDoCancelamento, motivo = MotivoDeCancelamentoDaVaga.OUTRO))
        compose.capturar("cancelar-05-fonte-200-claro")
    }

    // ---- Republicar vaga ----

    private val inicioRepublicar = Instant.parse("2026-11-20T21:00:00Z")
    private val fimRepublicar = Instant.parse("2026-11-21T03:00:00Z")

    private fun montarRepublicar(estado: EstadoRepublicarVaga) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) { ConteudoRepublicarVaga(estado, {}, {}, {}, {}) }
        }
    }

    @Test
    fun `republicar vaga - claro`() {
        montarRepublicar(EstadoRepublicarVaga(inicioRepublicar, fimRepublicar))
        compose.capturar("republicar-01-formulario-claro")
    }

    @Test
    fun `republicar vaga com erro de campo e falha de rede - claro`() {
        montarRepublicar(
            EstadoRepublicarVaga(
                inicioRepublicar, fimRepublicar, erroFim = TextosRepublicarVaga.TURNO_CURTO,
                camposBloqueados = true, mensagemErro = TextosRepublicarVaga.SEM_REDE,
            ),
        )
        compose.capturar("republicar-02-erros-claro")
    }

    @Test
    fun `republicar vaga republicada - claro`() {
        montarRepublicar(EstadoRepublicarVaga(inicioRepublicar, fimRepublicar, vagaPublicadaId = "nova"))
        compose.capturar("republicar-03-republicada-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `republicar vaga com fonte do sistema em 200 por cento`() {
        montarRepublicar(EstadoRepublicarVaga(inicioRepublicar, fimRepublicar))
        compose.capturar("republicar-04-fonte-200-claro")
    }

    @Test
    fun `republicar posicoes restantes, folha de confirmacao - claro`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                DialogoRepublicarPosicoesRestantes(
                    EstadoRepublicarPosicoesRestantes(posicoesRestantes = 2, erro = "O turno desta vaga já começou."), {}, {},
                )
            }
        }
        compose.capturarJanela("republicar-05-posicoes-restantes-claro", janela = 1)
    }
}
