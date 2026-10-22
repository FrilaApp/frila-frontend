package br.com.frila.feature.vagas.detalhe

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
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
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val vaga = estado.vaga

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(text = vaga.funcao.nome, style = MaterialTheme.typography.titleLarge)
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
            Text(text = "Inclui", style = MaterialTheme.typography.titleSmall)
            LinhaBeneficio("Refeição", vaga.inclusos.incluiRefeicao)
            LinhaBeneficio("Transporte", vaga.inclusos.incluiTransporte)
            LinhaBeneficio("Material próprio exigido", vaga.inclusos.exigeMaterialProprio)
        }

        estado.contato?.let { contato ->
            CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                Text(text = "Contato confirmado", style = MaterialTheme.typography.titleSmall)
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
    Text(
        text = "${if (incluido) "✓" else "—"} $rotulo",
        style = MaterialTheme.typography.bodySmall,
    )
}
