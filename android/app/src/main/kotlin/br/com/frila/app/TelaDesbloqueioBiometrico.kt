package br.com.frila.app

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.fragment.app.FragmentActivity
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.perfil.AutenticadorBiometrico
import br.com.frila.feature.perfil.DisponibilidadeBiometrica
import org.koin.compose.koinInject

/**
 * Gate real de desbloqueio de sessão (RN15) quando `isBiometriaAtivada()` está ligada
 * ([rotaInicial]/[Rotas.DESBLOQUEIO], ou interceptado por [GuardaBiometrico] num deep link).
 * Sucesso chama [aoDesbloquear] sem tocar na sessão. Falha na autenticação NÃO chama
 * [aoDesbloquear] e mantém o botão "Desbloquear" para tentar de novo — a sessão continua
 * intacta, só não navega. Só "Entrar com outra conta" chama [ArmazenamentoDeSessao.limparSessao]
 * e devolve a navegação para a entrada: nunca deixa a sessão anterior acessível sem confirmação
 * biométrica válida, mas também nunca a descarta por uma falha isolada do sensor.
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

    val cores = FrilaTema.cores
    val disponivel = disponibilidade == DisponibilidadeBiometrica.DISPONIVEL

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            // Sem hardware não há o que desbloquear: sem rodapé, só a saída manual na tela.
            if (disponivel) {
                RodapeAncorado {
                    mensagemErro?.let { MensagemJuntoAoBotao(texto = it) }
                    BotaoPrimario(
                        texto = "Desbloquear",
                        aoClicar = ::autenticar,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.respiro,
                    bottom = FrilaEspacamento.grupo,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                TituloDaTela("Confirme sua identidade para continuar")
                if (!disponivel) {
                    Text(
                        text = "Desbloqueio rápido indisponível neste aparelho agora.",
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                }
            }

            // Sair da conta é ação discreta; sem o desbloqueio, é a única saída e vira o botão secundário.
            if (disponivel) {
                AcaoDiscreta(texto = "Entrar com outra conta", aoClicar = ::entrarComOutraConta)
            } else {
                BotaoSecundario(
                    texto = "Entrar com outra conta",
                    aoClicar = ::entrarComOutraConta,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
