package br.com.frila.app

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import br.com.frila.app.falhas.GerenciadorConsentimentoCrashlytics
import br.com.frila.app.falhas.TelaConsentimentoCrashlytics
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import br.com.frila.core.dominio.regra.ListaAtualizavel
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import br.com.frila.feature.chamadas.casa.TelaPerfilPublico
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.conta.ContaSuspensaViewModel
import br.com.frila.feature.conta.ContestarDespachoViewModel
import br.com.frila.feature.conta.TelaContaSuspensaComContestacao
import br.com.frila.feature.conta.TelaContestarDespacho
import br.com.frila.feature.conta.TextosContestarDespacho
import br.com.frila.feature.conta.TelaExclusaoDeConta
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.cadastro.PerfilDaConta
import br.com.frila.feature.entrada.cadastro.TelaCadastro
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.codigo.ModoCodigo
import br.com.frila.feature.entrada.codigo.TelaCodigo
import br.com.frila.feature.entrada.criar.CriarContaViewModel
import br.com.frila.feature.entrada.criar.TelaCriarConta
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.TelaEntrada
import br.com.frila.feature.entrada.recuperacao.RecuperacaoSenhaViewModel
import br.com.frila.feature.entrada.recuperacao.TelaRecuperacaoSenha
import br.com.frila.feature.entrada.senha.DefinirSenhaViewModel
import br.com.frila.feature.entrada.senha.EntradaComSenhaViewModel
import br.com.frila.feature.entrada.senha.TelaDefinirSenha
import br.com.frila.feature.entrada.senha.TelaEntradaComSenha
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import br.com.frila.feature.vagas.candidatos.TelaCandidatosDaVaga
import br.com.frila.feature.vagas.candidaturas.DestinoDaCandidatura
import br.com.frila.feature.vagas.candidaturas.ItemCandidatura
import br.com.frila.feature.vagas.candidaturas.MinhasCandidaturasViewModel
import br.com.frila.feature.vagas.candidaturas.RetirarCandidaturaViewModel
import br.com.frila.feature.vagas.candidaturas.TelaMinhasCandidaturas
import br.com.frila.feature.vagas.candidaturas.TelaRetirarCandidatura
import br.com.frila.feature.vagas.candidaturas.TextosCandidaturas
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.detalhe.MotivoIndisponibilidadeVaga
import br.com.frila.feature.vagas.detalhe.ModoPreenchimentoVaga
import br.com.frila.feature.vagas.detalhe.TelaAberturaDeVaga
import br.com.frila.feature.vagas.detalhe.TelaDetalheVaga
import br.com.frila.feature.vagas.detalhe.TelaTurnoConfirmado
import br.com.frila.feature.vagas.detalhe.TelaConflitoHorario
import br.com.frila.feature.vagas.detalhe.paraVagaAberta
import br.com.frila.feature.vagas.detalhe.TelaVagaIndisponivel
import br.com.frila.feature.turnos.contratante.TelaAvaliacaoDoContratante
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import br.com.frila.feature.vagas.feed.TelaFeedVagas
import br.com.frila.feature.vagas.escala.TextosEscala
import br.com.frila.feature.vagas.painel.CancelarVagaViewModel
import br.com.frila.feature.vagas.painel.ItemMinhaVaga
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.painel.RepublicarPosicoesRestantesViewModel
import br.com.frila.feature.vagas.painel.RepublicarVagaViewModel
import br.com.frila.feature.vagas.painel.TelaCancelarVaga
import br.com.frila.feature.vagas.painel.TelaMinhasVagas
import br.com.frila.feature.vagas.painel.TelaRepublicarPosicoesRestantes
import br.com.frila.feature.vagas.painel.TelaRepublicarVaga
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
import br.com.frila.feature.equipe.casa.TelaTenhoUmConvite
import br.com.frila.feature.equipe.casa.TelaTrocarDeCasa
import br.com.frila.feature.equipe.casa.TenhoUmConviteViewModel
import br.com.frila.feature.equipe.casa.TextosEquipeDaCasa
import br.com.frila.feature.equipe.casa.TrocarDeCasaViewModel
import br.com.frila.feature.equipe.TelaEquipeDeConfianca
import br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel
import br.com.frila.feature.estabelecimento.TelaCadastroEstabelecimento
import br.com.frila.feature.perfil.AtalhoDaConta
import br.com.frila.feature.perfil.EnderecosOficiais
import br.com.frila.feature.perfil.ApresentacaoERegioesViewModel
import br.com.frila.feature.perfil.PontoBaseViewModel
import br.com.frila.feature.perfil.FuncoesEHorariosViewModel
import br.com.frila.feature.perfil.HistoricoDeTurnosViewModel
import br.com.frila.feature.perfil.PorQueReceboVagasViewModel
import br.com.frila.feature.perfil.FotoDePerfilViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.TelaApresentacaoERegioes
import br.com.frila.feature.perfil.TelaPontoBase
import br.com.frila.feature.perfil.TelaFuncoesEHorarios
import br.com.frila.feature.perfil.TelaHistoricoDeTurnos
import br.com.frila.feature.perfil.TelaPorQueReceboVagas
import br.com.frila.feature.perfil.TelaFotoDePerfilConectada
import br.com.frila.feature.perfil.TelaAjudaPerfil
import br.com.frila.feature.perfil.TelaLicencas
import br.com.frila.feature.perfil.TelaPerfil
import br.com.frila.feature.perfil.TelaVerificacaoDocumento
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.suporte.BloqueiosViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.suporte.TelaBloqueios
import br.com.frila.feature.suporte.TextosBloqueios
import br.com.frila.feature.suporte.TelaDenuncia
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import br.com.frila.feature.turnos.StatusMeusTurnos
import br.com.frila.feature.turnos.TelaAvaliacao
import br.com.frila.feature.turnos.TelaMeusTurnos
import br.com.frila.feature.turnos.TelaOcorrencia
import br.com.frila.feature.turnos.TelaTurnoNaoEncontrado
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import org.koin.androidx.compose.koinViewModel
import org.koin.compose.getKoin
import org.koin.compose.koinInject
import org.koin.core.parameter.parametersOf

/** Rotas da navegação declarativa. Única fonte de verdade dos destinos possíveis do app. */
/** Marcas de teste das duas linhas que o app põe no grupo da conta do Perfil. */
internal const val ENTRADA_BLOQUEIOS = "entrada-bloqueios"
internal const val ENTRADA_PUBLICAR_ESCALA = "entrada-publicar-escala"
internal const val ENTRADA_EQUIPE_DA_CASA = "entrada-equipe-da-casa"
internal const val ENTRADA_TENHO_UM_CONVITE = "entrada-tenho-um-convite"
internal const val ENTRADA_TROCAR_DE_CASA = "entrada-trocar-de-casa"
internal const val ENTRADA_CONTESTAR_DESPACHO = "entrada-contestar-despacho"
internal const val ENTRADA_SENHA_DA_CONTA = "entrada-senha-da-conta"

object Rotas {
    const val ENTRADA = "entrada"
    const val CRIAR_CONTA = "criar_conta?email={email}"
    const val RECUPERAR_SENHA = "recuperar_senha?email={email}"
    const val CODIGO = "codigo/{email}?modo={modo}&desafioId={desafioId}&reenviarEmSegundos={reenviarEmSegundos}"
    const val DEFINIR_SENHA = "definir_senha?origem={origem}&manterDispositivo={manterDispositivo}&email={email}"
    const val CADASTRO = "cadastro"
    /** Pergunta ao servidor quem é a conta e segue para a tela do papel (#782, #783). */
    const val ABERTURA = "abertura"
    const val FEED = "feed"
    const val DETALHE = "detalhe/{vagaId}"
    const val MEUS_TURNOS = "meus_turnos"
    const val AVALIACAO = "avaliacao/{turnoId}"
    const val PERFIL = "perfil"
    const val APRESENTACAO = "perfil_apresentacao"
    const val PONTO_BASE = "perfil_ponto_base"
    const val FUNCOES_E_HORARIOS = "perfil_funcoes_e_horarios"
    const val HISTORICO_TURNOS = "perfil_historico_turnos"
    const val POR_QUE_RECEBO_VAGAS = "por_que_recebo_vagas"
    const val FOTO_DE_PERFIL = "perfil_foto"
    const val SELO_CONFIANCA = "selo_confianca"
    const val OCORRENCIA = "ocorrencia/{turnoId}"
    const val DESBLOQUEIO = "desbloqueio"
    const val APARENCIA = "aparencia"
    const val AJUDA = "ajuda"
    const val LICENCAS = "licencas"
    /** O perfil público da casa, aberto pelo nome dela no detalhe da vaga (3k9E6ojp). */
    const val PERFIL_DA_CASA = "vaga_casa/{estabelecimentoId}"
    fun perfilDaCasa(estabelecimentoId: String) = "vaga_casa/$estabelecimentoId"
    const val VAGA_INDISPONIVEL = "vaga_indisponivel"
    const val ATUALIZACAO_OBRIGATORIA = "atualizacao_obrigatoria"
    const val TURNO_NAO_ENCONTRADO = "turno_nao_encontrado"
    const val TURNO_AVISO = "meus_turnos/{turnoId}"
    const val EXCLUSAO_DE_CONTA = "exclusao_de_conta"
    const val CONTA_SUSPENSA = "conta_suspensa?motivo={motivo}&desde={desde}"
    const val DENUNCIA = "denuncia/{alvoTipo}/{alvoId}?turnoId={turnoId}&chamadaId={chamadaId}&fotoId={fotoId}"
    const val EQUIPE = "equipe/{estabelecimentoId}"
    const val CADASTRO_ESTABELECIMENTO = "cadastro_estabelecimento"
    const val PUBLICAR_VAGA = "publicar_vaga/{estabelecimentoId}"
    const val PUBLICAR_ESCALA = "publicar_escala/{estabelecimentoId}"
    const val EQUIPE_DA_CASA = "equipe_da_casa/{estabelecimentoId}"
    const val TENHO_UM_CONVITE = "tenho_um_convite"
    const val TROCAR_DE_CASA = "trocar_de_casa?atual={atual}"
    const val MINHAS_VAGAS = "minhas_vagas/{estabelecimentoId}?nomeEstabelecimento={nomeEstabelecimento}&vagaRecemPublicadaId={vagaRecemPublicadaId}"
    const val TURNO_DO_CONTRATANTE = "turno_do_contratante/{estabelecimentoId}/{vagaId}/{posicaoId}"
    /** O turno da casa aberto pelo toque num push, que traz o `turno_id` e não a vaga nem a posição. */
    const val TURNO_DO_CONTRATANTE_AVISO = "turno_do_contratante_aviso/{estabelecimentoId}/{turnoId}"
    const val CANDIDATOS_DA_VAGA = "candidatos_da_vaga/{vagaId}?posicoesAbertas={posicoesAbertas}&inicioDaVaga={inicioDaVaga}&estabelecimentoId={estabelecimentoId}"

    // Lote 2 do Android (L2-8).
    const val CANCELAR_VAGA = "cancelar_vaga/{vagaId}?inicioDaVaga={inicioDaVaga}"
    const val REPUBLICAR_VAGA = "republicar_vaga/{vagaId}?selecao={selecao}&duracaoMin={duracaoMin}"
    const val MINHAS_CANDIDATURAS = "minhas_candidaturas"
    const val BLOQUEIOS = "bloqueios"
    const val CONTESTAR_DESPACHO = "contestar_despacho"
    const val CONSENTIMENTO_FALHAS = "consentimento_falhas"

    // Paridade iOS - Lote A (#6, #7, #8, #9, #10, #27)
    const val TURNO_CONFIRMADO = "turno_confirmado/{vagaId}"
    const val CONFLITO_HORARIO = "conflito_horario/{vagaId}"
    const val VAGA_PREENCHIDA = "vaga_preenchida/{vagaId}"
    const val VAGA_ENCERRADA = "vaga_encerrada/{vagaId}"
    const val AVALIACAO_DO_CONTRATANTE = "avaliacao_contratante/{turnoId}?estabelecimentoId={estabelecimentoId}"

