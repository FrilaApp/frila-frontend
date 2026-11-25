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
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.notificacoes.RegistradorDeDispositivo
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import org.koin.core.context.GlobalContext

/** `FragmentActivity` (não `ComponentActivity`) porque `BiometricPrompt` exige um host com `FragmentManager` (RN15). */
class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
                var versaoMinima by remember { mutableStateOf<String?>(null) }
                var chamadaDireta by remember { mutableStateOf(false) }
                var buscaProfissionais by remember { mutableStateOf(false) }
                var checkinPorCodigo by remember { mutableStateOf(false) }
                var mensagemBloqueio by remember { mutableStateOf(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO) }
                var perfilRico by remember { mutableStateOf(false) }
                var fotoDePerfil by remember { mutableStateOf(false) }

                LaunchedEffect(cliente) {
                    if (cliente != null) {
                        val cache = CacheDeConfiguracaoDoAppPreferencias(applicationContext)
                        fun aplicar(configuracao: ConfiguracaoDoAppDto) {
                            versaoMinima = configuracao.versaoMinima
                            chamadaDireta = configuracao.recursos.chamadaDireta
                            buscaProfissionais = configuracao.recursos.buscaProfissionais
                            checkinPorCodigo = configuracao.recursos.checkinPorCodigo
                            configuracao.mensagem?.takeIf { it.isNotBlank() }?.let { mensagemBloqueio = it }
                            perfilRico = configuracao.recursos.perfilRico
                            fotoDePerfil = configuracao.recursos.fotoDePerfil
                        }
                        // #795: a primeira tela não fica presa à chamada. Abre na hora com a última configuração guardada para esta
                        // versão do app ou, sem ela, depois de TEMPO_MAXIMO_ABERTURA_MS; a resposta, quando chega, vale do mesmo jeito.
                        val abertura = launch {
                            val guardada = lerConfiguracaoGuardada(cache, BuildConfig.VERSION_NAME)
                            if (guardada != null) aplicar(guardada) else delay(TEMPO_MAXIMO_ABERTURA_MS)
                            verificando = false
                        }
                        try {
                            // 10 s; se estourar ou falhar, vale a última configuração guardada para esta versão do app.
                            val configuracao = obterConfiguracaoDoApp(
                                cache = cache,
                                versaoApp = BuildConfig.VERSION_NAME,
                            ) { consultarConfiguracaoDoApp(cliente) }
                            abertura.cancel() // a resposta chegou: a guardada não pode mais sobrescrevê-la
                            if (configuracao != null) aplicar(configuracao)
                        } catch (_: Exception) {
                            // Falha transitória de rede ou offline nunca bloqueia o acesso
                        } finally {
                            abertura.cancel()
                            verificando = false
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
                            checkinPorCodigoHabilitado = checkinPorCodigo,
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
