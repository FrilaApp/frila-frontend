package br.com.frila.feature.chamadas.profissional

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.EspecialidadeDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.ResultadoChamadaDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelasDoProfissionalTest {

    @get:Rule
    val rule = createComposeRule()

    private fun detalhe(estado: String = "aberta", contaNova: Boolean = false, recado: String? = "Traga avental"): ChamadaDetalheDto =
        ClienteSupabase.jsonFrila.decodeFromString(Fixtures.detalheChamadaJson(estado = estado, contaNova = contaNova, recado = recado))

    private fun resultado(estado: String): ResultadoChamadaDto =
        ClienteSupabase.jsonFrila.decodeFromString(Fixtures.resultadoJson(estado))

    private fun semSemantica(propriedade: androidx.compose.ui.semantics.SemanticsPropertyKey<*>) = SemanticsMatcher.keyIsDefined(propriedade)

    // --- Preferências de chamada -----------------------------------------------------------------

    private class Preferencias {
        var aceita: Boolean? = null
        var pausa: Boolean? = null
        var antecedencia: Int? = null
        var quem: String? = null
        var salvou = 0
        var voltou = 0
        var servicos = 0
        var novamente = 0
    }

    private fun montarPreferencias(
        tela: EstadoPreferenciasChamada,
        p: Preferencias = Preferencias(),
        servicos: Boolean = true,
        busca: Boolean = true,
    ): Preferencias {
        rule.setContent {
            FrilaTheme {
                ConteudoPreferenciasDeChamada(
                    tela = tela,
                    aoTentarNovamente = { p.novamente++ },
                    aoAlternarAceitaChamadas = { p.aceita = it },
                    aoAlternarAceitaDeQuemJaTrabalhou = {},
                    aoAlternarPausa = { p.pausa = it },
                    aoEscolherDataDaPausa = {},
                    aoEscolherAntecedencia = { p.antecedencia = it },
                    aoEscolherQuemPodeChamar = { p.quem = it },
                    aoSalvar = { p.salvou++ },
                    aoVoltar = { p.voltou++ },
                    aoEditarServicos = if (servicos) ({ p.servicos++ }) else null,
                    buscaProfissionaisHabilitada = busca,
                    hoje = LocalDate.of(2026, 11, 16),
                )
            }
        }
        return p
    }

    private fun preferencias(ajuste: EstadoPreferenciasChamada.() -> EstadoPreferenciasChamada = { this }) =
        EstadoPreferenciasChamada(carregando = false, carregou = true, pausadoAte = LocalDate.of(2026, 11, 17)).ajuste()

    @Test
    fun preferenciasMostraTituloComoHeadingVoltarComAlvoMinimoEOsCamposNaOrdemDoIos() {
        val p = montarPreferencias(preferencias())

        rule.onNodeWithText(TextosChamadaProfissional.PREFERENCIAS_TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithContentDescription(TextosChamadaProfissional.ROTULO_VOLTAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        assertEquals(1, p.voltou)
        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TEXTO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_O_QUE_APARECE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.RECEBER_DE_QUEM_JA_TRABALHOU).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.PAUSAR_CHAMADAS).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.ANTECEDENCIA_MINIMA).assertExists()
        rule.onNodeWithText(TextosChamadaProfissional.QUEM_PODE_CHAMAR).assertExists()
    }

    @Test
    fun preferenciasComAChaveDaBuscaDesligadaNaoTemOBlocoAceitoChamadasNemPendenciasMasTemOAtalhoDeServicos() {
        montarPreferencias(
            preferencias { copy(aceitaChamadas = true, pendencias = listOf("sem_regiao")) },
            busca = false,
        )

        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TITULO).assertDoesNotExist()
        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TEXTO).assertDoesNotExist()
        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_O_QUE_APARECE).assertDoesNotExist()
        rule.onNodeWithTag("chave-aceita-chamadas").assertDoesNotExist()
        rule.onNodeWithTag("pendencias-busca").assertDoesNotExist()
        // Serviços são da chamada direta, não da busca: o atalho existe com a chave da busca desligada.
        rule.onNodeWithTag("editar-servicos").performScrollTo().assertExists()
        // O resto fica como no iOS de hoje.
        rule.onNodeWithText(TextosChamadaProfissional.RECEBER_DE_QUEM_JA_TRABALHOU).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.PAUSAR_CHAMADAS).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.ANTECEDENCIA_MINIMA).performScrollTo().assertExists()
        rule.onNodeWithText(TextosChamadaProfissional.QUEM_PODE_CHAMAR).performScrollTo().assertExists()
        rule.onNodeWithTag("salvar-preferencias-chamada").assertExists()
    }

    @Test
    fun preferenciasComAChaveDaBuscaLigadaTemOBlocoAceitoChamadas() {
        montarPreferencias(preferencias { copy(aceitaChamadas = true, pendencias = listOf("sem_regiao")) }, busca = true)

        rule.onNodeWithText(TextosChamadaProfissional.ACEITO_TITULO).assertIsDisplayed()
        rule.onNodeWithTag("chave-aceita-chamadas").assertIsDisplayed()
        rule.onNodeWithTag("pendencias-busca").assertIsDisplayed()
        rule.onNodeWithTag("editar-servicos").performScrollTo().assertExists()
    }

    @Test
    fun preferenciasLigarAceitoChamadasAvisaAChaveEOEstadoDaChaveVemDoViewModel() {
        val p = montarPreferencias(preferencias())

        rule.onNodeWithTag("chave-aceita-chamadas").assertIsOff().performClick()
        assertEquals(true, p.aceita)
    }

    @Test
    fun preferenciasComAceitoLigadoMostraAsPendenciasDaBuscaSoAsConhecidas() {
        montarPreferencias(preferencias { copy(aceitaChamadas = true, pendencias = listOf("sem_servico_com_preco", "sem_regiao", "codigo_novo")) })

        rule.onNodeWithTag("chave-aceita-chamadas").assertIsOn()
        rule.onNodeWithText(TextosChamadaProfissional.PENDENCIAS_TITULO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("• ${TextosChamadaProfissional.PENDENCIA_SEM_SERVICO}").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("• ${TextosChamadaProfissional.PENDENCIA_SEM_REGIAO}").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun preferenciasSemAceitoLigadoNaoMostraPendencias() {
        montarPreferencias(preferencias { copy(aceitaChamadas = false, pendencias = listOf("sem_regiao")) })

        rule.onNodeWithTag("pendencias-busca").assertDoesNotExist()
    }

    @Test
    fun preferenciasPausaMostraADataEARetomadaSoQuandoLigada() {
        montarPreferencias(preferencias())
        rule.onNodeWithTag("data-pausa-chamadas").assertDoesNotExist()
    }

    @Test
    fun preferenciasPausaLigadaMostraDataELinhaDaRetomada() {
        montarPreferencias(preferencias { copy(pausar = true, pausadoAte = LocalDate.of(2026, 11, 20)) })

        rule.onNodeWithTag("data-pausa-chamadas").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("${TextosChamadaProfissional.PAUSAR_ATE_DATA}: 20/11/2026").assertExists()
        rule.onNodeWithText(TextosChamadaProfissional.retomadaDaPausa("21/11/2026")).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun preferenciasEscolhasEvaiParaSalvarEEditarServicos() {
        val p = montarPreferencias(preferencias())

        rule.onNodeWithText(TextosChamadaProfissional.ANTECEDENCIA_24H).performScrollTo().performClick()
        assertEquals(24, p.antecedencia)
        rule.onNodeWithText(TextosChamadaProfissional.QUEM_SO_CNPJ).performScrollTo().performClick()
        assertEquals("so_cnpj", p.quem)
        rule.onNodeWithTag("editar-servicos").performScrollTo().performClick()
        assertEquals(1, p.servicos)
        rule.onNodeWithTag("salvar-preferencias-chamada").performClick()
        assertEquals(1, p.salvou)
    }

    @Test
    fun preferenciasSalvandoBloqueiaOBotaoEErroEPosicaoSucessoAparecem() {
        montarPreferencias(preferencias { copy(salvando = true, erro = TextosChamadaProfissional.DESLIGADO) })

        rule.onNodeWithText(TextosChamadaProfissional.DESLIGADO).assertIsDisplayed()
        rule.onNodeWithTag("salvar-preferencias-chamada").assertIsNotEnabled()
    }

    @Test
    fun preferenciasSucessoMostraOAvisoDeSalvo() {
        montarPreferencias(preferencias { copy(sucesso = true) })
        rule.onNodeWithTag("preferencias-sucesso").assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.PREFERENCIAS_SALVAS).assertIsDisplayed()
    }

    @Test
    fun preferenciasSemEditarServicosEscondeOAtalho() {
        montarPreferencias(preferencias(), servicos = false)
        rule.onNodeWithTag("editar-servicos").assertDoesNotExist()
    }

    @Test
    fun preferenciasCarregandoMostraOIndicadorEFalhaMostraTentarNovamente() {
        montarPreferencias(EstadoPreferenciasChamada(pausadoAte = LocalDate.of(2026, 11, 17)))
        rule.onNodeWithText(TextosChamadaProfissional.CARREGANDO).assertIsDisplayed()
    }

    @Test
    fun preferenciasFalhaDeCargaOferecerTentarNovamente() {
        val p = montarPreferencias(
            EstadoPreferenciasChamada(carregando = false, carregou = false, erro = TextosChamadaProfissional.ERRO, pausadoAte = LocalDate.of(2026, 11, 17)),
        )
        rule.onNodeWithText(TextosChamadaProfissional.ERRO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.TENTAR_NOVAMENTE).performClick()
        assertEquals(1, p.novamente)
    }

    // --- Chamada recebida ------------------------------------------------------------------------

    private class Recebida {
        var aceitou = 0
        var abriuRecusa = 0
        var fechouRecusa = 0
        var confirmouRecusa = 0
        var motivo: String? = "nenhum"
        var turno: String? = null
        var novamente = 0
        var voltou = 0
    }

    private fun montarRecebida(
        tela: EstadoChamadaRecebida,
        r: Recebida = Recebida(),
        seguranca: (@androidx.compose.runtime.Composable (br.com.frila.core.rede.PerfilPublicoDto) -> Unit)? = null,
    ): Recebida {
        rule.setContent {
            FrilaTheme {
                ConteudoDaChamadaRecebida(
                    tela = tela,
                    aoTentarNovamente = { r.novamente++ },
                    aoAceitar = { r.aceitou++ },
                    aoAbrirRecusa = { r.abriuRecusa++ },
                    aoFecharRecusa = { r.fechouRecusa++ },
                    aoEscolherMotivo = { r.motivo = it },
                    aoConfirmarRecusa = { r.confirmouRecusa++ },
                    aoVoltar = { r.voltou++ },
                    aoAbrirTurno = { r.turno = it },
                    acoesDeSeguranca = seguranca,
                )
            }
        }
        return r
    }

    private fun recebida(ajuste: EstadoChamadaRecebida.() -> EstadoChamadaRecebida = { this }) =
        EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA, carregando = false, detalhe = detalhe()).ajuste()

    @Test
    fun recebidaMostraQuemChamouValorHorarioRegiaoRecadoInclusosPrazoEAvisoDeSeguranca() {
        montarRecebida(recebida())

        rule.onNodeWithText(TextosChamadaProfissional.RECEBIDA_TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText("Bistrô Aurora").assertIsDisplayed()
        rule.onNodeWithText("Garçom").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("R$ 180,00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("20/11/2026 às 19:00 até 23:00").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Plano Piloto • De 5 a 15 km").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Traga avental").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.REFEICAO_INCLUSA).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.AVISO_SEGURANCA).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("responder-ate").performScrollTo()
        rule.onNodeWithText("${TextosChamadaProfissional.RESPONDER_ATE} 09:00").assertExists()
    }

    @Test
    fun recebidaContaNovaMostraSeloEAviso() {
        montarRecebida(recebida { copy(detalhe = detalhe(contaNova = true)) })
        rule.onNodeWithText(TextosChamadaProfissional.CONTA_NOVA_BADGE).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.CONTA_NOVA_AVISO).assertIsDisplayed()
    }

    @Test
    fun recebidaSemRecadoEscondeASecaoDoRecado() {
        montarRecebida(recebida { copy(detalhe = detalhe(recado = null)) })
        rule.onNodeWithText(TextosChamadaProfissional.RECADO_DO_CONTRATANTE).assertDoesNotExist()
    }

    @Test
    fun recebidaAbertaTemAceitarERecusarQueDisparamACallbackCerta() {
        val r = montarRecebida(recebida())

        rule.onNodeWithTag("aceitar-chamada").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.onNodeWithTag("recusar-chamada").performClick()
        assertEquals(1, r.aceitou)
        assertEquals(1, r.abriuRecusa)
    }

    @Test
    fun recebidaEncerradaMostraOAvisoESemBotoesDeResposta() {
        montarRecebida(recebida { copy(mensagemDeConcorrencia = TextosChamadaProfissional.CHAMADA_EXPIRADA, detalhe = detalhe("expirada")) })

        rule.onNodeWithTag("aviso-concorrencia").assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.CHAMADA_EXPIRADA).assertIsDisplayed()
        rule.onNodeWithTag("aceitar-chamada").assertDoesNotExist()
        rule.onNodeWithTag("recusar-chamada").assertDoesNotExist()
    }

    @Test
    fun recebidaRespondendoDeixaOAceiteDesligadoNoLugar() {
        montarRecebida(recebida { copy(respondendo = true) })
        rule.onNodeWithTag("aceitar-chamada").assertIsNotEnabled()
        rule.onNodeWithTag("recusar-chamada").assertIsNotEnabled()
    }

    @Test
    fun recebidaAceitaMostraLocalResponsavelEVerTurno() {
        val r = montarRecebida(recebida { copy(resultado = resultado("aceita"), detalhe = detalhe("aceita")) })

        rule.onNodeWithTag("chamada-aceita").assertIsDisplayed()
        rule.onNodeWithText("SCS Quadra 2").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Ana").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("ver-turno-aceito").performClick()
        assertEquals(Fixtures.TURNO, r.turno)
    }

    @Test
    fun recebidaRecusadaMostraOAvisoSemPenalidadeEAindaDaLugarParaDenunciar() {
        var ofereceuSeguranca = false
        montarRecebida(
            recebida { copy(resultado = resultado("recusada"), detalhe = detalhe("recusada")) },
            seguranca = { ofereceuSeguranca = true },
        )

        rule.onNodeWithTag("chamada-recusada").assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.CHAMADA_RECUSADA).assertIsDisplayed()
        assertTrue(ofereceuSeguranca)
    }

    @Test
    fun recebidaFolhaDeRecusaListaOsMotivosDoContratoEConfirma() {
        val r = montarRecebida(recebida { copy(mostrarRecusa = true) })

        rule.onNodeWithTag("motivos-recusa").assertIsDisplayed()
        listOf(
            TextosChamadaProfissional.MOTIVO_NENHUM,
            TextosChamadaProfissional.MOTIVO_AGENDA,
            TextosChamadaProfissional.MOTIVO_DISTANCIA,
            TextosChamadaProfissional.MOTIVO_VALOR,
            TextosChamadaProfissional.MOTIVO_TIPO_DE_SERVICO,
            TextosChamadaProfissional.MOTIVO_OUTRO,
        ).forEach { rule.onNodeWithText(it).assertExists() }
        rule.onNodeWithText(TextosChamadaProfissional.MOTIVO_AGENDA).performScrollTo().performClick()
        assertEquals("agenda", r.motivo)
        rule.onNodeWithTag("confirmar-recusa-chamada").performScrollTo().performClick()
        assertEquals(1, r.confirmouRecusa)
    }

    @Test
    fun recebidaCarregandoEFalhaMostramIndicadorETentarNovamente() {
        montarRecebida(EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA))
        rule.onNodeWithText(TextosChamadaProfissional.CARREGANDO).assertIsDisplayed()
    }

    @Test
    fun recebidaFalhaDeCargaMostraErroETentarNovamente() {
        val r = montarRecebida(EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA, carregando = false, erro = TextosChamadaProfissional.INDISPONIVEL))
        rule.onNodeWithText(TextosChamadaProfissional.INDISPONIVEL).assertIsDisplayed()
        rule.onNodeWithTag("tentar-novamente-chamada").performClick()
        assertEquals(1, r.novamente)
    }

    // --- Serviços -------------------------------------------------------------------------------

    private class Servicos {
        val edicoes = mutableListOf<String>()
        var salvou = 0
        var especialidade: Pair<String, Boolean>? = null
    }

    private val garcom = FuncaoDto(Fixtures.FUNCAO, "Garçom", "salao")

    private fun montarServicos(tela: EstadoEditarServicos, s: Servicos = Servicos()): Servicos {
        rule.setContent {
            FrilaTheme {
                ConteudoEditarServicos(
                    tela = tela,
                    aoEditar = { id, mudanca ->
                        val linha = tela.rascunhos.first { it.funcao.id == id }
                        val nova = mudanca(linha)
                        s.edicoes += "habilitado=${nova.habilitado};unidade=${nova.unidade};valor=${nova.valor}"
                    },
                    aoAlternarEspecialidade = { _, id, marcada -> s.especialidade = id to marcada },
                    aoSalvar = { s.salvou++ },
                    aoTentarNovamente = {},
                    aoVoltar = {},
                )
            }
        }
        return s
    }

    private fun servicos(linha: ServicoEmEdicao, ajuste: EstadoEditarServicos.() -> EstadoEditarServicos = { this }) =
        EstadoEditarServicos(
            carregando = false,
            carregou = true,
            rascunhos = listOf(linha),
            especialidades = mapOf(
                Fixtures.FUNCAO to listOf(EspecialidadeDto(Fixtures.ESPECIALIDADE, Fixtures.FUNCAO, "Eventos", true)),
            ),
        ).ajuste()

    @Test
    fun servicosMostraTituloExplicacaoELinhaDaFuncaoSemCamposQuandoDesmarcada() {
        montarServicos(servicos(ServicoEmEdicao(garcom)))

        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithTag("valor-servico-${Fixtures.FUNCAO}").assertDoesNotExist()
    }

    @Test
    fun servicosMarcarAFuncaoAvisaOViewModel() {
        val s = montarServicos(servicos(ServicoEmEdicao(garcom)))
        rule.onNodeWithTag("habilitar-${Fixtures.FUNCAO}").performClick()
        assertEquals(listOf("habilitado=true;unidade=a_combinar;valor="), s.edicoes)
    }

    @Test
    fun servicosHabilitadoMostraUnidadesValorFaixaMaterialIncluiEEspecialidades() {
        montarServicos(servicos(ServicoEmEdicao(garcom, habilitado = true, unidade = "hora", valor = "30")))

        rule.onNodeWithTag("valor-servico-${Fixtures.FUNCAO}").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("valor-maximo-${Fixtures.FUNCAO}").performScrollTo().assertExists()
        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_FAIXA_DE_VALOR).performScrollTo().assertExists()
        rule.onNodeWithTag("minimo-horas-${Fixtures.FUNCAO}").performScrollTo().assertExists()
        TextosChamadaProfissional.unidade("diaria").let { rule.onNodeWithText(it).performScrollTo().assertExists() }
        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_LEVA_MATERIAL).performScrollTo().assertExists()
        rule.onNodeWithTag("inclui-servico-${Fixtures.FUNCAO}").performScrollTo().assertExists()
        rule.onNodeWithText("Eventos").performScrollTo().assertExists()
        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_ESPECIALIDADES).performScrollTo().assertExists()
    }

    @Test
    fun servicosACombinarNaoPedeValor() {
        montarServicos(servicos(ServicoEmEdicao(garcom, habilitado = true, unidade = "a_combinar")))

        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_A_COMBINAR).performScrollTo().assertExists()
        rule.onNodeWithTag("valor-servico-${Fixtures.FUNCAO}").assertDoesNotExist()
    }

    @Test
    fun servicosDiariaMostraOResumoComValorEHoras() {
        montarServicos(servicos(ServicoEmEdicao(garcom, habilitado = true, unidade = "diaria", valor = "150", horasIncluidas = "8")))
        rule.onNodeWithText("R$ 150,00 por diária de 8 h").performScrollTo().assertExists()
    }

    @Test
    fun servicosDigitarNoValorAvisaOViewModel() {
        val s = montarServicos(servicos(ServicoEmEdicao(garcom, habilitado = true, unidade = "hora")))
        rule.onNodeWithTag("valor-servico-${Fixtures.FUNCAO}").performScrollTo().performTextInput("45")
        assertEquals("habilitado=true;unidade=hora;valor=45", s.edicoes.last())
    }

    @Test
    fun servicosErroDeCampoApareceNaLinhaDaFuncaoComTextoPropio() {
        montarServicos(
            servicos(ServicoEmEdicao(garcom, habilitado = true, unidade = "hora")) {
                copy(erro = TextosChamadaProfissional.campo("valor_centavos"), funcaoComErro = Fixtures.FUNCAO, campoComErro = "valor_centavos")
            },
        )
        rule.onNodeWithTag("erro-servico-valor_centavos").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun servicosSalvarSoComCargaProntaEMostraSucessoEErro() {
        val s = montarServicos(servicos(ServicoEmEdicao(garcom)) { copy(sucesso = true) })
        rule.onNodeWithTag("servicos-sucesso").assertIsDisplayed()
        rule.onNodeWithTag("salvar-servicos").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        assertEquals(1, s.salvou)
    }

    @Test
    fun servicosSalvandoDesabilitaOBotao() {
        montarServicos(servicos(ServicoEmEdicao(garcom)) { copy(salvando = true) })
        rule.onNodeWithTag("salvar-servicos").assertIsNotEnabled()
    }

    @Test
    fun servicosSemFuncoesExplicaEFalhaDeCargaOferecerTentarNovamente() {
        montarServicos(EstadoEditarServicos(carregando = false, carregou = true))
        rule.onNodeWithText(TextosChamadaProfissional.SERVICOS_SEM_FUNCOES).assertIsDisplayed()
    }

    @Test
    fun servicosFalhaDeCargaMostraErroETentarNovamente() {
        montarServicos(EstadoEditarServicos(carregando = false, carregou = false, erro = TextosChamadaProfissional.ERRO))
        rule.onNodeWithText(TextosChamadaProfissional.ERRO).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaProfissional.TENTAR_NOVAMENTE).assertIsDisplayed()
        rule.onNodeWithTag("salvar-servicos").assertIsNotEnabled()
    }
}
