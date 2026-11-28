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
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.MotivoOcorrencia

/**
 * Tela de ocorrência de um turno (RF12/RF23/RN15, UC14): escolha do motivo normativo, relato
 * livre. Sem anexo de foto (como no iOS). O relato fica só no aparelho e no corpo do e-mail que
 * [aoAbrirEmailDeSuporte] dispara depois do sucesso — nunca sobe numa RPC.
 *
 * Desenho: o motivo é uma lista com check em tinta (escolha única de formulário), o relato é um campo com o rótulo
 * acima e o envio fica ancorado embaixo, com a recusa escrita logo acima do botão. Suporte é por e-mail.
 */
@Composable
fun TelaOcorrencia(
    viewModel: OcorrenciaTurnoViewModel,
    modifier: Modifier = Modifier,
    /** E-mail oficial de suporte, citado na mensagem de falha quando nenhum app de e-mail abre. */
    emailDeSuporte: String = "",
    /** Abre o e-mail já escrito; devolve `false` se nenhum app de e-mail abriu (a tela avisa e mantém o relato). */
    aoAbrirEmailDeSuporte: (PedidoDeEmailDeSuporte) -> Boolean = { true },
    /** Abre o discador com o número (190 ou 180), no "Risco de segurança"; sem discador, quem chama avisa. */
    aoLigar: (String) -> Unit = {},
    aoVoltar: () -> Unit = {},
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    when (estado.status) {
        StatusOcorrencia.SUCESSO -> ConfirmacaoDeOcorrencia(
            pedido = PedidoDeEmailDeSuporte(
                protocoloCurto = estado.protocolo?.ocorrenciaId?.take(8)?.replace("-", "")?.uppercase() ?: "",
                motivo = estado.motivo,
                relato = estado.relato,
            ),
            emailDeSuporte = emailDeSuporte,
            aoAbrirEmailDeSuporte = aoAbrirEmailDeSuporte,
            aoVoltar = aoVoltar,
            modifier = modifier,
        )
        else -> FormularioDeOcorrencia(
            estado = estado,
            aoSelecionarMotivo = viewModel::selecionarMotivo,
            aoAtualizarRelato = viewModel::atualizarRelato,
            aoEnviar = { viewModel.enviar() },
            aoLigar = aoLigar,
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
    aoEnviar: () -> Unit,
    aoLigar: (String) -> Unit,
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

            if (estado.motivo == MotivoOcorrencia.RISCO_SEGURANCA) Emergencia(aoLigar)

            CampoDeTexto(
                valor = estado.relato,
                aoMudar = aoAtualizarRelato,
                rotulo = TextosOcorrencia.ROTULO_RELATO,
                umaLinha = false,
                linhasMinimas = 4,
            )
        }
    }
}

@Composable
private fun ConfirmacaoDeOcorrencia(
    pedido: PedidoDeEmailDeSuporte,
    emailDeSuporte: String,
    aoAbrirEmailDeSuporte: (PedidoDeEmailDeSuporte) -> Boolean,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Sem app de e-mail, o relato só existe aqui: a tela diz, mantém o texto selecionável e deixa tentar de novo.
    var emailFalhou by rememberSaveable { mutableStateOf(false) }
    val protocoloCurto = pedido.protocoloCurto
    Scaffold(
        modifier = modifier,
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                BotaoPrimario(
                    texto = TextosOcorrencia.ABRIR_EMAIL,
                    aoClicar = { emailFalhou = !aoAbrirEmailDeSuporte(pedido) },
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
                text = TextosOcorrencia.CONFIRMACAO,
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tintaSuave,
            )
            if (emailFalhou) {
                AvisoFrila(
                    tom = TomAviso.ERRO,
                    mensagem = TextosOcorrencia.FALHA_AO_ABRIR_EMAIL.format(emailDeSuporte, protocoloCurto),
                )
                if (pedido.relato.isNotBlank()) {
                    Text(text = TextosOcorrencia.RELATO_PARA_COPIAR, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                    SelectionContainer {
                        Text(text = pedido.relato.trim(), style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
                    }
                }
            }
        }
    }
}

/** Risco de segurança: o aviso e os dois números de emergência, como na Denúncia e na folha de suporte do iOS. */
@Composable
private fun Emergencia(aoLigar: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosOcorrencia.EMERGENCIA)
        BotaoSecundario(texto = TextosOcorrencia.LIGAR_190, aoClicar = { aoLigar("190") }, modifier = Modifier.fillMaxWidth())
        BotaoSecundario(texto = TextosOcorrencia.LIGAR_180, aoClicar = { aoLigar("180") }, modifier = Modifier.fillMaxWidth())
    }
}
