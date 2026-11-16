package br.com.frila.feature.chamadas.profissional

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.EspecialidadeDto

/** Liga o [EditarServicosViewModel] ao [ConteudoEditarServicos]. */
@Composable
fun TelaEditarServicos(
    viewModel: EditarServicosViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoEditarServicos(
        tela = estado,
        aoEditar = viewModel::editar,
        aoAlternarEspecialidade = viewModel::alternarEspecialidade,
        aoSalvar = { viewModel.salvar() },
        aoTentarNovamente = { viewModel.carregar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Serviços com preço (RN27, RN44; paridade com `TelaEditarServicos.swift`): uma linha por função marcada no
 * perfil, com chave "oferecer este serviço", unidade de preço, valor e os campos que a unidade pede, "leva
 * material?", o que está incluído e as especialidades (até 8). O erro de campo aparece na linha da função.
 */
@Composable
fun ConteudoEditarServicos(
    tela: EstadoEditarServicos,
    aoEditar: (funcaoId: String, (ServicoEmEdicao) -> ServicoEmEdicao) -> Unit,
    aoAlternarEspecialidade: (funcaoId: String, especialidadeId: String, marcada: Boolean) -> Unit,
    aoSalvar: () -> Unit,
    aoTentarNovamente: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = { BarraDoTopoChamada(TextosChamadaProfissional.SERVICOS_TITULO, aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Text(text = TextosChamadaProfissional.SERVICOS_EXPLICACAO, style = MaterialTheme.typography.bodyMedium)
            if (tela.carregando) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.grande),
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    Text(text = TextosChamadaProfissional.CARREGANDO, style = MaterialTheme.typography.bodyMedium)
                }
            }
            if (tela.carregou && tela.rascunhos.isEmpty()) {
                Text(text = TextosChamadaProfissional.SERVICOS_SEM_FUNCOES, style = MaterialTheme.typography.bodyMedium)
            }
            tela.rascunhos.forEach { linha ->
                EditorDeServico(
                    linha = linha,
                    especialidades = tela.especialidades[linha.funcao.id].orEmpty(),
                    campoComErro = tela.campoComErro.takeIf { tela.funcaoComErro == null || tela.funcaoComErro == linha.funcao.id },
                    bloqueado = tela.salvando,
                    aoEditar = { mudanca -> aoEditar(linha.funcao.id, mudanca) },
                    aoAlternarEspecialidade = { id, marcada -> aoAlternarEspecialidade(linha.funcao.id, id, marcada) },
                )
            }
            tela.erro?.let { erro ->
                AvisoFrila(tom = TomAviso.ERRO, mensagem = erro, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive })
                if (!tela.carregou) {
                    BotaoSecundario(texto = TextosChamadaProfissional.TENTAR_NOVAMENTE, aoClicar = aoTentarNovamente)
                }
            }
            if (tela.sucesso) {
                AvisoFrila(
                    tom = TomAviso.INFORMATIVO,
                    mensagem = TextosChamadaProfissional.SERVICOS_SALVOS,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }.testTag("servicos-sucesso"),
                )
            }
            BotaoPrimario(
                texto = TextosChamadaProfissional.SERVICOS_SALVAR,
                aoClicar = aoSalvar,
                habilitado = tela.carregou && !tela.carregando && !tela.salvando,
                modifier = Modifier.fillMaxWidth().testTag("salvar-servicos"),
            )
        }
    }
}

