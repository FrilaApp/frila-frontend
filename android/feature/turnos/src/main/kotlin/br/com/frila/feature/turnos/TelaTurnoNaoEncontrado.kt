package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema

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
 * No desenho do Fabrício: só o voltar na barra, o título "Meu turno" como conteúdo e o estado vazio (o fato, a dica
 * e a saída em botão secundário, sem ícone e sem laranja: a tela não decide nada).
 */
@Composable
fun TelaTurnoNaoEncontrado(
    aoVoltar: () -> Unit,
    aoVerMeusTurnos: () -> Unit,
    modifier: Modifier = Modifier,
    rotuloBotao: String = TextosTurnoNaoEncontrado.BOTAO_VER_MEUS_TURNOS,
    /** Sem ícone por padrão (o estado vazio do sistema não leva ícone); só quem ainda precisa de um passa o seu. */
    icone: ImageVector? = null,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState()),
        ) {
            TituloDaTela(
                texto = TextosTurnoNaoEncontrado.TITULO_BARRA,
                modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo),
            )
            EstadoVazio(
                titulo = TextosTurnoNaoEncontrado.NAO_ENCONTRADO_TITULO,
                mensagem = TextosTurnoNaoEncontrado.NAO_ENCONTRADO_MENSAGEM,
                icone = icone,
                textoAcao = rotuloBotao,
                aoClicarAcao = aoVerMeusTurnos,
            )
        }
    }
}
