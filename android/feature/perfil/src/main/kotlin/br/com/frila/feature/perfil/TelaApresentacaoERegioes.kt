package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

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
 * TELA PROVISÓRIA: só campos e listas nativos, sem estilo novo.
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoApresentacaoERegioes(
    estado: EstadoApresentacaoERegioes,
    acoes: AcoesApresentacaoERegioes,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        TextosApresentacaoERegioes.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = acoes.aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = TextosApresentacaoERegioes.VOLTAR)
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
                .padding(FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            if (estado.carregando) Text(TextosApresentacaoERegioes.CARREGANDO, style = MaterialTheme.typography.bodyMedium)
            estado.erroGeral?.let { Mensagem(it, erro = true) }

            Secao(TextosApresentacaoERegioes.SOBRE_MIM, TextosApresentacaoERegioes.SOBRE_MIM_DICA) {
                CampoDeTexto(
                    valor = estado.sobreMim,
                    rotulo = TextosApresentacaoERegioes.SOBRE_MIM,
                    etiqueta = "campo-sobre-mim",
                    erro = estado.erroSobreMim,
                    limite = ApresentacaoERegioesViewModel.LIMITE_SOBRE_MIM,
                    aoMudar = acoes.aoMudarSobreMim,
                )
            }

            Secao(TextosApresentacaoERegioes.EXPERIENCIA, TextosApresentacaoERegioes.EXPERIENCIA_DICA) {
                OpcaoUnica(TextosApresentacaoERegioes.NAO_INFORMADO, estado.experienciaFaixa == null) { acoes.aoEscolherExperiencia(null) }
                for (faixa in ApresentacaoERegioesViewModel.EXPERIENCIAS) {
                    OpcaoUnica(TextosApresentacaoERegioes.experiencia(faixa), estado.experienciaFaixa == faixa) {
                        acoes.aoEscolherExperiencia(faixa)
                    }
                }
            }

            Secao(TextosApresentacaoERegioes.ONDE_TRABALHEI, TextosApresentacaoERegioes.ONDE_TRABALHEI_DICA) {
                CampoDeTexto(
                    valor = estado.ondeTrabalhei,
                    rotulo = TextosApresentacaoERegioes.ONDE_TRABALHEI,
                    etiqueta = "campo-onde-trabalhei",
                    erro = estado.erroOndeTrabalhei,
                    limite = ApresentacaoERegioesViewModel.LIMITE_ONDE_TRABALHEI,
                    aoMudar = acoes.aoMudarOndeTrabalhei,
                )
            }

            Secao(TextosApresentacaoERegioes.CURSOS, null) {
                estado.cursos.forEachIndexed { indice, curso ->
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        Text(curso, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                        IconButton(
                            onClick = { acoes.aoRemoverCurso(indice) },
                            modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                        ) {
                            Icon(Icons.Filled.Close, contentDescription = "${TextosApresentacaoERegioes.REMOVER_CURSO}: $curso")
                        }
                    }
                }
                OutlinedTextField(
                    value = estado.novoCurso,
                    onValueChange = acoes.aoMudarNovoCurso,
                    label = { Text(TextosApresentacaoERegioes.CURSO_ROTULO) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("campo-novo-curso"),
                )
                estado.erroCursos?.let { Mensagem(it, erro = true) }
                BotaoSecundario(texto = TextosApresentacaoERegioes.ADICIONAR_CURSO, aoClicar = acoes.aoAdicionarCurso)
            }

            Secao(TextosApresentacaoERegioes.IDIOMAS, TextosApresentacaoERegioes.IDIOMAS_DICA) {
                for (idioma in ApresentacaoERegioesViewModel.IDIOMAS) {
                    OpcaoMarcavel(TextosApresentacaoERegioes.idioma(idioma), idioma in estado.idiomas) { acoes.aoAlternarIdioma(idioma) }
                }
            }

            Secao(TextosApresentacaoERegioes.REGIOES, TextosApresentacaoERegioes.REGIOES_DICA) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                        .toggleable(value = estado.atendeTodoDf, role = Role.Switch, onValueChange = acoes.aoAlternarTodoDf),
                ) {
                    Text(TextosApresentacaoERegioes.TODO_O_DF, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                    Switch(checked = estado.atendeTodoDf, onCheckedChange = null)
                }
                for (regiao in estado.regioesDisponiveis) {
                    OpcaoMarcavel("RA ${regiao.numero} · ${regiao.nome}", regiao.id in estado.regioesSelecionadas) {
                        acoes.aoAlternarRegiao(regiao.id)
                    }
                }
                estado.erroRegioes?.let { Mensagem(it, erro = true) }
                Text(
                    TextosApresentacaoERegioes.AVISO_PONTO_BASE,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (estado.sucesso) Mensagem(TextosApresentacaoERegioes.SUCESSO, erro = false)
            BotaoPrimario(
                texto = if (estado.salvando) TextosApresentacaoERegioes.SALVANDO else TextosApresentacaoERegioes.SALVAR,
                aoClicar = acoes.aoSalvar,
                habilitado = !estado.salvando && !estado.carregando,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun Secao(titulo: String, dica: String?, conteudo: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        Text(titulo, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        dica?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        conteudo()
    }
}

@Composable
private fun CampoDeTexto(valor: String, rotulo: String, etiqueta: String, erro: String?, limite: Int, aoMudar: (String) -> Unit) {
    OutlinedTextField(
        value = valor,
        onValueChange = aoMudar,
        label = { Text(rotulo) },
        isError = erro != null,
        supportingText = { Text(erro ?: "${ApresentacaoERegioesViewModel.letras(valor)}/$limite") },
        minLines = 3,
        modifier = Modifier.fillMaxWidth().testTag(etiqueta),
    )
}

@Composable
private fun OpcaoUnica(texto: String, escolhida: Boolean, aoEscolher: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .selectable(selected = escolhida, role = Role.RadioButton, onClick = aoEscolher),
    ) {
        RadioButton(selected = escolhida, onClick = null)
        Text(texto, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(start = FrilaEspacamento.pequeno))
    }
}

@Composable
private fun OpcaoMarcavel(texto: String, marcada: Boolean, aoAlternar: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .toggleable(value = marcada, role = Role.Checkbox, onValueChange = { aoAlternar() }),
    ) {
        Checkbox(checked = marcada, onCheckedChange = null)
        Text(texto, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(start = FrilaEspacamento.pequeno))
    }
}

@Composable
private fun Mensagem(texto: String, erro: Boolean) {
    Text(
        text = texto,
        style = MaterialTheme.typography.bodyMedium,
        color = if (erro) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.semantics { liveRegion = if (erro) LiveRegionMode.Assertive else LiveRegionMode.Polite },
    )
}
