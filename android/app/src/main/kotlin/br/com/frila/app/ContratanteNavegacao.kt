package br.com.frila.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import br.com.frila.core.dominio.regra.ListaAtualizavel
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.feature.equipe.IncluirNaEquipe
import br.com.frila.feature.equipe.IncluirNaEquipeViewModel
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.TelaTurnoDoContratante
import br.com.frila.feature.vagas.escala.EscalaDeEventoViewModel
import br.com.frila.feature.vagas.escala.TelaEscalaDeEvento
import br.com.frila.feature.vagas.escala.TextosEscala
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.PublicarVagaViewModel
import br.com.frila.feature.vagas.publicacao.TelaPublicarVaga
import java.time.Instant
import kotlinx.coroutines.CancellationException
import org.koin.androidx.compose.koinViewModel
import org.koin.compose.getKoin
import org.koin.core.parameter.parametersOf

/** Textos da carga do estabelecimento antes do formulário de publicação. */
internal object TextosPublicarVagaDaRota {
    const val CARREGANDO = "Carregando o estabelecimento…"
    const val TITULO_FALHA = "Não foi possível abrir a publicação"
    const val FALHA = "Não foi possível carregar os dados do estabelecimento. Verifique sua conexão e tente novamente."
    const val SEM_PERMISSAO = "Você não é membro deste estabelecimento, então não pode publicar vagas nele."
}

/** O que o perfil sabe sobre as casas da conta, para decidir quais atalhos de contratante mostrar. */
internal sealed interface CasasDaConta {
    /** Não foi possível saber (profissional, sem rede, sem o serviço): nenhum atalho de contratante. */
    data object Desconhecidas : CasasDaConta

    /** Contratante sem estabelecimento: pode cadastrar o primeiro. */
    data object Nenhuma : CasasDaConta

    /**
     * A casa em uso, para a equipe, a publicação e Minhas vagas: a que a pessoa escolheu em "Trocar de casa" ou, sem
     * escolha, a primeira por nome. [papel] é o de quem chama nela (`null` se o servidor mandou um papel que o app não
     * conhece); [total] é quantas casas a conta tem, e só com mais de uma "Trocar de casa" faz sentido.
     */
    data class Primeira(val id: String, val nome: String, val papel: PapelMembro? = null, val total: Int = 1) : CasasDaConta
}

/**
 * Casas da conta (a lista vem ordenada por nome). Qualquer falha (conta de profissional recebe `422
 * perfil_incompativel`, sem rede, resposta ilegível, sem o serviço no grafo) é [CasasDaConta.Desconhecidas]:
 * o perfil nunca quebra por causa disso, e conta de profissional nunca é convidada a cadastrar uma casa.
 */
internal suspend fun buscarCasasDaConta(servicoMembros: ServicoMembros?, preferidaId: String? = null): CasasDaConta = try {
    val casas = servicoMembros?.listarMeusEstabelecimentos().orEmpty()
    // A casa escolhida em "Trocar de casa" vale enquanto a conta ainda é membro dela; senão, a primeira por nome.
    (casas.firstOrNull { it.id == preferidaId } ?: casas.firstOrNull())
        ?.let { CasasDaConta.Primeira(it.id, it.nome, PapelMembro.deChave(it.papel), casas.size) }
        ?: if (servicoMembros == null) CasasDaConta.Desconhecidas else CasasDaConta.Nenhuma
} catch (erro: CancellationException) {
    throw erro
} catch (_: Exception) {
    CasasDaConta.Desconhecidas
}

internal sealed interface EstadoDoEstabelecimentoDaRota {
    data object Carregando : EstadoDoEstabelecimentoDaRota
    data class Pronto(val estabelecimento: EstabelecimentoDaVaga) : EstadoDoEstabelecimentoDaRota
    data class Falha(val semPermissao: Boolean) : EstadoDoEstabelecimentoDaRota
}

