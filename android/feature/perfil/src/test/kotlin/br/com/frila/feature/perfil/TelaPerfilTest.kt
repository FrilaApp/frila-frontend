package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaPerfilTest {

    @get:Rule
    val rule = createComposeRule()

    private val perfilJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "usuario_id": "22222222-2222-2222-2222-222222222222",
          "funcoes": [{"id": "f1", "nome": "Garçom", "categoria": "Salão"}],
          "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
          "disponibilidades": [],
          "reputacao": {
            "positivas": 7, "total": 7, "taxa_comparecimento": 0.95,
            "turnos_considerados": 8, "turnos_realizados": 8
          }
        }
    """.trimIndent()

    private fun criarViewModel(
        respostaJson: String = perfilJson,
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
        armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true),
        respostaTurnosJson: String = "[]",
        comprimirFoto: (android.content.Context, android.net.Uri) -> java.io.File = { _, _ ->
            throw IllegalStateException("comprimirFoto não configurado neste teste")
        },
        obterAvatarSalvo: (android.content.Context) -> java.io.File? = { null },
        preferenciasNotificacao: br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacao =
            br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoEmMemoria(),
    ): PerfilViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = statusHttp,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val clienteTurnos = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaTurnosJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return PerfilViewModel(
            servicoPerfil = ServicoPerfil(cliente),
            servicoTurnos = ServicoTurnos(clienteTurnos),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
            comprimirFoto = comprimirFoto,
            obterAvatarSalvo = obterAvatarSalvo,
            preferenciasNotificacao = preferenciasNotificacao,
        )
    }

    private fun turnoJson(id: String, estado: String, valorAcordadoCentavos: Long) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "garçom",
            "local": "SQN 108",
            "regiao_administrativa": "Asa Norte",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": $valorAcordadoCentavos
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": null,
          "checkin_em": null,
          "checkin_tipo": null,
          "checkin_distancia_m": null,
          "checkin_confirmado_em": null,
          "checkout_em": null,
          "checkout_distancia_m": null,
          "verificacao": "pendente",
          "valor_acordado_centavos": $valorAcordadoCentavos,
          "pode_avaliar": false,
          "estado": "$estado",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    @Test
    fun titulosPossuemSemanticaDeCabecalho() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Meu Perfil").assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            rule.onNodeWithText("Reputação").assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            rule.onNodeWithText("Funções cadastradas").performScrollTo().assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        }
    }

    @Test
    fun filterChipsDeEspecialidadesPossuemAlvoMinimoEStateDescription() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            val chip = rule.onNodeWithText("Coquetelaria clássica")
            chip.performScrollTo().assertIsDisplayed()

            chip.assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

            // Inicialmente não selecionada via stateDescription
            chip.assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionada"))

            // Ao clicar, transiciona para selecionada
            chip.performClick()
            rule.waitForIdle()

            chip.assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionada"))
        }
    }

    @Test
    fun erroDeCarregamentoExibeMensagemComLiveRegionAssertive() {
        runBlocking {
            val viewModel = criarViewModel(
                respostaJson = """{"code":"nao_encontrado","message":"perfil nao existe"}""",
                statusHttp = HttpStatusCode.NotFound,
            )
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Assertive),
                useUnmergedTree = true,
            ).assertIsDisplayed()

            rule.onNodeWithText("Tentar novamente")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        }
    }

    @Test
    fun blocoDeRemuneracoesExibeValoresFormatadosComSemanticaDeCabecalho() {
        runBlocking {
            val turnosJson = "[" + listOf(
                turnoJson(id = "a", estado = "cumprida", valorAcordadoCentavos = 128_000L),
                turnoJson(id = "b", estado = "confirmada", valorAcordadoCentavos = 32_000L),
                turnoJson(id = "c", estado = "cancelada", valorAcordadoCentavos = 999_999L),
            ).joinToString(",") + "]"
            val viewModel = criarViewModel(respostaTurnosJson = turnosJson)
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Remunerações acordadas").performScrollTo().assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
            rule.onNodeWithText("Valores combinados diretamente com os estabelecimentos (RN09)")
                .performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Concluído: ${Dinheiro(128_000L).formatado()} (1 turnos cumpridos)")
                .performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Pendente: ${Dinheiro(32_000L).formatado()} (1 turnos agendados)")
                .performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Total acumulado: ${Dinheiro(160_000L).formatado()}")
                .performScrollTo().assertIsDisplayed()
        }
    }

    @Test
    fun blocoDeRemuneracoesSemHistoricoExibeTextoNeutroSemZerosArtificiais() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Remunerações acordadas").performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Nenhum turno realizado ou agendado ainda").performScrollTo().assertIsDisplayed()
            assertTrue(rule.onAllNodesWithText("Exportar extrato em PDF").fetchSemanticsNodes().isEmpty())
        }
    }

    @Test
    fun botaoExportarExtratoApareceComAlvoMinimoQuandoHaHistorico() {
        runBlocking {
            val turnosJson = "[${turnoJson(id = "a", estado = "cumprida", valorAcordadoCentavos = 16_000L)}]"
            val viewModel = criarViewModel(respostaTurnosJson = turnosJson)
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Exportar extrato em PDF")
                .performScrollTo()
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        }
    }

    @Test
    fun avatarSemFotoMostraPlaceholderEBotaoComAlvoMinimo() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithContentDescription("Sem foto de perfil cadastrada").assertIsDisplayed()

            rule.onNodeWithText("Alterar foto de perfil")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        }
    }

    @Test
    fun selecionarFotoComSucessoTrocaPlaceholderPelaImagemDoAvatar() {
        runBlocking {
            val arquivoAvatar = kotlin.io.path.createTempFile(prefix = "avatar", suffix = ".jpg").toFile()
            android.graphics.Bitmap.createBitmap(10, 10, android.graphics.Bitmap.Config.ARGB_8888)
                .compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, arquivoAvatar.outputStream())

            val viewModel = criarViewModel(comprimirFoto = { _, _ -> arquivoAvatar })
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            viewModel.selecionarFoto(mockk(relaxed = true), mockk(relaxed = true)).join()
            rule.waitForIdle()

            rule.onNodeWithContentDescription("Foto de perfil do profissional").assertIsDisplayed()
            assertTrue(rule.onAllNodesWithContentDescription("Sem foto de perfil cadastrada").fetchSemanticsNodes().isEmpty())
        }
    }

    @Test
    fun falhaAoSelecionarFotoMostraMensagemDeErroEMantemPlaceholder() {
        runBlocking {
            val viewModel = criarViewModel(
                comprimirFoto = { _, _ -> throw IllegalStateException("Não foi possível decodificar a imagem selecionada.") },
            )
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            viewModel.selecionarFoto(mockk(relaxed = true), mockk(relaxed = true)).join()
            rule.waitForIdle()

            rule.onNodeWithText("Não foi possível processar a foto. Tente outra imagem.").assertIsDisplayed()
            rule.onNodeWithContentDescription("Sem foto de perfil cadastrada").assertIsDisplayed()
        }
    }

    @Test
    fun avatarSalvoEmDiscoApareceAoAbrirATelaSemPrecisarSelecionarDeNovo() {
        runBlocking {
            val arquivoAvatar = kotlin.io.path.createTempFile(prefix = "avatar", suffix = ".jpg").toFile()
            android.graphics.Bitmap.createBitmap(10, 10, android.graphics.Bitmap.Config.ARGB_8888)
                .compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, arquivoAvatar.outputStream())

            // MEDIDO (Shisui, PR #590): o bug era o avatar desaparecer ao reabrir a tela porque
            // nada lia o filesDir na montagem. Aqui obterAvatarSalvo simula um avatar já
            // persistido de uma sessão anterior — selecionarFoto nunca é chamado.
            val viewModel = criarViewModel(obterAvatarSalvo = { arquivoAvatar })
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            rule.onNodeWithContentDescription("Foto de perfil do profissional").assertIsDisplayed()
            assertTrue(rule.onAllNodesWithContentDescription("Sem foto de perfil cadastrada").fetchSemanticsNodes().isEmpty())
        }
    }

    @Test
    fun toggleDeBiometriaDesabilitadoQuandoAparelhoNaoTemBiometriaDisponivel() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.SEM_HARDWARE },
                    )
                }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").performScrollTo()
                .assertIsDisplayed()
                .assertIsOff()
            rule.onNodeWithText("Este aparelho não tem biometria disponível.").performScrollTo().assertIsDisplayed()
        }
    }

    @Test
    fun ativarBiometriaDisponivelExigeAutenticacaoAntesDeMarcarOToggle() {
        runBlocking {
            val armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)
            val viewModel = criarViewModel(armazenamento = armazenamento)
            viewModel.carregar().join()
            var sucessoChamado: (() -> Unit)? = null

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.DISPONIVEL },
                        autenticarBiometria = { _, aoSucesso, _ -> sucessoChamado = aoSucesso },
                    )
                }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").performScrollTo().assertIsOff()
            rule.onNodeWithTag("toggle-biometria").performClick()
            rule.waitForIdle()

            // Confirmação biométrica ainda não respondeu — o toggle não liga por conta própria.
            rule.onNodeWithTag("toggle-biometria").assertIsOff()

            sucessoChamado?.invoke()
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").assertIsOn()
        }
    }

    @Test
    fun falhaNaAutenticacaoBiometricaMostraErroEMantemToggleDesligado() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.DISPONIVEL },
                        autenticarBiometria = { _, _, aoErro -> aoErro("Autenticação cancelada") },
                    )
                }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").performScrollTo().performClick()
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").assertIsOff()
            rule.onNodeWithText("Autenticação cancelada").performScrollTo().assertIsDisplayed()
        }
    }

    @Test
    fun desativarBiometriaNaoExigeAutenticacao() {
        runBlocking {
            val armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)
            every { armazenamento.isBiometriaAtivada() } returns true
            val viewModel = criarViewModel(armazenamento = armazenamento)
            viewModel.carregar().join()
            var autenticarFoiChamado = false

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.DISPONIVEL },
                        autenticarBiometria = { _, _, _ -> autenticarFoiChamado = true },
                    )
                }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").performScrollTo().assertIsOn()
            rule.onNodeWithTag("toggle-biometria").performClick()
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").assertIsOff()
            assertFalse(autenticarFoiChamado)
            verify(exactly = 1) { armazenamento.definirBiometriaAtivada(false) }
        }
    }

    @Test
    fun toggleAtivadoComHardwareIndisponivelPodeSerDesligado() {
        runBlocking {
            // MEDIDO (Shisui, PR #591): se o usuário ativou a biometria e depois o sensor ficou
            // indisponível (ou removeu o PIN), o switch não pode ficar ON e travado — ele tem que
            // poder desligar sempre, mesmo sem hardware disponível.
            val armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true)
            every { armazenamento.isBiometriaAtivada() } returns true
            val viewModel = criarViewModel(armazenamento = armazenamento)
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.HARDWARE_INDISPONIVEL },
                    )
                }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").performScrollTo().assertIsEnabled().assertIsOn()
            rule.onNodeWithTag("toggle-biometria").performClick()
            rule.waitForIdle()

            rule.onNodeWithTag("toggle-biometria").assertIsOff()
            verify(exactly = 1) { armazenamento.definirBiometriaAtivada(false) }
        }
    }

    @Test
    fun switchesDeNotificacaoRenderizamEAtualizamAPreferencia() {
        runBlocking {
            val preferencias = br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoEmMemoria()
            val viewModel = criarViewModel(preferenciasNotificacao = preferencias)
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = viewModel, aoDeslogar = {})
                }
            }
            rule.waitForIdle()

            val linhaUrgencia = rule.onNodeWithTag("toggle-notificacao-canal_urgencia").performScrollTo()
            linhaUrgencia.assert(
                androidx.compose.ui.test.SemanticsMatcher.expectValue(
                    androidx.compose.ui.semantics.SemanticsProperties.StateDescription,
                    "ativado",
                ),
            )

            linhaUrgencia.performClick()
            rule.waitForIdle()

            assertFalse(
                preferencias.estaAtivado(br.com.frila.core.notificacoes.GerenciadorDeCanais.CANAL_URGENCIA),
            )
            linhaUrgencia.assert(
                androidx.compose.ui.test.SemanticsMatcher.expectValue(
                    androidx.compose.ui.semantics.SemanticsProperties.StateDescription,
                    "desativado",
                ),
            )
        }
    }

    @Test
    fun blocoDeNotificacoesMostraStatusAtivadoQuandoPermissaoDoSistemaConcedida() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificarNotificacoesDoSistema = { true },
                    )
                }
            }
            rule.waitForIdle()

            val statusNode = rule.onNodeWithTag("status-notificacoes-sistema").performScrollTo()
            statusNode.assertIsDisplayed()
            rule.onNodeWithText("Ativadas").assertIsDisplayed()
            rule.onNodeWithTag("aviso-notificacoes-desativadas-sistema").assertDoesNotExist()
        }
    }

    @Test
    fun blocoDeNotificacoesMostraStatusDesativadoEAvisoQuandoPermissaoDoSistemaNegada() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificarNotificacoesDoSistema = { false },
                    )
                }
            }
            rule.waitForIdle()

            val statusNode = rule.onNodeWithTag("status-notificacoes-sistema").performScrollTo()
            statusNode.assertIsDisplayed()
            rule.onNodeWithText("Desativadas").assertIsDisplayed()
            rule.onNodeWithTag("aviso-notificacoes-desativadas-sistema").performScrollTo().assertIsDisplayed()
            rule.onNodeWithText("Configurações de notificação do sistema").performScrollTo().assertIsDisplayed()
        }
    }

    @Test
    fun lincePerfilAtualizaPermissaoQuandoRetornaDasConfiguracoes() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()
            val app = org.robolectric.RuntimeEnvironment.getApplication()
            val manager = app.getSystemService(android.app.NotificationManager::class.java)
            val sombra = org.robolectric.Shadows.shadowOf(manager)
            sombra.setNotificationsEnabled(false)
            val dono = object : androidx.lifecycle.LifecycleOwner {
                val registro = androidx.lifecycle.LifecycleRegistry(this)
                override val lifecycle: androidx.lifecycle.Lifecycle get() = registro
            }
            rule.runOnIdle { dono.registro.currentState = androidx.lifecycle.Lifecycle.State.RESUMED }
            rule.setContent {
                androidx.compose.runtime.CompositionLocalProvider(
                    androidx.lifecycle.compose.LocalLifecycleOwner provides dono,
                ) { FrilaTheme { TelaPerfil(viewModel = vm, aoDeslogar = {}) } }
            }
            rule.waitForIdle()
            rule.onNodeWithText("Desativadas").performScrollTo().assertIsDisplayed()
            rule.runOnIdle {
                dono.registro.currentState = androidx.lifecycle.Lifecycle.State.CREATED
                sombra.setNotificationsEnabled(true)
                dono.registro.currentState = androidx.lifecycle.Lifecycle.State.RESUMED
            }
            rule.waitForIdle()
            assertTrue(androidx.core.app.NotificationManagerCompat.from(app).areNotificationsEnabled())
            rule.onNodeWithText("Ativadas").assertExists()
            rule.onNodeWithTag("aviso-notificacoes-desativadas-sistema").assertDoesNotExist()
        }
    }

    @Test
    fun excluirContaComRotaDedicadaNavegaEMantemODialogoFechado() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()
            var navegou = 0

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(viewModel = vm, aoAbrirExclusaoDeConta = { navegou++ })
                }
            }
            rule.waitForIdle()

            rule.onNodeWithText("Excluir conta").performScrollTo().performClick()
            rule.waitForIdle()

            assertEquals(1, navegou)
            assertEquals(StatusExclusao.OCIOSO, vm.estado.value.statusExclusao)
            rule.onAllNodesWithText("Excluir conta definitivamente?").assertCountEquals(0)
        }
    }

    @Test
    fun excluirContaSemRotaDedicadaContinuaAbrindoODialogoDoPerfil() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()

            rule.setContent { FrilaTheme { TelaPerfil(viewModel = vm) } }
            rule.waitForIdle()

            rule.onNodeWithText("Excluir conta").performScrollTo().performClick()
            rule.waitForIdle()

            assertEquals(StatusExclusao.DIALOGO_ABERTO, vm.estado.value.statusExclusao)
            rule.onNodeWithText("Excluir conta definitivamente?").assertIsDisplayed()
        }
    }

    @Test
    fun atalhoDaEquipeDeConfiancaSoApareceQuandoOChamadorInformaOCallback() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()
            var aberta = 0

            rule.setContent {
                FrilaTheme { TelaPerfil(viewModel = vm, aoAbrirEquipe = { aberta++ }) }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("perfil-equipe").performScrollTo()
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .performClick()
            rule.waitForIdle()

            assertEquals(1, aberta)
        }
    }

    @Test
    fun semCallbackDaEquipeOAtalhoNaoExiste() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()

            rule.setContent { FrilaTheme { TelaPerfil(viewModel = vm) } }
            rule.waitForIdle()

            rule.onAllNodesWithTag("perfil-equipe").assertCountEquals(0)
        }
    }

    @Test
    fun atalhoDePublicarVagaSoApareceQuandoOChamadorInformaOCallback() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()
            var abertas = 0

            rule.setContent {
                FrilaTheme { TelaPerfil(viewModel = vm, aoPublicarVaga = { abertas++ }) }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("perfil-publicar-vaga").performScrollTo()
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .performClick()
            rule.waitForIdle()

            assertEquals(1, abertas)
            rule.onAllNodesWithTag("perfil-cadastrar-estabelecimento").assertCountEquals(0)
        }
    }

    @Test
    fun atalhoDeCadastrarEstabelecimentoSoApareceQuandoOChamadorInformaOCallback() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()
            var abertos = 0

            rule.setContent {
                FrilaTheme { TelaPerfil(viewModel = vm, aoCadastrarEstabelecimento = { abertos++ }) }
            }
            rule.waitForIdle()

            rule.onNodeWithTag("perfil-cadastrar-estabelecimento").performScrollTo()
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .performClick()
            rule.waitForIdle()

            assertEquals(1, abertos)
            rule.onAllNodesWithTag("perfil-publicar-vaga").assertCountEquals(0)
        }
    }

    @Test
    fun semCallbacksDeContratanteNenhumAtalhoExiste() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()

            rule.setContent { FrilaTheme { TelaPerfil(viewModel = vm) } }
            rule.waitForIdle()

            rule.onAllNodesWithTag("perfil-publicar-vaga").assertCountEquals(0)
            rule.onAllNodesWithTag("perfil-cadastrar-estabelecimento").assertCountEquals(0)
        }
    }

    @Test
    fun botaoAjudaEmBlocoDeContaAcionaCallback() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()
            var ajudaClicada = false

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = vm,
                        aoDeslogar = {},
                        aoAbrirAjuda = { ajudaClicada = true },
                    )
                }
            }
            rule.waitForIdle()

            val botaoAjuda = rule.onNodeWithTag("perfil-ajuda").performScrollTo()
            botaoAjuda.assertIsDisplayed()
            botaoAjuda.performClick()
            rule.waitForIdle()

            assertTrue(ajudaClicada)
        }
    }

    @Test
    fun iconeAjudaNaBarraSuperiorAcionaCallback() {
        runBlocking {
            val vm = criarViewModel()
            vm.carregar().join()
            var ajudaClicada = false

            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = vm,
                        aoDeslogar = {},
                        aoAbrirAjuda = { ajudaClicada = true },
                    )
                }
            }
            rule.waitForIdle()

            val iconeAjuda = rule.onNodeWithTag("botao-ajuda-barra")
            iconeAjuda.assertIsDisplayed()
            iconeAjuda.performClick()
            rule.waitForIdle()

            assertTrue(ajudaClicada)
        }
    }

    private fun mostrarPerfilComSelo(
        status: br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade?,
        podeSolicitar: Boolean = false,
        aoAbrirSelo: () -> Unit = {},
        recursoHabilitado: Boolean = true,
    ) {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()
            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        recursoSeloHabilitado = recursoHabilitado,
                        verificacaoIdentidade = status?.let {
                            br.com.frila.core.dominio.modelo.VerificacaoIdentidade(
                                status = it,
                                identidadeVerificada = it == br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade.APROVADA,
                            )
                        },
                        podeSolicitarSelo = podeSolicitar,
                        aoAbrirSelo = aoAbrirSelo,
                    )
                }
            }
            rule.waitForIdle()
        }
    }

    @Test
    fun seloAprovadoMostraBadgeDiscretoESemConvite() {
        mostrarPerfilComSelo(br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade.APROVADA)

        rule.onNodeWithTag("selo-identidade-verificada").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("Identidade Verificada").assertIsDisplayed()
        rule.onAllNodesWithTag("selo-obter").assertCountEquals(0)
    }

    @Test
    fun seloElegivelMostraConviteQueAbreOFluxo() {
        var abriu = false
        mostrarPerfilComSelo(
            br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade.NAO_EXIGIDA,
            podeSolicitar = true,
            aoAbrirSelo = { abriu = true },
        )

        rule.onNodeWithTag("selo-obter").performScrollTo().assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertTrue(abriu)
        rule.onAllNodesWithTag("selo-identidade-verificada").assertCountEquals(0)
    }

    @Test
    fun seloEmAnaliseMostraAvisoSemConviteNemBadge() {
        mostrarPerfilComSelo(br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade.EM_ANALISE)

        rule.onNodeWithTag("selo-em-analise").performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithTag("selo-obter").assertCountEquals(0)
        rule.onAllNodesWithTag("selo-identidade-verificada").assertCountEquals(0)
    }

    @Test
    fun recursoDesligadoEscondeOConviteMesmoComEstadoElegivel() {
        mostrarPerfilComSelo(
            br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade.NAO_EXIGIDA,
            podeSolicitar = true,
            recursoHabilitado = false,
        )

        rule.onAllNodesWithTag("selo-obter").assertCountEquals(0)
        rule.onAllNodesWithTag("selo-convite").assertCountEquals(0)
        rule.onNodeWithText("Reputação").assertIsDisplayed()
    }

    @Test
    fun recursoDesligadoEscondeOBadgeMesmoComSeloAprovado() {
        mostrarPerfilComSelo(
            br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade.APROVADA,
            recursoHabilitado = false,
        )

        rule.onAllNodesWithTag("selo-identidade-verificada").assertCountEquals(0)
        rule.onNodeWithText("Reputação").assertIsDisplayed()
    }

    @Test
    fun recursoDesligadoPorPadraoNaoMostraConviteNemBadge() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()
            rule.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        verificacaoIdentidade = br.com.frila.core.dominio.modelo.VerificacaoIdentidade(
                            status = br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade.APROVADA,
                            identidadeVerificada = true,
                        ),
                        podeSolicitarSelo = true,
                    )
                }
            }
            rule.waitForIdle()
        }

        rule.onAllNodesWithTag("selo-identidade-verificada").assertCountEquals(0)
        rule.onAllNodesWithTag("selo-obter").assertCountEquals(0)
    }

    @Test
    fun semEstadoDoSeloOPerfilNaoMostraNada() {
        mostrarPerfilComSelo(status = null)

        rule.onAllNodesWithTag("selo-obter").assertCountEquals(0)
        rule.onAllNodesWithTag("selo-identidade-verificada").assertCountEquals(0)
        rule.onAllNodesWithTag("selo-em-analise").assertCountEquals(0)
        rule.onNodeWithText("Reputação").assertIsDisplayed()
    }
}
