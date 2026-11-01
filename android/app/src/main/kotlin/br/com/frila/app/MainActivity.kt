package br.com.frila.app

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
                AppNavegacao(
                    aoPronto = {
                        MedidorDeColdStart.marcarInterfacePronta(this@MainActivity)
                    },
                )
            }
        }
        // Observa o primeiro quadro real via doOnPreDraw (TTID), em vez de agendamento arbitrário na fila de mensagens (decorView.post)
        window.decorView.doOnPreDraw {
            MedidorDeColdStart.marcarPrimeiroQuadro()
        }
    }
}
