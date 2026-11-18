package br.com.frila.feature.chamadas.profissional

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
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
 * Serviços com preço (RN27, RN44; paridade com `TelaEditarServicos.swift`): um cartão por função marcada no
 * perfil, com a chave "oferecer este serviço", unidade de preço, valor e os campos que a unidade pede, "leva
 * material?", o que está incluído e as especialidades (até 8, em chips). O erro de campo aparece no campo da
 * função; o que não tem campo vai junto ao botão. "Salvar alterações" fica no rodapé ancorado.
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
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                if (tela.carregou) {
                    tela.erro?.let { MensagemJuntoAoBotao(it) }
                    if (tela.sucesso) {
                        MensagemJuntoAoBotao(
                            texto = TextosChamadaProfissional.SERVICOS_SALVOS,
                            modifier = Modifier.testTag("servicos-sucesso"),
                        )
                    }
                }
                BotaoPrimario(
                    texto = TextosChamadaProfissional.SERVICOS_SALVAR,
                    aoClicar = aoSalvar,
                    habilitado = tela.carregou && !tela.carregando && !tela.salvando,
                    modifier = Modifier.fillMaxWidth().testTag("salvar-servicos"),
                )
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(TextosChamadaProfissional.SERVICOS_TITULO, modifier = Modifier.padding(bottom = FrilaEspacamento.item))
            Text(
                text = TextosChamadaProfissional.SERVICOS_EXPLICACAO,
                style = FrilaTipo.apoio,
                color = FrilaTema.cores.tintaSuave,
            )
            if (tela.carregando) {
                EstadoCarregando(mensagem = TextosChamadaProfissional.CARREGANDO)
            }
            if (!tela.carregando && !tela.carregou) {
                ErroDeCargaChamada(
                    mensagem = tela.erro ?: TextosChamadaProfissional.ERRO,
                    aoTentarNovamente = aoTentarNovamente,
                )
            }
            if (tela.carregou && tela.rascunhos.isEmpty()) {
                EstadoVazio(titulo = TextosChamadaProfissional.SERVICOS_SEM_FUNCOES)
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
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
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
    // O campo do contrato que a API recusou só vira erro de campo se o campo está na tela; senão cai no fim do cartão.
    val camposNaTela = camposNaTela(linha)

    CartaoFrila(modifier = Modifier.fillMaxWidth().testTag("servico-$id")) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
            LinhaComChave(
                titulo = linha.funcao.nome,
                ligado = linha.habilitado,
                aoMudar = { ligado -> aoEditar { it.copy(habilitado = ligado) } },
                habilitado = !bloqueado,
                comRecuo = false,
                estiloDoTitulo = FrilaTipo.nome,
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
                Text(
                    text = TextosChamadaProfissional.SERVICOS_A_COMBINAR,
                    style = FrilaTipo.apoio,
                    color = FrilaTema.cores.tintaSuave,
                )
            } else {
                Campo(TextosChamadaProfissional.SERVICOS_VALOR, linha.valor, KeyboardType.Decimal, bloqueado, "valor-servico-$id", "valor_centavos", campoComErro) { novo ->
                    aoEditar { it.copy(valor = novo) }
                }
                if (linha.unidade in listOf("hora", "diaria", "pacote")) {
                    Campo(TextosChamadaProfissional.SERVICOS_VALOR_MAXIMO, linha.valorMaximo, KeyboardType.Decimal, bloqueado, "valor-maximo-$id", "valor_max_centavos", campoComErro) { novo ->
                        aoEditar { it.copy(valorMaximo = novo) }
                    }
                }
                Text(
                    text = TextosChamadaProfissional.SERVICOS_FAIXA_DE_VALOR,
                    style = FrilaTipo.apoio,
                    color = FrilaTema.cores.tintaSuave,
                )
            }
            resumoDaDiaria(linha)?.let { Text(text = it, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave) }

            when (linha.unidade) {
                "diaria" -> Campo(TextosChamadaProfissional.SERVICOS_HORAS_DIARIA, linha.horasIncluidas, KeyboardType.Number, bloqueado, "horas-servico-$id", "horas_incluidas", campoComErro) { novo ->
                    aoEditar { it.copy(horasIncluidas = novo) }
                }
                "hora" -> Campo(TextosChamadaProfissional.SERVICOS_MINIMO_HORAS, linha.minimoHoras, KeyboardType.Number, bloqueado, "minimo-horas-$id", "minimo_horas", campoComErro) { novo ->
                    aoEditar { it.copy(minimoHoras = novo) }
                }
                "evento" -> {
                    Campo(TextosChamadaProfissional.SERVICOS_DURACAO, linha.duracaoTipicaH, KeyboardType.Number, bloqueado, "duracao-servico-$id", "duracao_tipica_h", campoComErro) { novo ->
                        aoEditar { it.copy(duracaoTipicaH = novo) }
                    }
                    Campo(TextosChamadaProfissional.SERVICOS_ATE_PESSOAS, linha.atePessoas, KeyboardType.Number, bloqueado, "ate-pessoas-$id", "ate_pessoas", campoComErro) { novo ->
                        aoEditar { it.copy(atePessoas = novo) }
                    }
                }
                "pacote" -> Campo(TextosChamadaProfissional.SERVICOS_DESCRICAO_PACOTE, linha.descricaoPacote, KeyboardType.Text, bloqueado, "pacote-servico-$id", "descricao_pacote", campoComErro) { novo ->
                    aoEditar { it.copy(descricaoPacote = novo) }
                }
                "por_pessoa" -> Campo(TextosChamadaProfissional.SERVICOS_MINIMO_PESSOAS, linha.minimoPessoas, KeyboardType.Number, bloqueado, "minimo-pessoas-$id", "minimo_pessoas", campoComErro) { novo ->
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
            Campo(TextosChamadaProfissional.SERVICOS_INCLUI, linha.inclui, KeyboardType.Text, bloqueado, "inclui-servico-$id", "inclui", campoComErro, umaLinha = false) { novo ->
                aoEditar { it.copy(inclui = novo) }
            }

            if (especialidades.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(TextosChamadaProfissional.SERVICOS_ESPECIALIDADES)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                        especialidades.forEach { especialidade ->
                            val marcada = especialidade.id in linha.especialidadeIds
                            ChipFrila(
                                texto = especialidade.nome,
                                selecionado = marcada,
                                aoClicar = { aoAlternarEspecialidade(especialidade.id, !marcada) },
                                habilitado = !bloqueado && (marcada || linha.especialidadeIds.size < MAXIMO_DE_ESPECIALIDADES),
                            )
                        }
                    }
                }
            }
            if (campoComErro != null && campoComErro !in camposNaTela) {
                Text(
                    text = TextosChamadaProfissional.campo(campoComErro),
                    style = FrilaTipo.corpo,
                    color = FrilaTema.cores.tinta,
                    modifier = Modifier.testTag("erro-servico-$campoComErro"),
                )
            }
        }
    }
}

