package br.com.frila.feature.equipe.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Liga o [TenhoUmConviteViewModel] ao [ConteudoTenhoUmConvite]. */
@Composable
fun TelaTenhoUmConvite(
    viewModel: TenhoUmConviteViewModel,
    aoVoltar: () -> Unit,
    aoAbrirCasa: (estabelecimentoId: String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    ConteudoTenhoUmConvite(
        estado = estado,
        aoEditar = viewModel::editar,
        aoAceitar = { viewModel.aceitarConvite() },
        aoVoltar = aoVoltar,
        aoAbrirCasa = aoAbrirCasa,
        modifier = modifier,
    )
}

/**
 * "Tenho um convite": UMA frase explica o colar ("Cole aqui o link do convite que você recebeu."), um campo recebe o
 * link inteiro ou só o código, e o botão aceita. A recusa do servidor fica junto do botão. Aceito, a tela vira a
 * confirmação com um só caminho adiante, "Abrir a casa".
 */
@Composable
fun ConteudoTenhoUmConvite(
    estado: EstadoTenhoUmConvite,
    aoEditar: (String) -> Unit,
    aoAceitar: () -> Unit,
    aoVoltar: () -> Unit,
    aoAbrirCasa: (estabelecimentoId: String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val aceito = estado.aceito
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { if (aceito == null) FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                if (aceito != null) {
                    BotaoPrimario(
                        texto = TextosEquipeDaCasa.CONVITE_ABRIR_CASA,
                        aoClicar = { aoAbrirCasa(aceito.estabelecimentoId) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    estado.erro?.let { MensagemJuntoAoBotao(it) }
                    BotaoPrimario(
                        texto = if (estado.enviando) TextosEquipeDaCasa.CONVITE_ACEITANDO else TextosEquipeDaCasa.CONVITE_ACEITAR,
                        aoClicar = aoAceitar,
                        habilitado = !estado.enviando && estado.texto.isNotBlank(),
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
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            if (aceito != null) {
                TituloDaTela(TextosEquipeDaCasa.CONVITE_ACEITO_TITULO)
                AvisoFrila(
                    tom = TomAviso.SUCESSO,
                    mensagem = aceito.papel?.let { TextosEquipeDaCasa.CONVITE_ACEITO.format(rotuloDoPapel(it).lowercase()) }
                        ?: TextosEquipeDaCasa.CONVITE_ACEITO_SEM_PAPEL,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
            } else {
                TituloDaTela(TextosEquipeDaCasa.CONVITE_TITULO)
                Text(text = TextosEquipeDaCasa.CONVITE_EXPLICACAO, style = FrilaTipo.corpo, color = cores.tintaSuave)
                CampoDeTexto(
                    valor = estado.texto,
                    aoMudar = aoEditar,
                    rotulo = TextosEquipeDaCasa.CONVITE_CAMPO,
                    habilitado = !estado.enviando,
                    umaLinha = false,
                    linhasMinimas = 3,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                )
            }
        }
    }
}
