package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.ChamadaResumoDto

/** Liga o [AcompanharChamadasViewModel] ao [ConteudoAcompanharChamadas]. */
@Composable
fun TelaAcompanharChamadas(
    viewModel: AcompanharChamadasViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoVerVagaPublicada: ((vagaId: String) -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoAcompanharChamadas(
        tela = estado,
        aoCancelar = { viewModel.cancelar(it) },
        aoPublicarParaTodos = { viewModel.publicarParaTodos() },
        aoVoltar = aoVoltar,
        modifier = modifier,
        aoVerVagaPublicada = aoVerVagaPublicada,
        aoTentarNovamente = { viewModel.carregar() },
    )
}

/**
 * Acompanhar as chamadas de uma vaga: lista com um cartão por chamada, o selo do estado, o motivo da recusa e, na
 * aberta, "Cancelar chamada" (ação discreta, atrás de uma confirmação); "Publicar para todos" (o único primário)
 * quando nenhuma chamada foi aceita e todas terminaram.
 */
@Composable
fun ConteudoAcompanharChamadas(
    tela: EstadoAcompanharChamadas,
    aoCancelar: (chamadaId: String) -> Unit,
    aoPublicarParaTodos: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoVerVagaPublicada: ((vagaId: String) -> Unit)? = null,
    /** Lê a lista de novo depois de uma falha da carga ("Tentar novamente"). */
    aoTentarNovamente: (() -> Unit)? = null,
) {
    var idParaCancelar by rememberSaveable { mutableStateOf<String?>(null) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(TextosChamadaCasa.ACOMPANHAR_TITULO)
            val falha = tela.falhaAoCarregar
            if (tela.carregando) {
                EstadoCarregando()
            } else if (falha != null && tela.chamadas.isEmpty()) {
                // rsojCnB5: sem lista para mostrar, a falha não é "Nenhuma chamada encontrada": é o erro, com "Tentar novamente".
                EstadoErro(
                    titulo = falha,
                    mensagem = null,
                    textoBotao = TextosChamadaCasa.TENTAR_NOVAMENTE,
                    aoTentarNovamente = aoTentarNovamente,
                )
            } else {
                tela.erro?.let { AvisoFrila(tom = TomAviso.ERRO, mensagem = it) }
                // Com a lista já na tela, a releitura que falhou não a apaga: a lista fica e a falha vira aviso.
                falha?.let { AvisoFrila(tom = TomAviso.ERRO, mensagem = it) }
                tela.sucesso?.let { AvisoFrila(tom = TomAviso.SUCESSO, mensagem = it) }

                RotuloDeGrupo(TextosChamadaCasa.CHAMADAS_ENVIADAS)
                if (tela.chamadas.isEmpty()) {
                    EstadoVazio(titulo = TextosChamadaCasa.NENHUMA_CHAMADA)
                } else {
                    tela.chamadas.forEach { chamada ->
                        CartaoDaChamada(chamada, tela, bloqueado = tela.acaoEmVoo, aoCancelar = { idParaCancelar = chamada.id })
                    }
                }

                if (tela.podePublicarParaTodos) {
                    Text(
                        text = TextosChamadaCasa.PUBLICAR_PARA_TODOS_EXPLICACAO,
                        style = FrilaTipo.apoio,
                        color = FrilaTema.cores.tintaSuave,
                    )
                    BotaoPrimario(
                        texto = TextosChamadaCasa.PUBLICAR_PARA_TODOS,
                        aoClicar = aoPublicarParaTodos,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                val nova = tela.vagaPublicadaId
                if (nova != null && aoVerVagaPublicada != null) {
                    BotaoSecundario(
                        texto = TextosChamadaCasa.VER_VAGA_ABERTA,
                        aoClicar = { aoVerVagaPublicada(nova) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }

    if (idParaCancelar != null) {
        AlertDialog(
            onDismissRequest = { idParaCancelar = null },
            containerColor = FrilaTema.cores.superficie,
            title = {
                Text(
                    TextosChamadaCasa.CONFIRMAR_CANCELAMENTO_TITULO,
                    style = FrilaTipo.nome,
                    color = FrilaTema.cores.tinta,
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = { Text(TextosChamadaCasa.CONFIRMAR_CANCELAMENTO, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta) },
            confirmButton = {
                TextButton(
                    onClick = {
                        val id = idParaCancelar
                        idParaCancelar = null
                        if (id != null) aoCancelar(id)
                    },
                    modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo),
                ) { Text(TextosChamadaCasa.CONFIRMAR_CANCELAMENTO_BOTAO, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tinta) }
            },
            dismissButton = {
                TextButton(
                    onClick = { idParaCancelar = null },
                    modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo),
                ) { Text(TextosChamadaCasa.VOLTAR, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tintaSuave) }
            },
        )
    }
}

/** Cada estado é um fato dito no selo: aguardando é contorno, aceita é amarelo, o que terminou sem aceite é encerrado. */
private fun estiloDoEstado(estado: String): EstiloDoSelo = when (estado) {
    EstadoAcompanharChamadas.ESTADO_ACEITA -> EstiloDoSelo.CONFIRMADO
    EstadoAcompanharChamadas.ESTADO_ABERTA -> EstiloDoSelo.CONTORNO
    else -> EstiloDoSelo.ENCERRADO
}

@Composable
private fun CartaoDaChamada(
    chamada: ChamadaResumoDto,
    tela: EstadoAcompanharChamadas,
    bloqueado: Boolean,
    aoCancelar: () -> Unit,
) {
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            SeloDeStatus(
                texto = tela.rotuloDoEstado(chamada.estado),
                estilo = estiloDoEstado(chamada.estado),
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                Text(text = chamada.outraParte.nome, style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
                Text(text = chamada.funcao.nome, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
                chamada.motivoRecusa?.let {
                    Text(
                        text = "${TextosChamadaCasa.MOTIVO_ROTULO}: ${textoDoMotivoDeRecusa(it)}",
                        style = FrilaTipo.apoio,
                        color = FrilaTema.cores.tintaSuave,
                    )
                }
            }
            if (chamada.estado == EstadoAcompanharChamadas.ESTADO_ABERTA) {
                AcaoDiscreta(
                    texto = TextosChamadaCasa.CANCELAR_CHAMADA,
                    aoClicar = aoCancelar,
                    habilitado = !bloqueado,
                    modifier = Modifier.semantics { contentDescription = "${TextosChamadaCasa.CANCELAR_CHAMADA}: ${chamada.outraParte.nome}" },
                )
            }
        }
    }
}