    fun turnoConfirmado(vagaId: String) = "turno_confirmado/$vagaId"
    fun conflitoHorario(vagaId: String) = "conflito_horario/$vagaId"
    fun vagaPreenchida(vagaId: String) = "vaga_preenchida/$vagaId"
    fun vagaEncerrada(vagaId: String) = "vaga_encerrada/$vagaId"
    fun avaliacaoDoContratante(turnoId: String, estabelecimentoId: String? = null): String {
        val base = "avaliacao_contratante/$turnoId"
        return if (estabelecimentoId == null) base else "$base?estabelecimentoId=${Uri.encode(estabelecimentoId)}"
    }

    fun codigo(
        email: String,
        modo: ModoCodigo = ModoCodigo.ENTRADA,
        desafioId: String? = null,
        reenviarEmSegundos: Int? = null,
    ): String {
        val esperaValida = reenviarEmSegundos?.takeIf { it > 0 }
        val base = if (modo == ModoCodigo.ENTRADA && desafioId.isNullOrBlank() && esperaValida == null) {
            "codigo/$email"
        } else {
            val params = buildList {
                if (modo != ModoCodigo.ENTRADA) add("modo=${modo.chave}")
                if (!desafioId.isNullOrBlank()) add("desafioId=${Uri.encode(desafioId)}")
                if (esperaValida != null) add("reenviarEmSegundos=$esperaValida")
            }
            "codigo/$email?${params.joinToString("&")}"
        }
        return base
    }

    fun criarConta(email: String = "") =
        if (email.isBlank()) "criar_conta" else "criar_conta?email=${Uri.encode(email)}"

    fun recuperarSenha(email: String = "") =
        if (email.isBlank()) "recuperar_senha" else "recuperar_senha?email=${Uri.encode(email)}"

    fun definirSenha(origem: String = "entrada", manterDispositivoAtual: Boolean = false, email: String? = null): String {
        val base = "definir_senha?origem=${Uri.encode(origem)}&manterDispositivo=$manterDispositivoAtual"
        return if (email.isNullOrBlank()) base else "$base&email=${Uri.encode(email)}"
    }
    fun detalhe(vagaId: String) = "detalhe/$vagaId"
    fun avaliacao(turnoId: String) = "avaliacao/$turnoId"
    fun ocorrencia(turnoId: String) = "ocorrencia/$turnoId"
    fun turnoAviso(turnoId: String) = "meus_turnos/$turnoId"

    /** `motivo` e `desde` ficaram só por compatibilidade com links antigos: desde o L2-5 a tela lê `situacao_da_conta` e mostra o que o servidor diz. */
    fun contaSuspensa(motivo: String? = null, desde: String? = null): String {
        val parametros = listOfNotNull(
            motivo?.let { "motivo=${Uri.encode(it)}" },
            desde?.let { "desde=${Uri.encode(it)}" },
        )
        return if (parametros.isEmpty()) "conta_suspensa" else "conta_suspensa?" + parametros.joinToString("&")
    }

    /**
     * `alvoId` é o `id` do `PerfilPublico`; `turnoId` e `chamadaId` só associam a denúncia (contrato 0.2.71). `fotoId` é o
     * `foto_id` do perfil, quando ele veio com foto: só com ele a tela oferece denunciar a foto (`midia_id`, 0.2.54).
     */
    fun denuncia(
        alvoTipo: TipoDeAlvo,
        alvoId: String,
        turnoId: String? = null,
        chamadaId: String? = null,
        fotoId: String? = null,
    ): String {
        val parametros = listOfNotNull(
            turnoId?.let { "turnoId=${Uri.encode(it)}" },
            chamadaId?.let { "chamadaId=${Uri.encode(it)}" },
            fotoId?.let { "fotoId=${Uri.encode(it)}" },
        )
        val base = "denuncia/${alvoTipo.chave}/${Uri.encode(alvoId)}"
        return if (parametros.isEmpty()) base else base + "?" + parametros.joinToString("&")
    }

    fun equipe(estabelecimentoId: String) = "equipe/$estabelecimentoId"

    /** `inicioDaVaga` (ISO-8601 UTC) só serve ao aviso do que o cancelamento causa; sem ele a tela fica sem o aviso de prazo. */
    fun cancelarVaga(vagaId: String, inicioDaVaga: Instant? = null): String {
        val base = "cancelar_vaga/${Uri.encode(vagaId)}"
        return inicioDaVaga?.let { "$base?inicioDaVaga=${Uri.encode(it.toString())}" } ?: base
    }

    /** `duracaoMin` é a duração da vaga de origem, em minutos: o novo horário sugerido a mantém. */
    fun republicarVaga(vagaId: String, selecao: Boolean, duracaoMin: Long) =
        "republicar_vaga/${Uri.encode(vagaId)}?selecao=$selecao&duracaoMin=$duracaoMin"

    fun publicarVaga(estabelecimentoId: String) = "publicar_vaga/${Uri.encode(estabelecimentoId)}"

    fun publicarEscala(estabelecimentoId: String) = "publicar_escala/${Uri.encode(estabelecimentoId)}"

    fun equipeDaCasa(estabelecimentoId: String) = "equipe_da_casa/${Uri.encode(estabelecimentoId)}"

    fun trocarDeCasa(atual: String? = null) = if (atual == null) "trocar_de_casa" else "trocar_de_casa?atual=${Uri.encode(atual)}"

    /** O turno da posição `posicaoId` da vaga `vagaId`, lido do painel do estabelecimento. */
    fun turnoDoContratanteAviso(estabelecimentoId: String, turnoId: String) =
        "turno_do_contratante_aviso/${Uri.encode(estabelecimentoId)}/${Uri.encode(turnoId)}"

    fun turnoDoContratante(estabelecimentoId: String, vagaId: String, posicaoId: String) =
        "turno_do_contratante/${Uri.encode(estabelecimentoId)}/${Uri.encode(vagaId)}/${Uri.encode(posicaoId)}"

    /** `nomeEstabelecimento` e `vagaRecemPublicadaId` são opcionais; a vaga recém-publicada sobe na lista. */
    fun minhasVagas(estabelecimentoId: String, nomeEstabelecimento: String? = null, vagaRecemPublicadaId: String? = null): String {
        val parametros = listOfNotNull(
            nomeEstabelecimento?.let { "nomeEstabelecimento=${Uri.encode(it)}" },
            vagaRecemPublicadaId?.let { "vagaRecemPublicadaId=${Uri.encode(it)}" },
        )
        val base = "minhas_vagas/${Uri.encode(estabelecimentoId)}"
        return if (parametros.isEmpty()) base else base + "?" + parametros.joinToString("&")
    }

    /**
     * `posicoesAbertas` e `inicioDaVaga` são opcionais: a tela de origem os informa quando conhece a vaga.
     * O início vai em ISO-8601 UTC, como o contrato o entrega.
     */
    fun candidatosDaVaga(vagaId: String, posicoesAbertas: Int? = null, inicioDaVaga: Instant? = null, estabelecimentoId: String? = null): String {
        val parametros = listOfNotNull(
            posicoesAbertas?.let { "posicoesAbertas=$it" },
            inicioDaVaga?.let { "inicioDaVaga=${Uri.encode(it.toString())}" },
            estabelecimentoId?.let { "estabelecimentoId=${Uri.encode(it)}" },
        )
        val base = "candidatos_da_vaga/${Uri.encode(vagaId)}"
        return if (parametros.isEmpty()) base else base + "?" + parametros.joinToString("&")
    }
}

object DeepLinks {
    const val DETALHE_VAGA = "frila://vagas/{vagaId}"
    const val MEUS_TURNOS = "frila://meus_turnos"
    const val TURNO_AVISO = "frila://meus_turnos/{turnoId}"
    const val SUPORTE = "frila://suporte?turno_id={turnoId}"
}

/**
 * Rota inicial (RN15): sem sessão válida vai para [Rotas.ENTRADA]; com sessão válida e
 * desbloqueio rápido ativado (RN15), passa primeiro por [Rotas.DESBLOQUEIO] em vez de abrir o
 * feed direto — é o gate real da flag `isBiometriaAtivada()`, não só a pintura do toggle no
 * perfil (MEDIDO, Shisui PR #591: antes desta correção nada consumia a flag na inicialização).
 * Sem biometria ativada, vai direto para [Rotas.FEED] — ver `AppNavegacaoTest`.
 */
fun rotaInicial(armazenamentoDeSessao: ArmazenamentoDeSessao, biometriaHabilitada: Boolean = false): String = when {
    !armazenamentoDeSessao.estaAutenticado() -> Rotas.ENTRADA
    biometriaHabilitada && armazenamentoDeSessao.isBiometriaAtivada() -> Rotas.DESBLOQUEIO
    else -> Rotas.FEED
}

