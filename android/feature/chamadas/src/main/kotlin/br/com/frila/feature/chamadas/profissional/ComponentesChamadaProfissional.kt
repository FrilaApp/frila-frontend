package br.com.frila.feature.chamadas.profissional

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Interruptor do Material (nativo) numa linha: a linha inteira liga e desliga, não só o botão, como o `Toggle`
 * do iOS. Dentro de um [FrilaGrupoDeLinhas] leva o mesmo recuo das outras linhas (`comRecuo`); dentro de um
 * cartão, que já tem o próprio padding, vai sem recuo. O texto de apoio, se houver, fica sob o título.
 */
@Composable
internal fun LinhaComChave(
    titulo: String,
    ligado: Boolean,
    aoMudar: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
    subtitulo: String? = null,
    comRecuo: Boolean = true,
    estiloDoTitulo: TextStyle = FrilaTipo.rotuloSecundario,
) {
    val cores = FrilaTema.cores
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .toggleable(value = ligado, enabled = habilitado, role = Role.Switch, onValueChange = aoMudar)
            .padding(
                horizontal = if (comRecuo) FrilaEspacamento.bloco else 0.dp,
                vertical = if (comRecuo) FrilaEspacamento.item else 0.dp,
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
            Text(text = titulo, style = estiloDoTitulo, color = cores.tinta)
            if (!subtitulo.isNullOrBlank()) {
                Text(text = subtitulo, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }
        }
        Switch(checked = ligado, onCheckedChange = null, enabled = habilitado)
    }
}

/**
 * Escolha de uma opção entre poucas: o par do `Picker` do iOS, como grupo de linhas com o check em tinta
 * ([FrilaLinhaDeOpcao]). Escolha única em formulário é lista com check, não chip.
 */
@Composable
internal fun <T> EscolhaUnica(
    titulo: String,
    opcoes: List<Pair<T, String>>,
    selecionada: T,
    aoEscolher: (T) -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    FrilaGrupoDeLinhas(modifier = modifier.selectableGroup(), titulo = titulo) {
        opcoes.forEach { (valor, rotulo) ->
            linha {
                FrilaLinhaDeOpcao(
                    titulo = rotulo,
                    marcada = valor == selecionada,
                    aoClicar = { aoEscolher(valor) },
                    habilitada = habilitado,
                )
            }
        }
    }
}

/**
 * Falha ao carregar a tela: o que falhou, escrito em tinta, e "Tentar novamente" em botão secundário.
 * Igual ao `EstadoErro` do sistema, mas com o texto do próprio erro como frase e com `modifierDoBotao`
 * para o botão ter o `testTag` que os testes usam. (Candidato a subir ao `EstadoErro`.)
 */
@Composable
internal fun ErroDeCargaChamada(
    mensagem: String,
    aoTentarNovamente: () -> Unit,
    modifier: Modifier = Modifier,
    modifierDoBotao: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = FrilaEspacamento.respiro, bottom = FrilaEspacamento.grupo)
            .semantics { error(mensagem) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
    ) {
        Text(
            text = mensagem,
            style = FrilaTipo.corpo,
            color = FrilaTema.cores.tinta,
            textAlign = TextAlign.Center,
        )
        BotaoSecundario(
            texto = TextosChamadaProfissional.TENTAR_NOVAMENTE,
            aoClicar = aoTentarNovamente,
            modifier = modifierDoBotao,
        )
    }
}