/** Lê `meu_estabelecimento`; qualquer falha vira [EstadoDoEstabelecimentoDaRota.Falha], nunca derruba a tela. */
internal suspend fun carregarEstabelecimentoDaVaga(
    servicoMembros: ServicoMembros?,
    estabelecimentoId: String,
): EstadoDoEstabelecimentoDaRota {
    if (servicoMembros == null) return EstadoDoEstabelecimentoDaRota.Falha(semPermissao = false)
    return try {
        val casa = servicoMembros.meuEstabelecimento(estabelecimentoId)
        EstadoDoEstabelecimentoDaRota.Pronto(
            EstabelecimentoDaVaga(
                id = casa.id,
                endereco = casa.endereco,
                regiaoAdministrativa = casa.regiaoAdministrativa,
                ponto = casa.ponto,
            ),
        )
    } catch (erro: CancellationException) {
        throw erro
    } catch (erro: ErroDaApi) {
        EstadoDoEstabelecimentoDaRota.Falha(semPermissao = erro.codigo == CodigoErroAPI.SEM_PERMISSAO)
    } catch (_: Exception) {
        // Corpo que não é JSON ou campo ausente escapam do ErroDaApi; sem isto o spinner ficaria para sempre.
        EstadoDoEstabelecimentoDaRota.Falha(semPermissao = false)
    }
}

/**
 * Rota de publicação de vaga: lê o estabelecimento da rota e só então cria o [PublicarVagaViewModel]
 * (que precisa do endereço, da Região Administrativa e do ponto, não só do id). Falha de carga mostra
 * o erro com "Tentar novamente"; quem não é membro (`403 sem_permissao`) vê o motivo, sem retentativa.
 * A confirmação "Vaga publicada." fica na própria tela, e o contratante sai por "Voltar".
 */
@Composable
internal fun RotaPublicarVaga(
    estabelecimentoId: String,
    servicoMembros: ServicoMembros?,
    aoVoltar: () -> Unit,
    /** Preenche a publicação antes de a pessoa ver (a busca vazia leva o serviço e o horário buscados). */
    aoPreparar: ((PublicarVagaViewModel) -> Unit)? = null,
) {
    var tentativa by remember { mutableIntStateOf(0) }
    var estado by remember(estabelecimentoId) { mutableStateOf<EstadoDoEstabelecimentoDaRota>(EstadoDoEstabelecimentoDaRota.Carregando) }
    LaunchedEffect(estabelecimentoId, tentativa, servicoMembros) {
        estado = EstadoDoEstabelecimentoDaRota.Carregando
        estado = carregarEstabelecimentoDaVaga(servicoMembros, estabelecimentoId)
    }

    when (val atual = estado) {
        EstadoDoEstabelecimentoDaRota.Carregando -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            IndicadorCarregando()
        }
        is EstadoDoEstabelecimentoDaRota.Falha -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EstadoErro(
                titulo = TextosPublicarVagaDaRota.TITULO_FALHA,
                mensagem = if (atual.semPermissao) TextosPublicarVagaDaRota.SEM_PERMISSAO else TextosPublicarVagaDaRota.FALHA,
                aoTentarNovamente = if (atual.semPermissao) null else { { tentativa++ } },
            )
        }
        is EstadoDoEstabelecimentoDaRota.Pronto -> {
            val viewModel: PublicarVagaViewModel = koinViewModel(parameters = { parametersOf(atual.estabelecimento) })
            if (aoPreparar != null) LaunchedEffect(viewModel) { aoPreparar(viewModel) }
            TelaPublicarVaga(viewModel = viewModel, aoPublicar = { }, aoVoltar = aoVoltar)
        }
    }
}

/**
 * Rota da escala de evento (RF19): como a publicação de vaga, lê o estabelecimento da rota (endereço, região e ponto
 * vêm do cadastro) e só então cria o [EscalaDeEventoViewModel]. Falha de carga mostra o erro com "Tentar novamente";
 * quem não é membro (`403 sem_permissao`) vê o motivo, sem retentativa. Publicada, "Ver minhas vagas" chama [aoConcluir].
 */
