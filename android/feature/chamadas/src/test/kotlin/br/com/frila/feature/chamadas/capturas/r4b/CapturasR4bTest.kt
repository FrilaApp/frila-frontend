package br.com.frila.feature.chamadas.capturas.r4b

import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.EspecialidadeDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ResultadoChamadaDto
import br.com.frila.feature.chamadas.profissional.ConteudoDaChamadaRecebida
import br.com.frila.feature.chamadas.profissional.ConteudoEditarServicos
import br.com.frila.feature.chamadas.profissional.ConteudoPreferenciasDeChamada
import br.com.frila.feature.chamadas.profissional.EstadoChamadaRecebida
import br.com.frila.feature.chamadas.profissional.EstadoEditarServicos
import br.com.frila.feature.chamadas.profissional.EstadoPreferenciasChamada
import br.com.frila.feature.chamadas.profissional.Fixtures
import br.com.frila.feature.chamadas.profissional.ServicoEmEdicao
import br.com.frila.feature.chamadas.profissional.TextosChamadaProfissional
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.LocalDate

/**
 * Prints do lote R4b (profissional · chamadas) num Pixel de 411 × 914 dp, no claro. As telas longas têm uma
 * captura "alta" (411 × 1800 dp) para ver o fim. Sem `FRILA_CAPTURAS_DIR` (na CI) cada teste só confere que a
 * tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR4bTest {

    @get:Rule
    val compose = createComposeRule()

    private val garcom = FuncaoDto(Fixtures.FUNCAO, "Garçom", "salao")
    private val barman = FuncaoDto(Fixtures.FUNCAO_BARMAN, "Barman", "bar")
    private val hoje = LocalDate.of(2026, 11, 17)

    // --- Editar serviços ---------------------------------------------------------------------------

    private fun servicos(vararg linhas: ServicoEmEdicao, ajuste: EstadoEditarServicos.() -> EstadoEditarServicos = { this }) =
        EstadoEditarServicos(
            carregando = false,
            carregou = true,
            rascunhos = linhas.toList(),
            especialidades = mapOf(
                Fixtures.FUNCAO to listOf(
                    EspecialidadeDto(Fixtures.ESPECIALIDADE, Fixtures.FUNCAO, "Eventos", true),
                    EspecialidadeDto("99999999-9999-9999-9999-999999999999", Fixtures.FUNCAO, "Casamentos", true),
                    EspecialidadeDto("99999999-9999-9999-9999-999999999998", Fixtures.FUNCAO, "Coquetéis", true),
                ),
            ),
        ).ajuste()

    private fun montarServicos(tela: EstadoEditarServicos) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoEditarServicos(
                    tela = tela,
                    aoEditar = { _, _ -> },
                    aoAlternarEspecialidade = { _, _, _ -> },
                    aoSalvar = {},
                    aoTentarNovamente = {},
                    aoVoltar = {},
                )
            }
        }
    }

    private val diaria = ServicoEmEdicao(
        funcao = garcom,
        habilitado = true,
        unidade = "diaria",
        valor = "150",
        valorMaximo = "220",
        horasIncluidas = "8",
        levaMaterial = "nao",
        inclui = "Avental e luvas",
        especialidadeIds = setOf(Fixtures.ESPECIALIDADE),
    )

    @Test
    fun `servicos - carregando`() {
        montarServicos(EstadoEditarServicos())
        compose.capturar("r4b-01-servicos-carregando")
    }

    @Test
    fun `servicos - falha ao carregar`() {
        montarServicos(EstadoEditarServicos(carregando = false, carregou = false, erro = TextosChamadaProfissional.ERRO))
        compose.capturar("r4b-02-servicos-erro-de-carga")
    }

    @Test
    fun `servicos - sem funcoes`() {
        montarServicos(EstadoEditarServicos(carregando = false, carregou = true))
        compose.capturar("r4b-03-servicos-vazio")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h1900dp-xxhdpi")
    fun `servicos - com dados e salvo`() {
        montarServicos(servicos(diaria, ServicoEmEdicao(barman)) { copy(sucesso = true) })
        compose.capturar("r4b-04-servicos-dados")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h1900dp-xxhdpi")
    fun `servicos - erro de campo`() {
        montarServicos(
            servicos(diaria.copy(unidade = "hora", horasIncluidas = "", minimoHoras = "2", valor = "5"), ServicoEmEdicao(barman)) {
                copy(
                    erro = TextosChamadaProfissional.campo("valor_centavos"),
                    funcaoComErro = Fixtures.FUNCAO,
                    campoComErro = "valor_centavos",
                )
            },
        )
        compose.capturar("r4b-05-servicos-erro-de-campo")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `servicos - fonte do sistema em 200 por cento`() {
        montarServicos(servicos(diaria, ServicoEmEdicao(barman)))
        compose.capturar("r4b-06-servicos-fonte-200")
    }

    @Test
    fun `servicos - salvando e a combinar`() {
        montarServicos(servicos(diaria.copy(unidade = "a_combinar", valor = "", valorMaximo = "", horasIncluidas = "")) { copy(salvando = true) })
        compose.capturar("r4b-07-servicos-salvando")
    }

    // --- Preferências de chamadas ------------------------------------------------------------------

    private fun preferencias(ajuste: EstadoPreferenciasChamada.() -> EstadoPreferenciasChamada = { this }) =
        EstadoPreferenciasChamada(carregando = false, carregou = true, pausadoAte = hoje.plusDays(3)).ajuste()

    private fun montarPreferencias(tela: EstadoPreferenciasChamada, busca: Boolean = true) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoPreferenciasDeChamada(
                    tela = tela,
                    aoTentarNovamente = {},
                    aoAlternarAceitaChamadas = {},
                    aoAlternarAceitaDeQuemJaTrabalhou = {},
                    aoAlternarPausa = {},
                    aoEscolherDataDaPausa = {},
                    aoEscolherAntecedencia = {},
                    aoEscolherQuemPodeChamar = {},
                    aoSalvar = {},
                    aoVoltar = {},
                    aoEditarServicos = {},
                    buscaProfissionaisHabilitada = busca,
                    hoje = hoje,
                )
            }
        }
    }

    @Test
    fun `preferencias - carregando`() {
        montarPreferencias(EstadoPreferenciasChamada(pausadoAte = hoje))
        compose.capturar("r4b-10-preferencias-carregando")
    }

    @Test
    fun `preferencias - falha ao carregar`() {
        montarPreferencias(EstadoPreferenciasChamada(carregando = false, carregou = false, erro = TextosChamadaProfissional.ERRO, pausadoAte = hoje))
        compose.capturar("r4b-11-preferencias-erro-de-carga")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h1900dp-xxhdpi")
    fun `preferencias - com dados, busca ligada, pendencias e pausa`() {
        montarPreferencias(
            preferencias { copy(aceitaChamadas = true, pausar = true, pendencias = listOf("sem_servico_com_preco", "sem_regiao", "pausado"), sucesso = true) },
        )
        compose.capturar("r4b-12-preferencias-dados")
    }

    @Test
    fun `preferencias - erro ao salvar e chave da busca desligada`() {
        montarPreferencias(preferencias { copy(erro = TextosChamadaProfissional.ERRO) }, busca = false)
        compose.capturar("r4b-13-preferencias-erro-ao-salvar")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `preferencias - fonte do sistema em 200 por cento`() {
        montarPreferencias(preferencias { copy(aceitaChamadas = true, pendencias = listOf("sem_regiao")) })
        compose.capturar("r4b-14-preferencias-fonte-200")
    }

    // --- Chamada recebida --------------------------------------------------------------------------

    private fun detalhe(estado: String = "aberta", contaNova: Boolean = false, recado: String? = "Traga avental preto e chegue 15 minutos antes."): ChamadaDetalheDto =
        ClienteSupabase.jsonFrila.decodeFromString(Fixtures.detalheChamadaJson(estado = estado, contaNova = contaNova, recado = recado))

    private fun resultado(estado: String): ResultadoChamadaDto =
        ClienteSupabase.jsonFrila.decodeFromString(Fixtures.resultadoJson(estado))

    private fun recebida(ajuste: EstadoChamadaRecebida.() -> EstadoChamadaRecebida = { this }) =
        EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA, carregando = false, detalhe = detalhe()).ajuste()

    private fun montarRecebida(tela: EstadoChamadaRecebida) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoDaChamadaRecebida(
                    tela = tela,
                    aoTentarNovamente = {},
                    aoAceitar = {},
                    aoAbrirRecusa = {},
                    aoFecharRecusa = {},
                    aoEscolherMotivo = {},
                    aoConfirmarRecusa = {},
                    aoVoltar = {},
                    aoAbrirTurno = {},
                    acoesDeSeguranca = { _: PerfilPublicoDto -> },
                )
            }
        }
    }

    @Test
    fun `recebida - carregando`() {
        montarRecebida(EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA))
        compose.capturar("r4b-20-recebida-carregando")
    }

    @Test
    fun `recebida - falha ao carregar`() {
        montarRecebida(EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA, carregando = false, erro = TextosChamadaProfissional.INDISPONIVEL))
        compose.capturar("r4b-21-recebida-erro-de-carga")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h1400dp-xxhdpi")
    fun `recebida - aberta, conta nova`() {
        montarRecebida(recebida { copy(detalhe = detalhe(contaNova = true)) })
        compose.capturar("r4b-22-recebida-aberta")
    }

    @Test
    fun `recebida - aberta, janela de celular`() {
        montarRecebida(recebida())
        compose.capturar("r4b-23-recebida-aberta-janela")
    }

    @Test
    fun `recebida - respondendo`() {
        montarRecebida(recebida { copy(respondendo = true) })
        compose.capturar("r4b-24-recebida-respondendo")
    }

    @Test
    fun `recebida - erro ao responder`() {
        montarRecebida(recebida { copy(erro = TextosChamadaProfissional.ERRO) })
        compose.capturar("r4b-25-recebida-erro-ao-responder")
    }

    @Test
    fun `recebida - encerrada`() {
        montarRecebida(recebida { copy(mensagemDeConcorrencia = TextosChamadaProfissional.CHAMADA_EXPIRADA, detalhe = detalhe("expirada")) })
        compose.capturar("r4b-26-recebida-encerrada")
    }

    @Test
    fun `recebida - aceita`() {
        montarRecebida(recebida { copy(resultado = resultado("aceita"), detalhe = detalhe("aceita")) })
        compose.capturar("r4b-27-recebida-aceita")
    }

    @Test
    fun `recebida - recusada`() {
        montarRecebida(recebida { copy(resultado = resultado("recusada"), detalhe = detalhe("recusada")) })
        compose.capturar("r4b-28-recebida-recusada")
    }

    @Test
    fun `recebida - folha de recusa`() {
        montarRecebida(recebida { copy(mostrarRecusa = true, motivoSelecionado = "agenda") })
        compose.capturar("r4b-29-recebida-folha-de-recusa", daFolha = true)
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `recebida - fonte do sistema em 200 por cento`() {
        montarRecebida(recebida { copy(detalhe = detalhe(contaNova = true)) })
        compose.capturar("r4b-30-recebida-fonte-200")
    }
}
