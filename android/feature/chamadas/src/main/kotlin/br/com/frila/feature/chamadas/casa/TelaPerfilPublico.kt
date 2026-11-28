package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
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
    /** Bloqueado nesta tela, "Chamar" deixa de ser oferecido. Não esconde o perfil: o conjunto de bloqueios da sessão não existe. */
    bloqueado: Boolean = false,
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
        bloqueado = bloqueado,
    )
}

/**
 * Perfil público de um profissional, visto pela casa: tela de leitura, sem laranja a não ser a ação de chamar. Nome só
 * com a inicial quando a casa não tem vínculo (o servidor decide), reputação escrita como fato, serviços com preço,
 * sobre mim, experiência, cursos, idiomas e onde atende. [aoChamar] só aparece para um perfil de profissional e quando
 * a chave `chamada_direta` está ligada (quem monta a rota passa `null` com ela desligada); [acoesDeSeguranca] é o
 * espaço de denunciar e bloquear, no fim da tela.
 */
@Composable
fun ConteudoPerfilPublico(
    estado: EstadoPerfilPublico,
    aoTentarNovamente: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoChamar: ((PerfilPublicoDto) -> Unit)? = null,
    acoesDeSeguranca: @Composable (PerfilPublicoDto) -> Unit = {},
    bloqueado: Boolean = false,
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
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(TextosChamadaCasa.PERFIL_TITULO)
            when (estado) {
                EstadoPerfilPublico.Carregando -> EstadoCarregando()
                EstadoPerfilPublico.Indisponivel -> EstadoVazio(titulo = TextosChamadaCasa.PERFIL_INDISPONIVEL)
                is EstadoPerfilPublico.Falha -> EstadoErro(
                    titulo = estado.mensagem,
                    mensagem = null,
                    aoTentarNovamente = aoTentarNovamente,
                )
                is EstadoPerfilPublico.Carregado -> {
                    CorpoDoPerfil(estado.perfil)
                    if (aoChamar != null && !bloqueado && estado.perfil.tipo == "profissional") {
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
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
            Text(
                text = perfil.nome,
                style = FrilaTipo.nome,
                color = FrilaTema.cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
            perfil.funcoes?.takeIf { it.isNotEmpty() }?.let {
                Text(text = it.joinToString(", "), style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            }
            Text(
                text = TextosChamadaCasa.reputacao(perfil.reputacao.positivas, perfil.reputacao.total),
                style = FrilaTipo.rotuloSecundario,
                color = FrilaTema.cores.tinta,
            )
            if (perfil.reputacao.total <= 0) {
                Text(text = TextosChamadaCasa.AINDA_SEM_TURNOS, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            } else {
                TextosChamadaCasa.comparecimento(perfil.reputacao.turnosRealizados, perfil.reputacao.turnosConsiderados)?.let {
                    Text(text = it, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                }
            }
        }
    }

    perfil.servicos?.takeIf { it.isNotEmpty() }?.let { servicos ->
        Secao(TextosChamadaCasa.SERVICOS_OFERECIDOS) {
            servicos.forEach { ServicoDoPerfil(it) }
        }
    }
    perfil.apresentacao?.takeIf { it.isNotBlank() }?.let { Secao(TextosChamadaCasa.SOBRE_MIM) { Texto(it) } }

    val faixa = perfil.experienciaFaixa
    val onde = perfil.ondeTrabalhei?.takeIf { it.isNotBlank() }
    if (faixa != null || onde != null) {
        Secao(TextosChamadaCasa.EXPERIENCIA) {
            faixa?.let { Texto(TextosChamadaCasa.experiencia(it)) }
            onde?.let { Text(it, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave) }
        }
    }
    perfil.cursos?.takeIf { it.isNotEmpty() }?.let { cursos ->
        Secao(TextosChamadaCasa.CURSOS) { cursos.forEach { Texto("• $it") } }
    }
    perfil.idiomas?.takeIf { it.isNotEmpty() }?.let { idiomas ->
        Secao(TextosChamadaCasa.IDIOMAS) { Texto(idiomas.joinToString(", ") { TextosChamadaCasa.idioma(it) }) }
    }
    val regioes = perfil.regioes.orEmpty()
    if (perfil.atendeTodoDf == true || regioes.isNotEmpty()) {
        Secao(TextosChamadaCasa.ONDE_ATENDO) {
            Texto(if (perfil.atendeTodoDf == true) TextosChamadaCasa.TODO_O_DF else regioes.joinToString(", ") { it.nome })
        }
    }
}

@Composable
private fun Texto(texto: String) {
    Text(text = texto, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
}

@Composable
private fun Secao(titulo: String, conteudo: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(titulo)
        conteudo()
    }
}

@Composable
private fun ServicoDoPerfil(servico: ServicoNoPerfilDto) {
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
            Text(text = servico.funcao.nome, style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
            resumoDoServico(servico)?.let { Texto(it) }
            servico.inclui?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            }
            servico.especialidades?.takeIf { it.isNotEmpty() }?.let { especialidades ->
                Text(
                    especialidades.joinToString(", ") { it.nome },
                    style = FrilaTipo.legenda,
                    color = FrilaTema.cores.tintaSuave,
                )
            }
        }
    }
}