@Composable
internal fun RotaEscalaDeEvento(
    estabelecimentoId: String,
    servicoMembros: ServicoMembros?,
    aoVoltar: () -> Unit,
    aoConcluir: () -> Unit,
) {
    var tentativa by remember { mutableIntStateOf(0) }
    var estado by remember(estabelecimentoId) { mutableStateOf<EstadoDoEstabelecimentoDaRota>(EstadoDoEstabelecimentoDaRota.Carregando) }
    LaunchedEffect(estabelecimentoId, tentativa, servicoMembros) {
        estado = EstadoDoEstabelecimentoDaRota.Carregando
        estado = carregarEstabelecimentoDaVaga(servicoMembros, estabelecimentoId)
    }

    when (val atual = estado) {
        EstadoDoEstabelecimentoDaRota.Carregando -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            IndicadorCarregando()
        }
        is EstadoDoEstabelecimentoDaRota.Falha -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EstadoErro(
                titulo = TextosEscala.ROTA_TITULO_FALHA,
                mensagem = if (atual.semPermissao) TextosPublicarVagaDaRota.SEM_PERMISSAO else TextosPublicarVagaDaRota.FALHA,
                aoTentarNovamente = if (atual.semPermissao) null else { { tentativa++ } },
            )
        }
        is EstadoDoEstabelecimentoDaRota.Pronto -> {
            val viewModel: EscalaDeEventoViewModel = koinViewModel(parameters = { parametersOf(atual.estabelecimento) })
            TelaEscalaDeEvento(viewModel = viewModel, aoConcluir = aoConcluir, aoVoltar = aoVoltar)
        }
    }
}

/**
 * Passa a usar a casa [id] (trocar de casa ou entrar numa por convite): a raiz do contratante aponta para as vagas dela e a
 * pilha recomeça ali, sem a tela anterior por baixo. Com a aba "Minhas vagas" na pilha, ela é que dá lugar; sem ela (conta
 * que ainda não tinha casa e abriu pelo Perfil), o Perfil é o chão que sai. [nome] pode faltar (convite aceito): a lista de
 * vagas aceita a casa sem nome.
 */
internal fun abrirCasa(
    navController: androidx.navigation.NavHostController,
    id: String,
    nome: String?,
    definirPapelDaRaiz: (PapelDaRaiz) -> Unit,
    definirCasaEscolhida: (String) -> Unit,
) {
    val rota = Rotas.minhasVagas(id, nome)
    definirPapelDaRaiz(PapelDaRaiz.Contratante(id, rota))
    definirCasaEscolhida(id)
    val abaNaPilha = runCatching { navController.getBackStackEntry(Rotas.MINHAS_VAGAS) }.isSuccess
    navController.navigate(rota) {
        popUpTo(if (abaNaPilha) Rotas.MINHAS_VAGAS else Rotas.PERFIL) { inclusive = true }
        launchSingleTop = true
    }
}

/** Textos da carga do turno antes da tela de acompanhamento. */
internal object TextosTurnoDoContratanteDaRota {
    const val TITULO_FALHA = "Não foi possível abrir o turno"
    const val FALHA = "Não foi possível carregar o turno. Verifique sua conexão e tente novamente."
    const val NAO_ENCONTRADO = "Não encontramos este turno. Ele pode ter sido cancelado."
    const val SEM_PERMISSAO = "Você não é membro deste estabelecimento, então não pode acompanhar o turno dele."
}

internal sealed interface EstadoDoTurnoDaRota {
    data object Carregando : EstadoDoTurnoDaRota
    data class Pronto(val contexto: ContextoDoTurnoContratante) : EstadoDoTurnoDaRota
    /** [naoEncontrado]: o painel respondeu e o turno não está nele. */
    data class Falha(val motivo: String, val podeTentarDeNovo: Boolean, val naoEncontrado: Boolean = false) : EstadoDoTurnoDaRota
}

