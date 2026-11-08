package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.dominio.modelo.MotivoOcorrencia

/**
 * Tela de ocorrência de um turno (RF12/RF23/RN15, UC14): escolha do motivo normativo, relato
 * livre e anexo opcional de foto. Relato e foto ficam só no aparelho e no e-mail que
 * [aoAbrirEmailDeSuporte] dispara depois do sucesso — nunca sobem numa RPC.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaOcorrencia(
    viewModel: OcorrenciaTurnoViewModel,
    modifier: Modifier = Modifier,
    aoSelecionarFoto: () -> Unit = {},
    aoAbrirEmailDeSuporte: (protocoloCurto: String) -> Unit = {},
    aoVoltar: () -> Unit = {},
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = "Relatar ocorrência",
                        modifier = Modifier.semantics { heading() },
                    )
                },
            )
        },
    ) { paddingInterno ->
        when (estado.status) {
            StatusOcorrencia.SUCESSO -> ConfirmacaoDeOcorrencia(
                protocoloCurto = estado.protocolo?.ocorrenciaId?.take(8)?.replace("-", "")?.uppercase() ?: "",
                aoAbrirEmailDeSuporte = aoAbrirEmailDeSuporte,
                aoVoltar = aoVoltar,
            )
            else -> FormularioDeOcorrencia(
                estado = estado,
                aoSelecionarMotivo = viewModel::selecionarMotivo,
                aoAtualizarRelato = viewModel::atualizarRelato,
                aoSelecionarFoto = aoSelecionarFoto,
                aoEnviar = { viewModel.enviar() },
            )
        }
    }
}

@Composable
private fun FormularioDeOcorrencia(
    estado: EstadoOcorrencia,
    aoSelecionarMotivo: (MotivoOcorrencia) -> Unit,
    aoAtualizarRelato: (String) -> Unit,
    aoSelecionarFoto: () -> Unit,
    aoEnviar: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = "O que aconteceu?",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Column(modifier = Modifier.selectableGroup()) {
            MotivoOcorrencia.entries.forEach { motivo ->
                LinhaDeMotivo(
                    motivo = motivo,
                    selecionado = estado.motivo == motivo,
                    aoSelecionar = { aoSelecionarMotivo(motivo) },
                )
            }
        }

        OutlinedTextField(
            value = estado.relato,
            onValueChange = aoAtualizarRelato,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Relato (vai só no e-mail de suporte)") },
        )

        BotaoSecundario(
            texto = if (estado.anexoUri == null) "Anexar foto" else "Foto anexada",
            aoClicar = aoSelecionarFoto,
            modifier = Modifier.fillMaxWidth(),
        )

        if (estado.status == StatusOcorrencia.ERRO) {
            val mensagem = estado.mensagemErro ?: "Não foi possível abrir o chamado."
            Text(
                text = mensagem,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.semantics {
                    liveRegion = LiveRegionMode.Assertive
                    error(mensagem)
                },
            )
        }

        BotaoPrimario(
            texto = if (estado.status == StatusOcorrencia.ENVIANDO) "Enviando…" else "Enviar",
            aoClicar = aoEnviar,
            habilitado = estado.motivo != null && estado.status != StatusOcorrencia.ENVIANDO,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun LinhaDeMotivo(motivo: MotivoOcorrencia, selecionado: Boolean, aoSelecionar: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo)
            .selectable(
                selected = selecionado,
                role = Role.RadioButton,
                onClick = aoSelecionar,
            )
            .semantics {
                stateDescription = if (selecionado) "selecionado" else "não selecionado"
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selecionado, onClick = null)
        Text(
            text = motivo.descricao,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(start = FrilaEspacamento.pequeno),
        )
    }
}

@Composable
private fun ConfirmacaoDeOcorrencia(
    protocoloCurto: String,
    aoAbrirEmailDeSuporte: (String) -> Unit,
    aoVoltar: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(FrilaEspacamento.grande),
        horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, androidx.compose.ui.Alignment.CenterVertically),
    ) {
        Text(
            text = "Chamado aberto. Protocolo #$protocoloCurto",
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            text = "Agora envie seu relato e a foto por e-mail para que a Equipe Frila possa ajudar.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
        BotaoPrimario(texto = "Abrir e-mail de suporte", aoClicar = { aoAbrirEmailDeSuporte(protocoloCurto) })
        BotaoSecundario(texto = "Voltar", aoClicar = aoVoltar)
    }
}
