package br.com.frila.feature.turnos

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

/** Textos normativos em português brasileiro (guia de voz Frila / paridade iOS DestinosDoAviso.swift:274-293). */
object TextosTurnoNaoEncontrado {
    const val TITULO_BARRA = "Meu turno"
    const val ROTULO_VOLTAR = "Voltar"
    const val NAO_ENCONTRADO_TITULO = "Não encontramos este turno"
    const val NAO_ENCONTRADO_MENSAGEM = "Ele não está entre os turnos desta conta."
    const val BOTAO_VER_MEUS_TURNOS = "Ver meus turnos"
}

/**
 * Tela de Turno Não Encontrado (Tela 43 do mapa de paridade v1.2 / `DestinosDoAviso.swift:224-306`).
 * Exibida quando um push notification ou link profundo aponta para um turno que não pertence
 * à conta logada no dispositivo ou não foi encontrado na base local do profissional.
 *
 * Segue o padrão de estados do Frila: círculo de 72dp, título de estado com semântica de cabeçalho,
 * texto explicativo de apoio e botão secundário com alvo mínimo de 48dp para redirecionar à lista de turnos.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaTurnoNaoEncontrado(
    aoVoltar: () -> Unit,
    aoVerMeusTurnos: () -> Unit,
    modifier: Modifier = Modifier,
    rotuloBotao: String = TextosTurnoNaoEncontrado.BOTAO_VER_MEUS_TURNOS,
    icone: ImageVector = Icons.Default.Info,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosTurnoNaoEncontrado.TITULO_BARRA,
                        style = MaterialTheme.typography.titleLarge,
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier.sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosTurnoNaoEncontrado.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.grande),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = FrilaEspacamento.enorme),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
            ) {
                // Círculo com ícone de estado de 72dp (padrão MidFi / DestinosDoAviso.swift:271)
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .background(
                            color = MaterialTheme.colorScheme.surfaceContainerHigh,
                            shape = CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = icone,
                        contentDescription = null,
                        modifier = Modifier.size(32.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                Spacer(modifier = Modifier.height(FrilaEspacamento.pequeno))

                // Título com semântica de cabeçalho
                Text(
                    text = TextosTurnoNaoEncontrado.NAO_ENCONTRADO_TITULO,
                    style = MaterialTheme.typography.headlineSmall,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics { heading() },
                )

                // Mensagem de apoio
                Text(
                    text = TextosTurnoNaoEncontrado.NAO_ENCONTRADO_MENSAGEM,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // Ação principal de recuperação: direciona para Meus Turnos
            BotaoSecundario(
                texto = rotuloBotao,
                aoClicar = aoVerMeusTurnos,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = FrilaEspacamento.grande),
            )
        }
    }
}
