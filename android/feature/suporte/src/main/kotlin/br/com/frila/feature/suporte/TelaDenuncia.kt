package br.com.frila.feature.suporte

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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.MotivoDenuncia
import br.com.frila.core.rede.ProtocoloDto

/** Liga o [DenunciaViewModel] ao [ConteudoDenuncia]. */
@Composable
fun TelaDenuncia(
    viewModel: DenunciaViewModel,
    aoFechar: () -> Unit,
    aoLigar: (numero: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    ConteudoDenuncia(
        estado = estado,
        associadaAoTurno = viewModel.associadaAoTurno,
        associadaAChamada = viewModel.associadaAChamada,
        aoEscolherMotivo = viewModel::escolherMotivo,
        aoEditarRelato = viewModel::editarRelato,
        aoEnviar = { viewModel.enviarDenuncia() },
        aoAbrirBloqueio = viewModel::abrirDialogoBloqueio,
        aoCancelarBloqueio = viewModel::cancelarBloqueio,
        aoConfirmarBloqueio = { viewModel.confirmarBloqueio() },
        aoFechar = aoFechar,
        aoLigar = aoLigar,
        modifier = modifier,
    )
}

/**
 * Denúncia e bloqueio (RF26, UC17, paridade com `AcoesDeSeguranca.swift`). Os atalhos 190/180
 * ficam sempre à vista, também depois do envio, e não esperam a resposta da denúncia (diretriz 1.2 da App Store).
 *
 * Tela de risco e suporte: sem vermelho e com um único laranja, o "Enviar denúncia" (ou o "Concluir") no rodapé
 * ancorado, com o erro do envio logo acima. Bloquear é ação discreta no fim, atrás de uma confirmação.
 */
@Composable
fun ConteudoDenuncia(
    estado: EstadoDenuncia,
    associadaAoTurno: Boolean,
    associadaAChamada: Boolean,
    aoEscolherMotivo: (MotivoDenuncia) -> Unit,
    aoEditarRelato: (String) -> Unit,
    aoEnviar: () -> Unit,
    aoAbrirBloqueio: () -> Unit,
    aoCancelarBloqueio: () -> Unit,
    aoConfirmarBloqueio: () -> Unit,
    aoFechar: () -> Unit,
    aoLigar: (numero: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val protocolo = estado.protocolo
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoFechar) },
        bottomBar = {
            RodapeAncorado {
                if (protocolo != null) {
                    BotaoPrimario(
                        texto = TextosSuporte.CONCLUIR,
                        aoClicar = aoFechar,
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    estado.erroDenuncia?.let { mensagem ->
                        MensagemJuntoAoBotao(
                            texto = mensagem,
                            modifier = Modifier.semantics {
                                error(mensagem)
                                liveRegion = LiveRegionMode.Assertive
                            },
                        )
                    }
                    BotaoPrimario(
                        texto = if (estado.enviando) TextosSuporte.ENVIANDO else TextosSuporte.ENVIAR,
                        aoClicar = aoEnviar,
                        habilitado = estado.podeEnviar,
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
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(top = FrilaEspacamento.item, bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosSuporte.TITULO)
            Emergencia(aoLigar)

            if (protocolo != null) {
                DenunciaEnviada(protocolo = protocolo)
            } else {
                FormularioDenuncia(
                    estado = estado,
                    associadaAoTurno = associadaAoTurno,
                    associadaAChamada = associadaAChamada,
                    aoEscolherMotivo = aoEscolherMotivo,
                    aoEditarRelato = aoEditarRelato,
                )
            }

            SecaoBloqueio(estado = estado, aoAbrir = aoAbrirBloqueio)
        }
    }

    if (estado.dialogoBloqueioAberto) {
        DialogoDeConfirmacao(
            titulo = TextosSuporte.BLOQUEIO_TITULO,
            mensagem = TextosSuporte.BLOQUEIO_EFEITO,
            textoConfirmar = TextosSuporte.BLOQUEIO_CONFIRMAR,
            aoConfirmar = aoConfirmarBloqueio,
            textoCancelar = TextosSuporte.CANCELAR,
            aoCancelar = aoCancelarBloqueio,
        )
    }
}

@Composable
private fun Emergencia(aoLigar: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = TextosSuporte.EMERGENCIA)
        BotaoSecundario(
            texto = TextosSuporte.LIGAR_190,
            aoClicar = { aoLigar("190") },
            modifier = Modifier.fillMaxWidth(),
        )
        BotaoSecundario(
            texto = TextosSuporte.LIGAR_180,
            aoClicar = { aoLigar("180") },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun FormularioDenuncia(
    estado: EstadoDenuncia,
    associadaAoTurno: Boolean,
    associadaAChamada: Boolean,
    aoEscolherMotivo: (MotivoDenuncia) -> Unit,
    aoEditarRelato: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo)) {
        FrilaGrupoDeLinhas(titulo = TextosSuporte.SECAO_MOTIVO) {
            MotivoDenuncia.entries.forEach { motivo ->
                linha {
                    FrilaLinhaDeOpcao(
                        titulo = TextosSuporte.nome(motivo),
                        marcada = estado.motivo == motivo,
                        aoClicar = { aoEscolherMotivo(motivo) },
                        habilitada = !estado.enviando,
                    )
                }
            }
        }

        CampoDeTexto(
            valor = estado.relato,
            aoMudar = aoEditarRelato,
            rotulo = TextosSuporte.SECAO_RELATO,
            habilitado = !estado.enviando,
            umaLinha = false,
            linhasMinimas = 4,
            apoio = if (estado.relatoValido) TextosSuporte.RELATO_VALIDO else TextosSuporte.RELATO_DICA,
        )

        if (associadaAoTurno || associadaAChamada) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                if (associadaAoTurno) {
                    Text(TextosSuporte.ASSOCIADA_AO_TURNO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                }
                if (associadaAChamada) {
                    Text(TextosSuporte.ASSOCIADA_A_CHAMADA, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                }
            }
        }
    }
}

@Composable
private fun DenunciaEnviada(protocolo: ProtocoloDto) {
    val cores = FrilaTema.cores
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            Text(
                text = TextosSuporte.ENVIADA,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics {
                    heading()
                    liveRegion = LiveRegionMode.Polite
                },
            )
            Text(
                text = "${TextosSuporte.PROTOCOLO}: #${protocolo.protocoloCurto}",
                style = FrilaTipo.corpo,
                color = cores.tinta,
            )
            Text(
                text = "${TextosSuporte.PRAZO} ${formatarPrazo(protocolo.prazoRespostaAte)}",
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
            )
        }
    }
}

@Composable
private fun SecaoBloqueio(estado: EstadoDenuncia, aoAbrir: () -> Unit) {
    Column(
        modifier = Modifier.padding(top = FrilaEspacamento.item),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        estado.erroBloqueio?.let { mensagem ->
            MensagemJuntoAoBotao(
                texto = mensagem,
                modifier = Modifier.semantics {
                    error(mensagem)
                    liveRegion = LiveRegionMode.Assertive
                },
            )
        }
        if (estado.bloqueado) {
            Text(
                text = TextosSuporte.BLOQUEADO,
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tinta,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        } else {
            AcaoDiscreta(
                texto = if (estado.bloqueando) TextosSuporte.BLOQUEANDO else TextosSuporte.BLOQUEAR,
                aoClicar = aoAbrir,
                habilitado = !estado.bloqueando,
            )
        }
    }
}
