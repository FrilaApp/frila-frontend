package br.com.frila.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.view.doOnPreDraw
import androidx.fragment.app.FragmentActivity
import br.com.frila.app.desempenho.MedidorDeColdStart
import br.com.frila.core.designsystem.abertura.AberturaAnimada
import br.com.frila.core.designsystem.abertura.aquecerAberturaAnimada
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.SegurancaOAuthSocial
import br.com.frila.core.notificacoes.CaixaDoAvisoDoToque
import br.com.frila.core.notificacoes.RegistradorDeDispositivo
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import org.koin.core.context.GlobalContext

internal fun extrairCallbackOAuthSocialDoIntent(
    intent: Intent?,
    permitirCustomSchemeDev: Boolean = BuildConfig.DEBUG,
): String? {
    if (intent?.action != Intent.ACTION_VIEW) return null
    val uri = intent.dataString ?: return null
    return uri.takeIf {
        SegurancaOAuthSocial.ehCallbackOAuthSocial(it, permitirCustomSchemeDev = permitirCustomSchemeDev)
    }
}

/** `FragmentActivity` (não `ComponentActivity`) porque `BiometricPrompt` exige um host com `FragmentManager` (RN15). */
class MainActivity : FragmentActivity() {
    private val callbackOAuthSocial = MutableStateFlow<String?>(null)

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extrairCallbackOAuthSocialDoIntent(intent)?.let { callbackOAuthSocial.value = it }
    }

    private fun abrirNavegadorLoginSocial(url: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
        }
        runCatching { startActivity(intent) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extrairCallbackOAuthSocialDoIntent(intent)?.let { callbackOAuthSocial.value = it }
        // O app desenha de borda a borda em todas as versões (no Android 15+ já é obrigatório): as telas recuam para as
        // barras do sistema e o rodapé ancorado sobe com o teclado. Sem isto, no Android 14 ou menos o teclado cobria o botão.
        enableEdgeToEdge()
        // A abertura animada toca só na abertura a frio do processo (ver PoliticaDaAbertura) e cobre o app SEM segurá-lo:
        // a configuração do app, o registro do push e a primeira tela carregam por baixo desde o primeiro quadro.
        val inicioDaActivity = SystemClock.elapsedRealtime()
        val tocarAbertura = PoliticaDaAbertura().deveTocar(intent, primeiraCriacao = savedInstanceState == null)
        val tempoCongelado = PoliticaDaAbertura.tempoCongelado(intent, BuildConfig.DEBUG)
        val aberturaCobrindo = AtomicBoolean(tocarAbertura)
        if (tocarAbertura) aquecerAberturaAnimada()
        val preferenciasAparencia = GlobalContext.getOrNull()?.getOrNull<PreferenciasAparencia>()
        val avisosDoToque = CaixaDoAvisoDoToque.link.map(::avisoDoLink).stateIn(lifecycleScope, SharingStarted.Eagerly, null)
        setContent {
            TemaDoAparelho(preferenciasAparencia?.temaEscuro ?: remember { flowOf(false) }) {
                val cliente = remember {
                    try {
                        GlobalContext.getOrNull()?.getOrNull<ClienteSupabase>()
                    } catch (_: Exception) {
                        null
                    }
                }
                var verificando by remember { mutableStateOf(cliente != null) }
                var estadoConfig by remember { mutableStateOf(EstadoDaConfiguracaoDoApp()) }

                LaunchedEffect(cliente) {
                    if (cliente != null) {
                        val cache = CacheDeConfiguracaoDoAppPreferencias(applicationContext)
                        try {
                            carregarConfiguracaoNaAbertura(
                                cache = cache,
                                versaoApp = BuildConfig.VERSION_NAME,
                                aoAplicar = { estadoConfig = it },
                                aoLiberarAbertura = { verificando = false },
                            ) { consultarConfiguracaoDoApp(cliente) }
                        } finally {
                            registrarAbertura("configuração do app resolvida", inicioDaActivity, aberturaCobrindo.get())
                        }
                    } else {
                        verificando = false
                    }
                }

                LaunchedEffect(Unit) {
                    // C0-10: ao abrir com sessão, registra o aparelho para o push (com versao_app), sem esperar. Sem sessão, o
                    // registrador não chama; sem token (sem Firebase ou sem rede), nada sai. Falha nunca trava a abertura.
                    try {
                        GlobalContext.getOrNull()?.getOrNull<RegistradorDeDispositivo>()?.registrarEmSegundoPlano()
                    } catch (cancelado: CancellationException) {
                        throw cancelado
                    } catch (_: Exception) {
                    }
                }

                AberturaAnimada(
                    ligada = tocarAbertura,
                    tempoCongelado = tempoCongelado,
                    aoTerminar = {
                        aberturaCobrindo.set(false)
                        registrarAbertura("abertura saiu de cena", inicioDaActivity, cobrindo = false)
                    },
                ) {
                    PortaoDeAtualizacao(
                        versaoAtual = BuildConfig.VERSION_NAME,
                        versaoMinima = estadoConfig.versaoMinima,
                        verificando = verificando,
                        mensagem = estadoConfig.mensagemBloqueio,
                        aoAtualizar = {
                            val uriLoja = Uri.parse("market://details?id=$packageName")
                            val intent = Intent(Intent.ACTION_VIEW, uriLoja).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            try {
                                startActivity(intent)
                            } catch (e: Exception) {
                                startActivity(
                                    Intent(
                                        Intent.ACTION_VIEW,
                                        Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
                                    ).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    },
                                )
                            }
                        },
                    ) {
                        AppNavegacao(
                            perfilRicoHabilitado = estadoConfig.perfilRico,
                            fotoDePerfilHabilitada = estadoConfig.fotoDePerfil,
                            chamadaDiretaHabilitada = estadoConfig.chamadaDireta,
                            buscaProfissionaisHabilitada = estadoConfig.buscaProfissionais,
                            checkinPorCodigoHabilitado = estadoConfig.checkinPorCodigo,
                            callbackOAuthSocial = callbackOAuthSocial,
                            aoConsumirCallbackOAuthSocial = { callbackOAuthSocial.value = null },
                            aoAbrirLoginSocial = { url -> abrirNavegadorLoginSocial(url) },
                            // O toque num push chega pela entrada não exportada, nunca pelo Intent desta activity.
                            avisoDoToque = avisosDoToque,
                            aoConsumirAvisoDoToque = CaixaDoAvisoDoToque::consumir,
                            aoPronto = {
                                MedidorDeColdStart.marcarInterfacePronta(this@MainActivity)
                                registrarAbertura("interface do app pronta", inicioDaActivity, aberturaCobrindo.get())
                            },
                        )
                    }
                }
            }
        }
        // Observa o primeiro quadro real via doOnPreDraw (TTID), em vez de agendamento arbitrário na fila de mensagens (decorView.post)
        window.decorView.doOnPreDraw {
            MedidorDeColdStart.marcarPrimeiroQuadro()
        }
    }
}
