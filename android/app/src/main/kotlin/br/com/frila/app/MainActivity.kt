package br.com.frila.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.core.view.doOnPreDraw
import androidx.fragment.app.FragmentActivity
import br.com.frila.app.desempenho.MedidorDeColdStart
import br.com.frila.core.designsystem.tema.FrilaTheme

/** `FragmentActivity` (não `ComponentActivity`) porque `BiometricPrompt` exige um host com `FragmentManager` (RN15). */
class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            FrilaTheme {
                PortaoDeAtualizacao(
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