/**
 * Lê o painel do estabelecimento e acha a posição pedida, com o turno dela: o Android não tem leitura de
 * turno para o contratante, e o painel é a fonte (a mesma do iOS). Com [turnoId] (o toque num push, que não traz a
 * posição), a posição é a que tem aquele `turno_id`. Painel de outra casa, vaga ou posição
 * que sumiu, ou posição sem turno viram [EstadoDoTurnoDaRota.Falha] "não encontrado"; qualquer falha da
 * leitura também vira Falha, nunca derruba a tela.
 */
internal suspend fun carregarTurnoDoContratante(
    buscarPainel: (suspend (estabelecimentoId: String, de: Instant, ate: Instant) -> Result<PainelDto>)?,
    estabelecimentoId: String,
    vagaId: String,
    posicaoId: String,
    agora: Instant = Instant.now(),
    turnoId: String? = null,
): EstadoDoTurnoDaRota {
    if (buscarPainel == null) return EstadoDoTurnoDaRota.Falha(TextosTurnoDoContratanteDaRota.FALHA, podeTentarDeNovo = false)
    val hoje = agora.atZone(MinhasVagasViewModel.FUSO_DO_PAINEL)
    val resultado = try {
        buscarPainel(
            estabelecimentoId,
            hoje.minusDays(MinhasVagasViewModel.JANELA_EM_DIAS).toInstant(),
            hoje.plusDays(MinhasVagasViewModel.JANELA_EM_DIAS).toInstant(),
        )
    } catch (erro: CancellationException) {
        throw erro
    } catch (erro: Exception) {
        Result.failure(erro)
    }
    val painel = resultado.getOrElse { erro ->
        return if ((erro as? ErroDaApi)?.codigo == CodigoErroAPI.SEM_PERMISSAO) {
            EstadoDoTurnoDaRota.Falha(TextosTurnoDoContratanteDaRota.SEM_PERMISSAO, podeTentarDeNovo = false)
        } else {
            EstadoDoTurnoDaRota.Falha(TextosTurnoDoContratanteDaRota.FALHA, podeTentarDeNovo = true)
        }
    }
    val vagas = painel.vagas.takeIf { painel.estabelecimentoId == estabelecimentoId }.orEmpty()
    val contexto = if (turnoId != null) {
        vagas.firstNotNullOfOrNull { vaga ->
            vaga.posicoes.firstOrNull { it.turnoId == turnoId }?.let { ContextoDoTurnoContratante.dePainel(vaga.vaga, it, estabelecimentoId) }
        }
    } else {
        val vaga = vagas.firstOrNull { it.vaga.id == vagaId }
        vaga?.posicoes?.firstOrNull { it.id == posicaoId }?.let { ContextoDoTurnoContratante.dePainel(vaga.vaga, it, estabelecimentoId) }
    }
    return if (contexto == null) {
        EstadoDoTurnoDaRota.Falha(TextosTurnoDoContratanteDaRota.NAO_ENCONTRADO, podeTentarDeNovo = false, naoEncontrado = true)
    } else {
        EstadoDoTurnoDaRota.Pronto(contexto)
    }
}

/**
 * Rota do turno pela casa: lê o turno do painel e só então cria o [AcompanhamentoContratanteViewModel]
 * (que recebe o contexto pronto). Falha de leitura mostra o erro com "Tentar novamente"; turno que não
 * existe mais e falta de permissão mostram o motivo, sem nova tentativa.
 */
