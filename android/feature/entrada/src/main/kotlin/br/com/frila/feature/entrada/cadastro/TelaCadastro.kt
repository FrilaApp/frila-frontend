package br.com.frila.feature.entrada.cadastro

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
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
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.mascara.CpfVisualTransformation
import br.com.frila.core.designsystem.mascara.TelefoneVisualTransformation
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.feature.entrada.fraseComLinksLegais

/**
 * Cadastro do profissional (o que vem depois do código, para conta nova), no mesmo sistema da entrada:
 * título e os campos com o rótulo acima, o aceite dos termos e, ancorado embaixo, o único botão laranja.
 * O erro de cada campo fica junto dele; o do aceite e o da ação (rede, servidor) ficam junto ao botão.
 * Sem desenho dele (extrapolada do mesmo sistema).
 */
@Composable
fun TelaCadastro(
    viewModel: CadastroViewModel,
    aoConcluir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val cores = FrilaTema.cores
    val erroNome = estado.erro?.takeIf { it == "Informe seu nome." }
    val erroCpf = estado.erro?.takeIf { it == "Informe seu CPF." || it == MENSAGEM_CPF_INVALIDO }
    val erroTelefone = estado.erro?.takeIf { it == "Informe seu telefone." || it == MENSAGEM_TELEFONE_INVALIDO }
    val erroNascimento = estado.erro?.takeIf {
        it == "Informe sua data de nascimento." || it == MENSAGEM_MENOR_DE_IDADE
    }
    val erroTermos = estado.erro?.takeIf { it == "Você precisa aceitar os termos para continuar." }

    LaunchedEffect(estado.concluido) {
        if (estado.concluido) {
            aoConcluir()
        }
    }

    // O que não é de um campo (o aceite, a rede, o servidor) fica junto ao botão, em tinta.
    val erroDaAcao = estado.erro?.takeUnless {
        it == erroNome || it == erroCpf || it == erroTelefone || it == erroNascimento
    }
    val podeSubmeter = estado.nascimentoValido && estado.cpfValido && estado.telefoneValido

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            RodapeAncorado {
                erroDaAcao?.let { mensagem ->
                    MensagemJuntoAoBotao(
                        texto = mensagem,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
                BotaoPrimario(
                    texto = "Concluir cadastro",
                    aoClicar = viewModel::concluirCadastro,
                    habilitado = podeSubmeter && !estado.enviando,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.respiro,
                    bottom = FrilaEspacamento.grupo,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela("Complete seu cadastro")

            CampoDeTexto(
                valor = estado.nome,
                aoMudar = viewModel::aoMudarNome,
                rotulo = "Nome completo",
                erro = erroNome,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                modifier = Modifier.anunciandoOErro(erroNome),
            )

            CampoDeTexto(
                valor = estado.cpf,
                aoMudar = viewModel::aoMudarCpf,
                rotulo = "CPF",
                dica = "000.000.000-00",
                erro = erroCpf,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                visualTransformation = remember { CpfVisualTransformation() },
                modifier = Modifier.anunciandoOErro(erroCpf),
            )

            CampoDeTexto(
                valor = estado.telefone,
                aoMudar = viewModel::aoMudarTelefone,
                rotulo = "Telefone com DDD",
                dica = "(00) 00000-0000",
                erro = erroTelefone,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                visualTransformation = remember { TelefoneVisualTransformation() },
                modifier = Modifier.anunciandoOErro(erroTelefone),
            )

            CampoDeNascimento(
                nascimento = estado.nascimento,
                aoMudar = viewModel::aoMudarNascimento,
                mensagemErro = erroNascimento,
            )

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        )
                        .toggleable(
                            value = estado.aceitouTermos,
                            role = Role.Checkbox,
                            onValueChange = viewModel::aoMudarAceiteDeTermos,
                        )
                        .semantics {
                            stateDescription = if (estado.aceitouTermos) "selecionado" else "não selecionado"
                            erroTermos?.let { error(it) }
                        },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    Checkbox(
                        checked = estado.aceitouTermos,
                        onCheckedChange = null,
                        modifier = Modifier.clearAndSetSemantics { },
                    )
                    Text(
                        text = "Li e aceito os termos de uso e a política de privacidade.",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                }
                // Os links ficam fora da caixa: tocar no texto da caixa marca o aceite, tocar no link abre a página.
                Text(
                    text = fraseComLinksLegais(
                        antes = "Leia os ",
                        termos = "Termos de Uso",
                        conector = " e a ",
                        privacidade = "Política de Privacidade",
                        depois = ".",
                    ),
                    style = FrilaTipo.legenda,
                    color = cores.tintaSuave,
                )
            }
        }
    }
}

/** O erro do campo é anunciado quando aparece (live region só enquanto há erro: digitar não repete a leitura). */
private fun Modifier.anunciandoOErro(erro: String?): Modifier = semantics {
    if (erro != null) liveRegion = LiveRegionMode.Assertive
}

@Composable
private fun CampoDeNascimento(
    nascimento: DataCivil?,
    aoMudar: (DataCivil) -> Unit,
    mensagemErro: String?,
) {
    var texto by remember {
        mutableStateOf(
            nascimento?.let { "%02d/%02d/%04d".format(it.data.dayOfMonth, it.data.monthValue, it.data.year) } ?: "",
        )
    }

    CampoDeTexto(
        valor = texto,
        aoMudar = { novoTexto ->
            texto = novoTexto
            parseDataBr(novoTexto)?.let(aoMudar)
        },
        rotulo = "Data de nascimento (dd/mm/aaaa)",
        dica = "dd/mm/aaaa",
        erro = mensagemErro,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        visualTransformation = VisualTransformation.None,
        modifier = Modifier.anunciandoOErro(mensagemErro),
    )
}

private fun parseDataBr(texto: String): DataCivil? {
    val partes = texto.split("/")
    if (partes.size != 3) return null
    val dia = partes[0].toIntOrNull() ?: return null
    val mes = partes[1].toIntOrNull() ?: return null
    val ano = partes[2].toIntOrNull() ?: return null
    return runCatching { DataCivil.de(ano, mes, dia) }.getOrNull()
}
