package br.com.frila.feature.equipe.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.PapelMembro
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Tudo o que a tela pode pedir ao [EquipeDaCasaViewModel]; o padrão `{}` mantém o teste de tela curto. */
data class AcoesEquipeDaCasa(
    val aoTentarNovamente: () -> Unit = {},
    val aoEditarEmail: (String) -> Unit = {},
    val aoEscolherPapel: (PapelMembro) -> Unit = {},
    val aoGerarConvite: () -> Unit = {},
    /** Entrega a mensagem do convite à folha de compartilhar do sistema (`ACTION_SEND`); quem monta a navegação a abre. */
    val aoCompartilhar: (link: String) -> Unit = {},
    val aoPedirConfirmacao: (AcaoSobreMembro, MembroDaCasa) -> Unit = { _, _ -> },
    val aoConfirmar: () -> Unit = {},
    val aoCancelar: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
)

/** Liga o [EquipeDaCasaViewModel] ao [ConteudoEquipeDaCasa]. */
@Composable
fun TelaEquipeDaCasa(
    viewModel: EquipeDaCasaViewModel,
    nomeDaCasa: String?,
    aoVoltar: () -> Unit,
    aoCompartilhar: (link: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoEquipeDaCasa(
        estado = estado,
        nomeDaCasa = nomeDaCasa,
        acoes = AcoesEquipeDaCasa(
            aoTentarNovamente = { viewModel.carregar() },
            aoEditarEmail = viewModel::editarEmail,
            aoEscolherPapel = viewModel::escolherPapel,
            aoGerarConvite = { viewModel.gerarConvite() },
            aoCompartilhar = aoCompartilhar,
            aoPedirConfirmacao = viewModel::pedirConfirmacao,
            aoConfirmar = { viewModel.confirmar() },
            aoCancelar = viewModel::cancelarConfirmacao,
            aoVoltar = aoVoltar,
        ),
        modifier = modifier,
    )
}

/**
 * Equipe da casa (RF21): para o administrador, convidar por e-mail e papel (o link sai pela folha de compartilhar) e a
 * lista de quem faz parte, com "Remover" e "Tornar administrador" atrás de uma confirmação; para quem não é
 * administrador, só o aviso de que a gestão é do administrador, sem botão algum. Tela de escolha: o único laranja é
 * "Gerar convite". O erro de cada ação fica junto do botão ou no alto da tela, em texto do Frila.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ConteudoEquipeDaCasa(
    estado: EstadoEquipeDaCasa,
    nomeDaCasa: String?,
    acoes: AcoesEquipeDaCasa,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = acoes.aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                TituloDaTela(TextosEquipeDaCasa.TITULO)
                if (!nomeDaCasa.isNullOrBlank()) Text(text = nomeDaCasa, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }

            if (!estado.podeGerenciar) {
                Text(text = TextosEquipeDaCasa.SO_ADMINISTRADOR, style = FrilaTipo.corpo, color = cores.tinta)
            } else {
                BlocoDeConvite(estado = estado, nomeDaCasa = nomeDaCasa, acoes = acoes)
                BlocoDaLista(estado = estado, acoes = acoes)
            }
        }
    }

    estado.pendente?.let { pendente -> DialogoDeConfirmacao(pendente = pendente, aoConfirmar = acoes.aoConfirmar, aoCancelar = acoes.aoCancelar) }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BlocoDeConvite(estado: EstadoEquipeDaCasa, nomeDaCasa: String?, acoes: AcoesEquipeDaCasa) {
    val cores = FrilaTema.cores
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
        RotuloDeGrupo(TextosEquipeDaCasa.CONVIDAR)
        Text(text = TextosEquipeDaCasa.EXPLICACAO, style = FrilaTipo.apoio, color = cores.tintaSuave)
        CampoDeTexto(
            valor = estado.email,
            aoMudar = acoes.aoEditarEmail,
            rotulo = TextosEquipeDaCasa.EMAIL,
            erro = estado.erroDoEmail,
            habilitado = !estado.gerandoConvite,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            RotuloDeGrupo(TextosEquipeDaCasa.PAPEL)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                PapelMembro.entries.forEach { papel ->
                    ChipFrila(
                        texto = rotuloDoPapel(papel),
                        selecionado = estado.papelConvidado == papel,
                        aoClicar = { acoes.aoEscolherPapel(papel) },
                        habilitado = !estado.gerandoConvite,
                        escolhaUnica = true,
                    )
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            estado.erroDoConvite?.let { MensagemJuntoAoBotao(it) }
            BotaoPrimario(
                texto = if (estado.gerandoConvite) TextosEquipeDaCasa.GERANDO else TextosEquipeDaCasa.GERAR_CONVITE,
                aoClicar = acoes.aoGerarConvite,
                habilitado = !estado.ocupado,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        estado.convite?.let { convite ->
            CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    Text(
                        text = TextosEquipeDaCasa.CONVITE_PARA.format(convite.email),
                        style = FrilaTipo.nome,
                        color = cores.tinta,
                        modifier = Modifier.semantics { heading(); liveRegion = LiveRegionMode.Polite },
                    )
                    val prazo = convite.expiraEm?.let(::formatarPrazoDoConvite)
                    Text(
                        text = prazo?.let { TextosEquipeDaCasa.CONVITE_PRONTO.format(it) }
                            ?: TextosEquipeDaCasa.CONVITE_PRONTO_SEM_PRAZO,
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                    Text(text = TextosEquipeDaCasa.LINK_DO_CONVITE, style = FrilaTipo.rotuloDeGrupo, color = cores.tintaSuave)
                    Text(text = convite.link, style = FrilaTipo.apoio, color = cores.tinta)
                    BotaoSecundario(
                        texto = TextosEquipeDaCasa.COMPARTILHAR,
                        aoClicar = {
                            acoes.aoCompartilhar(
                                TextosEquipeDaCasa.mensagemDoConvite(
                                    casa = nomeDaCasa,
                                    papel = convite.papel,
                                    email = convite.email,
                                    prazo = prazo,
                                    link = convite.link,
                                ),
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun BlocoDaLista(estado: EstadoEquipeDaCasa, acoes: AcoesEquipeDaCasa) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
        RotuloDeGrupo(TextosEquipeDaCasa.LISTA)
        // O resultado de remover e de tornar administrador aparece aqui, onde a pessoa acabou de tocar.
        estado.aviso?.let {
            AvisoFrila(tom = TomAviso.SUCESSO, mensagem = it, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
        }
        estado.erroDaAcao?.let {
            AvisoFrila(tom = TomAviso.ERRO, mensagem = it, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive })
        }
        when (val lista = estado.lista) {
            ListaDaEquipe.Carregando -> EstadoCarregando(mensagem = TextosEquipeDaCasa.CARREGANDO)
            ListaDaEquipe.SoAdministrador -> Text(text = TextosEquipeDaCasa.SO_ADMINISTRADOR, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
            is ListaDaEquipe.Erro -> EstadoErro(
                titulo = lista.mensagem,
                mensagem = null,
                aoTentarNovamente = if (lista.podeTentarDeNovo) acoes.aoTentarNovamente else null,
            )
            is ListaDaEquipe.Conteudo -> if (lista.membros.isEmpty()) {
                EstadoVazio(titulo = TextosEquipeDaCasa.VAZIA)
            } else {
                lista.membros.forEach { membro ->
                    CartaoDoMembro(membro = membro, ocupado = estado.ocupado, acoes = acoes)
                }
            }
        }
    }
}

@Composable
private fun CartaoDoMembro(membro: MembroDaCasa, ocupado: Boolean, acoes: AcoesEquipeDaCasa) {
    val cores = FrilaTema.cores
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
            Text(
                text = membro.nome,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = listOfNotNull(rotuloDoPapelOuDesconhecido(membro.papel), if (membro.eVoce) TextosEquipeDaCasa.VOCE else null).joinToString(" · "),
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
            )
            membro.desde?.let {
                Text(text = TextosEquipeDaCasa.DESDE.format(DIA.format(it.atZone(FUSO))), style = FrilaTipo.apoio, color = cores.tintaSuave)
            }
            // Quem é "você" não tem ações: o app não oferece sair da casa nem se tornar administrador de novo por aqui. Papel que o app
            // não conhece também não: não se sabe o que a pessoa é, então nada é oferecido sobre ela (iOS `papelConhecido`).
            if (!membro.eVoce && membro.papel != null) {
                if (membro.papel == PapelMembro.OPERADOR) {
                    BotaoSecundario(
                        texto = TextosEquipeDaCasa.TRANSFERIR,
                        aoClicar = { acoes.aoPedirConfirmacao(AcaoSobreMembro.TRANSFERIR, membro) },
                        habilitado = !ocupado,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = FrilaEspacamento.item)
                            .semantics { contentDescription = TextosEquipeDaCasa.TRANSFERIR_DE.format(membro.nome) },
                    )
                }
                BotaoSecundario(
                    texto = TextosEquipeDaCasa.REMOVER,
                    aoClicar = { acoes.aoPedirConfirmacao(AcaoSobreMembro.REMOVER, membro) },
                    habilitado = !ocupado,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = FrilaEspacamento.item)
                        .semantics { contentDescription = TextosEquipeDaCasa.REMOVER_DE.format(membro.nome) },
                )
            }
        }
    }
}

@Composable
private fun DialogoDeConfirmacao(pendente: AcaoPendente, aoConfirmar: () -> Unit, aoCancelar: () -> Unit) {
    val cores = FrilaTema.cores
    val remover = pendente.acao == AcaoSobreMembro.REMOVER
    AlertDialog(
        onDismissRequest = aoCancelar,
        containerColor = cores.superficie,
        title = {
            Text(
                text = if (remover) TextosEquipeDaCasa.CONFIRMAR_REMOCAO else TextosEquipeDaCasa.CONFIRMAR_TRANSFERENCIA,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Text(
                text = (if (remover) TextosEquipeDaCasa.EFEITO_REMOCAO else TextosEquipeDaCasa.EFEITO_TRANSFERENCIA).format(pendente.nome),
                style = FrilaTipo.corpo,
                color = cores.tinta,
            )
        },
        confirmButton = {
            TextButton(onClick = aoConfirmar, modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo)) {
                Text(TextosEquipeDaCasa.CONFIRMAR, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
            }
        },
        dismissButton = {
            TextButton(onClick = aoCancelar, modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo)) {
                Text(TextosEquipeDaCasa.CANCELAR, style = FrilaTipo.rotuloSecundario, color = cores.tintaSuave)
            }
        },
    )
}

internal fun rotuloDoPapel(papel: PapelMembro): String = when (papel) {
    PapelMembro.ADMINISTRADOR -> TextosEquipeDaCasa.PAPEL_ADMINISTRADOR
    PapelMembro.OPERADOR -> TextosEquipeDaCasa.PAPEL_OPERADOR
}

/** O rótulo do papel, ou "Outro papel" quando ele é nulo ou este app não o conhece: a pessoa e a casa continuam na lista, nunca sem papel (iOS `papelDesconhecido`). */
internal fun rotuloDoPapelOuDesconhecido(papel: PapelMembro?): String = papel?.let(::rotuloDoPapel) ?: TextosEquipeDaCasa.PAPEL_DESCONHECIDO

private val FUSO = ZoneId.of("America/Sao_Paulo")
private val DIA = DateTimeFormatter.ofPattern("dd/MM/yyyy", Locale.forLanguageTag("pt-BR"))
