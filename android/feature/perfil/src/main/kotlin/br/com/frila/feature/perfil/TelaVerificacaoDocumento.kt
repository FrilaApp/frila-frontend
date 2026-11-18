package br.com.frila.feature.perfil

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.net.Uri
import android.view.Window
import android.view.WindowManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.dominio.modelo.VerificacaoIdentidade

internal object TextosVerificacaoDocumento {
    const val TITULO = "Selo de confiança"
    const val ROTULO_VOLTAR = "Voltar"
    const val CARREGANDO = "Carregando a verificação"
    const val ERRO_PADRAO = "Não foi possível carregar a verificação."
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val APROVADA = "Sua identidade foi verificada. O selo \"Identidade Verificada\" aparece no seu perfil."
    const val EM_ANALISE = "Recebemos seus documentos. A moderação está analisando e você será avisado do resultado."
    const val PENDENTE = "A moderação pediu a verificação da sua identidade."
    const val REJEITADA = "Não conseguimos confirmar sua identidade com o envio anterior. Você pode enviar de novo."
    const val ORIENTACAO =
        "Escolha o tipo de documento e envie três fotos nítidas, com boa luz e sem cortar as bordas: " +
            "frente, verso e uma selfie. Cada foto pode ter até 5 MB."
    const val DOCUMENTO = "Tipo de documento"
    const val FOTOS = "Fotos"
    const val ESCOLHER = "Escolher foto"
    const val TROCAR = "Trocar foto"
    const val ENVIAR = "Enviar para análise"
    const val ENVIANDO = "Enviando"

    fun rotuloDocumento(tipo: TipoDocumentoIdentidade) = when (tipo) {
        TipoDocumentoIdentidade.RG -> "RG"
        TipoDocumentoIdentidade.CNH -> "CNH"
    }

    fun rotuloParte(parte: TipoParteEvidencia) = when (parte) {
        TipoParteEvidencia.FRENTE -> "Frente do documento"
        TipoParteEvidencia.VERSO -> "Verso do documento"
        TipoParteEvidencia.SELFIE -> "Selfie"
    }
}

/**
 * Fluxo do selo (RN14/RN15): primeiro o consentimento ([TelaConsentimentoSelo]), depois
 * documento e três fotos, depois o envio. A tela só mostra o estado que o servidor devolve; não
 * decide aprovação. Ler o estado não manda biometria, então roda ao abrir; o envio só sai com o
 * consentimento registrado (garantido também no [VerificacaoIdentidadeViewModel]).
 *
 * No desenho do Fabrício: o "Enviar para análise" é o único primário e fica no rodapé ancorado, com o erro
 * logo acima; o tipo de documento é uma lista com check; as três fotos ficam num cartão.
 */
