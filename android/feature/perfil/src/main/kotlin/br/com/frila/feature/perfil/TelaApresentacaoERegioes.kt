package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Tudo o que a tela pode pedir ao [ApresentacaoERegioesViewModel] e a quem a abriu. */
data class AcoesApresentacaoERegioes(
    val aoMudarSobreMim: (String) -> Unit = {},
    val aoMudarOndeTrabalhei: (String) -> Unit = {},
    val aoEscolherExperiencia: (String?) -> Unit = {},
    val aoMudarNovoCurso: (String) -> Unit = {},
    val aoAdicionarCurso: () -> Unit = {},
    val aoRemoverCurso: (Int) -> Unit = {},
    val aoAlternarIdioma: (String) -> Unit = {},
    val aoAlternarTodoDf: (Boolean) -> Unit = {},
    val aoAlternarRegiao: (Int) -> Unit = {},
    val aoSalvar: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
)

/** Liga o [ApresentacaoERegioesViewModel] ao [ConteudoApresentacaoERegioes] e carrega o perfil ao abrir. */
@Composable
fun TelaApresentacaoERegioes(
    viewModel: ApresentacaoERegioesViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoApresentacaoERegioes(
        estado = estado,
        acoes = AcoesApresentacaoERegioes(
            aoMudarSobreMim = viewModel::alterarSobreMim,
            aoMudarOndeTrabalhei = viewModel::alterarOndeTrabalhei,
            aoEscolherExperiencia = viewModel::escolherExperiencia,
            aoMudarNovoCurso = viewModel::alterarNovoCurso,
            aoAdicionarCurso = viewModel::adicionarCurso,
            aoRemoverCurso = viewModel::removerCurso,
            aoAlternarIdioma = viewModel::alternarIdioma,
            aoAlternarTodoDf = viewModel::alternarTodoDf,
            aoAlternarRegiao = viewModel::alternarRegiao,
            aoSalvar = { viewModel.salvar() },
            aoVoltar = aoVoltar,
        ),
        modifier = modifier,
    )
}

