package br.com.frila.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.view.doOnPreDraw
import androidx.fragment.app.FragmentActivity
import br.com.frila.app.desempenho.MedidorDeColdStart
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.notificacoes.RegistradorDeDispositivo
import kotlin.coroutines.cancellation.CancellationException
import org.koin.core.context.GlobalContext

/** `FragmentActivity` (não `ComponentActivity`) porque `BiometricPrompt` exige um host com `FragmentManager` (RN15). */
class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            FrilaTheme {
                val cliente = remember {
                    try {
                        GlobalContext.getOrNull()?.getOrNull<ClienteSupabase>()
                    } catch (_: Exception) {
                        null
                    }
                }
                var verificando by remember { mutableStateOf(cliente != null) }
                var versaoMinima by remember { mutableStateOf<String?>(null) }
                var chamadaDireta by remember { mutableStateOf(false) }
                var buscaProfissionais by remember { mutableStateOf(false) }
                var perfilRico by remember { mutableStateOf(false) }
                var fotoDePerfil by remember { mutableStateOf(false) }
                var mensagemBloqueio by remember { mutableStateOf(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO) }

                LaunchedEffect(cliente) {
                    if (cliente != null) {
                        try {
                            // 10 s; se estourar ou falhar, vale a última configuração guardada para esta versão do app.
                            val configuracao = obterConfiguracaoDoApp(
                                cache = CacheDeConfiguracaoDoAppPreferencias(applicationContext),
                                versaoApp = BuildConfig.VERSION_NAME,
                            ) { consultarConfiguracaoDoApp(cliente) }
                            if (configuracao != null) {
                                versaoMinima = configuracao.versaoMinima
                                chamadaDireta = configuracao.recursos.chamadaDireta
                                buscaProfissionais = configuracao.recursos.buscaProfissionais
                                perfilRico = configuracao.recursos.perfilRico
                                fotoDePerfil = configuracao.recursos.fotoDePerfil
                                configuracao.mensagem?.takeIf { it.isNotBlank() }?.let { mensagemBloqueio = it }
                            }
                        } catch (_: Exception) {
                            // Falha transitória de rede ou offline nunca bloqueia o acesso
                        } finally {
                            verificando = false
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

                PortaoDeAtualizacao(
                    versaoAtual = BuildConfig.VERSION_NAME,
                    versaoMinima = versaoMinima,
                    verificando = verificando,
                    mensagem = mensagemBloqueio,
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
                        perfilRicoHabilitado = perfilRico,
                        fotoDePerfilHabilitada = fotoDePerfil,
                        chamadaDiretaHabilitada = chamadaDireta,
                        buscaProfissionaisHabilitada = buscaProfissionais,
                        aoPronto = {
                            MedidorDeColdStart.marcarInterfacePronta(this@MainActivity)
                        },
                    )
                }
            }
        }
        // Observa o primeiro quadro real via doOnPreDraw (TTID), em vez de agendamento arbitrário na fila de mensagens (decorView.post)
        window.decorView.doOnPreDraw {
            MedidorDeColdStart.marcarPrimeiroQuadro()
        }
    }
}
