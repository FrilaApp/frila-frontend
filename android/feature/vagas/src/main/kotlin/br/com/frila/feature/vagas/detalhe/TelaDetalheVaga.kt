package br.com.frila.feature.vagas.detalhe

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.dominio.modelo.Dinheiro
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
private val FORMATO_HORARIO: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")

@Composable
fun TelaDetalheVaga(
    viewModel: DetalheVagaViewModel,
    modifier: Modifier = Modifier,
    verificarPermissaoNotificacao: (Context) -> Boolean = { ctx ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                ctx,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    },
    aoRequisitarPermissao: (() -> Unit)? = null,
    aoResultadoPermissao: (Boolean) -> Unit = {},
) {
    val contexto = LocalContext.current
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val vaga = estado.vaga

    var dialogoPermissaoVisivel by rememberSaveable { mutableStateOf(false) }
    var jaPediuPermissaoNaSessao by rememberSaveable { mutableStateOf(false) }

    val launcherPermissao = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { concedida ->
        aoResultadoPermissao(concedida)
    }

    LaunchedEffect(estado.statusCandidatura) {
        if (estado.statusCandidatura == StatusCandidatura.CONFIRMADA && !jaPediuPermissaoNaSessao) {
            if (!verificarPermissaoNotificacao(contexto)) {
                jaPediuPermissaoNaSessao = true
                dialogoPermissaoVisivel = true
            }
        }
    }

    if (dialogoPermissaoVisivel) {
        DialogoPermissaoNotificacao(
            aoConfirmar = {
                dialogoPermissaoVisivel = false
                if (aoRequisitarPermissao != null) {
                    aoRequisitarPermissao()
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    launcherPermissao.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    aoResultadoPermissao(true)
                }
            },
            aoDispensar = {
                dialogoPermissaoVisivel = false
                aoResultadoPermissao(false)
            },
        )
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = vaga.funcao.nome,
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.semantics { heading() },
        )
        Text(text = vaga.estabelecimento.nome, style = MaterialTheme.typography.titleSmall)
        Text(
            text = if (estado.ehModoUrgencia) "Modo urgência: confirmação na hora" else "Modo seleção: contratante escolhe depois",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        CartaoVaga(modifier = Modifier.fillMaxWidth()) {
            LinhaDetalhe(rotulo = "Local", valor = vaga.local)
            LinhaDetalhe(rotulo = "Região", valor = vaga.regiaoAdministrativa)
            LinhaDetalhe(rotulo = "Início", valor = FORMATO_HORARIO.withZone(FUSO_BRASILIA).format(Instant.parse(vaga.inicioEm)))
            LinhaDetalhe(rotulo = "Fim", valor = FORMATO_HORARIO.withZone(FUSO_BRASILIA).format(Instant.parse(vaga.fimEm)))
            LinhaDetalhe(rotulo = "Valor", valor = Dinheiro(vaga.valorCentavos).formatado())
            LinhaDetalhe(rotulo = "Distância", valor = "${"%.1f".format(vaga.distanciaKm)} km")
        }

        CartaoVaga(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "Inclui",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.semantics { heading() },
            )
            LinhaBeneficio("Refeição", vaga.inclusos.incluiRefeicao)
            LinhaBeneficio("Transporte", vaga.inclusos.incluiTransporte)
            LinhaBeneficio("Material próprio exigido", vaga.inclusos.exigeMaterialProprio)
        }

        estado.contato?.let { contato ->
            CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "Contato confirmado",
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.semantics { heading() },
                )
                LinhaDetalhe(rotulo = "Nome", valor = contato.nome)
                LinhaDetalhe(rotulo = "Telefone", valor = contato.telefone)
            }
        }

        estado.mensagem?.let { mensagem ->
            Text(
                text = mensagem,
                style = MaterialTheme.typography.bodyMedium,
                color = when (estado.statusCandidatura) {
                    StatusCandidatura.ERRO -> MaterialTheme.colorScheme.error
                    else -> MaterialTheme.colorScheme.onSurface
                },
                modifier = Modifier.semantics {
                    when (estado.statusCandidatura) {
                        StatusCandidatura.ERRO -> {
                            liveRegion = LiveRegionMode.Assertive
                            error(mensagem)
                        }
                        StatusCandidatura.CONFIRMADA, StatusCandidatura.PENDENTE -> {
                            liveRegion = LiveRegionMode.Polite
                        }
                        else -> Unit
                    }
                },
            )
        }

        val candidaturaJaEnviada = estado.statusCandidatura == StatusCandidatura.CONFIRMADA ||
            estado.statusCandidatura == StatusCandidatura.PENDENTE

        BotaoPrimario(
            texto = when (estado.statusCandidatura) {
                StatusCandidatura.ENVIANDO -> "Enviando…"
                StatusCandidatura.CONFIRMADA -> "Candidatura confirmada"
                StatusCandidatura.PENDENTE -> "Candidatura enviada"
                else -> "Candidatar-se"
            },
            aoClicar = viewModel::candidatar,
            habilitado = estado.statusCandidatura != StatusCandidatura.ENVIANDO && !candidaturaJaEnviada,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun LinhaDetalhe(rotulo: String, valor: String) {
    Text(text = "$rotulo: $valor", style = MaterialTheme.typography.bodyMedium)
}

@Composable
private fun LinhaBeneficio(rotulo: String, incluido: Boolean) {
    val estado = if (incluido) "incluído" else "não incluído"
    Text(
        text = "${if (incluido) "✓" else "—"} $rotulo",
        style = MaterialTheme.typography.bodySmall,
        modifier = Modifier.clearAndSetSemantics {
            contentDescription = "$rotulo: $estado"
        },
    )
}