@Composable
fun TelaVerificacaoDocumento(
    viewModel: VerificacaoIdentidadeViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val contexto = LocalContext.current
    var parteEmEscolha by remember { mutableStateOf<TipoParteEvidencia?>(null) }
    val seletor = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        val parte = parteEmEscolha
        if (uri != null && parte != null) viewModel.escolherParte(contexto, parte, uri)
    }

    LaunchedEffect(Unit) { viewModel.carregar() }

    // RN15: documento e selfie não podem aparecer na miniatura dos apps recentes nem em captura de
    // tela. Vale para a tela inteira (consentimento incluso) e sai junto com ela.
    DisposableEffect(contexto) {
        val janela = contexto.encontrarActivity()?.window
        val desfazer = janela?.protegerContraCaptura()
        onDispose { desfazer?.invoke() }
    }

    val precisaConsentir = estado.carga == StatusCargaVerificacao.PRONTO &&
        estado.podeSolicitar && estado.precisaConsentimento
    if (precisaConsentir) {
        TelaConsentimentoSelo(
            aoConfirmar = viewModel::confirmarConsentimento,
            aoVoltar = aoVoltar,
            modifier = modifier,
        )
        return
    }

    val formularioAberto = estado.carga == StatusCargaVerificacao.PRONTO && estado.podeSolicitar
    Scaffold(
        modifier = modifier,
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar, modifier = Modifier.testTag("verificacao-voltar")) },
        bottomBar = {
            if (formularioAberto) {
                RodapeAncorado {
                    estado.mensagemErro?.let { mensagem ->
                        MensagemJuntoAoBotao(
                            texto = mensagem,
                            modifier = Modifier
                                .semantics { liveRegion = LiveRegionMode.Assertive }
                                .testTag("verificacao-erro"),
                        )
                    }
                    val enviando = estado.envio == StatusEnvioVerificacao.ENVIANDO
                    BotaoPrimario(
                        texto = if (enviando) TextosVerificacaoDocumento.ENVIANDO else TextosVerificacaoDocumento.ENVIAR,
                        aoClicar = { viewModel.enviar() },
                        habilitado = estado.podeEnviar,
                        modifier = Modifier.fillMaxWidth().testTag("verificacao-enviar"),
                    )
                }
            }
        },
    ) { paddingInterno ->
        when (estado.carga) {
            StatusCargaVerificacao.CARREGANDO -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingInterno)
                    .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
            ) {
                TituloDaTela(TextosVerificacaoDocumento.TITULO)
                EstadoCarregando(mensagem = TextosVerificacaoDocumento.CARREGANDO)
            }
            StatusCargaVerificacao.ERRO -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingInterno)
                    .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
            ) {
                TituloDaTela(TextosVerificacaoDocumento.TITULO)
                // O texto do erro é a própria mensagem (a do servidor ou a padrão); o botão refaz a leitura.
                EstadoErro(
                    modifier = Modifier.testTag("verificacao-tentar-novamente"),
                    titulo = estado.mensagemErro ?: TextosVerificacaoDocumento.ERRO_PADRAO,
                    mensagem = null,
                    textoBotao = TextosVerificacaoDocumento.TENTAR_NOVAMENTE,
                    aoTentarNovamente = viewModel::carregar,
                )
            }
            StatusCargaVerificacao.PRONTO -> ConteudoVerificacao(
                estado = estado,
                paddingValues = paddingInterno,
                aoEscolherDocumento = viewModel::definirDocumento,
                aoEscolherParte = { parte ->
                    parteEmEscolha = parte
                    seletor.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
            )
        }
    }
}