/**
 * Apresentação e regiões do profissional (RN26/RN38/RN44): "Sobre mim", experiência, onde já trabalhou, cursos, idiomas e regiões.
 * Campos no sistema novo (rótulo acima, erro escrito embaixo), escolha única em lista com check e seleção múltipla em
 * chips. O Salvar é o único primário e fica no rodapé ancorado, com o resultado logo acima dele.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ConteudoApresentacaoERegioes(
    estado: EstadoApresentacaoERegioes,
    acoes: AcoesApresentacaoERegioes,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { BarraDeTopoDoPerfil(aoVoltar = acoes.aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                estado.erroGeral?.let { MensagemJuntoAoBotao(it) }
                if (estado.sucesso) MensagemJuntoAoBotao(TextosApresentacaoERegioes.SUCESSO)
                BotaoPrimario(
                    texto = if (estado.salvando) TextosApresentacaoERegioes.SALVANDO else TextosApresentacaoERegioes.SALVAR,
                    aoClicar = acoes.aoSalvar,
                    habilitado = !estado.salvando && !estado.carregando,
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
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                TituloDaTela(TextosApresentacaoERegioes.TITULO)
                if (estado.carregando) Text(TextosApresentacaoERegioes.CARREGANDO, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }

            CampoDeTextoLongo(
                valor = estado.sobreMim,
                rotulo = TextosApresentacaoERegioes.SOBRE_MIM,
                dica = TextosApresentacaoERegioes.SOBRE_MIM_DICA,
                etiqueta = "campo-sobre-mim",
                erro = estado.erroSobreMim,
                limite = ApresentacaoERegioesViewModel.LIMITE_SOBRE_MIM,
                aoMudar = acoes.aoMudarSobreMim,
            )

            Secao(TextosApresentacaoERegioes.EXPERIENCIA, TextosApresentacaoERegioes.EXPERIENCIA_DICA) {
                FrilaGrupoDeLinhas {
                    linha {
                        FrilaLinhaDeOpcao(
                            titulo = TextosApresentacaoERegioes.NAO_INFORMADO,
                            marcada = estado.experienciaFaixa == null,
                            aoClicar = { acoes.aoEscolherExperiencia(null) },
                        )
                    }
                    for (faixa in ApresentacaoERegioesViewModel.EXPERIENCIAS) {
                        linha {
                            FrilaLinhaDeOpcao(
                                titulo = TextosApresentacaoERegioes.experiencia(faixa),
                                marcada = estado.experienciaFaixa == faixa,
                                aoClicar = { acoes.aoEscolherExperiencia(faixa) },
                            )
                        }
                    }
                }
            }

            CampoDeTextoLongo(
                valor = estado.ondeTrabalhei,
                rotulo = TextosApresentacaoERegioes.ONDE_TRABALHEI,
                dica = TextosApresentacaoERegioes.ONDE_TRABALHEI_DICA,
                etiqueta = "campo-onde-trabalhei",
                erro = estado.erroOndeTrabalhei,
                limite = ApresentacaoERegioesViewModel.LIMITE_ONDE_TRABALHEI,
                aoMudar = acoes.aoMudarOndeTrabalhei,
            )

            Secao(TextosApresentacaoERegioes.CURSOS, null) {
                if (estado.cursos.isNotEmpty()) {
                    FrilaGrupoDeLinhas {
                        estado.cursos.forEachIndexed { indice, curso ->
                            linha {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(start = FrilaEspacamento.bloco),
                                ) {
                                    Text(curso, style = FrilaTipo.corpo, color = cores.tinta, modifier = Modifier.weight(1f))
                                    IconButton(
                                        onClick = { acoes.aoRemoverCurso(indice) },
                                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                                    ) {
                                        Icon(
                                            Icons.Filled.Close,
                                            contentDescription = "${TextosApresentacaoERegioes.REMOVER_CURSO}: $curso",
                                            tint = cores.tintaSuave,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                CampoDeTexto(
                    valor = estado.novoCurso,
                    aoMudar = acoes.aoMudarNovoCurso,
                    rotulo = TextosApresentacaoERegioes.CURSO_ROTULO,
                    erro = estado.erroCursos,
                    modifier = Modifier.testTag("campo-novo-curso"),
                )
                BotaoSecundario(texto = TextosApresentacaoERegioes.ADICIONAR_CURSO, aoClicar = acoes.aoAdicionarCurso)
            }

            Secao(TextosApresentacaoERegioes.IDIOMAS, TextosApresentacaoERegioes.IDIOMAS_DICA) {
                FlowRow(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    for (idioma in ApresentacaoERegioesViewModel.IDIOMAS) {
                        ChipFrila(
                            texto = TextosApresentacaoERegioes.idioma(idioma),
                            selecionado = idioma in estado.idiomas,
                            aoClicar = { acoes.aoAlternarIdioma(idioma) },
                        )
                    }
                }
            }

            Secao(TextosApresentacaoERegioes.REGIOES, TextosApresentacaoERegioes.REGIOES_DICA) {
                FrilaGrupoDeLinhas {
                    linha {
                        LinhaDeInterruptor(
                            rotulo = TextosApresentacaoERegioes.TODO_O_DF,
                            ativada = estado.atendeTodoDf,
                            aoAlternar = acoes.aoAlternarTodoDf,
                        )
                    }
                }
                FlowRow(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    for (regiao in estado.regioesDisponiveis) {
                        ChipFrila(
                            texto = "RA ${regiao.numero} · ${regiao.nome}",
                            selecionado = regiao.id in estado.regioesSelecionadas,
                            aoClicar = { acoes.aoAlternarRegiao(regiao.id) },
                        )
                    }
                }
                estado.erroRegioes?.let { AvisoFrila(tom = TomAviso.ERRO, mensagem = it) }
                Text(TextosApresentacaoERegioes.AVISO_PONTO_BASE, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }
        }
    }
}

/** Uma seção do formulário: o nome do grupo, a explicação em tinta suave (se houver) e o conteúdo. */
@Composable
private fun Secao(titulo: String, dica: String?, conteudo: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(titulo)
        dica?.let { Text(it, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave) }
        conteudo()
    }
}

/** Campo de texto de várias linhas com o contador "n/limite" embaixo (ou o erro, no lugar dele) e a dica depois. */
@Composable
private fun CampoDeTextoLongo(
    valor: String,
    rotulo: String,
    dica: String,
    etiqueta: String,
    erro: String?,
    limite: Int,
    aoMudar: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        CampoDeTexto(
            valor = valor,
            aoMudar = aoMudar,
            rotulo = rotulo,
            apoio = "${ApresentacaoERegioesViewModel.letras(valor)}/$limite",
            erro = erro,
            umaLinha = false,
            linhasMinimas = 3,
            modifier = Modifier.testTag(etiqueta),
        )
        Text(dica, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
    }
}