@Composable
internal fun RotaTurnoDoContratante(
    estabelecimentoId: String,
    vagaId: String,
    posicaoId: String,
    buscarPainel: (suspend (String, Instant, Instant) -> Result<PainelDto>)?,
    aoVoltar: () -> Unit,
    /** C0-9: denunciar a profissional do turno (id do perfil público, id do turno). */
    aoDenunciarProfissional: ((profissionalId: String, turnoId: String) -> Unit)? = null,
    /** Pedir ajuda com o turno (id do turno): abre o relato de ocorrência. */
    aoPedirSuporte: ((turnoId: String) -> Unit)? = null,
    /** L1-5: chave `checkin_por_codigo`; ligada, a casa vê o código de chegada do turno e, ao confirmar, o turno é relido. */
    checkinPorCodigoHabilitado: Boolean = false,
    /** Item #27 da Paridade: avaliar o profissional pela casa. */
    aoAvaliarTurno: ((turnoId: String) -> Unit)? = null,
    /** O turno do aviso, quando a rota vem do toque num push e não sabe a vaga nem a posição. */
    turnoId: String? = null,
    /** Com ele, turno que não está no painel (aviso de outra casa) não mostra "não encontrado": quem chama decide. */
    aoNaoEncontrar: (() -> Unit)? = null,
) {
    var tentativa by remember { mutableIntStateOf(0) }
    var estado by remember(estabelecimentoId, vagaId, posicaoId, turnoId) { mutableStateOf<EstadoDoTurnoDaRota>(EstadoDoTurnoDaRota.Carregando) }
    LaunchedEffect(estabelecimentoId, vagaId, posicaoId, turnoId, tentativa) {
        estado = EstadoDoTurnoDaRota.Carregando
        estado = carregarTurnoDoContratante(buscarPainel, estabelecimentoId, vagaId, posicaoId, turnoId = turnoId)
    }
    // HaRJJ0L0: relê o painel ao voltar do segundo plano e com um push, sem trocar o turno por "carregando"; a falha deixa o que está
    // na tela. A rota já carrega ao entrar, por isso a primeira vez ativa só conta como carga (no iOS, `.sempre`, porque lá a tela não carrega).
    getKoin().getOrNull<AtualizacaoAutomatica>()?.let { atualizacao ->
        AtualizacaoAutomaticaDaLista(ListaAtualizavel.TURNO_DO_CONTRATANTE, atualizacao) {
            if (estado is EstadoDoTurnoDaRota.Pronto) {
                val novo = carregarTurnoDoContratante(buscarPainel, estabelecimentoId, vagaId, posicaoId, turnoId = turnoId)
                if (novo is EstadoDoTurnoDaRota.Pronto) estado = novo
            }
        }
    }

    when (val atual = estado) {
        EstadoDoTurnoDaRota.Carregando -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { IndicadorCarregando() }
        is EstadoDoTurnoDaRota.Falha -> if (atual.naoEncontrado && aoNaoEncontrar != null) {
            LaunchedEffect(atual) { aoNaoEncontrar() }
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { IndicadorCarregando() }
        } else Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EstadoErro(
                titulo = TextosTurnoDoContratanteDaRota.TITULO_FALHA,
                mensagem = atual.motivo,
                aoTentarNovamente = if (atual.podeTentarDeNovo) { { tentativa++ } } else null,
            )
        }
        is EstadoDoTurnoDaRota.Pronto -> {
            val viewModel: AcompanhamentoContratanteViewModel = koinViewModel(parameters = { parametersOf(atual.contexto) })
            LaunchedEffect(viewModel, atual.contexto) {
                viewModel.atualizarContexto(atual.contexto)
            }
            val codigoDaCasa = codigoDaCasaDoTurno(checkinPorCodigoHabilitado, atual.contexto.turnoId) { tentativa++ }
            // L2-6: só com a presença verificada (a condição de `incluir_na_equipe`; o servidor confere de novo), como o iOS.
            // O bloco entra na própria tela do turno, depois da chegada.
            val profissional = atual.contexto.profissional?.takeIf { atual.contexto.verificacao == "verificado" }
            TelaTurnoDoContratante(
                viewModel = viewModel,
                aoVoltar = aoVoltar,
                aoDenunciarProfissional = aoDenunciarProfissional,
                aoPedirSuporte = aoPedirSuporte,
                codigoDaCasa = codigoDaCasa,
                aoAvaliarTurno = aoAvaliarTurno,
                depoisDaChegada = profissional?.let {
                    {
                        val incluir: IncluirNaEquipeViewModel = koinViewModel(
                            key = "incluir-${it.id}",
                            parameters = { parametersOf(estabelecimentoId, it.id) },
                        )
                        IncluirNaEquipe(viewModel = incluir, nome = it.nome)
                    }
                },
            )
        }
    }
}