/** Os campos do contrato que a tela desenha para a unidade de preço da linha. */
private fun camposNaTela(linha: ServicoEmEdicao): Set<String> = buildSet {
    if (!linha.habilitado) return@buildSet
    add("inclui")
    if (linha.unidade != "a_combinar") add("valor_centavos")
    if (linha.unidade in listOf("hora", "diaria", "pacote")) add("valor_max_centavos")
    when (linha.unidade) {
        "diaria" -> add("horas_incluidas")
        "hora" -> add("minimo_horas")
        "evento" -> {
            add("duracao_tipica_h")
            add("ate_pessoas")
        }
        "pacote" -> add("descricao_pacote")
        "por_pessoa" -> add("minimo_pessoas")
    }
}

/**
 * Campo de texto da linha. Se a API recusou este campo (`campoDoContrato`), o erro vai embaixo dele, escrito em
 * tinta, e o `testTag` `erro-servico-<campo>` marca o campo com erro.
 */
@Composable
private fun Campo(
    rotulo: String,
    valor: String,
    teclado: KeyboardType,
    bloqueado: Boolean,
    etiqueta: String,
    campoDoContrato: String,
    campoComErro: String?,
    umaLinha: Boolean = true,
    aoMudar: (String) -> Unit,
) {
    val comErro = campoComErro == campoDoContrato
    Box(modifier = if (comErro) Modifier.testTag("erro-servico-$campoDoContrato") else Modifier) {
        CampoDeTexto(
            valor = valor,
            aoMudar = aoMudar,
            rotulo = rotulo,
            habilitado = !bloqueado,
            umaLinha = umaLinha,
            keyboardOptions = KeyboardOptions(keyboardType = teclado),
            erro = if (comErro) TextosChamadaProfissional.campo(campoDoContrato) else null,
            modifier = Modifier.testTag(etiqueta),
        )
    }
}

/** "R$ 800,00 por diária de 8 h", quando a diária tem valor e horas válidos (como o iOS). */
private fun resumoDaDiaria(linha: ServicoEmEdicao): String? {
    if (linha.unidade != "diaria") return null
    val oferta = runCatching { linha.oferta() }.getOrNull() ?: return null
    val centavos = oferta.valorCentavos ?: return null
    val horas = oferta.horasIncluidas ?: return null
    return TextosChamadaProfissional.resumoDaDiaria(FormatoChamada.dinheiro(centavos), horas)
}
