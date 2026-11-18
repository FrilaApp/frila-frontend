package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.MotivoOcorrencia

/**
 * Tela de ocorrência de um turno (RF12/RF23/RN15, UC14): escolha do motivo normativo, relato
 * livre e anexo opcional de foto. Relato e foto ficam só no aparelho e no e-mail que
 * [aoAbrirEmailDeSuporte] dispara depois do sucesso — nunca sobem numa RPC.
 *
 * Desenho: o motivo é uma lista com check em tinta (escolha única de formulário), o relato é um campo com o rótulo
 * acima e o envio fica ancorado embaixo, com a recusa escrita logo acima do botão. Suporte é por e-mail.
 */
@Composable
fun TelaOcorrencia(
    viewModel: OcorrenciaTurnoViewModel,
    modifier: Modifier = Modifier,
    aoSelecionarFoto: () -> Unit = {},
    aoAbrirEmailDeSuporte: (protocoloCurto: String) -> Unit = {},
    aoVoltar: () -> Unit = {},
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    when (estado.status) {
        StatusOcorrencia.SUCESSO -> ConfirmacaoDeOcorrencia(
            protocoloCurto = estado.protocolo?.ocorrenciaId?.take(8)?.replace("-", "")?.uppercase() ?: "",
            aoAbrirEmailDeSuporte = aoAbrirEmailDeSuporte,
            aoVoltar = aoVoltar,
            modifier = modifier,
        )
        else -> FormularioDeOcorrencia(
            estado = estado,
            aoSelecionarMotivo = viewModel::selecionarMotivo,
            aoAtualizarRelato = viewModel::atualizarRelato,
            aoSelecionarFoto = aoSelecionarFoto,
            aoEnviar = { viewModel.enviar() },
            aoVoltar = aoVoltar,
            modifier = modifier,
        )
    }
}

@Composable
private fun FormularioDeOcorrencia(
    estado: EstadoOcorrencia,
    aoSelecionarMotivo: (MotivoOcorrencia) -> Unit,
    aoAtualizarRelato: (String) -> Unit,
    aoSelecionarFoto: () -> Unit,
    aoEnviar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                if (estado.status == StatusOcorrencia.ERRO) {
                    MensagemDeAcao(texto = estado.mensagemErro ?: "Não foi possível abrir o chamado.")
                }
                BotaoPrimario(
                    texto = if (estado.status == StatusOcorrencia.ENVIANDO) "Enviando…" else "Enviar",
                    aoClicar = aoEnviar,
                    habilitado = estado.motivo != null && estado.status != StatusOcorrencia.ENVIANDO,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela("Relatar ocorrência")
            FrilaGrupoDeLinhas(
                modifier = Modifier.selectableGroup(),
                titulo = "O que aconteceu?",
            ) {
                MotivoOcorrencia.entries.forEach { motivo ->
                    linha {
                        FrilaLinhaDeOpcao(
                            titulo = motivo.descricao,
                            marcada = estado.motivo == motivo,
                            aoClicar = { aoSelecionarMotivo(motivo) },
                        )
                    }
                }
            }

            CampoDeTexto(
                valor = estado.relato,
                aoMudar = aoAtualizarRelato,
                rotulo = "Relato (vai só no e-mail de suporte)",
                umaLinha = false,
                linhasMinimas = 4,
            )

            BotaoSecundario(
                texto = if (estado.anexoUri == null) "Anexar foto" else "Foto anexada",
                aoClicar = aoSelecionarFoto,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun ConfirmacaoDeOcorrencia(
    protocoloCurto: String,
    aoAbrirEmailDeSuporte: (String) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                BotaoPrimario(
                    texto = "Abrir e-mail de suporte",
                    aoClicar = { aoAbrirEmailDeSuporte(protocoloCurto) },
                    modifier = Modifier.fillMaxWidth(),
                )
                BotaoSecundario(texto = "Voltar", aoClicar = aoVoltar, modifier = Modifier.fillMaxWidth())
            }
        },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            TituloDaTela("Chamado aberto. Protocolo #$protocoloCurto")
            Text(
                text = "Agora envie seu relato e a foto por e-mail para que a Equipe Frila possa ajudar.",
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tintaSuave,
            )
        }
    }
}
