package br.com.frila.app

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.fragment.app.FragmentActivity
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.perfil.AutenticadorBiometrico
import br.com.frila.feature.perfil.DisponibilidadeBiometrica
import org.koin.compose.koinInject

/**
 * Gate real de desbloqueio de sessão (RN15) quando `isBiometriaAtivada()` está ligada
 * ([rotaInicial]/[Rotas.DESBLOQUEIO]). Sucesso navega ao feed sem tocar na sessão; falha ou
 * "Entrar com outra conta" chama [ArmazenamentoDeSessao.limparSessao] e volta para a entrada —
 * nunca deixa a sessão anterior acessível sem confirmação biométrica válida.
 */
@Composable
fun TelaDesbloqueioBiometrico(
    aoDesbloquear: () -> Unit,
    aoEntrarComOutraConta: () -> Unit,
    armazenamentoDeSessao: ArmazenamentoDeSessao = koinInject(),
    /** Injetáveis para teste — mesmo motivo documentado em `TelaPerfil`: sem sensor físico/emulador
     * e sem um host `FragmentActivity` no `createComposeRule()`. */
    verificarDisponibilidadeBiometrica: (Context) -> DisponibilidadeBiometrica = AutenticadorBiometrico::verificarDisponibilidade,
    autenticarBiometria: (Context, aoSucesso: () -> Unit, aoErro: (String) -> Unit) -> Unit = { ctx, aoSucesso, aoErro ->
        val activity = ctx as? FragmentActivity
        if (activity != null) {
            AutenticadorBiometrico.autenticar(activity, aoSucesso, aoErro)
        } else {
            aoErro("Não foi possível abrir a autenticação biométrica.")
        }
    },
) {
    val contexto = LocalContext.current
    val disponibilidade = remember { verificarDisponibilidadeBiometrica(contexto) }
    var mensagemErro by remember { mutableStateOf<String?>(null) }

    fun autenticar() {
        mensagemErro = null
        autenticarBiometria(contexto, aoDesbloquear) { erro -> mensagemErro = erro }
    }

    fun entrarComOutraConta() {
        armazenamentoDeSessao.limparSessao()
        aoEntrarComOutraConta()
    }

    // Dispara o prompt sozinho na montagem só quando há hardware disponível — sem hardware, não
    // há o que tentar automaticamente, e a tela já parte para a saída manual.
    LaunchedEffect(Unit) {
        if (disponibilidade == DisponibilidadeBiometrica.DISPONIVEL) {
            autenticar()
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        Text(text = "Confirme sua identidade para continuar")

        if (disponibilidade != DisponibilidadeBiometrica.DISPONIVEL) {
            Text(text = "Desbloqueio rápido indisponível neste aparelho agora.")
        } else if (mensagemErro != null) {
            Text(text = mensagemErro!!)
        }

        if (disponibilidade == DisponibilidadeBiometrica.DISPONIVEL) {
            BotaoPrimario(
                texto = "Desbloquear",
                aoClicar = ::autenticar,
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            )
        }

        BotaoSecundario(
            texto = "Entrar com outra conta",
            aoClicar = ::entrarComOutraConta,
            modifier = Modifier.padding(top = FrilaEspacamento.minimo),
        )
    }
}