@Composable
fun AppNavegacao(
    /**
     * #789: o padrão é o [CoordenadorDeLogout], porque as saídas desta navegação (conta suspensa, "outra conta"
     * no desbloqueio) chamam `limparSessao()` aqui, e só o coordenador fecha o cliente Ktor da conta que saiu.
     * Grafo sem o coordenador (testes com Koin mínimo) usa o armazenamento; o de produção sempre o tem
     * (`KoinGrafoTest`), e o token em memória já não passa de uma conta a outra pelo próprio `ClienteSupabase`.
     */
    armazenamentoDeSessao: ArmazenamentoDeSessao = getKoin().getOrNull<CoordenadorDeLogout>() ?: koinInject(),
    monitorDeConectividade: MonitorDeConectividade = koinInject(),
    navController: NavHostController = rememberNavController(),
    aoPronto: (() -> Unit)? = null,
    /**
     * Trava do selo de confiança (RN14): desligada por padrão até a moderação e os termos serem
     * validados pelos sócios. Desligada, a rota [Rotas.SELO_CONFIANCA] nem existe no grafo e o
     * perfil não consulta o estado do selo.
     */
    recursoSeloHabilitado: Boolean = false,
    /**
     * Chave `chamada_direta` (`configuracao_do_app`): desligada, "Chamar de novo" nem aparece na equipe de
     * confiança. Ligada, a equipe leva à folha de chamar do lado da casa.
     */
    chamadaDiretaHabilitada: Boolean = false,
    /**
     * Chave `busca_profissionais` (`configuracao_do_app`, RN46): desligada, as preferências de chamada ficam como no
     * iOS de hoje, sem o "Aceito chamadas diretas" nem as pendências da busca.
     */
    buscaProfissionaisHabilitada: Boolean = false,
    /**
     * Chave `checkin_por_codigo` (`configuracao_do_app`, a do servidor): ligada, o profissional digita o código que a casa mostra e a casa vê o
     * código do turno. Desligada (padrão), a tela de turnos fica como antes.
     */
    checkinPorCodigoHabilitado: Boolean = false,
    callbackOAuthSocial: StateFlow<String?>? = null,
    aoConsumirCallbackOAuthSocial: () -> Unit = {},
    /** Abre o navegador do login social; `false` quando o aparelho não tem navegador (a navegação avisa). */
    aoAbrirLoginSocial: (String) -> Boolean = { true },
    /** O toque num push (`frila://aviso`), pendente até a navegação escolher a tela pelo papel ([rotaDoAviso]). */
    avisoDoToque: StateFlow<AvisoDoToque?>? = null,
    aoConsumirAvisoDoToque: () -> Unit = {},
    /**
     * Quem é membro de um estabelecimento ganha no perfil os atalhos da equipe de confiança e da
     * publicação de vaga; contratante sem casa ganha o do cadastro. Nulo (grafo sem o serviço) esconde
     * todos. Conta de profissional recebe `422 perfil_incompativel` e também não vê nenhum.
     */
    servicoMembros: ServicoMembros? = getKoin().getOrNull(),
    /** Lê o painel para a rota do turno do contratante. Nulo (grafo sem o serviço) mostra a falha da rota. */
    servicoVagas: ServicoVagas? = getKoin().getOrNull(),
    /**
     * Decide a tela inicial pelo papel da conta, depois do código e a cada abertura com sessão. Nulo (grafo
     * sem o serviço) mantém o caminho antigo: cadastro depois do código e feed na abertura.
     */
    avaliadorDeDestino: AvaliadorDeDestino? = getKoin().getOrNull(),
    /**
     * C0-8: conta as sessões apagadas (token recusado, Sair, exclusão). Sem sessão, tela de dentro só falha, e a
     * navegação volta à entrada, como o iOS (`FrilaApp.swift:519`). Nulo (grafo sem a [SessaoComCacheVagas]) não observa.
     */
    encerramentosDaSessao: StateFlow<Int>? = (getKoin().getOrNull<ArmazenamentoDeSessao>() as? SessaoComCacheVagas)?.encerramentos,
    /**
     * C0-11 (decisão de 16/11/2026: o Android fica só com o que o iOS tem): o iOS não tem desbloqueio por biometria.
     * Desligada (padrão; nada no app a liga), a abertura não pede a digital nem a quem a tinha ligado antes.
     */
    biometriaHabilitada: Boolean = false,
    /**
     * Chave `perfil_rico` (`configuracao_do_app`, a do servidor): ligada, o profissional vê no perfil o atalho "Apresentação e regiões". Desligada
     * (padrão), o perfil fica como era.
     */
    perfilRicoHabilitado: Boolean = false,
    /** Chave `foto_de_perfil` (`configuracao_do_app`, a do servidor): ligada, o profissional vê no perfil o atalho "Foto de perfil". Desligada (padrão), não vê. */
    fotoDePerfilHabilitada: Boolean = false,
    /** Política opcional de espera (segundos) para fluxos GoTrue direto, vinda de `configuracao_do_app.reenviar_otp_em_segundos`. */
    reenviarOtpEmSegundos: Int? = null,
    gerenciadorConsentimento: GerenciadorConsentimentoCrashlytics = getKoin().getOrNull() ?: object : GerenciadorConsentimentoCrashlytics {
        override fun coletaAtiva(): Boolean = false
        override fun precisaPerguntar(): Boolean = false
        override fun definirConsentimento(concedido: Boolean) {}
    },
) {
    val destinoInicial = remember(armazenamentoDeSessao, avaliadorDeDestino, biometriaHabilitada) {
        rotaInicial(armazenamentoDeSessao, biometriaHabilitada).let { if (it == Rotas.FEED && avaliadorDeDestino != null) Rotas.ABERTURA else it }
    }
    // RN15: gate em memória independente de rotaInicial — pega deep link (frila://vagas/...,
    // frila://meus_turnos, frila://suporte) que chega direto numa rota autenticada sem passar
    // pela decisão de abertura (MEDIDO, Shisui PR #591). Ver GuardaBiometrico.
    val guardaBiometrico = remember(armazenamentoDeSessao, biometriaHabilitada) {
        GuardaBiometrico(sessaoDesbloqueadaInicial = !(biometriaHabilitada && armazenamentoDeSessao.isBiometriaAtivada()))
    }

    DisposableEffect(navController, guardaBiometrico) {
        val listener = instalarGuardaBiometrico(navController, guardaBiometrico)
        onDispose { navController.removeOnDestinationChangedListener(listener) }
    }

    // RN: o papel da conta diz que abas a raiz mostra. Vem da abertura; quando só a rota diz quem é (link que cai direto
    // numa raiz do profissional, grafo sem a abertura), a rota decide, e o papel fica lembrado para a aba Conta.
    var papelDaRaiz by rememberSaveable(stateSaver = SalvadorDoPapelDaRaiz) { mutableStateOf<PapelDaRaiz?>(null) }
    // "Trocar de casa": a casa que a pessoa escolheu vale até ela sair do app; sem escolha, vale a primeira por nome.
    var casaEscolhidaId by rememberSaveable { mutableStateOf<String?>(null) }
    // O papel veio do servidor nesta abertura. Sem rede a abertura usa o último destino guardado, e o toque num push
    // não escolhe tela por ele.
    var papelConfirmadoNoServidor by rememberSaveable { mutableStateOf(false) }
    val padraoAtual = padraoDoTopoDaPilha(navController)
    LaunchedEffect(padraoAtual) {
        if (papelDaRaiz == null) papelPelaRota(padraoAtual)?.let { papelDaRaiz = it }
    }
    val comBarraDaRaiz = temBarraDaRaiz(papelDaRaiz, padraoAtual)

    // C0-8: toda saída da sessão (Sair, exclusão, 401 na abertura, outra conta, sessão que caiu) termina aqui, numa
    // navegação só: quem chega com a pilha já reduzida à entrada não navega de novo.
    fun irParaEntrada() {
        guardaBiometrico.liberarAposLimparSessao()
        papelDaRaiz = null
        papelConfirmadoNoServidor = false
        // O aviso pendente era da conta que saiu.
        aoConsumirAvisoDoToque()
        // A casa escolhida em "Trocar de casa" é da conta que saiu: a próxima abertura vale a padrão do servidor.
        casaEscolhidaId = null
        if (navController.currentDestination?.route == Rotas.ENTRADA && navController.previousBackStackEntry == null) return
        navController.navigate(Rotas.ENTRADA) {
            popUpTo(0) { inclusive = true }
        }
    }

    // RN: o voltar do detalhe da vaga. Aberto por link, sem tela embaixo, leva às vagas em vez de esvaziar a pilha.
    val voltarDoDetalhe: () -> Unit = {
        if (navController.previousBackStackEntry != null) {
            navController.popBackStack()
        } else {
            navController.navigate(Rotas.FEED) { popUpTo(Rotas.DETALHE) { inclusive = true } }
        }
    }

    // C0-9: a profissional denuncia a casa pelo turno dela, como o iOS (`TelaMeuTurno.swift:125`).
    val denunciarCasa: (String, String) -> Unit = { casaId, turnoId ->
        navController.navigate(Rotas.denuncia(TipoDeAlvo.ESTABELECIMENTO, casaId, turnoId = turnoId))
    }
    // O relato de ocorrência nasce do turno (antes só o link frila://suporte chegava nele), como a folha de suporte do iOS.
    val pedirSuporte: (String) -> Unit = { turnoId -> navController.navigate(Rotas.ocorrencia(turnoId)) }

    // O toque num push escolhe a tela pelo tipo e pelo papel confirmado no servidor, como o `RoteadorDePush` do iOS.
    // Enquanto a abertura decide, o aviso espera; sem papel confirmado, o app fica na raiz que a abertura escolheu.
    val avisoPendente = avisoDoToque?.collectAsStateWithLifecycle()?.value
    LaunchedEffect(avisoPendente, papelDaRaiz, papelConfirmadoNoServidor, padraoAtual) {
        val aviso = avisoPendente ?: return@LaunchedEffect
        val papel = papelDaRaiz?.takeIf { papelConfirmadoNoServidor }
        val abrindo = padraoAtual == null || padraoAtual == Rotas.ABERTURA
        if (papel == null && abrindo && armazenamentoDeSessao.estaAutenticado()) return@LaunchedEffect
        aoConsumirAvisoDoToque()
        val rota = papel?.let { rotaDoAviso(aviso, it) } ?: return@LaunchedEffect
        if (rota == Rotas.ABERTURA) {
            // Suspensão ou reativação: a abertura relê a conta no servidor e leva à tela da situação dela, com a pilha
            // de antes fora (ela é da conta como estava).
            if (avaliadorDeDestino != null) navController.navigate(Rotas.ABERTURA) { popUpTo(0) { inclusive = true } }
            return@LaunchedEffect
        }
        // Por cima do que está aberto: um formulário a meio fica embaixo, e "voltar" o devolve.
        navController.navigate(rota) { launchSingleTop = true }
    }

    // N3 e N16: confere ao abrir (link frila:// sem sessão, pilha restaurada) e a cada sessão apagada. O cliente de
    // rede apaga fora da thread principal quando o Auth recusa o token, e a navegação só anda na principal.
    // Sem sessão, tela de dentro só falha.
    LaunchedEffect(encerramentosDaSessao, navController, guardaBiometrico) {
        encerramentosDaSessao?.collect {
            withContext(Dispatchers.Main.immediate) {
                val rota = navController.currentDestination?.route
                if (rota != null && rota !in GuardaBiometrico.ROTAS_SEM_GATE && !armazenamentoDeSessao.estaAutenticado()) {
                    irParaEntrada()
                }
            }
        }
    }

    // RNF04 (bloqueante do Shisui, PR #604): collectAsState() não é lifecycle-aware — a
    // composição ficava viva com a Activity parada, então o StateFlow nunca perdia assinante e
    // o callback do ConnectivityManager nunca era desregistrado em segundo plano (MEDIDO:
    // dumpsys connectivity continuava mostrando os registros depois de +15s/+24s em background).
    val statusConectividade by monitorDeConectividade.status.collectAsStateWithLifecycle()

    // Cartão B7bqwHxg: e-mail, discador ou navegador que não abre vira um aviso com o endereço para copiar, nunca silêncio.
    val contextoDaNavegacao = LocalContext.current
    var avisoDeAberturaExterna by rememberSaveable(stateSaver = AvisoDeAberturaExterna.Salvador) {
        mutableStateOf<AvisoDeAberturaExterna?>(null)
    }
    val abrirForaDoApp: (Intent, AvisoDeAberturaExterna) -> Unit = { intent, aviso ->
        if (!abrirExterno(contextoDaNavegacao, intent)) avisoDeAberturaExterna = aviso
    }

    // P3: se um callback OAuth for recebido enquanto o app não está em Rotas.ENTRADA, descarta para não reter.
    val callbackGlobal = callbackOAuthSocial?.collectAsStateWithLifecycle()?.value
    val rotaNoTopo = padraoAtual
    LaunchedEffect(callbackGlobal, rotaNoTopo) {
        if (callbackGlobal != null && rotaNoTopo != null && rotaNoTopo != Rotas.ENTRADA) {
            aoConsumirCallbackOAuthSocial()
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
    Box(
        modifier = Modifier
            .weight(1f)
            .fillMaxWidth()
            // Com a barra de abas embaixo, é ela que recua para a barra de navegação do sistema: a tela não recua de novo.
            .then(if (comBarraDaRaiz) Modifier.consumeWindowInsets(WindowInsets.navigationBars) else Modifier),
    ) {
        NavHost(navController = navController, startDestination = destinoInicial) {
            composable(Rotas.ENTRADA) {
                val koin = getKoin()
                val viewModelSenha: EntradaComSenhaViewModel? = if (koin.getOrNull<EntradaComSenhaViewModel>() != null) {
                    koinViewModel<EntradaComSenhaViewModel>()
                } else {
                    null
                }
                LaunchedEffect(Unit) {
                    aoPronto?.invoke()
                }
                if (viewModelSenha != null) {
                    val callbackPendente = callbackOAuthSocial?.collectAsStateWithLifecycle()?.value
                    LaunchedEffect(callbackPendente) {
                        if (callbackPendente != null) {
                            viewModelSenha.aoReceberCallbackOAuth(callbackPendente)
                            aoConsumirCallbackOAuthSocial()
                        }
                    }
                    TelaEntradaComSenha(
                        viewModel = viewModelSenha,
                        aoAutenticar = {
                            val proximoDestino = if (avaliadorDeDestino != null) Rotas.ABERTURA else Rotas.CADASTRO
                            if (gerenciadorConsentimento.precisaPerguntar()) {
                                navController.navigate(Rotas.CONSENTIMENTO_FALHAS) {
                                    popUpTo(Rotas.ENTRADA) { inclusive = true }
                                }
                            } else {
                                navController.navigate(proximoDestino) {
                                    popUpTo(Rotas.ENTRADA) { inclusive = true }
                                }
                            }
                        },
                        aoCriarConta = { email -> navController.navigate(Rotas.criarConta(email)) },
                        aoRecuperarSenha = { email -> navController.navigate(Rotas.recuperarSenha(email)) },
                        aoEntrarDemonstracao = { email ->
                            navController.navigate(Rotas.codigo(email, ModoCodigo.DEMO))
                        },
                        aoExigirDesafioOtpComEspera = { email, desafioId, reenviarEmSegundos ->
                            navController.navigate(
                                Rotas.codigo(email, ModoCodigo.LOGIN_DISPOSITIVO, desafioId, reenviarEmSegundos),
                            )
                        },
                        aoExigirDefinirSenha = {
                            navController.navigate(Rotas.definirSenha(origem = "pendente", manterDispositivoAtual = true)) {
                                popUpTo(Rotas.ENTRADA) { inclusive = true }
                            }
                        },
                        aoAbrirLoginSocial = { url ->
                            if (!aoAbrirLoginSocial(url)) avisoDeAberturaExterna = AvisoDeAberturaExterna.semNavegadorParaEntrar
                        },
                    )
                } else {
                    val viewModel: EntradaViewModel = koinViewModel()
                    TelaEntrada(
                        viewModel = viewModel,
                        aoReceberCodigo = {
                            navController.navigate(
                                Rotas.codigo(
                                    viewModel.estado.value.email,
                                    reenviarEmSegundos = reenviarOtpEmSegundos,
                                ),
                            )
                        },
                    )
                }
            }

            composable(
                route = Rotas.CRIAR_CONTA,
                arguments = listOf(navArgument("email") { type = NavType.StringType; defaultValue = "" }),
            ) { entrada ->
                val emailInicial = entrada.arguments?.getString("email").orEmpty()
                val viewModel: CriarContaViewModel = koinViewModel(parameters = { parametersOf(emailInicial) })
                TelaCriarConta(
                    viewModel = viewModel,
                    aoEnviarCodigo = { email ->
                        navController.navigate(
                            Rotas.codigo(
                                email,
                                ModoCodigo.CRIACAO,
                                reenviarEmSegundos = reenviarOtpEmSegundos,
                            ),
                        )
                    },
                    aoVoltarParaLogin = { if (!navController.popBackStack(Rotas.ENTRADA, inclusive = false)) irParaEntrada() },
                )
            }

            composable(
                route = Rotas.RECUPERAR_SENHA,
                arguments = listOf(navArgument("email") { type = NavType.StringType; defaultValue = "" }),
            ) { entrada ->
                val emailInicial = entrada.arguments?.getString("email").orEmpty()
                val viewModel: RecuperacaoSenhaViewModel = koinViewModel(parameters = { parametersOf(emailInicial) })
                TelaRecuperacaoSenha(
                    viewModel = viewModel,
                    aoAvancarParaCodigo = { email ->
                        navController.navigate(
                            Rotas.codigo(
                                email,
                                ModoCodigo.RECUPERACAO,
                                reenviarEmSegundos = reenviarOtpEmSegundos,
                            ),
                        )
                    },
                    aoVoltarParaLogin = { if (!navController.popBackStack(Rotas.ENTRADA, inclusive = false)) irParaEntrada() },
                )
            }

            composable(
                route = Rotas.CODIGO,
                arguments = listOf(
                    navArgument("email") { type = NavType.StringType },
                    navArgument("modo") { type = NavType.StringType; defaultValue = ModoCodigo.ENTRADA.chave },
                    navArgument("desafioId") { type = NavType.StringType; defaultValue = "" },
                    navArgument("reenviarEmSegundos") { type = NavType.IntType; defaultValue = 0 },
                ),
            ) { entrada ->
                val email = entrada.arguments?.getString("email").orEmpty()
                val modo = ModoCodigo.deChave(entrada.arguments?.getString("modo"))
                val desafioId = entrada.arguments?.getString("desafioId")?.takeIf { it.isNotBlank() }
                val reenviarEmSegundos = entrada.arguments?.getInt("reenviarEmSegundos")?.takeIf { it > 0 }
                val viewModel: CodigoViewModel = koinViewModel(
                    parameters = { parametersOf(email, modo, desafioId, reenviarEmSegundos) },
                )
                TelaCodigo(
                    viewModel = viewModel,
                    aoAutenticar = {
                        val estadoCodigo = viewModel.estado.value
                        if (modo == ModoCodigo.CRIACAO || modo == ModoCodigo.RECUPERACAO || estadoCodigo.precisaDefinirSenha) {
                            navController.navigate(
                                Rotas.definirSenha(
                                    origem = modo.chave,
                                    manterDispositivoAtual = estadoCodigo.dispositivoLembrado,
                                    email = email,
                                ),
                            ) {
                                popUpTo(Rotas.CODIGO) { inclusive = true }
                            }
                        } else {
                            val proximoDestino = if (avaliadorDeDestino != null) Rotas.ABERTURA else Rotas.CADASTRO
                            if (gerenciadorConsentimento.precisaPerguntar()) {
                                navController.navigate(Rotas.CONSENTIMENTO_FALHAS) {
                                    popUpTo(Rotas.ENTRADA) { inclusive = true }
                                }
                            } else {
                                navController.navigate(proximoDestino) {
                                    popUpTo(Rotas.ENTRADA) { inclusive = true }
                                }
                            }
                        }
                    },
                    aoTrocarEmail = {
                        val voltou = when (modo) {
                            ModoCodigo.CRIACAO -> navController.popBackStack(Rotas.CRIAR_CONTA, inclusive = false)
                            ModoCodigo.RECUPERACAO -> navController.popBackStack(Rotas.RECUPERAR_SENHA, inclusive = false)
                            else -> navController.popBackStack(Rotas.ENTRADA, inclusive = false)
                        }
                        if (!voltou) irParaEntrada()
                    },
                )
            }

            composable(
                route = Rotas.DEFINIR_SENHA,
                arguments = listOf(
                    navArgument("origem") { type = NavType.StringType; defaultValue = "entrada" },
                    navArgument("manterDispositivo") { type = NavType.BoolType; defaultValue = false },
                    navArgument("email") { type = NavType.StringType; defaultValue = "" },
                ),
            ) { entrada ->
                val origem = entrada.arguments?.getString("origem").orEmpty()
                val manterDispositivo = entrada.arguments?.getBoolean("manterDispositivo") ?: false
                val emailDefinir = entrada.arguments?.getString("email")?.takeIf { it.isNotBlank() }
                val viewModel: DefinirSenhaViewModel = koinViewModel(parameters = { parametersOf(manterDispositivo, emailDefinir) })
                TelaDefinirSenha(
                    viewModel = viewModel,
                    aoConcluir = {
                        if (origem == "perfil") {
                            navController.popBackStack()
                        } else {
                            val proximoDestino = if (avaliadorDeDestino != null) Rotas.ABERTURA else Rotas.CADASTRO
                            if (gerenciadorConsentimento.precisaPerguntar()) {
                                navController.navigate(Rotas.CONSENTIMENTO_FALHAS) {
                                    popUpTo(Rotas.ENTRADA) { inclusive = true }
                                }
                            } else {
                                navController.navigate(proximoDestino) {
                                    popUpTo(Rotas.ENTRADA) { inclusive = true }
                                }
                            }
                        }
                    },
                )
            }

            composable(Rotas.CONSENTIMENTO_FALHAS) {
                val proximoDestino = if (avaliadorDeDestino != null) Rotas.ABERTURA else Rotas.CADASTRO
                fun continuar() {
                    navController.navigate(proximoDestino) {
                        popUpTo(Rotas.CONSENTIMENTO_FALHAS) { inclusive = true }
                    }
                }
                TelaConsentimentoCrashlytics(
                    aoPermitir = {
                        gerenciadorConsentimento.definirConsentimento(true)
                        continuar()
                    },
                    aoRecusar = {
                        gerenciadorConsentimento.definirConsentimento(false)
                        continuar()
                    },
                )
            }

            composable(Rotas.ABERTURA) {
                RotaProtegida(guardaBiometrico) {
                    if (avaliadorDeDestino != null) {
                        RotaDeAbertura(
                            avaliador = avaliadorDeDestino,
                            aoDecidir = { destino, doServidor ->
                                // Cada abertura decide a casa pelo servidor; uma escolha de antes não vale para esta conta.
                                casaEscolhidaId = null
                                papelConfirmadoNoServidor = doServidor
                                val casa = (destino as? DestinoDaConta.Contratante)?.casa
                                if (destino is DestinoDaConta.Contratante && casa == null) {
                                    // Contratante ainda sem casa não tem abas: o Perfil (Sair, Excluir conta) fica como
                                    // raiz da pilha e o cadastro da casa entra por cima dele. "Voltar" do cadastro leva
                                    // ao Perfil; "Voltar" no Perfil sai do app (pilha nunca vazia).
                                    navController.navigate(Rotas.PERFIL) {
                                        popUpTo(Rotas.ABERTURA) { inclusive = true }
                                    }
                                    navController.navigate(destino.rota())
                                } else {
                                    // Profissional e casa abrem na primeira aba; a Conta (Sair, Equipe) é a última aba.
                                    if (destino == DestinoDaConta.Profissional) papelDaRaiz = PapelDaRaiz.Profissional
                                    if (casa != null) papelDaRaiz = PapelDaRaiz.Contratante(casa.id, Rotas.minhasVagas(casa.id, casa.nome))
                                    navController.navigate(destino.rota()) {
                                        popUpTo(Rotas.ABERTURA) { inclusive = true }
                                    }
                                }
                            },
                            aoSessaoVencida = {
                                // 401: a renovação já falhou; sai da árvore autenticada como o logout faz.
                                armazenamentoDeSessao.limparSessao()
                                irParaEntrada()
                            },
                            aoTerminarDeAvaliar = { aoPronto?.invoke() },
                        )
                    }
                }
            }

            composable(Rotas.CADASTRO) {
                val viewModel: CadastroViewModel = koinViewModel()
                val koinDoCadastro = getKoin()
                val destinoGuardado = remember(koinDoCadastro) { koinDoCadastro.getOrNull<DestinoGuardado>() }
                TelaCadastro(
                    viewModel = viewModel,
                    // #784: o destino segue o perfil criado e fica guardado, como o iOS (`DestinoGuardado.salvar`).
                    aoConcluir = { perfil ->
                        when (perfil) {
                            PerfilDaConta.PROFISSIONAL -> {
                                destinoGuardado?.salvar(DestinoDaConta.Profissional)
                                navController.navigate(Rotas.FEED) {
                                    popUpTo(Rotas.CADASTRO) { inclusive = true }
                                }
                            }
                            PerfilDaConta.CONTRATANTE -> {
                                destinoGuardado?.salvar(DestinoDaConta.Contratante(casa = null))
                                // Como na abertura de quem ainda não tem casa: o Perfil (Sair, Excluir conta) fica como
                                // raiz e o cadastro da casa entra por cima; "Voltar" do cadastro leva ao Perfil.
                                navController.navigate(Rotas.PERFIL) {
                                    popUpTo(Rotas.CADASTRO) { inclusive = true }
                                }
                                navController.navigate(Rotas.CADASTRO_ESTABELECIMENTO)
                            }
                        }
                    },
                )
            }

            composable(Rotas.FEED) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: FeedVagasViewModel = koinViewModel()
                    LaunchedEffect(viewModel) { viewModel.carregar() }
                    // HaRJJ0L0: relê ao voltar do segundo plano e com um push da conta, em silêncio (a lista não pisca). Sem o ponto central no Koin (testes de navegação que montam o próprio módulo), a rota segue sem a atualização.
                    getKoin().getOrNull<AtualizacaoAutomatica>()?.let { atualizacao ->
                        AtualizacaoAutomaticaDaLista(ListaAtualizavel.VAGAS, atualizacao) { viewModel.atualizarEmSilencio().join() }
                    }
                    val estadoFeed by viewModel.estado.collectAsStateWithLifecycle()
                    LaunchedEffect(estadoFeed.status) {
                        if (estadoFeed.status != StatusFeed.CARREGANDO) {
                            aoPronto?.invoke()
                        }
                    }
                    // Meus turnos, Candidaturas e Conta são abas da raiz (`AbasDaRaiz.kt`), como no iOS.
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = { vagaId -> navController.navigate(Rotas.detalhe(vagaId)) },
                        aoDefinirPontoBase = { navController.navigate(Rotas.PONTO_BASE) },
                    )
                }
            }

            composable(
                route = Rotas.DETALHE,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.DETALHE_VAGA }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    // Só o feed conhece a lista de vagas; de qualquer outro lugar (candidaturas, link, aviso) a vaga é lida do servidor.
                    val feedAnterior = navController.previousBackStackEntry?.takeIf { it.destination.route == Rotas.FEED }?.let {
                        koinViewModel<FeedVagasViewModel>(viewModelStoreOwner = it)
                    }
                    val estadoFeed = feedAnterior?.estado?.collectAsStateWithLifecycle()?.value
                    val vaga: VagaAbertaDto? = estadoFeed?.let { feedAnterior.encontrarVagaPorId(vagaId) }

                    if (vaga != null) {
                        val viewModel: DetalheVagaViewModel = koinViewModel(parameters = { parametersOf(vaga) })
                        Column {
                            if (estadoFeed.emCache) Text(
                                "Disponibilidade não confirmada. Conecte-se e atualize o feed antes de se candidatar.",
                                modifier = Modifier.padding(16.dp),
                            )
                            TelaDetalheVaga(
                                viewModel = viewModel,
                                aoVoltar = voltarDoDetalhe,
                                aoAbrirPerfilDaCasa = { navController.navigate(Rotas.perfilDaCasa(it)) },
                                aoNavegarParaConfirmada = { vagaConfirmada, _ ->
                                    navegarComVaga(navController, Rotas.turnoConfirmado(vagaConfirmada.id), vagaConfirmada)
                                },
                                aoNavegarParaConflito = { vagaConflito ->
                                    navegarComVaga(navController, Rotas.conflitoHorario(vagaConflito.id), vagaConflito)
                                },
                                aoNavegarParaVagaPreenchida = { vagaPreenchida ->
                                    navegarComVaga(navController, Rotas.vagaPreenchida(vagaPreenchida.id), vagaPreenchida)
                                },
                                aoNavegarParaVagaEncerrada = { vagaEncerrada ->
                                    navegarComVaga(navController, Rotas.vagaEncerrada(vagaEncerrada.id), vagaEncerrada)
                                },
                                aoNavegarParaContaSuspensa = {
                                    navController.navigate(Rotas.contaSuspensa())
                                },
                            )
                        }
                    } else {
                        // L2-4: a vaga fora da lista (link, aviso, candidatura) é lida do servidor pelo id; 404 é "não encontrada".
                        val abertura: AberturaDeVagaViewModel = koinViewModel(parameters = { parametersOf(vagaId) })
                        TelaAberturaDeVaga(
                            viewModel = abertura,
                            aoVoltarParaFeed = {
                                navController.navigate(Rotas.FEED) {
                                    popUpTo(Rotas.FEED) { inclusive = true }
                                }
                            },
                        ) { detalhe ->
                            val viewModel: DetalheVagaViewModel = koinViewModel(parameters = { parametersOf(detalhe.paraVagaAberta(), detalhe) })
                            TelaDetalheVaga(
                                viewModel = viewModel,
                                aoVoltar = voltarDoDetalhe,
                                aoAbrirPerfilDaCasa = { navController.navigate(Rotas.perfilDaCasa(it)) },
                                aoNavegarParaConfirmada = { vagaConfirmada, _ ->
                                    navegarComVaga(navController, Rotas.turnoConfirmado(vagaConfirmada.id), vagaConfirmada)
                                },
                                aoNavegarParaConflito = { vagaConflito ->
                                    navegarComVaga(navController, Rotas.conflitoHorario(vagaConflito.id), vagaConflito)
                                },
                                aoNavegarParaVagaPreenchida = { vagaPreenchida ->
                                    navegarComVaga(navController, Rotas.vagaPreenchida(vagaPreenchida.id), vagaPreenchida)
                                },
                                aoNavegarParaVagaEncerrada = { vagaEncerrada ->
                                    navegarComVaga(navController, Rotas.vagaEncerrada(vagaEncerrada.id), vagaEncerrada)
                                },
                                aoNavegarParaContaSuspensa = {
                                    navController.navigate(Rotas.contaSuspensa())
                                },
                            )
                        }
                    }
                }
            }

            composable(
                route = Rotas.PERFIL_DA_CASA,
                arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    val viewModel: PerfilPublicoViewModel = koinViewModel(parameters = { parametersOf(estabelecimentoId) })
                    // O profissional só lê o perfil da casa: sem "Chamar", que é da casa chamando um profissional.
                    TelaPerfilPublico(viewModel = viewModel, aoVoltar = { navController.popBackStack() })
                }
            }

            composable(Rotas.VAGA_INDISPONIVEL) {
                RotaProtegida(guardaBiometrico) {
                    TelaVagaIndisponivel(
                        motivo = MotivoIndisponibilidadeVaga.NAO_ENCONTRADA,
                        aoVoltarParaFeed = {
                            navController.navigate(Rotas.FEED) {
                                popUpTo(Rotas.FEED) { inclusive = true }
                            }
                        },
                    )
                }
            }

            composable(Rotas.TURNO_CONFIRMADO) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    val vaga = vagaDaPilha(navController, entrada, vagaId)
                    if (vaga != null) {
                        TelaTurnoConfirmado(
                            vaga = vaga,
                            aoVerMeusTurnos = {
                                navController.navigate(Rotas.MEUS_TURNOS) {
                                    popUpTo(Rotas.FEED) { saveState = true }
                                    launchSingleTop = true
                                }
                            },
                            aoVoltarAoFeed = {
                                navController.navigate(Rotas.FEED) {
                                    popUpTo(Rotas.FEED) { inclusive = true }
                                }
                            },
                        )
                    } else {
                        // Fallback se a vaga não estiver em memória: volta ao feed (só enquanto esta rota estiver no topo)
                        FallbackVoltarAoFeed(navController, entrada)
                    }
                }
            }

            composable(Rotas.CONFLITO_HORARIO) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    val vaga = vagaDaPilha(navController, entrada, vagaId)
                    if (vaga != null) {
                        TelaConflitoHorario(
                            vaga = vaga,
                            aoVoltarAoFeed = {
                                navController.navigate(Rotas.FEED) {
                                    popUpTo(Rotas.FEED) { inclusive = true }
                                }
                            },
                        )
                    } else {
                        FallbackVoltarAoFeed(navController, entrada)
                    }
                }
            }

            composable(Rotas.VAGA_PREENCHIDA) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    val vaga = vagaDaPilha(navController, entrada, vagaId)
                    val modo = if (vaga?.modo == "selecao") ModoPreenchimentoVaga.SELECAO else ModoPreenchimentoVaga.URGENCIA
                    TelaVagaIndisponivel(
                        motivo = MotivoIndisponibilidadeVaga.PREENCHIDA,
                        modo = modo,
                        aoVoltarParaFeed = {
                            navController.navigate(Rotas.FEED) {
                                popUpTo(Rotas.FEED) { inclusive = true }
                            }
                        },
                    )
                }
            }

            composable(Rotas.VAGA_ENCERRADA) {
                RotaProtegida(guardaBiometrico) {
                    TelaVagaIndisponivel(
                        motivo = MotivoIndisponibilidadeVaga.ENCERRADA,
                        aoVoltarParaFeed = {
                            navController.navigate(Rotas.FEED) {
                                popUpTo(Rotas.FEED) { inclusive = true }
                            }
                        },
                    )
                }
            }

            composable(Rotas.TURNO_NAO_ENCONTRADO) {
                RotaProtegida(guardaBiometrico) {
                    TelaTurnoNaoEncontrado(
                        aoVoltar = { navController.popBackStack() },
                        aoVerMeusTurnos = {
                            navController.navigate(Rotas.MEUS_TURNOS) {
                                popUpTo(Rotas.MEUS_TURNOS) { inclusive = true }
                            }
                        },
                    )
                }
            }

            composable(
                route = Rotas.TURNO_AVISO,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.TURNO_AVISO }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                    val viewModel: MeusTurnosViewModel = koinViewModel()
                    val estado by viewModel.estado.collectAsStateWithLifecycle()

                    LaunchedEffect(turnoId) {
                        viewModel.carregar()
                    }

                    when (estado.status) {
                        StatusMeusTurnos.CARREGANDO -> {
                            Box(
                                modifier = Modifier.fillMaxSize(),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "Carregando...",
                                    style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
                                )
                            }
                        }
                        StatusMeusTurnos.SUCESSO -> {
                            val turnoEncontrado = estado.agendados.any { it.turnoId == turnoId } ||
                                estado.historicoCompleto.any { it.turnoId == turnoId }
                            if (turnoEncontrado) {
                                ComConfirmacaoPorCodigo(
                                    habilitada = checkinPorCodigoHabilitado,
                                    aoPresencaVerificada = { viewModel.carregar() },
                                ) {
                                    TelaMeusTurnos(
                                        viewModel = viewModel,
                                        criarCheckinViewModel = { turno ->
                                            // C0-7: um check-in por turno (key), com o ponto da vaga para medir a distância.
                                            koinViewModel(key = "checkin-${turno.turnoId}", parameters = { parametersOf(turno.turnoId, turno.pontoDaVaga) })
                                        },
                                        aoAbrirAvaliacao = { id -> navController.navigate(Rotas.avaliacao(id)) },
                                        aoDenunciarEstabelecimento = denunciarCasa,
                                        aoPedirSuporte = pedirSuporte,
                                        aoAvisarACaminho = { turno -> viewModel.avisarACaminho(turno) },
                                    )
                                }
                            } else {
                                TelaTurnoNaoEncontrado(
                                    aoVoltar = { navController.popBackStack() },
                                    aoVerMeusTurnos = {
                                        navController.navigate(Rotas.MEUS_TURNOS) {
                                            popUpTo(Rotas.MEUS_TURNOS) { inclusive = true }
                                        }
                                    },
                                )
                            }
                        }
                        StatusMeusTurnos.VAZIO -> {
                            TelaTurnoNaoEncontrado(
                                aoVoltar = { navController.popBackStack() },
                                aoVerMeusTurnos = {
                                    navController.navigate(Rotas.MEUS_TURNOS) {
                                        popUpTo(Rotas.MEUS_TURNOS) { inclusive = true }
                                    }
                                },
                            )
                        }
                        StatusMeusTurnos.ERRO -> {
                            // Não transforma erro de conexão em "não encontrado" (DestinosDoAviso.swift:208)
                            ComConfirmacaoPorCodigo(
                                habilitada = checkinPorCodigoHabilitado,
                                aoPresencaVerificada = { viewModel.carregar() },
                            ) {
                                TelaMeusTurnos(
                                    viewModel = viewModel,
                                    criarCheckinViewModel = { turno ->
                                        // C0-7: um check-in por turno (key), com o ponto da vaga para medir a distância.
                                        koinViewModel(key = "checkin-${turno.turnoId}", parameters = { parametersOf(turno.turnoId, turno.pontoDaVaga) })
                                    },
                                    aoAbrirAvaliacao = { id -> navController.navigate(Rotas.avaliacao(id)) },
                                    aoDenunciarEstabelecimento = denunciarCasa,
                                    aoPedirSuporte = pedirSuporte,
                                    aoAvisarACaminho = { turno -> viewModel.avisarACaminho(turno) },
                                )
                            }
                        }
                    }
                }
            }

            composable(
                route = Rotas.MEUS_TURNOS,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.MEUS_TURNOS }),
            ) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: MeusTurnosViewModel = koinViewModel()
                    LaunchedEffect(viewModel) { viewModel.carregar() }
                    getKoin().getOrNull<AtualizacaoAutomatica>()?.let { atualizacao ->
                        AtualizacaoAutomaticaDaLista(ListaAtualizavel.MEUS_TURNOS, atualizacao) { viewModel.atualizarSemPiscar().join() }
                    }
                    ComConfirmacaoPorCodigo(
                        habilitada = checkinPorCodigoHabilitado,
                        aoPresencaVerificada = { viewModel.carregar() },
                    ) {
                        TelaMeusTurnos(
                            viewModel = viewModel,
                            criarCheckinViewModel = { turno ->
                                // C0-7: um check-in por turno (key; antes todos os cartões dividiam um só), com o ponto
                                // da vaga (`VagaResumo.ponto`), para medir a distância até ela (RN06).
                                koinViewModel(key = "checkin-${turno.turnoId}", parameters = { parametersOf(turno.turnoId, turno.pontoDaVaga) })
                            },
                            aoAbrirAvaliacao = { turnoId -> navController.navigate(Rotas.avaliacao(turnoId)) },
                            aoDenunciarEstabelecimento = denunciarCasa,
                            aoPedirSuporte = pedirSuporte,
                            aoAvisarACaminho = { turno -> viewModel.avisarACaminho(turno) },
                            // Raiz com aba: abre sem título de página (a aba já diz onde a pessoa está).
                            comTitulo = false,
                        )
                    }
                }
            }

            composable(Rotas.AVALIACAO) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                    val viewModel: AvaliacaoViewModel = koinViewModel()
                    TelaAvaliacao(
                        turnoId = turnoId,
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.AVALIACAO_DO_CONTRATANTE,
                arguments = listOf(
                    navArgument("estabelecimentoId") {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId")
                    val viewModel: AvaliacaoViewModel = koinViewModel()
                    TelaAvaliacaoDoContratante(
                        turnoId = turnoId,
                        estabelecimentoId = estabelecimentoId,
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.OCORRENCIA,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.SUPORTE }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                    val viewModel: OcorrenciaTurnoViewModel = koinViewModel(parameters = { parametersOf(turnoId) })
                    val contexto = LocalContext.current
                    TelaOcorrencia(
                        viewModel = viewModel,
                        emailDeSuporte = EnderecosOficiais.padrao.emailSuporte,
                        // O relato só existe no corpo deste e-mail (nunca sobe numa RPC): sem app de e-mail, a tela avisa e mantém o relato.
                        aoAbrirEmailDeSuporte = { pedido ->
                            abrirExterno(contexto, intentDoEmailDeSuporte(EnderecosOficiais.padrao.emailSuporte, turnoId, pedido))
                        },
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.DESBLOQUEIO) {
                if (!biometriaHabilitada) {
                    // C0-11 (P2 do Lince no #854): com a trava desligada não há desbloqueio, mas o Android ainda restaura
                    // uma pilha salva nesta rota (processo morto, rotação). Não desenha a tela, que pediria a digital
                    // sozinha, e segue para o destino normal da conta.
                    LaunchedEffect(Unit) {
                        navController.navigate(destinoInicial) {
                            popUpTo(0) { inclusive = true }
                        }
                    }
                    return@composable
                }
                LaunchedEffect(Unit) {
                    aoPronto?.invoke()
                }
                TelaDesbloqueioBiometrico(
                    aoDesbloquear = {
                        val liberado = guardaBiometrico.aoDesbloquearComSucesso()
                        // Sem deep link pendente a guarda devolve o feed: a casa não pode cair nele (#783).
                        val destino = if (liberado == Rotas.FEED && avaliadorDeDestino != null) Rotas.ABERTURA else liberado
                        navController.navigate(destino) {
                            popUpTo(0) { inclusive = true }
                        }
                    },
                    aoEntrarComOutraConta = { irParaEntrada() },
                    armazenamentoDeSessao = armazenamentoDeSessao,
                )
            }

            composable(Rotas.PERFIL) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: PerfilViewModel = koinViewModel()
                    LaunchedEffect(viewModel) { viewModel.carregar() }
                    val viewModelSelo: VerificacaoIdentidadeViewModel? =
                        if (recursoSeloHabilitado) koinViewModel() else null
                    val estadoSelo = viewModelSelo?.estado?.collectAsStateWithLifecycle()?.value
                    // Ao voltar do fluxo do selo a rota entra de novo em composição e relê o estado.
                    LaunchedEffect(viewModelSelo) { viewModelSelo?.carregar() }
                    var casas by remember { mutableStateOf<CasasDaConta>(CasasDaConta.Desconhecidas) }
                    LaunchedEffect(servicoMembros, casaEscolhidaId) { casas = buscarCasasDaConta(servicoMembros, casaEscolhidaId) }
                    val primeiraCasa = casas as? CasasDaConta.Primeira
                    // L2-5 e L2-6: "Pessoas e locais bloqueados" é dos dois papéis; contestar o despacho é só do profissional
                    // (mesma regra de `casas` das outras entradas dele). São linhas do grupo da conta, no Perfil.
                    val atalhosDaConta = listOfNotNull(
                        AtalhoDaConta(androidx.compose.ui.res.stringResource(br.com.frila.feature.perfil.R.string.aparencia_titulo), "perfil-aparencia") { navController.navigate(Rotas.APARENCIA) },
                        AtalhoDaConta("Senha da conta", ENTRADA_SENHA_DA_CONTA) { navController.navigate(Rotas.definirSenha(origem = "perfil")) },
                        if (casas == CasasDaConta.Desconhecidas) {
                            AtalhoDaConta(TextosContestarDespacho.TITULO, ENTRADA_CONTESTAR_DESPACHO) { navController.navigate(Rotas.CONTESTAR_DESPACHO) }
                        } else {
                            null
                        },
                        AtalhoDaConta(TextosBloqueios.TITULO, ENTRADA_BLOQUEIOS) { navController.navigate(Rotas.BLOQUEIOS) },
                        // RF19: a escala do evento é da casa; entra ao lado de "Publicar vaga", que continua como está.
                        primeiraCasa?.let { casa ->
                            AtalhoDaConta(TextosEscala.ENTRADA, ENTRADA_PUBLICAR_ESCALA) { navController.navigate(Rotas.publicarEscala(casa.id)) }
                        },
                        // RF21: só o administrador vê a equipe da casa; o operador não tem esta linha (o servidor recusaria).
                        primeiraCasa?.takeIf { it.papel?.podeGerenciarEquipe == true }?.let { casa ->
                            AtalhoDaConta(TextosEquipeDaCasa.ENTRADA_EQUIPE, ENTRADA_EQUIPE_DA_CASA) { navController.navigate(Rotas.equipeDaCasa(casa.id)) }
                        },
                        primeiraCasa?.takeIf { it.total > 1 }?.let { casa ->
                            AtalhoDaConta(TextosEquipeDaCasa.ENTRADA_TROCAR, ENTRADA_TROCAR_DE_CASA) { navController.navigate(Rotas.trocarDeCasa(casa.id)) }
                        },
                        // Sem deep link: quem recebeu o link cola aqui. Só contas de contratante (com casa ou a caminho da primeira).
                        if (casas is CasasDaConta.Primeira || casas == CasasDaConta.Nenhuma) {
                            AtalhoDaConta(TextosEquipeDaCasa.ENTRADA_CONVITE, ENTRADA_TENHO_UM_CONVITE) { navController.navigate(Rotas.TENHO_UM_CONVITE) }
                        } else {
                            null
                        },
                    )
                    var relatoriosDeFalhasAtivados by remember { mutableStateOf(gerenciadorConsentimento.coletaAtiva()) }
                    TelaPerfil(
                        viewModel = viewModel,
                        atalhosExtras = atalhosDaConta,
                        manterAtalhosDeContratanteNoErro = primeiraCasa != null,
                        recursoSeloHabilitado = recursoSeloHabilitado,
                        verificacaoIdentidade = estadoSelo?.verificacao,
                        podeSolicitarSelo = estadoSelo?.podeSolicitar == true,
                        aoAbrirSelo = { navController.navigate(Rotas.SELO_CONFIANCA) },
                        relatoriosDeFalhasAtivados = relatoriosDeFalhasAtivados,
                        aoAlternarRelatoriosDeFalhas = { ligado ->
                            gerenciadorConsentimento.definirConsentimento(ligado)
                            relatoriosDeFalhasAtivados = gerenciadorConsentimento.coletaAtiva()
                        },
                        aoDeslogar = { irParaEntrada() },
                        aoAbrirAjuda = { navController.navigate(Rotas.AJUDA) },
                        aoAbrirExclusaoDeConta = { navController.navigate(Rotas.EXCLUSAO_DE_CONTA) },
                        aoAbrirEquipe = primeiraCasa?.let { casa ->
                            { navController.navigate(Rotas.equipe(casa.id)) }
                        },
                        aoPublicarVaga = primeiraCasa?.let { casa ->
                            { navController.navigate(Rotas.publicarVaga(casa.id)) }
                        },
                        // Com as abas da casa, "Minhas vagas" é a primeira aba: o atalho do Perfil sai.
                        aoMinhasVagas = primeiraCasa?.takeIf { papelDaRaiz !is PapelDaRaiz.Contratante }?.let { casa ->
                            { navController.navigate(Rotas.minhasVagas(casa.id, casa.nome)) }
                        },
                        aoCadastrarEstabelecimento = if (casas == CasasDaConta.Nenhuma) {
                            { navController.navigate(Rotas.CADASTRO_ESTABELECIMENTO) }
                        } else {
                            null
                        },
                        // Busca de profissionais (tela provisória): só para quem é membro de uma casa e com a chave ligada.
                        aoEncontrarProfissional = if (buscaProfissionaisHabilitada && primeiraCasa != null) {
                            { navController.navigate(RotasChamadaCasa.buscar(primeiraCasa.id)) }
                        } else {
                            null
                        },
                        // Preferências de chamada são do profissional (como `suportaChamadaDireta` no iOS): quem tem
                        // casa, ou pode cadastrar uma, é contratante e não vê o atalho. Só `Desconhecidas` (conta de
                        // profissional recebe `perfil_incompativel` da lista de casas) o mostra.
                        aoAbrirChamadasDiretas = if (chamadaDiretaHabilitada && casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(RotasChamadaProfissional.PREFERENCIAS) }
                        } else {
                            null
                        },
                        // L1-7c: apresentação e foto são do profissional, como as preferências de chamada (mesma regra de `casas`).
                        aoAbrirApresentacao = if (perfilRicoHabilitado && casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.APRESENTACAO) }
                        } else {
                            null
                        },
                        aoAbrirFotoDePerfil = if (fotoDePerfilHabilitada && casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.FOTO_DE_PERFIL) }
                        } else {
                            null
                        },
                        // O ponto base é do profissional (mesma regra de `casas`). Sem chave: sem ele a lista de vagas não abre.
                        aoAbrirPontoBase = if (casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.PONTO_BASE) }
                        } else {
                            null
                        },
                        aoAbrirFuncoesEHorarios = if (casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.FUNCOES_E_HORARIOS) }
                        } else {
                            null
                        },
                        aoAbrirHistoricoTurnos = { navController.navigate(Rotas.HISTORICO_TURNOS) },
                        aoAbrirPorQueReceboVagas = if (casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.POR_QUE_RECEBO_VAGAS) }
                        } else {
                            null
                        },
                    )
                }
            }

            // Ao salvar, volta para quem abriu: a lista de vagas recarrega sozinha ao reaparecer.
            composable(Rotas.PONTO_BASE) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: PontoBaseViewModel = koinViewModel()
                    TelaPontoBase(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoSalvo = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.FUNCOES_E_HORARIOS) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: FuncoesEHorariosViewModel = koinViewModel()
                    TelaFuncoesEHorarios(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoSalvo = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.HISTORICO_TURNOS) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: HistoricoDeTurnosViewModel = koinViewModel()
                    TelaHistoricoDeTurnos(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.POR_QUE_RECEBO_VAGAS) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: PorQueReceboVagasViewModel = koinViewModel()
                    TelaPorQueReceboVagas(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoContestar = { navController.navigate(Rotas.CONTESTAR_DESPACHO) },
                    )
                }
            }

            composable(Rotas.APRESENTACAO) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: ApresentacaoERegioesViewModel = koinViewModel()
                    TelaApresentacaoERegioes(viewModel = viewModel, aoVoltar = { navController.popBackStack() })
                }
            }

            composable(Rotas.FOTO_DE_PERFIL) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: FotoDePerfilViewModel = koinViewModel()
                    TelaFotoDePerfilConectada(viewModel = viewModel)
                }
            }

            composable(Rotas.EXCLUSAO_DE_CONTA) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: ExclusaoDeContaViewModel = koinViewModel()
                    val estado by viewModel.estado.collectAsStateWithLifecycle()
                    // Sessão já limpa por `aoConcluir`; sai da árvore autenticada como o logout faz.
                    LaunchedEffect(estado.resultado) {
                        if (estado.resultado != null) irParaEntrada()
                    }
                    TelaExclusaoDeConta(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.CONTA_SUSPENSA,
                arguments = listOf(
                    navArgument("motivo") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("desde") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) {
                // L2-5: a tela lê `situacao_da_conta` (motivo, data, contestação já aberta). Conta reativada: reavalia a abertura, que a leva ao destino de sempre.
                val aoReativar: () -> Unit = {
                    navController.navigate(if (avaliadorDeDestino != null) Rotas.ABERTURA else Rotas.FEED) {
                        popUpTo(Rotas.CONTA_SUSPENSA) { inclusive = true }
                    }
                }
                val viewModel: ContaSuspensaViewModel = koinViewModel(parameters = { parametersOf(aoReativar) })
                TelaContaSuspensaComContestacao(
                    viewModel = viewModel,
                    emailSuporte = EnderecosOficiais.padrao.emailSuporte,
                    aoContatarSuporte = { email ->
                        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$email")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        abrirForaDoApp(intent, AvisoDeAberturaExterna.semEmail(email))
                    },
                    aoSair = {
                        armazenamentoDeSessao.limparSessao()
                        irParaEntrada()
                    },
                )
            }

            composable(Rotas.CONTESTAR_DESPACHO) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: ContestarDespachoViewModel = koinViewModel()
                    TelaContestarDespacho(viewModel = viewModel, aoVoltar = { navController.popBackStack() })
                }
            }

            composable(Rotas.BLOQUEIOS) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: BloqueiosViewModel = koinViewModel()
                    TelaBloqueios(viewModel = viewModel, aoVoltar = { navController.popBackStack() })
                }
            }

            composable(
                route = Rotas.DENUNCIA,
                arguments = listOf(
                    navArgument("alvoTipo") { type = NavType.StringType },
                    navArgument("alvoId") { type = NavType.StringType },
                    navArgument("turnoId") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("chamadaId") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("fotoId") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val alvoTipo = TipoDeAlvo.entries.firstOrNull { it.chave == entrada.arguments?.getString("alvoTipo") }
                    val alvoId = entrada.arguments?.getString("alvoId").orEmpty()
                    if (alvoTipo == null || alvoId.isEmpty()) {
                        // Rota montada à mão com um tipo fora do contrato: não há quem denunciar.
                        LaunchedEffect(Unit) { navController.popBackStack() }
                    } else {
                        val turnoId = entrada.arguments?.getString("turnoId")
                        val chamadaId = entrada.arguments?.getString("chamadaId")
                        val fotoId = entrada.arguments?.getString("fotoId")
                        val viewModel: DenunciaViewModel = koinViewModel(
                            parameters = { parametersOf(alvoTipo, alvoId, turnoId, chamadaId, fotoId) },
                        )
                        TelaDenuncia(
                            viewModel = viewModel,
                            aoFechar = { navController.popBackStack() },
                            aoLigar = { numero ->
                                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$numero")).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                abrirForaDoApp(intent, AvisoDeAberturaExterna.semTelefone(numero))
                            },
                        )
                    }
                }
            }

            composable(
                route = Rotas.EQUIPE,
                arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    val viewModel: EquipeDeConfiancaViewModel = koinViewModel(
                        parameters = { parametersOf(estabelecimentoId) },
                    )
                    // A tela relê sozinha a cada aparição: só a volta do segundo plano e o push entram (`.nunca` do iOS).
                    getKoin().getOrNull<AtualizacaoAutomatica>()?.let { atualizacao ->
                        AtualizacaoAutomaticaDaLista(ListaAtualizavel.EQUIPE_DE_CONFIANCA, atualizacao, AtualizacaoAoAparecer.NUNCA) {
                            viewModel.atualizarEmSilencio().join()
                        }
                    }
                    TelaEquipeDeConfianca(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoChamarDeNovo = if (chamadaDiretaHabilitada) {
                            { profissional ->
                                navController.navigate(RotasChamadaCasa.chamar(estabelecimentoId, profissional.id))
                            }
                        } else {
                            null
                        },
                        // Denúncia sem turno associado: o alvo é o perfil público do membro da equipe.
                        aoDenunciar = { profissional ->
                            navController.navigate(Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, profissional.id, fotoId = profissional.fotoId))
                        },
                    )
                }
            }

            rotasDaChamadaDiretaCasa(navController, guardaBiometrico, buscaProfissionaisHabilitada, servicoMembros, abrirForaDoApp)
            rotasDaChamadaDiretaProfissional(navController, guardaBiometrico, buscaProfissionaisHabilitada)

            composable(Rotas.CADASTRO_ESTABELECIMENTO) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: CadastroEstabelecimentoViewModel = koinViewModel()
                    TelaCadastroEstabelecimento(
                        viewModel = viewModel,
                        // Recém-cadastrada, a casa segue direto para a primeira vaga; "Voltar" da
                        // publicação leva ao perfil, não de volta ao formulário já concluído.
                        aoConcluir = { criado ->
                            // A casa acabou de nascer: a partir daqui a raiz tem as abas dela.
                            papelDaRaiz = PapelDaRaiz.Contratante(criado.id, Rotas.minhasVagas(criado.id, criado.nome))
                            navController.navigate(Rotas.publicarVaga(criado.id)) {
                                popUpTo(Rotas.CADASTRO_ESTABELECIMENTO) { inclusive = true }
                            }
                        },
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.PUBLICAR_VAGA,
                arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    RotaPublicarVaga(
                        estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty(),
                        servicoMembros = servicoMembros,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.EQUIPE_DA_CASA,
                arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    RotaEquipeDaCasa(
                        estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty(),
                        servicoMembros = servicoMembros,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.TENHO_UM_CONVITE) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: TenhoUmConviteViewModel = koinViewModel()
                    TelaTenhoUmConvite(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoAbrirCasa = { id ->
                            if (id == null) {
                                navController.popBackStack()
                            } else {
                                abrirCasa(navController, id, null, { papelDaRaiz = it }, { casaEscolhidaId = it })
                            }
                        },
                    )
                }
            }

            composable(
                route = Rotas.TROCAR_DE_CASA,
                arguments = listOf(navArgument("atual") { type = NavType.StringType; nullable = true; defaultValue = null }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val viewModel: TrocarDeCasaViewModel = koinViewModel()
                    TelaTrocarDeCasa(
                        viewModel = viewModel,
                        casaEmUsoId = entrada.arguments?.getString("atual"),
                        aoEscolher = { casa -> abrirCasa(navController, casa.id, casa.nome, { papelDaRaiz = it }, { casaEscolhidaId = it }) },
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.PUBLICAR_ESCALA,
                arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    RotaEscalaDeEvento(
                        estabelecimentoId = estabelecimentoId,
                        servicoMembros = servicoMembros,
                        aoVoltar = { navController.popBackStack() },
                        // "Ver minhas vagas" abre Minhas vagas sempre, também quando a escala veio do Perfil: com a lista na
                        // pilha, volta até ela; sem a lista (rota aberta direto), abre a da casa no lugar da escala.
                        aoConcluir = {
                            if (!navController.popBackStack(Rotas.MINHAS_VAGAS, inclusive = false)) {
                                navController.navigate(Rotas.minhasVagas(estabelecimentoId)) {
                                    popUpTo(Rotas.PUBLICAR_ESCALA) { inclusive = true }
                                    launchSingleTop = true
                                }
                            }
                        },
                    )
                }
            }

            composable(
                route = Rotas.MINHAS_VAGAS,
                arguments = listOf(
                    navArgument("estabelecimentoId") { type = NavType.StringType },
                    navArgument("nomeEstabelecimento") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("vagaRecemPublicadaId") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    val nomeEstabelecimento = entrada.arguments?.getString("nomeEstabelecimento")?.takeIf { it.isNotBlank() }
                    val vagaRecemPublicadaId = entrada.arguments?.getString("vagaRecemPublicadaId")?.takeIf { it.isNotBlank() }
                    val viewModel: MinhasVagasViewModel = koinViewModel(
                        parameters = { parametersOf(estabelecimentoId, nomeEstabelecimento, vagaRecemPublicadaId) },
                    )
                    getKoin().getOrNull<AtualizacaoAutomatica>()?.let { atualizacao ->
                        AtualizacaoAutomaticaDaLista(ListaAtualizavel.MINHAS_VAGAS, atualizacao) { viewModel.atualizarEmSilencio().join() }
                    }
                    // L2-3: "Republicar posições em urgência" é uma confirmação na própria lista; cancelar e republicar são telas.
                    var restantesDe by remember { mutableStateOf<ItemMinhaVaga?>(null) }
                    TelaMinhasVagas(
                        viewModel = viewModel,
                        // Com as abas da casa, Minhas vagas é raiz: sem voltar. Sem elas (aberta pelo Perfil), volta.
                        aoVoltar = if (papelDaRaiz is PapelDaRaiz.Contratante) null else ({ navController.popBackStack() }),
                        aoCancelarVaga = { item -> navController.navigate(Rotas.cancelarVaga(item.id, item.inicio)) },
                        aoRepublicarVaga = { item ->
                            navController.navigate(Rotas.republicarVaga(item.id, item.selecao, duracaoDaVagaEmMinutos(item.inicio, item.fim)))
                        },
                        aoRepublicarPosicoesRestantes = { item -> restantesDe = item },
                        aoVerCandidatos = { vagaId, posicoesAbertas, inicioDaVaga ->
                            navController.navigate(Rotas.candidatosDaVaga(vagaId, posicoesAbertas, inicioDaVaga, estabelecimentoId))
                        },
                        aoPublicarVaga = { id -> navController.navigate(Rotas.publicarVaga(id)) },
                        aoPublicarEscala = { id -> navController.navigate(Rotas.publicarEscala(id)) },
                        // CD-RF09: da vaga que nasceu de uma chamada direta a casa acompanha as chamadas; só com a chave `chamada_direta` ligada.
                        aoAcompanharChamadas = if (chamadaDiretaHabilitada) {
                            { vagaId -> navController.navigate(RotasChamadaCasa.acompanhar(vagaId)) }
                        } else {
                            null
                        },
                        aoAcompanharTurno = { vagaId, posicaoId ->
                            navController.navigate(Rotas.turnoDoContratante(estabelecimentoId, vagaId, posicaoId))
                        },
                    )
                    restantesDe?.let { item ->
                        val republicar: RepublicarPosicoesRestantesViewModel = koinViewModel(
                            key = "restantes-${item.id}",
                            parameters = { parametersOf(item.id, item.republicavelEmUrgencia, { _: String -> }, { viewModel.carregar() }) },
                        )
                        TelaRepublicarPosicoesRestantes(viewModel = republicar, aoFechar = { restantesDe = null })
                    }
                }
            }

            composable(
                route = Rotas.CANCELAR_VAGA,
                arguments = listOf(
                    navArgument("vagaId") { type = NavType.StringType },
                    navArgument("inicioDaVaga") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    val inicioDaVaga = entrada.arguments?.getString("inicioDaVaga")?.let { runCatching { Instant.parse(it) }.getOrNull() }
                    val viewModel: CancelarVagaViewModel = koinViewModel(parameters = { parametersOf(vagaId, inicioDaVaga) })
                    TelaCancelarVaga(viewModel = viewModel, aoFechar = { navController.popBackStack() })
                }
            }

            composable(
                route = Rotas.REPUBLICAR_VAGA,
                arguments = listOf(
                    navArgument("vagaId") { type = NavType.StringType },
                    navArgument("selecao") { type = NavType.StringType; defaultValue = "false" },
                    navArgument("duracaoMin") { type = NavType.StringType; defaultValue = "" },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    val selecao = entrada.arguments?.getString("selecao") == "true"
                    val duracao = Duration.ofMinutes(
                        entrada.arguments?.getString("duracaoMin")?.toLongOrNull() ?: RepublicarVagaViewModel.DURACAO_MINIMA.toMinutes(),
                    )
                    val viewModel: RepublicarVagaViewModel = koinViewModel(parameters = { parametersOf(vagaId, selecao, duracao) })
                    TelaRepublicarVaga(viewModel = viewModel, aoFechar = { navController.popBackStack() })
                }
            }

            composable(Rotas.MINHAS_CANDIDATURAS) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: MinhasCandidaturasViewModel = koinViewModel()
                    getKoin().getOrNull<AtualizacaoAutomatica>()?.let { atualizacao ->
                        AtualizacaoAutomaticaDaLista(ListaAtualizavel.MINHAS_CANDIDATURAS, atualizacao) { viewModel.atualizarEmSilencio().join() }
                    }
                    var retirando by remember { mutableStateOf<ItemCandidatura?>(null) }
                    TelaMinhasCandidaturas(
                        viewModel = viewModel,
                        // Raiz com aba: sem voltar e sem título de página.
                        aoVoltar = null,
                        aoAbrir = { destino ->
                            when (destino) {
                                is DestinoDaCandidatura.Vaga -> navController.navigate(Rotas.detalhe(destino.vagaId))
                                is DestinoDaCandidatura.Turno -> navController.navigate(Rotas.turnoAviso(destino.turnoId))
                                DestinoDaCandidatura.MeusTurnos -> navController.navigate(Rotas.MEUS_TURNOS)
                            }
                        },
                        aoRetirar = { item -> retirando = item },
                    )
                    retirando?.let { item ->
                        // Um ViewModel por candidatura: a pergunta fecha e reabre sem perder o que o servidor já respondeu.
                        val retirar: RetirarCandidaturaViewModel = koinViewModel(
                            key = "retirar-${item.id}",
                            parameters = { parametersOf(item.id, { viewModel.carregar() }) },
                        )
                        TelaRetirarCandidatura(viewModel = retirar, aoFechar = { retirando = null; viewModel.carregar() })
                    }
                }
            }

            composable(
                route = Rotas.TURNO_DO_CONTRATANTE,
                arguments = listOf(
                    navArgument("estabelecimentoId") { type = NavType.StringType },
                    navArgument("vagaId") { type = NavType.StringType },
                    navArgument("posicaoId") { type = NavType.StringType },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    RotaTurnoDoContratante(
                        estabelecimentoId = estabelecimentoId,
                        vagaId = entrada.arguments?.getString("vagaId").orEmpty(),
                        posicaoId = entrada.arguments?.getString("posicaoId").orEmpty(),
                        buscarPainel = servicoVagas?.let { servico -> servico::painelEstabelecimento },
                        aoVoltar = { navController.popBackStack() },
                        checkinPorCodigoHabilitado = checkinPorCodigoHabilitado,
                        // C0-9: a casa denuncia a profissional pelo turno, como o iOS (`TelaTurnoDoContratante.swift:360`).
                        aoDenunciarProfissional = { profissionalId, turnoId ->
                            navController.navigate(Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, profissionalId, turnoId = turnoId))
                        },
                        aoPedirSuporte = pedirSuporte,
                        aoAvaliarTurno = { turnoId ->
                            navController.navigate(Rotas.avaliacaoDoContratante(turnoId, estabelecimentoId))
                        },
                    )
                }
            }

            // O toque num push da casa: o turno é achado pelo `turno_id` no painel da casa em uso. Fora dele (aviso de outra
            // casa), a entrada dá lugar a Minhas vagas, e o que estava embaixo fica.
            composable(
                route = Rotas.TURNO_DO_CONTRATANTE_AVISO,
                arguments = listOf(
                    navArgument("estabelecimentoId") { type = NavType.StringType },
                    navArgument("turnoId") { type = NavType.StringType },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    RotaTurnoDoContratante(
                        estabelecimentoId = estabelecimentoId,
                        vagaId = "",
                        posicaoId = "",
                        turnoId = entrada.arguments?.getString("turnoId").orEmpty(),
                        buscarPainel = servicoVagas?.let { servico -> servico::painelEstabelecimento },
                        aoVoltar = { navController.popBackStack() },
                        checkinPorCodigoHabilitado = checkinPorCodigoHabilitado,
                        aoDenunciarProfissional = { profissionalId, turnoId ->
                            navController.navigate(Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, profissionalId, turnoId = turnoId))
                        },
                        aoPedirSuporte = pedirSuporte,
                        aoAvaliarTurno = { turnoId ->
                            navController.navigate(Rotas.avaliacaoDoContratante(turnoId, estabelecimentoId))
                        },
                        aoNaoEncontrar = {
                            val minhasVagas = (papelDaRaiz as? PapelDaRaiz.Contratante)?.rotaDeMinhasVagas ?: Rotas.minhasVagas(estabelecimentoId)
                            navController.navigate(minhasVagas) {
                                popUpTo(Rotas.TURNO_DO_CONTRATANTE_AVISO) { inclusive = true }
                                launchSingleTop = true
                            }
                        },
                    )
                }
            }

            composable(
                route = Rotas.CANDIDATOS_DA_VAGA,
                arguments = listOf(
                    navArgument("vagaId") { type = NavType.StringType },
                    navArgument("posicoesAbertas") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("inicioDaVaga") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("estabelecimentoId") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    // A casa, quando quem abriu a tela a conhece (Minhas vagas); o aviso push só traz a vaga.
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId")
                    // Valor que não é número, negativo ou data inválida vira "não informado": o ViewModel
                    // só perde o aviso da última posição e o prazo, nunca recebe lixo.
                    val posicoesAbertas = entrada.arguments?.getString("posicoesAbertas")?.toIntOrNull()?.takeIf { it >= 0 }
                    val inicioDaVaga = entrada.arguments?.getString("inicioDaVaga")?.let { runCatching { instanteDoServidor(it) }.getOrNull() }
                    val viewModel: CandidatosDaVagaViewModel = koinViewModel(
                        parameters = { parametersOf(vagaId, posicoesAbertas, inicioDaVaga, estabelecimentoId) },
                    )
                    TelaCandidatosDaVaga(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        // Denúncia sem turno associado: a candidatura ainda não virou turno.
                        aoDenunciar = { profissional ->
                            navController.navigate(Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, profissional.id, fotoId = profissional.fotoId))
                        },
                    )
                }
            }

            if (recursoSeloHabilitado) {
                composable(Rotas.SELO_CONFIANCA) {
                    RotaProtegida(guardaBiometrico) {
                        val viewModel: VerificacaoIdentidadeViewModel = koinViewModel()
                        TelaVerificacaoDocumento(
                            viewModel = viewModel,
                            aoVoltar = { navController.popBackStack() },
                        )
                    }
                }
            }

            composable(Rotas.APARENCIA) {
                RotaProtegida(guardaBiometrico) {
                    val preferencias: PreferenciasAparencia = koinInject()
                    AparenciaDoAparelho(preferencias, aoVoltar = { navController.popBackStack() })
                }
            }

            composable(Rotas.AJUDA) {
                RotaProtegida(guardaBiometrico) {
                    TelaAjudaPerfil(
                        aoVoltar = { navController.popBackStack() },
                        aoNavegarParaLicencas = { navController.navigate(Rotas.LICENCAS) },
                        aoNavegarParaTermos = { url ->
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            abrirForaDoApp(intent, AvisoDeAberturaExterna.semNavegador(url))
                        },
                        aoNavegarParaPrivacidade = { url ->
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            abrirForaDoApp(intent, AvisoDeAberturaExterna.semNavegador(url))
                        },
                        aoAbrirEmailSuporte = { email ->
                            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$email")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            abrirForaDoApp(intent, AvisoDeAberturaExterna.semEmail(email))
                        },
                    )
                }
            }

            composable(Rotas.LICENCAS) {
                RotaProtegida(guardaBiometrico) {
                    TelaLicencas(
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.ATUALIZACAO_OBRIGATORIA) {
                val contexto = androidx.compose.ui.platform.LocalContext.current
                br.com.frila.core.designsystem.componentes.TelaAtualizacaoObrigatoria(
                    aoAtualizar = {
                        val uriLoja = android.net.Uri.parse("market://details?id=${contexto.packageName}")
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, uriLoja).apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        try {
                            contexto.startActivity(intent)
                        } catch (e: Exception) {
                            contexto.startActivity(
                                android.content.Intent(
                                    android.content.Intent.ACTION_VIEW,
                                    android.net.Uri.parse("https://play.google.com/store/apps/details?id=${contexto.packageName}"),
                                ).apply {
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                },
                            )
                        }
                    },
                )
            }
        }

        // RNF01 (cartão 9Q0sJIzW): banner flutuante centralizado sobre o NavHost — nunca dentro
        // de uma tela de feature individual (escopo explícito do cartão).
        BannerDeConectividade(
            status = statusConectividade,
            modifier = Modifier.align(Alignment.TopCenter).padding(16.dp),
        )
        avisoDeAberturaExterna?.let { aviso ->
            DialogoDeAberturaExterna(aviso = aviso, aoFechar = { avisoDeAberturaExterna = null })
        }
    }
    BarraDaRaiz(navController = navController, papel = papelDaRaiz, padraoAtual = padraoAtual)
    }
}

