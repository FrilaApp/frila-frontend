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
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.Json
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
                var versaoMinima by remember { mutableStateOf<String?>(null) }
                var mensagemBloqueio by remember { mutableStateOf(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO) }

                LaunchedEffect(cliente) {
                    if (cliente != null) {
                        try {
                            withTimeoutOrNull(3000L) {
                                val resposta = cliente.http.get("${cliente.baseUrl}/rpc/configuracao_do_app?plataforma=android")
                                if (resposta.status.isSuccess()) {
                                    val dto = Json { ignoreUnknownKeys = true }.decodeFromString<ConfiguracaoDoAppDto>(resposta.bodyAsText())
                                    versaoMinima = dto.versaoMinima
                                    dto.mensagem?.takeIf { it.isNotBlank() }?.let { mensagemBloqueio = it }
                                }
                            }
                        } catch (_: Exception) {
                            // Falha transitória de rede ou offline nunca bloqueia o acesso
                        }
                    }
                }

                PortaoDeAtualizacao(
                    versaoAtual = BuildConfig.VERSION_NAME,
                    versaoMinima = versaoMinima,
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