@Composable
private fun EditorDeServico(
    linha: ServicoEmEdicao,
    especialidades: List<EspecialidadeDto>,
    campoComErro: String?,
    bloqueado: Boolean,
    aoEditar: ((ServicoEmEdicao) -> ServicoEmEdicao) -> Unit,
    aoAlternarEspecialidade: (especialidadeId: String, marcada: Boolean) -> Unit,
) {
    val id = linha.funcao.id
    Column(
        modifier = Modifier.fillMaxWidth().testTag("servico-$id"),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
    ) {
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
        LinhaComChave(
            titulo = linha.funcao.nome,
            ligado = linha.habilitado,
            aoMudar = { ligado -> aoEditar { it.copy(habilitado = ligado) } },
            habilitado = !bloqueado,
            modifier = Modifier.testTag("habilitar-$id"),
        )
        if (!linha.habilitado) return@Column

        EscolhaUnica(
            titulo = TextosChamadaProfissional.SERVICOS_UNIDADE,
            opcoes = UNIDADES_DE_PRECO.map { it to TextosChamadaProfissional.unidade(it) },
            selecionada = linha.unidade,
            aoEscolher = { nova -> aoEditar { it.comUnidade(nova) } },
            habilitado = !bloqueado,
            modifier = Modifier.testTag("unidade-servico-$id"),
        )
        if (linha.unidade == "a_combinar") {
            Text(text = TextosChamadaProfissional.SERVICOS_A_COMBINAR, style = MaterialTheme.typography.bodyMedium)
        } else {
            Campo(TextosChamadaProfissional.SERVICOS_VALOR, linha.valor, KeyboardType.Decimal, bloqueado, "valor-servico-$id") { novo ->
                aoEditar { it.copy(valor = novo) }
            }
            if (linha.unidade in listOf("hora", "diaria", "pacote")) {
                Campo(TextosChamadaProfissional.SERVICOS_VALOR_MAXIMO, linha.valorMaximo, KeyboardType.Decimal, bloqueado, "valor-maximo-$id") { novo ->
                    aoEditar { it.copy(valorMaximo = novo) }
                }
            }
            Text(text = TextosChamadaProfissional.SERVICOS_FAIXA_DE_VALOR, style = MaterialTheme.typography.bodySmall)
        }
        resumoDaDiaria(linha)?.let { Text(text = it, style = MaterialTheme.typography.bodySmall) }

        when (linha.unidade) {
            "diaria" -> Campo(TextosChamadaProfissional.SERVICOS_HORAS_DIARIA, linha.horasIncluidas, KeyboardType.Number, bloqueado, "horas-servico-$id") { novo ->
                aoEditar { it.copy(horasIncluidas = novo) }
            }
            "hora" -> Campo(TextosChamadaProfissional.SERVICOS_MINIMO_HORAS, linha.minimoHoras, KeyboardType.Number, bloqueado, "minimo-horas-$id") { novo ->
                aoEditar { it.copy(minimoHoras = novo) }
            }
            "evento" -> {
                Campo(TextosChamadaProfissional.SERVICOS_DURACAO, linha.duracaoTipicaH, KeyboardType.Number, bloqueado, "duracao-servico-$id") { novo ->
                    aoEditar { it.copy(duracaoTipicaH = novo) }
                }
                Campo(TextosChamadaProfissional.SERVICOS_ATE_PESSOAS, linha.atePessoas, KeyboardType.Number, bloqueado, "ate-pessoas-$id") { novo ->
                    aoEditar { it.copy(atePessoas = novo) }
                }
            }
            "pacote" -> Campo(TextosChamadaProfissional.SERVICOS_DESCRICAO_PACOTE, linha.descricaoPacote, KeyboardType.Text, bloqueado, "pacote-servico-$id") { novo ->
                aoEditar { it.copy(descricaoPacote = novo) }
            }
            "por_pessoa" -> Campo(TextosChamadaProfissional.SERVICOS_MINIMO_PESSOAS, linha.minimoPessoas, KeyboardType.Number, bloqueado, "minimo-pessoas-$id") { novo ->
                aoEditar { it.copy(minimoPessoas = novo) }
            }
        }

        EscolhaUnica(
            titulo = TextosChamadaProfissional.SERVICOS_LEVA_MATERIAL,
            opcoes = listOf<Pair<String?, String>>(null to TextosChamadaProfissional.SERVICOS_MATERIAL_NAO_INFORMADO) +
                OPCOES_LEVA_MATERIAL.map { it to TextosChamadaProfissional.material(it) },
            selecionada = linha.levaMaterial,
            aoEscolher = { novo -> aoEditar { it.copy(levaMaterial = novo) } },
            habilitado = !bloqueado,
            modifier = Modifier.testTag("material-servico-$id"),
        )
        Campo(TextosChamadaProfissional.SERVICOS_INCLUI, linha.inclui, KeyboardType.Text, bloqueado, "inclui-servico-$id") { novo ->
            aoEditar { it.copy(inclui = novo) }
        }

        especialidades.forEach { especialidade ->
            val marcada = especialidade.id in linha.especialidadeIds
            LinhaComChave(
                titulo = especialidade.nome,
                ligado = marcada,
                aoMudar = { ligado -> aoAlternarEspecialidade(especialidade.id, ligado) },
                habilitado = !bloqueado && (marcada || linha.especialidadeIds.size < MAXIMO_DE_ESPECIALIDADES),
            )
        }
        if (especialidades.isNotEmpty()) {
            Text(text = TextosChamadaProfissional.SERVICOS_ESPECIALIDADES, style = MaterialTheme.typography.bodySmall)
        }
        if (campoComErro != null) {
            Text(
                text = TextosChamadaProfissional.campo(campoComErro),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.testTag("erro-servico-$campoComErro"),
            )
        }
    }
}

@Composable
private fun Campo(
    rotulo: String,
    valor: String,
    teclado: KeyboardType,
    bloqueado: Boolean,
    etiqueta: String,
    aoMudar: (String) -> Unit,
) {
    OutlinedTextField(
        value = valor,
        onValueChange = aoMudar,
        label = { Text(rotulo) },
        enabled = !bloqueado,
        keyboardOptions = KeyboardOptions(keyboardType = teclado),
        modifier = Modifier.fillMaxWidth().heightIn(min = FrilaMetricas.alvoMinimo).testTag(etiqueta),
    )
}

/** "R$ 800,00 por diária de 8 h", quando a diária tem valor e horas válidos (como o iOS). */
private fun resumoDaDiaria(linha: ServicoEmEdicao): String? {
    if (linha.unidade != "diaria") return null
    val oferta = runCatching { linha.oferta() }.getOrNull() ?: return null
    val centavos = oferta.valorCentavos ?: return null
    val horas = oferta.horasIncluidas ?: return null
    return TextosChamadaProfissional.resumoDaDiaria(FormatoChamada.dinheiro(centavos), horas)
}