/** A duração da vaga de origem, em minutos, dentro do que a republicação aceita (2 a 16 h). Sem os dois instantes, o mínimo. */
private fun duracaoDaVagaEmMinutos(inicio: Instant?, fim: Instant?): Long {
    val minima = RepublicarVagaViewModel.DURACAO_MINIMA
    val maxima = RepublicarVagaViewModel.DURACAO_MAXIMA
    if (inicio == null || fim == null) return minima.toMinutes()
    return minOf(maxOf(Duration.between(inicio, fim), minima), maxima).toMinutes()
}

private const val CHAVE_VAGA_SALVA = "vaga_aberta_json"

/**
 * Navega para uma rota de desfecho do detalhe levando a [VagaAbertaDto] serializada no `SavedStateHandle`
 * da entrada de destino, para sobreviver à morte do processo sem precisar reconstruir `DetalheVagaViewModel`.
 */
private fun navegarComVaga(navController: NavHostController, rota: String, vaga: VagaAbertaDto) {
    navController.navigate(rota)
    navController.currentBackStackEntry?.savedStateHandle?.set(
        CHAVE_VAGA_SALVA,
        ClienteSupabase.jsonFrila.encodeToString(VagaAbertaDto.serializer(), vaga),
    )
}

/**
 * Volta ao feed quando o destino ficou sem vaga: observa o topo atual como chave do efeito para reavaliar
 * se voltar ao topo depois, e remove a rota sem vaga da pilha mesmo quando `FEED` não estava nela.
 */
