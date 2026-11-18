package br.com.frila.feature.vagas.publicacao

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.time.Instant

// Peças deste formulário que o sistema de design ainda não tem. Quando subirem para `core/designsystem`, esta cópia sai.

/**
 * A barra de topo de uma tela de formulário: só o voltar, que pode ficar desligado enquanto o envio roda.
 * É a `FrilaBarraDeTopo` com `habilitado`, que o componente do sistema ainda não tem.
 */
@Composable
internal fun BarraDeTopoDoFormulario(
    aoVoltar: () -> Unit,
    rotuloDoVoltar: String,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    val cores = FrilaTema.cores
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(cores.fundo)
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .padding(horizontal = FrilaEspacamento.compacto),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = aoVoltar, enabled = habilitado, modifier = Modifier.size(FrilaMetricas.alvoMinimo)) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = rotuloDoVoltar,
                tint = if (habilitado) cores.tinta else cores.tintaSuave,
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

/**
 * Campo que abre uma escolha (folha) em vez de receber texto: o mesmo desenho do `CampoDeTexto` (rótulo
 * acima, caixa de 48dp, contorno `bordaControle`, raio 16), com a seta para baixo no fim. O rótulo e o valor
 * formam um alvo só para o leitor de tela (`rotulo` nulo: o rótulo vem de quem agrupa os campos; `descricao` troca a fala). O erro vem escrito embaixo, em tinta; sem erro, vem o apoio.
 */
@Composable
internal fun CampoDeSelecao(
    rotulo: String?,
    valor: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
    apoio: String? = null,
    erro: String? = null,
    descricao: String? = null,
) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.interno)
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = habilitado, role = Role.Button, onClick = aoClicar)
                .semantics {
                    if (erro != null) error(erro)
                    if (descricao != null) contentDescription = descricao
                },
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            if (rotulo != null) Text(text = rotulo, style = FrilaTipo.rotuloDeGrupo, color = cores.tintaSuave)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alturaCampo)
                    .background(cores.superficie, forma)
                    .border(width = if (erro != null) 2.dp else 1.dp, color = if (erro != null) cores.tinta else cores.bordaControle, shape = forma)
                    .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.compacto),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                Text(
                    text = valor,
                    style = FrilaTipo.corpo,
                    color = if (habilitado) cores.tinta else cores.tintaSuave,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = if (habilitado) cores.tinta else cores.tintaSuave,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
        if (erro != null) {
            Text(text = erro, style = FrilaTipo.apoio, color = cores.tinta)
        } else if (apoio != null) {
            Text(text = apoio, style = FrilaTipo.apoio, color = cores.tintaSuave)
        }
    }
}

/**
 * Data e hora de um instante, cada uma num campo que abre o seletor nativo do Material 3. O nome do instante
 * ("Início") fica acima dos dois campos; o erro vem escrito embaixo, em tinta. [rotuloData] e [rotuloHora] são
 * o que o leitor de tela fala ("Data do início: 10/11/2026").
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SeletorDeInstante(
    titulo: String,
    rotuloData: String,
    rotuloHora: String,
    instante: Instant,
    erro: String?,
    habilitado: Boolean,
    textoDeConfirmar: String,
    textoDeCancelar: String,
    aoMudar: (Instant) -> Unit,
) {
    var escolhendoData by rememberSaveable { mutableStateOf(false) }
    var escolhendoHora by rememberSaveable { mutableStateOf(false) }
    val data = formatarData(instante)
    val hora = formatarHora(instante)

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(titulo)
        val campoDaData: @Composable (Modifier) -> Unit = { modificador ->
            CampoDeSelecao(
                rotulo = null,
                valor = data,
                aoClicar = { escolhendoData = true },
                habilitado = habilitado,
                descricao = "$rotuloData: $data",
                modifier = modificador,
            )
        }
        val campoDaHora: @Composable (Modifier) -> Unit = { modificador ->
            CampoDeSelecao(
                rotulo = null,
                valor = hora,
                aoClicar = { escolhendoHora = true },
                habilitado = habilitado,
                descricao = "$rotuloHora: $hora",
                modifier = modificador,
            )
        }
        // Com a fonte do sistema grande (acima de 1,3×) a data não cabe em meia largura e quebraria no meio do número:
        // os dois campos passam a ficar um embaixo do outro.
        if (LocalDensity.current.fontScale <= 1.3f) {
            Row(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                campoDaData(Modifier.weight(1f))
                campoDaHora(Modifier.weight(1f))
            }
        } else {
            campoDaData(Modifier.fillMaxWidth())
            campoDaHora(Modifier.fillMaxWidth())
        }
        if (erro != null) Text(text = erro, style = FrilaTipo.apoio, color = FrilaTema.cores.tinta)
    }

    if (escolhendoData) {
        val estadoDoSeletor = rememberDatePickerState(initialSelectedDateMillis = dataParaSeletorUtcMs(instante))
        DatePickerDialog(
            onDismissRequest = { escolhendoData = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        estadoDoSeletor.selectedDateMillis?.let { aoMudar(trocarData(instante, it)) }
                        escolhendoData = false
                    },
                ) { Text(textoDeConfirmar) }
            },
            dismissButton = { TextButton(onClick = { escolhendoData = false }) { Text(textoDeCancelar) } },
        ) {
            DatePicker(state = estadoDoSeletor, title = { Text(rotuloData, modifier = Modifier.padding(FrilaEspacamento.bloco)) })
        }
    }

    if (escolhendoHora) {
        val local = instante.atZone(FUSO_DA_VAGA)
        val estadoDoSeletor = rememberTimePickerState(initialHour = local.hour, initialMinute = local.minute, is24Hour = true)
        AlertDialog(
            onDismissRequest = { escolhendoHora = false },
            title = { Text(rotuloHora, modifier = Modifier.semantics { heading() }) },
            text = { TimePicker(state = estadoDoSeletor) },
            confirmButton = {
                TextButton(
                    onClick = {
                        aoMudar(trocarHora(instante, estadoDoSeletor.hour, estadoDoSeletor.minute))
                        escolhendoHora = false
                    },
                ) { Text(textoDeConfirmar) }
            },
            dismissButton = { TextButton(onClick = { escolhendoHora = false }) { Text(textoDeCancelar) } },
        )
    }
}