@Composable
private fun ConteudoVerificacao(
    estado: EstadoVerificacaoIdentidade,
    paddingValues: androidx.compose.foundation.layout.PaddingValues,
    aoEscolherDocumento: (TipoDocumentoIdentidade) -> Unit,
    aoEscolherParte: (TipoParteEvidencia) -> Unit,
) {
    val cores = FrilaTema.cores
    val verificacao = estado.verificacao
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(paddingValues)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
    ) {
        TituloDaTela(TextosVerificacaoDocumento.TITULO)

        if (verificacao != null) BlocoDeSituacao(verificacao)

        // Com o formulário aberto, o erro vai junto ao botão de enviar (rodapé); sem ele, fica aqui.
        if (!estado.podeSolicitar) {
            estado.mensagemErro?.let { mensagem ->
                AvisoFrila(
                    tom = TomAviso.ERRO,
                    mensagem = mensagem,
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics { liveRegion = LiveRegionMode.Assertive }
                        .testTag("verificacao-erro"),
                )
            }
        }

        if (estado.podeSolicitar) {
            Text(TextosVerificacaoDocumento.ORIENTACAO, style = FrilaTipo.corpo, color = cores.tinta)

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosVerificacaoDocumento.DOCUMENTO)
                FrilaGrupoDeLinhas {
                    TipoDocumentoIdentidade.entries.forEach { tipo ->
                        linha {
                            FrilaLinhaDeOpcao(
                                titulo = TextosVerificacaoDocumento.rotuloDocumento(tipo),
                                marcada = estado.documento == tipo,
                                aoClicar = { aoEscolherDocumento(tipo) },
                                modifier = Modifier.testTag("documento-${tipo.name.lowercase()}"),
                            )
                        }
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosVerificacaoDocumento.FOTOS)
                CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                    Column {
                        TipoParteEvidencia.entries.forEachIndexed { indice, parte ->
                            if (indice > 0) {
                                FrilaDivisoria(modifier = Modifier.padding(vertical = FrilaEspacamento.bloco))
                            }
                            LinhaDeParte(
                                parte = parte,
                                escolhida = parte in estado.partesEscolhidas,
                                aoEscolher = { aoEscolherParte(parte) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BlocoDeSituacao(verificacao: VerificacaoIdentidade) {
    val (texto, tom) = when (verificacao.status) {
        StatusVerificacaoIdentidade.APROVADA -> TextosVerificacaoDocumento.APROVADA to TomAviso.SUCESSO
        StatusVerificacaoIdentidade.EM_ANALISE -> TextosVerificacaoDocumento.EM_ANALISE to TomAviso.INFORMATIVO
        StatusVerificacaoIdentidade.PENDENTE -> TextosVerificacaoDocumento.PENDENTE to TomAviso.ALERTA
        StatusVerificacaoIdentidade.REJEITADA -> TextosVerificacaoDocumento.REJEITADA to TomAviso.ALERTA
        StatusVerificacaoIdentidade.NAO_EXIGIDA -> return
    }
    AvisoFrila(
        tom = tom,
        mensagem = listOfNotNull(texto, verificacao.motivo?.let { "Motivo: $it" }).joinToString(" "),
        modifier = Modifier
            .fillMaxWidth()
            .semantics { liveRegion = LiveRegionMode.Polite }
            .testTag("verificacao-situacao"),
    )
}

/**
 * Uma das três fotos: nome e situação à esquerda, botão à direita. Com a fonte do sistema bem grande o botão desce para
 * baixo do texto, para o nome da parte não ser espremido.
 */
@Composable
private fun LinhaDeParte(parte: TipoParteEvidencia, escolhida: Boolean, aoEscolher: () -> Unit) {
    val cores = FrilaTema.cores
    val rotulo = TextosVerificacaoDocumento.rotuloParte(parte)
    val acao = if (escolhida) TextosVerificacaoDocumento.TROCAR else TextosVerificacaoDocumento.ESCOLHER
    val situacao: @Composable (Modifier) -> Unit = { moduloDoTexto ->
        Column(modifier = moduloDoTexto, verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
            Text(rotulo, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
            Text(
                text = if (escolhida) "Foto escolhida" else "Falta escolher",
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
            )
        }
    }
    val botao: @Composable (Modifier) -> Unit = { moduloDoBotao ->
        BotaoSecundario(
            texto = acao,
            aoClicar = aoEscolher,
            modifier = moduloDoBotao
                // O texto visível é igual nas três linhas; o leitor de tela precisa saber a parte.
                .semantics { contentDescription = "$acao: $rotulo" }
                .testTag("escolher-${parte.name.lowercase()}"),
        )
    }

    val empilhar = LocalDensity.current.fontScale > FONTE_PARA_EMPILHAR
    if (empilhar) {
        Column(
            modifier = Modifier.fillMaxWidth().testTag("parte-${parte.name.lowercase()}"),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            situacao(Modifier.fillMaxWidth())
            botao(Modifier.fillMaxWidth())
        }
    } else {
        Row(
            modifier = Modifier.fillMaxWidth().testTag("parte-${parte.name.lowercase()}"),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            situacao(Modifier.weight(1f))
            botao(Modifier)
        }
    }
}

/** Acima desta escala de fonte do sistema, o botão da foto passa para baixo do texto. */
private const val FONTE_PARA_EMPILHAR = 1.3f

/** Sobe a cadeia de [ContextWrapper] até a [Activity] que hospeda a composição; `null` se não houver. */
internal fun Context.encontrarActivity(): Activity? {
    var atual: Context? = this
    while (atual is ContextWrapper) {
        if (atual is Activity) return atual
        atual = atual.baseContext
    }
    return null
}

/**
 * Liga `FLAG_SECURE` na janela e devolve o desfazer. Se a janela já era segura por outro motivo, o
 * desfazer não a destrava.
 */
internal fun Window.protegerContraCaptura(): () -> Unit {
    val jaEraSegura = attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
    addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    return { if (!jaEraSegura) clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
}