@Composable
internal fun FallbackVoltarAoFeed(
    navController: NavHostController,
    entrada: NavBackStackEntry,
) {
    val topoAtual by navController.currentBackStackEntryAsState()
    LaunchedEffect(entrada.id, topoAtual?.id) {
        if (topoAtual?.id == entrada.id) {
            val feedNaPilha = runCatching { navController.getBackStackEntry(Rotas.FEED) }.isSuccess
            navController.navigate(Rotas.FEED) {
                if (feedNaPilha) {
                    popUpTo(Rotas.FEED) { inclusive = true }
                } else {
                    popUpTo(entrada.destination.id) { inclusive = true }
                }
                launchSingleTop = true
            }
        }
    }
}

/**
 * Lê a vaga na ordem: `SavedStateHandle` da própria entrada (sobrevive à morte do processo) ->
 * `FeedVagasViewModel` do `FEED` na pilha -> `null`. Nunca instancia `DetalheVagaViewModel` fora de `DETALHE`.
 */
@Composable
private fun vagaDaPilha(
    navController: NavHostController,
    entrada: NavBackStackEntry,
    vagaId: String,
): VagaAbertaDto? {
    val jsonSalvo = entrada.savedStateHandle.get<String>(CHAVE_VAGA_SALVA)
    val vagaSalva = remember(entrada.id, vagaId, jsonSalvo) {
        jsonSalvo?.let { json ->
            runCatching { ClienteSupabase.jsonFrila.decodeFromString(VagaAbertaDto.serializer(), json) }
                .getOrNull()
                ?.takeIf { it.id == vagaId }
        }
    }
    if (vagaSalva != null) return vagaSalva

    val feedNaPilha = runCatching { navController.getBackStackEntry(Rotas.FEED) }.getOrNull()
        ?.let { koinViewModel<FeedVagasViewModel>(viewModelStoreOwner = it) }
    return feedNaPilha?.estado?.collectAsStateWithLifecycle()?.value
        ?.let { feedNaPilha.encontrarVagaPorId(vagaId) }
}

/** Extraído para ser testável sozinho, sem montar o grafo Koin/NavHost completo. */
@Composable
fun BannerDeConectividade(status: StatusConectividade, modifier: Modifier = Modifier) {
    AnimatedVisibility(
        visible = status == StatusConectividade.SEM_CONEXAO,
        modifier = modifier,
    ) {
        AvisoFrila(
            tom = TomAviso.ALERTA,
            mensagem = "Sem conexão com a internet. Verifique sua rede.",
        )
    }
}
