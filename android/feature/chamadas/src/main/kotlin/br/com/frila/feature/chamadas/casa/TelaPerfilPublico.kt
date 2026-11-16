package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ServicoNoPerfilDto

/** Liga o [PerfilPublicoViewModel] ao [ConteudoPerfilPublico]. */
@Composable
fun TelaPerfilPublico(
    viewModel: PerfilPublicoViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoChamar: ((PerfilPublicoDto) -> Unit)? = null,
    acoesDeSeguranca: @Composable (PerfilPublicoDto) -> Unit = {},
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoPerfilPublico(
        estado = estado,
        aoTentarNovamente = { viewModel.carregar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
        aoChamar = aoChamar,
        acoesDeSeguranca = acoesDeSeguranca,
    )
}

/**
 * Perfil público de um profissional (desenho do iOS `TelaPerfilPublico`): nome só com a inicial quando a casa
 * não tem vínculo (o servidor decide), serviços com preço, reputação, sobre mim, experiência, cursos, idiomas e
 * onde atende. [aoChamar] só aparece para um perfil de profissional e quando a chave `chamada_direta` está ligada
 * (quem monta a rota passa `null` com ela desligada); [acoesDeSeguranca] é o espaço de denunciar e bloquear.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoPerfilPublico(
    estado: EstadoPerfilPublico,
    aoTentarNovamente: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoChamar: ((PerfilPublicoDto) -> Unit)? = null,
    acoesDeSeguranca: @Composable (PerfilPublicoDto) -> Unit = {},
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosChamadaCasa.PERFIL_TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = TextosChamadaCasa.VOLTAR)
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
            when (estado) {
                EstadoPerfilPublico.Carregando -> IndicadorCarregando()
                EstadoPerfilPublico.Indisponivel -> AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = TextosChamadaCasa.PERFIL_INDISPONIVEL)
                is EstadoPerfilPublico.Falha -> EstadoErro(
                    titulo = estado.mensagem,
                    mensagem = null,
                    aoTentarNovamente = aoTentarNovamente,
                )
                is EstadoPerfilPublico.Carregado -> {
                    CorpoDoPerfil(estado.perfil)
                    if (aoChamar != null && estado.perfil.tipo == "profissional") {
                        BotaoPrimario(
                            texto = TextosChamadaCasa.TITULO_DA_FOLHA,
                            aoClicar = { aoChamar(estado.perfil) },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    acoesDeSeguranca(estado.perfil)
                }
            }
        }
    }
}

@Composable
private fun CorpoDoPerfil(perfil: PerfilPublicoDto) {
    Text(text = perfil.nome, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.semantics { heading() })
    perfil.funcoes?.takeIf { it.isNotEmpty() }?.let {
        Text(text = it.joinToString(", "), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
        Text(
            text = TextosChamadaCasa.reputacao(perfil.reputacao.positivas, perfil.reputacao.total),
            style = MaterialTheme.typography.titleSmall,
        )
        if (perfil.reputacao.total <= 0) {
            Text(text = TextosChamadaCasa.AINDA_SEM_TURNOS, style = MaterialTheme.typography.bodySmall)
        } else {
            TextosChamadaCasa.comparecimento(perfil.reputacao.turnosRealizados, perfil.reputacao.turnosConsiderados)?.let {
                Text(text = it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }

    perfil.servicos?.takeIf { it.isNotEmpty() }?.let { servicos ->
        Secao(TextosChamadaCasa.SERVICOS_OFERECIDOS) {
            servicos.forEach { ServicoDoPerfil(it) }
        }
    }
    perfil.apresentacao?.takeIf { it.isNotBlank() }?.let { Secao(TextosChamadaCasa.SOBRE_MIM) { Text(it, style = MaterialTheme.typography.bodyMedium) } }

    val faixa = perfil.experienciaFaixa
    val onde = perfil.ondeTrabalhei?.takeIf { it.isNotBlank() }
    if (faixa != null || onde != null) {
        Secao(TextosChamadaCasa.EXPERIENCIA) {
            faixa?.let { Text(TextosChamadaCasa.experiencia(it), style = MaterialTheme.typography.bodyMedium) }
            onde?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
    perfil.cursos?.takeIf { it.isNotEmpty() }?.let { cursos ->
        Secao(TextosChamadaCasa.CURSOS) { cursos.forEach { Text("• $it", style = MaterialTheme.typography.bodyMedium) } }
    }
    perfil.idiomas?.takeIf { it.isNotEmpty() }?.let { idiomas ->
        Secao(TextosChamadaCasa.IDIOMAS) {
            Text(idiomas.joinToString(", ") { TextosChamadaCasa.idioma(it) }, style = MaterialTheme.typography.bodyMedium)
        }
    }
    val regioes = perfil.regioes.orEmpty()
    if (perfil.atendeTodoDf == true || regioes.isNotEmpty()) {
        Secao(TextosChamadaCasa.ONDE_ATENDO) {
            Text(
                text = if (perfil.atendeTodoDf == true) TextosChamadaCasa.TODO_O_DF else regioes.joinToString(", ") { it.nome },
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun Secao(titulo: String, conteudo: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
        Text(text = titulo, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        conteudo()
    }
}

@Composable
private fun ServicoDoPerfil(servico: ServicoNoPerfilDto) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
        Text(text = servico.funcao.nome, style = MaterialTheme.typography.titleSmall)
        resumoDoServico(servico)?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary) }
        servico.inclui?.takeIf { it.isNotBlank() }?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        servico.especialidades?.takeIf { it.isNotEmpty() }?.let { especialidades ->
            Text(
                especialidades.joinToString(", ") { it.nome },
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
