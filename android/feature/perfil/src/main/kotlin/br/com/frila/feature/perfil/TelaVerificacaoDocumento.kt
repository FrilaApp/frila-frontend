package br.com.frila.feature.perfil

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.dominio.modelo.VerificacaoIdentidade

internal object TextosVerificacaoDocumento {
    const val TITULO = "Selo de confiança"
    const val ROTULO_VOLTAR = "Voltar"
    const val CARREGANDO = "Carregando a verificação"
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val APROVADA = "Sua identidade foi verificada. O selo \"Identidade Verificada\" aparece no seu perfil."
    const val EM_ANALISE = "Recebemos seus documentos. A moderação está analisando e você será avisado do resultado."
    const val PENDENTE = "A moderação pediu a verificação da sua identidade."
    const val REJEITADA = "Não conseguimos confirmar sua identidade com o envio anterior. Você pode enviar de novo."
    const val ORIENTACAO =
        "Escolha o tipo de documento e envie três fotos nítidas, com boa luz e sem cortar as bordas: " +
            "frente, verso e uma selfie. Cada foto pode ter até 5 MB."
    const val DOCUMENTO = "Tipo de documento"
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
 */
@OptIn(ExperimentalMaterial3Api::class)
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

    Scaffold(
        modifier = modifier,
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosVerificacaoDocumento.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier
                            .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo)
                            .testTag("verificacao-voltar"),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosVerificacaoDocumento.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { paddingInterno ->
        when (estado.carga) {
            StatusCargaVerificacao.CARREGANDO -> Box(
                modifier = Modifier.fillMaxSize().padding(paddingInterno),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.semantics { contentDescription = TextosVerificacaoDocumento.CARREGANDO },
                )
            }
            StatusCargaVerificacao.ERRO -> ErroDeCarga(estado.mensagemErro, viewModel::carregar, paddingInterno)
            StatusCargaVerificacao.PRONTO -> ConteudoVerificacao(
                estado = estado,
                paddingValues = paddingInterno,
                aoEscolherDocumento = viewModel::definirDocumento,
                aoEscolherParte = { parte ->
                    parteEmEscolha = parte
                    seletor.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
                aoEnviar = { viewModel.enviar() },
            )
        }
    }
}

@Composable
private fun ErroDeCarga(mensagem: String?, aoTentarNovamente: () -> Unit, paddingValues: PaddingValues) {
    Column(
        modifier = Modifier.fillMaxSize().padding(paddingValues).padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        Text(
            text = mensagem ?: "Não foi possível carregar a verificação.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        )
        BotaoSecundario(
            texto = TextosVerificacaoDocumento.TENTAR_NOVAMENTE,
            aoClicar = aoTentarNovamente,
            modifier = Modifier.testTag("verificacao-tentar-novamente"),
        )
    }
}

@Composable
private fun ConteudoVerificacao(
    estado: EstadoVerificacaoIdentidade,
    paddingValues: PaddingValues,
    aoEscolherDocumento: (TipoDocumentoIdentidade) -> Unit,
    aoEscolherParte: (TipoParteEvidencia) -> Unit,
    aoEnviar: () -> Unit,
) {
    val verificacao = estado.verificacao
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(paddingValues)
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        if (verificacao != null) BlocoDeSituacao(verificacao)

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

        if (estado.podeSolicitar) {
            Text(TextosVerificacaoDocumento.ORIENTACAO, style = MaterialTheme.typography.bodyMedium)

            Text(
                text = TextosVerificacaoDocumento.DOCUMENTO,
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.semantics { heading() },
            )
            Row(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                TipoDocumentoIdentidade.entries.forEach { tipo ->
                    FilterChip(
                        selected = estado.documento == tipo,
                        onClick = { aoEscolherDocumento(tipo) },
                        label = { Text(TextosVerificacaoDocumento.rotuloDocumento(tipo)) },
                        modifier = Modifier
                            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                            .testTag("documento-${tipo.name.lowercase()}"),
                    )
                }
            }

            TipoParteEvidencia.entries.forEach { parte ->
                LinhaDeParte(
                    parte = parte,
                    escolhida = parte in estado.partesEscolhidas,
                    aoEscolher = { aoEscolherParte(parte) },
                )
            }

            val enviando = estado.envio == StatusEnvioVerificacao.ENVIANDO
            BotaoPrimario(
                texto = if (enviando) TextosVerificacaoDocumento.ENVIANDO else TextosVerificacaoDocumento.ENVIAR,
                aoClicar = aoEnviar,
                habilitado = estado.podeEnviar,
                modifier = Modifier.fillMaxWidth().testTag("verificacao-enviar"),
            )
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

@Composable
private fun LinhaDeParte(parte: TipoParteEvidencia, escolhida: Boolean, aoEscolher: () -> Unit) {
    CartaoVaga(modifier = Modifier.fillMaxWidth().testTag("parte-${parte.name.lowercase()}")) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(TextosVerificacaoDocumento.rotuloParte(parte), style = MaterialTheme.typography.bodyMedium)
                Text(
                    text = if (escolhida) "Foto escolhida" else "Falta escolher",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val acao = if (escolhida) TextosVerificacaoDocumento.TROCAR else TextosVerificacaoDocumento.ESCOLHER
            BotaoSecundario(
                texto = acao,
                aoClicar = aoEscolher,
                modifier = Modifier
                    // O texto visível é igual nas três linhas; o leitor de tela precisa saber a parte.
                    .semantics { contentDescription = "$acao: ${TextosVerificacaoDocumento.rotuloParte(parte)}" }
                    .testTag("escolher-${parte.name.lowercase()}"),
            )
        }
    }
}
