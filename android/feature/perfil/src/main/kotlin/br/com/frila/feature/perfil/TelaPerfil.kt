package br.com.frila.feature.perfil

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.EscopoDoGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeNavegacao
import br.com.frila.core.designsystem.tema.FrilaRaios
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.core.app.NotificationManagerCompat
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.TomAviso
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import android.content.Intent
import android.provider.Settings
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.semantics.stateDescription
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import androidx.core.content.FileProvider
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.VerificacaoIdentidade
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.ReputacaoDto
import kotlin.math.roundToInt

/**
 * Perfil do profissional (RF02/RF03/RF16/RF25/RN15/RNF08, UC09/UC16):
 * - RF02: Bio profissional limitada a 280 caracteres com contador e especialidades em FlowRow com ChipFrila.
 * - Reputação sempre com denominador (RN08), nunca uma média sem contexto (RN07).
 * - Logout e exclusão de conta locais primeiro (RN15) — a sessão só é limpa depois da confirmação
 *   (logout) ou do sucesso da Edge Function (exclusão), nunca antes.
 */
/** Um atalho da conta que vem de outro módulo (o app dá o rótulo, a marca de teste e para onde vai). */
data class AtalhoDaConta(val rotulo: String, val tag: String, val aoAbrir: () -> Unit)

@Composable
fun TelaPerfil(
    viewModel: PerfilViewModel,
    modifier: Modifier = Modifier,
    /** Atalhos de outros módulos (bloqueados, contestar o despacho), como linhas do grupo da conta, antes da "Ajuda". */
    atalhosExtras: List<AtalhoDaConta> = emptyList(),
    aoDeslogar: () -> Unit = {},
    aoAbrirAjuda: () -> Unit = {},
    /**
     * Exclusão de conta em tela cheia (cartão mDizumRD). Nulo mantém o diálogo de confirmação
     * deste perfil; informado, "Excluir conta" navega para a tela dedicada.
     */
    aoAbrirExclusaoDeConta: (() -> Unit)? = null,
    /** Equipe de confiança (RF18): nulo esconde o atalho, que só existe para quem administra um estabelecimento. */
    aoAbrirEquipe: (() -> Unit)? = null,
    /** Publicar vaga (RF04): nulo esconde o atalho, que só existe para quem é membro de um estabelecimento. */
    aoPublicarVaga: (() -> Unit)? = null,
    /** Minhas vagas (RF20): nulo esconde o atalho, que só existe para quem é membro de um estabelecimento. */
    aoMinhasVagas: (() -> Unit)? = null,
    /** Cadastrar estabelecimento (RF02): nulo esconde o atalho, que só existe para contratante que ainda não tem casa. */
    aoCadastrarEstabelecimento: (() -> Unit)? = null,
    /**
     * Chamada direta, lado do profissional (contrato 0.2.88): nulo esconde o atalho "Preferências de chamadas". O
     * chamador só informa com `recursos.chamada_direta` ligado (RN46) e para quem é profissional.
     */
    aoAbrirChamadasDiretas: (() -> Unit)? = null,
    /** L1-7c: atalhos do profissional para "Apresentação e regiões" e "Foto de perfil". Nulo esconde o atalho (chaves `perfil_rico` e `foto_de_perfil`). */
    aoAbrirApresentacao: (() -> Unit)? = null,
    aoAbrirFotoDePerfil: (() -> Unit)? = null,
    /** Atalho do profissional para o ponto base (tela provisória). Nulo esconde o atalho. */
    aoAbrirPontoBase: (() -> Unit)? = null,
    /**
     * Busca de profissionais pela casa (tela provisória): nulo esconde o atalho "Encontrar profissional". O chamador só
     * informa com `recursos.busca_profissionais` ligado (RN46) e para quem é membro de um estabelecimento.
     */
    aoEncontrarProfissional: (() -> Unit)? = null,
    /**
     * Mantém os atalhos da casa quando o perfil cai em erro (sem rede, servidor fora do ar).
     * O erro e a tentativa novamente continuam visíveis; esta flag nunca transforma falha em sucesso.
     */
    manterAtalhosDeContratanteNoErro: Boolean = false,
    /**
     * Trava do selo (RN14): desligada por padrão até a moderação e os termos serem validados pelos
     * sócios. Desligada, badge e convite não aparecem, qualquer que seja o estado recebido.
     */
    recursoSeloHabilitado: Boolean = false,
    /** Selo "Identidade Verificada" (RN14): estado já lido pelo chamador; nulo esconde o bloco. */
    verificacaoIdentidade: VerificacaoIdentidade? = null,
    podeSolicitarSelo: Boolean = false,
    aoAbrirSelo: () -> Unit = {},
    /**
     * C0-11 (decisão de 16/11/2026: o Android fica só com o que o iOS tem). O iOS não tem desbloqueio por
     * biometria: desligado, o interruptor não aparece. Desligar a entrada, sem apagar o código.
     */
    recursoBiometriaHabilitado: Boolean = false,
    /** C0-11: o iOS não tem "Remunerações acordadas" com extrato em PDF; desligado, o bloco não aparece. */
    recursoRemuneracoesHabilitado: Boolean = false,
    /**
     * Injetáveis para teste (RN15) — sem sensor físico/emulador não há como simular o hardware
     * real, e o host do `createComposeRule()` não é um `FragmentActivity` (por isso o cast fica
     * dentro do valor padrão, não em [TelaPerfil], e o teste nunca precisa de uma Activity real).
     */
    verificarDisponibilidadeBiometrica: (Context) -> DisponibilidadeBiometrica = AutenticadorBiometrico::verificarDisponibilidade,
    autenticarBiometria: (Context, aoSucesso: () -> Unit, aoErro: (String) -> Unit) -> Unit = { ctx, aoSucesso, aoErro ->
        val activity = ctx as? FragmentActivity
        if (activity != null) {
            AutenticadorBiometrico.autenticar(activity, aoSucesso, aoErro)
        } else {
            aoErro("Não foi possível abrir a autenticação biométrica.")
        }
    },
    verificarNotificacoesDoSistema: (Context) -> Boolean = { ctx ->
        NotificationManagerCompat.from(ctx).areNotificationsEnabled()
    },
    relatoriosDeFalhasAtivados: Boolean = false,
    aoAlternarRelatoriosDeFalhas: ((Boolean) -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val contexto = LocalContext.current
    // Com o recurso desligado o hardware nem é consultado: o app não declara a permissão de biometria, e a consulta sem ela lança.
    val disponibilidadeBiometrica = remember(recursoBiometriaHabilitado) {
        if (recursoBiometriaHabilitado) verificarDisponibilidadeBiometrica(contexto) else DisponibilidadeBiometrica.INDISPONIVEL
    }
    val lifecycleOwner = LocalLifecycleOwner.current
    var notificacoesDoSistemaAtivadas by remember {
        mutableStateOf(verificarNotificacoesDoSistema(contexto))
    }

    DisposableEffect(lifecycleOwner, contexto) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                notificacoesDoSistemaAtivadas = verificarNotificacoesDoSistema(contexto)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }
    var mensagemErroBiometria by remember { mutableStateOf<String?>(null) }
    val alternarBiometria: (Boolean) -> Unit = { marcado ->
        if (!marcado) {
            mensagemErroBiometria = null
            viewModel.definirBiometriaAtivada(false)
        } else {
            autenticarBiometria(
                contexto,
                { mensagemErroBiometria = null; viewModel.definirBiometriaAtivada(true) },
                { erro -> mensagemErroBiometria = erro },
            )
        }
    }

    // RF03/RNF04: repõe o avatar persistido ao montar a tela — independente do carregamento de
    // rede em viewModel.carregar(). MEDIDO (Shisui, PR #590): sem isto o avatar desaparecia ao
    // reabrir o app/tela.
    LaunchedEffect(Unit) {
        viewModel.carregarAvatarSalvo(contexto)
    }

    // RF25/UC16: a exclusão com sucesso expulsa a navegação do mesmo jeito que o logout —
    // a sessão local já foi limpa pelo ViewModel antes de chegar aqui.
    LaunchedEffect(estado.statusExclusao) {
        if (estado.statusExclusao == StatusExclusao.SUCESSO) {
            aoDeslogar()
        }
    }

    Scaffold(
        modifier = modifier,
        containerColor = FrilaTema.cores.fundo,
    ) { paddingInterno ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingInterno)) {
            CabecalhoDoPerfil(aoAbrirAjuda = aoAbrirAjuda)
            // A casa não tem perfil profissional: o perfil dela é a conta (`minha_conta`) e os atalhos da casa, como o iOS.
            if (estado.status == StatusPerfil.SUCESSO && estado.ehContratante) {
                ConteudoDaCasa(
                    nome = estado.conta?.nome.orEmpty(),
                    aoDeslogar = {
                        viewModel.aoDeslogar()
                        aoDeslogar()
                    },
                    aoAbrirExclusao = aoAbrirExclusaoDeConta ?: viewModel::abrirDialogoExclusao,
                    biometriaAtivada = estado.biometriaAtivada,
                    disponibilidadeBiometrica = disponibilidadeBiometrica,
                    mensagemErroBiometria = mensagemErroBiometria,
                    aoAlternarBiometria = alternarBiometria,
                    mostrarBiometria = recursoBiometriaHabilitado,
                    aoAbrirAjuda = aoAbrirAjuda,
                    aoAbrirEquipe = aoAbrirEquipe,
                    aoPublicarVaga = aoPublicarVaga,
                    aoMinhasVagas = aoMinhasVagas,
                    aoCadastrarEstabelecimento = aoCadastrarEstabelecimento,
                    aoEncontrarProfissional = aoEncontrarProfissional,
                    relatoriosDeFalhasAtivados = relatoriosDeFalhasAtivados,
                    aoAlternarRelatoriosDeFalhas = aoAlternarRelatoriosDeFalhas,
                    modifier = Modifier.weight(1f),
                    atalhosExtras = atalhosExtras,
                )
            } else when (estado.status) {
                StatusPerfil.CARREGANDO -> Carregando(Modifier.weight(1f))
                StatusPerfil.ERRO -> Erro(
                    mensagem = estado.mensagemErro,
                    aoTentarNovamente = viewModel::carregar,
                    aoAbrirEquipe = aoAbrirEquipe.takeIf { manterAtalhosDeContratanteNoErro },
                    aoPublicarVaga = aoPublicarVaga.takeIf { manterAtalhosDeContratanteNoErro },
                    aoMinhasVagas = aoMinhasVagas.takeIf { manterAtalhosDeContratanteNoErro },
                    // Com o perfil em erro (sem rede, por exemplo), a busca da casa continua acessível.
                    aoEncontrarProfissional = aoEncontrarProfissional.takeIf { manterAtalhosDeContratanteNoErro },
                    // Sair e excluir a conta não dependem do perfil ter carregado: mesmos caminhos do perfil carregado.
                    aoDeslogar = {
                        viewModel.aoDeslogar()
                        aoDeslogar()
                    },
                    aoAbrirExclusao = aoAbrirExclusaoDeConta ?: viewModel::abrirDialogoExclusao,
                    modifier = Modifier.weight(1f),
                    atalhosExtras = atalhosExtras,
                )
                StatusPerfil.SUCESSO -> ConteudoDoPerfil(
                    nome = estado.conta?.nome,
                    fotoLocalPath = estado.fotoLocalPath,
                    statusFoto = estado.statusFoto,
                    mensagemErroFoto = estado.mensagemErroFoto,
                    aoSelecionarFoto = { uri -> viewModel.selecionarFoto(contexto, uri) },
                    funcoes = estado.perfil?.funcoes.orEmpty(),
                    reputacao = estado.perfil?.reputacao,
                    resumoFinanceiro = estado.resumoFinanceiro,
                    aoExportarExtrato = {
                        // DEDUZIDO: PerfilProfissionalDto não traz nome do profissional (só id,
                        // usuario_id, funcoes, ponto_base, disponibilidades, reputacao — MEDIDO em
                        // Dtos.kt:282-289). Sem esse campo no contrato, o cabeçalho do PDF usa um
                        // rótulo neutro em vez de inventar uma fonte de nome fora de escopo.
                        val arquivo = viewModel.exportarExtratoPdf(contexto.cacheDir, "Profissional")
                        if (arquivo != null) {
                            val uri = FileProvider.getUriForFile(contexto, "${contexto.packageName}.fileprovider", arquivo)
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/pdf"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_SUBJECT, "Extrato de Remunerações Frila")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            contexto.startActivity(Intent.createChooser(intent, "Compartilhar extrato em PDF"))
                        }
                    },
                    bio = estado.bio,
                    bioEmEdicao = estado.bioEmEdicao,
                    estaEditandoBio = estado.estaEditandoBio,
                    caracteresRestantesBio = estado.caracteresRestantesBio,
                    especialidadesDisponiveis = estado.especialidadesDisponiveis,
                    especialidadesSelecionadas = estado.especialidadesSelecionadas,
                    aoIniciarEdicaoBio = viewModel::iniciarEdicaoBio,
                    aoAtualizarBioEmEdicao = viewModel::atualizarBioEmEdicao,
                    aoSalvarBio = viewModel::salvarBio,
                    aoCancelarEdicaoBio = viewModel::cancelarEdicaoBio,
                    aoAlternarEspecialidade = viewModel::alternarEspecialidade,
                    aoDeslogar = {
                        viewModel.aoDeslogar()
                        aoDeslogar()
                    },
                    aoAbrirExclusao = aoAbrirExclusaoDeConta ?: viewModel::abrirDialogoExclusao,
                    biometriaAtivada = estado.biometriaAtivada,
                    disponibilidadeBiometrica = disponibilidadeBiometrica,
                    mensagemErroBiometria = mensagemErroBiometria,
                    aoAlternarBiometria = alternarBiometria,
                    mostrarBiometria = recursoBiometriaHabilitado,
                    mostrarRemuneracoes = recursoRemuneracoesHabilitado,
                    notificacaoUrgenciaAtivada = estado.notificacaoUrgenciaAtivada,
                    notificacaoTurnosAtivada = estado.notificacaoTurnosAtivada,
                    notificacaoSistemaAtivada = estado.notificacaoSistemaAtivada,
                    aoAlternarNotificacao = viewModel::definirNotificacaoAtivada,
                    notificacoesDoSistemaAtivadas = notificacoesDoSistemaAtivadas,
                    aoAbrirAjuda = aoAbrirAjuda,
                    aoAbrirEquipe = aoAbrirEquipe,
                    aoPublicarVaga = aoPublicarVaga,
                    aoMinhasVagas = aoMinhasVagas,
                    aoCadastrarEstabelecimento = aoCadastrarEstabelecimento,
                    aoAbrirChamadasDiretas = aoAbrirChamadasDiretas,
                    aoAbrirApresentacao = aoAbrirApresentacao,
                    aoAbrirFotoDePerfil = aoAbrirFotoDePerfil,
                    aoAbrirPontoBase = aoAbrirPontoBase,
                    aoEncontrarProfissional = aoEncontrarProfissional,
                    verificacaoIdentidade = verificacaoIdentidade.takeIf { recursoSeloHabilitado },
                    podeSolicitarSelo = podeSolicitarSelo && recursoSeloHabilitado,
                    aoAbrirSelo = aoAbrirSelo,
                    relatoriosDeFalhasAtivados = relatoriosDeFalhasAtivados,
                    aoAlternarRelatoriosDeFalhas = aoAlternarRelatoriosDeFalhas,
                    modifier = Modifier.weight(1f),
                    atalhosExtras = atalhosExtras,
                )
            }
        }

        when (estado.statusExclusao) {
            StatusExclusao.DIALOGO_ABERTO -> DialogoConfirmarExclusao(
                aoConfirmar = { viewModel.confirmarExclusao() },
                aoCancelar = viewModel::cancelarExclusao,
            )
            StatusExclusao.EXCLUINDO -> DialogoExcluindo()
            StatusExclusao.ERRO -> DialogoErroExclusao(
                mensagem = estado.mensagemErroExclusao,
                aoFechar = viewModel::cancelarExclusao,
            )
            StatusExclusao.OCIOSO, StatusExclusao.SUCESSO -> Unit
        }
    }
}

/**
 * Título e ajuda no alto do perfil. A tela é raiz de aba: não há barra de navegação nem seta de voltar, só o título
 * da tela e o atalho da ajuda, que continua sendo um ícone com alvo de 48dp.
 */
@Composable
private fun CabecalhoDoPerfil(aoAbrirAjuda: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = FrilaEspacamento.grupo, end = FrilaEspacamento.compacto, top = FrilaEspacamento.item, bottom = FrilaEspacamento.item),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TituloDaTela("Meu Perfil", modifier = Modifier.weight(1f))
        IconButton(
            onClick = aoAbrirAjuda,
            modifier = Modifier
                .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo)
                .testTag("botao-ajuda-barra"),
        ) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = "Ajuda",
                tint = FrilaTema.cores.tinta,
            )
        }
    }
}

/** Uma seção do perfil: o nome do grupo (cabeçalho para o leitor de tela) e, embaixo, o conteúdo dela. */
@Composable
private fun SecaoDoPerfil(titulo: String, conteudo: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(titulo)
        conteudo()
    }
}

@Composable
private fun ConteudoDoPerfil(
    nome: String?,
    fotoLocalPath: String?,
    statusFoto: StatusFotoPerfil,
    mensagemErroFoto: String?,
    aoSelecionarFoto: (Uri) -> Unit,
    funcoes: List<FuncaoDto>,
    reputacao: ReputacaoDto?,
    resumoFinanceiro: ResumoFinanceiroPerfil?,
    aoExportarExtrato: () -> Unit,
    bio: String,
    bioEmEdicao: String,
    estaEditandoBio: Boolean,
    caracteresRestantesBio: Int,
    especialidadesDisponiveis: List<String>,
    especialidadesSelecionadas: Set<String>,
    aoIniciarEdicaoBio: () -> Unit,
    aoAtualizarBioEmEdicao: (String) -> Unit,
    aoSalvarBio: () -> Unit,
    aoCancelarEdicaoBio: () -> Unit,
    aoAlternarEspecialidade: (String) -> Unit,
    aoDeslogar: () -> Unit,
    aoAbrirExclusao: () -> Unit,
    biometriaAtivada: Boolean,
    disponibilidadeBiometrica: DisponibilidadeBiometrica,
    mensagemErroBiometria: String?,
    aoAlternarBiometria: (Boolean) -> Unit,
    mostrarBiometria: Boolean = false,
    mostrarRemuneracoes: Boolean = false,
    notificacaoUrgenciaAtivada: Boolean,
    notificacaoTurnosAtivada: Boolean,
    notificacaoSistemaAtivada: Boolean,
    aoAlternarNotificacao: (canal: String, ativado: Boolean) -> Unit,
    notificacoesDoSistemaAtivadas: Boolean,
    modifier: Modifier = Modifier,
    aoAbrirAjuda: () -> Unit = {},
    aoAbrirEquipe: (() -> Unit)? = null,
    aoPublicarVaga: (() -> Unit)? = null,
    aoMinhasVagas: (() -> Unit)? = null,
    aoCadastrarEstabelecimento: (() -> Unit)? = null,
    aoAbrirChamadasDiretas: (() -> Unit)? = null,
    /** L1-7c: atalhos do profissional para "Apresentação e regiões" e "Foto de perfil". Nulo esconde o atalho (chaves `perfil_rico` e `foto_de_perfil`). */
    aoAbrirApresentacao: (() -> Unit)? = null,
    aoAbrirFotoDePerfil: (() -> Unit)? = null,
    /** Atalho do profissional para o ponto base. Nulo esconde o atalho. */
    aoAbrirPontoBase: (() -> Unit)? = null,
    aoEncontrarProfissional: (() -> Unit)? = null,
    verificacaoIdentidade: VerificacaoIdentidade? = null,
    podeSolicitarSelo: Boolean = false,
    aoAbrirSelo: () -> Unit = {},
    atalhosExtras: List<AtalhoDaConta> = emptyList(),
    relatoriosDeFalhasAtivados: Boolean = false,
    aoAlternarRelatoriosDeFalhas: ((Boolean) -> Unit)? = null,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(start = FrilaEspacamento.grupo, end = FrilaEspacamento.grupo, top = FrilaEspacamento.item, bottom = FrilaEspacamento.grupo),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
    ) {
        BlocoDeAvatar(
            nome = nome,
            fotoLocalPath = fotoLocalPath,
            statusFoto = statusFoto,
            mensagemErroFoto = mensagemErroFoto,
            aoSelecionarFoto = aoSelecionarFoto,
        )
        BlocoDeReputacao(reputacao)
        BlocoDeSeloConfianca(verificacaoIdentidade, podeSolicitarSelo, aoAbrirSelo)
        // C0-11: o iOS não tem; só aparece com a trava ligada, que nada no app liga.
        if (mostrarRemuneracoes) BlocoDeRemuneracoes(resumoFinanceiro, aoExportarExtrato)
        BlocoDeBioProfissional(
            bio = bio,
            bioEmEdicao = bioEmEdicao,
            estaEditandoBio = estaEditandoBio,
            caracteresRestantes = caracteresRestantesBio,
            aoIniciarEdicao = aoIniciarEdicaoBio,
            aoAtualizarBio = aoAtualizarBioEmEdicao,
            aoSalvar = aoSalvarBio,
            aoCancelar = aoCancelarEdicaoBio,
        )
        BlocoDeEspecialidades(
            especialidades = especialidadesDisponiveis,
            selecionadas = especialidadesSelecionadas,
            aoAlternar = aoAlternarEspecialidade,
        )
        BlocoDeFuncoes(funcoes)
        BlocoDeNotificacoes(
            urgenciaAtivada = notificacaoUrgenciaAtivada,
            turnosAtivada = notificacaoTurnosAtivada,
            sistemaAtivada = notificacaoSistemaAtivada,
            aoAlternar = aoAlternarNotificacao,
            notificacoesDoSistemaAtivadas = notificacoesDoSistemaAtivadas,
        )
        BlocoDeConta(
            aoDeslogar = aoDeslogar,
            aoAbrirExclusao = aoAbrirExclusao,
            biometriaAtivada = biometriaAtivada,
            disponibilidadeBiometrica = disponibilidadeBiometrica,
            mensagemErroBiometria = mensagemErroBiometria,
            aoAlternarBiometria = aoAlternarBiometria,
            mostrarBiometria = mostrarBiometria,
            aoAbrirAjuda = aoAbrirAjuda,
            aoAbrirEquipe = aoAbrirEquipe,
            aoPublicarVaga = aoPublicarVaga,
            aoMinhasVagas = aoMinhasVagas,
            aoCadastrarEstabelecimento = aoCadastrarEstabelecimento,
            aoAbrirChamadasDiretas = aoAbrirChamadasDiretas,
            aoAbrirApresentacao = aoAbrirApresentacao,
            aoAbrirFotoDePerfil = aoAbrirFotoDePerfil,
            aoAbrirPontoBase = aoAbrirPontoBase,
            aoEncontrarProfissional = aoEncontrarProfissional,
            atalhosExtras = atalhosExtras,
            relatoriosDeFalhasAtivados = relatoriosDeFalhasAtivados,
            aoAlternarRelatoriosDeFalhas = aoAlternarRelatoriosDeFalhas,
        )
    }
}

/**
 * Perfil da casa (C0-4b): a conta de contratante não tem perfil profissional (`meu_perfil_profissional` responde
 * 404). Mostra o nome da conta e o bloco de conta com os atalhos da casa, sem os blocos do profissional; as
 * preferências de chamada são do profissional e nunca aparecem aqui.
 */
@Composable
private fun ConteudoDaCasa(
    nome: String,
    aoDeslogar: () -> Unit,
    aoAbrirExclusao: () -> Unit,
    biometriaAtivada: Boolean,
    disponibilidadeBiometrica: DisponibilidadeBiometrica,
    mensagemErroBiometria: String?,
    aoAlternarBiometria: (Boolean) -> Unit,
    mostrarBiometria: Boolean,
    aoAbrirAjuda: () -> Unit,
    aoAbrirEquipe: (() -> Unit)?,
    aoPublicarVaga: (() -> Unit)?,
    aoMinhasVagas: (() -> Unit)?,
    aoCadastrarEstabelecimento: (() -> Unit)?,
    aoEncontrarProfissional: (() -> Unit)?,
    modifier: Modifier = Modifier,
    atalhosExtras: List<AtalhoDaConta> = emptyList(),
    relatoriosDeFalhasAtivados: Boolean = false,
    aoAlternarRelatoriosDeFalhas: ((Boolean) -> Unit)? = null,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(start = FrilaEspacamento.grupo, end = FrilaEspacamento.grupo, top = FrilaEspacamento.item, bottom = FrilaEspacamento.grupo),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
    ) {
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = nome,
                style = FrilaTipo.nome,
                color = FrilaTema.cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
        }
        BlocoDeConta(
            aoDeslogar = aoDeslogar,
            aoAbrirExclusao = aoAbrirExclusao,
            biometriaAtivada = biometriaAtivada,
            disponibilidadeBiometrica = disponibilidadeBiometrica,
            mensagemErroBiometria = mensagemErroBiometria,
            aoAlternarBiometria = aoAlternarBiometria,
            mostrarBiometria = mostrarBiometria,
            aoAbrirAjuda = aoAbrirAjuda,
            aoAbrirEquipe = aoAbrirEquipe,
            aoPublicarVaga = aoPublicarVaga,
            aoMinhasVagas = aoMinhasVagas,
            aoCadastrarEstabelecimento = aoCadastrarEstabelecimento,
            aoAbrirChamadasDiretas = null,
            aoAbrirApresentacao = null,
            aoAbrirFotoDePerfil = null,
            aoEncontrarProfissional = aoEncontrarProfissional,
            atalhosExtras = atalhosExtras,
            relatoriosDeFalhasAtivados = relatoriosDeFalhasAtivados,
            aoAlternarRelatoriosDeFalhas = aoAlternarRelatoriosDeFalhas,
        )
    }
}

/**
 * RF06: preferências locais de notificação por canal (vagas urgentes, turnos, geral), mais o
 * atalho para as configurações de notificação do sistema (Android 13+ controla a permissão
 * `POST_NOTIFICATIONS` lá fora do app). Cada linha é toggleable inteira — não só o Switch — e
 * leva `stateDescription` para o leitor de tela anunciar "ativado"/"desativado".
 */
@Composable
private fun BlocoDeNotificacoes(
    urgenciaAtivada: Boolean,
    turnosAtivada: Boolean,
    sistemaAtivada: Boolean,
    aoAlternar: (canal: String, ativado: Boolean) -> Unit,
    notificacoesDoSistemaAtivadas: Boolean,
) {
    val contexto = LocalContext.current
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        FrilaGrupoDeLinhas(titulo = "Notificações") {
            linha {
                LinhaDeValor(
                    rotulo = "Permissão no sistema",
                    valor = if (notificacoesDoSistemaAtivadas) "Ativadas" else "Desativadas",
                    modifier = Modifier.testTag("status-notificacoes-sistema"),
                    modificadorDoValor = Modifier.semantics {
                        stateDescription = if (notificacoesDoSistemaAtivadas) "ativado" else "desativado"
                    },
                )
            }
            linha { LinhaDeNotificacao("Vagas urgentes", GerenciadorDeCanais.CANAL_URGENCIA, urgenciaAtivada, aoAlternar) }
            linha { LinhaDeNotificacao("Turnos", GerenciadorDeCanais.CANAL_TURNOS, turnosAtivada, aoAlternar) }
            linha { LinhaDeNotificacao("Geral", GerenciadorDeCanais.CANAL_SISTEMA, sistemaAtivada, aoAlternar) }
            linha {
                FrilaLinhaDeNavegacao(
                    titulo = "Configurações de notificação do sistema",
                    aoClicar = {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, contexto.packageName)
                        contexto.startActivity(intent)
                    },
                )
            }
        }
        if (!notificacoesDoSistemaAtivadas) {
            AvisoFrila(
                tom = TomAviso.ALERTA,
                mensagem = "Notificações desativadas no Android. Ative nas configurações do sistema para receber alertas de vagas e turnos.",
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("aviso-notificacoes-desativadas-sistema"),
            )
        }
    }
}

@Composable
private fun LinhaDeNotificacao(
    rotulo: String,
    canal: String,
    ativada: Boolean,
    aoAlternar: (canal: String, ativado: Boolean) -> Unit,
) {
    LinhaDeInterruptor(
        rotulo = rotulo,
        ativada = ativada,
        aoAlternar = { novoValor -> aoAlternar(canal, novoValor) },
        modifier = Modifier
            .testTag("toggle-notificacao-$canal")
            .semantics { stateDescription = if (ativada) "ativado" else "desativado" },
    )
}

/**
 * RF03/RNF04: avatar do profissional, selecionável via Android Photo Picker
 * (`ActivityResultContracts.PickVisualMedia`, sem permissão de storage) e comprimido
 * defensivamente antes de exibir (ver [CompressorDeFotoPerfil]). Sem foto cadastrada, mostra um
 * placeholder circular neutro — nunca um espaço vazio sem explicação.
 */
@Composable
private fun BlocoDeAvatar(
    nome: String?,
    fotoLocalPath: String?,
    statusFoto: StatusFotoPerfil,
    mensagemErroFoto: String?,
    aoSelecionarFoto: (Uri) -> Unit,
) {
    val cores = FrilaTema.cores
    val lancadorDeSelecao = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri -> if (uri != null) aoSelecionarFoto(uri) }

    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            Box(modifier = Modifier.size(TAMANHO_DO_AVATAR), contentAlignment = Alignment.Center) {
                // DEDUZIDO: decodificar o arquivo inteiro aqui é seguro porque ele já foi
                // comprimido para no máximo 512px por CompressorDeFotoPerfil — não é a imagem
                // original de origem desconhecida que motivou a subamostragem defensiva (RNF04).
                val imagemAvatar = remember(fotoLocalPath) {
                    fotoLocalPath?.let { caminho -> BitmapFactory.decodeFile(caminho)?.asImageBitmap() }
                }
                if (imagemAvatar != null) {
                    Image(
                        bitmap = imagemAvatar,
                        contentDescription = "Foto de perfil do profissional",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.size(TAMANHO_DO_AVATAR).clip(CircleShape),
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(TAMANHO_DO_AVATAR)
                            .clip(CircleShape)
                            .background(cores.superficiePressionada),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Person,
                            contentDescription = "Sem foto de perfil cadastrada",
                            tint = cores.tintaSuave,
                            modifier = Modifier.size(32.dp),
                        )
                    }
                }
                if (statusFoto == StatusFotoPerfil.COMPRIMINDO) {
                    IndicadorCarregando(
                        modifier = Modifier
                            .size(TAMANHO_DO_AVATAR)
                            .semantics { contentDescription = "Processando foto de perfil" },
                    )
                }
            }
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                if (!nome.isNullOrBlank()) {
                    Text(text = nome, style = FrilaTipo.nome, color = cores.tinta)
                }
                LinkFrila(
                    texto = "Alterar foto de perfil",
                    aoClicar = {
                        lancadorDeSelecao.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                )
                if (statusFoto == StatusFotoPerfil.ERRO) {
                    val textoErro = mensagemErroFoto ?: "Não foi possível processar a foto."
                    // Problema não tem cor: o erro vai escrito em tinta, e o leitor de tela o anuncia na hora.
                    Text(
                        text = textoErro,
                        style = FrilaTipo.apoio,
                        color = cores.tinta,
                        modifier = Modifier.semantics {
                            liveRegion = LiveRegionMode.Assertive
                            error(textoErro)
                        },
                    )
                }
            }
        }
    }
}

private val TAMANHO_DO_AVATAR = 64.dp

/** RN07/RN08: binária com denominador obrigatório. Nunca nota, nunca média sem "de quantas". */
@Composable
private fun BlocoDeReputacao(reputacao: ReputacaoDto?) {
    val cores = FrilaTema.cores
    SecaoDoPerfil("Reputação") {
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                if (reputacao == null || reputacao.total == 0) {
                    Text(text = "Sem histórico de avaliações", style = FrilaTipo.corpo, color = cores.tinta)
                } else {
                    Text(
                        text = "${reputacao.positivas} de ${reputacao.total} recomendariam de novo",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                    Text(
                        text = "Taxa de comparecimento: ${formatarTaxa(reputacao.taxaComparecimento)}",
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                    Text(
                        text = "${reputacao.turnosRealizados} turnos realizados",
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                }
            }
        }
    }
}

/**
 * Selo voluntário "Identidade Verificada" (RN14). Aprovada: selo discreto. Em análise: só o aviso.
 * Elegível (nunca verificou, exigência aberta ou rejeitada): convite para obter o selo. Sem estado
 * (ainda não lido ou falhou): nada, o perfil não depende dele.
 */
@Composable
private fun BlocoDeSeloConfianca(
    verificacao: VerificacaoIdentidade?,
    podeSolicitar: Boolean,
    aoAbrirSelo: () -> Unit,
) {
    if (verificacao == null) return
    when {
        verificacao.status == StatusVerificacaoIdentidade.APROVADA -> SeloDeStatus(
            texto = "Identidade Verificada",
            estilo = EstiloDoSelo.CONFIRMADO,
            modifier = Modifier.testTag("selo-identidade-verificada"),
        )
        verificacao.status == StatusVerificacaoIdentidade.EM_ANALISE -> SeloDeStatus(
            texto = "Verificação de identidade em análise",
            estilo = EstiloDoSelo.CONTORNO,
            modifier = Modifier.testTag("selo-em-analise"),
        )
        podeSolicitar -> CartaoFrila(modifier = Modifier.fillMaxWidth().testTag("selo-convite")) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                Text(
                    text = "Selo de confiança",
                    style = FrilaTipo.nome,
                    color = FrilaTema.cores.tinta,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    text = "Verifique sua identidade, se quiser, e mostre o selo \"Identidade Verificada\" no seu perfil.",
                    style = FrilaTipo.corpo,
                    color = FrilaTema.cores.tinta,
                )
                BotaoSecundario(
                    texto = "Obter selo de confiança",
                    aoClicar = aoAbrirSelo,
                    modifier = Modifier.fillMaxWidth().testTag("selo-obter"),
                )
            }
        }
    }
}

private fun formatarTaxa(taxa: Double?): String =
    if (taxa == null) "Sem histórico" else "${(taxa * 100).roundToInt()}%"

/**
 * RF16/RN09: resumo dos valores acordados diretamente entre profissional e estabelecimento.
 * Nunca um saldo, carteira ou extrato mantido pelo app — o Frila não intermedia pagamento
 * (Zero Escrow). Sem turnos cumpridos/agendados, mostra um texto neutro em vez de "R$ 0,00".
 */
@Composable
private fun BlocoDeRemuneracoes(resumo: ResumoFinanceiroPerfil?, aoExportarExtrato: () -> Unit) {
    val cores = FrilaTema.cores
    SecaoDoPerfil("Remunerações acordadas") {
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                Text(
                    text = "Valores combinados diretamente com os estabelecimentos (RN09)",
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
                if (resumo == null || !resumo.temHistorico) {
                    Text(text = "Nenhum turno realizado ou agendado ainda", style = FrilaTipo.corpo, color = cores.tinta)
                } else {
                    Text(
                        text = "Concluído: ${resumo.totalConcluidoFormatado} (${resumo.turnosCumpridosQtd} turnos cumpridos)",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                    Text(
                        text = "Pendente: ${resumo.totalPendenteFormatado} (${resumo.turnosAgendadosQtd} turnos agendados)",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                    Text(
                        text = "Total acumulado: ${resumo.totalGeralFormatado}",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                    BotaoSecundario(
                        texto = "Exportar extrato em PDF",
                        aoClicar = aoExportarExtrato,
                        modifier = Modifier.padding(top = FrilaEspacamento.item),
                    )
                }
            }
        }
    }
}

/**
 * RF02: Biografia profissional com limite estrito de 280 caracteres e contador acessível. Edição no lugar: "Editar"
 * troca o texto pelo campo, e "Salvar"/"Cancelar" aparecem só enquanto se edita.
 */
@Composable
private fun BlocoDeBioProfissional(
    bio: String,
    bioEmEdicao: String,
    estaEditandoBio: Boolean,
    caracteresRestantes: Int,
    aoIniciarEdicao: () -> Unit,
    aoAtualizarBio: (String) -> Unit,
    aoSalvar: () -> Unit,
    aoCancelar: () -> Unit,
) {
    val cores = FrilaTema.cores
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        if (estaEditandoBio) {
            CampoDeTexto(
                valor = bioEmEdicao,
                aoMudar = aoAtualizarBio,
                rotulo = "Biografia profissional",
                dica = "Ex.: Bartender com 5 anos de experiência em coquetelaria e grandes eventos no DF.",
                apoio = "$caracteresRestantes caracteres restantes",
                umaLinha = false,
                linhasMinimas = 3,
                modifier = Modifier.semantics {
                    contentDescription = "Campo de edição da biografia profissional. Limite de 280 caracteres."
                },
            )
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = FrilaEspacamento.item),
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                BotaoPrimario(texto = "Salvar", aoClicar = aoSalvar, modifier = Modifier.weight(1f))
                BotaoSecundario(texto = "Cancelar", aoClicar = aoCancelar, modifier = Modifier.weight(1f))
            }
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RotuloDeGrupo("Biografia profissional", modifier = Modifier.weight(1f).padding(end = FrilaEspacamento.item))
                LinkFrila(texto = if (bio.isBlank()) "Adicionar" else "Editar", aoClicar = aoIniciarEdicao)
            }
            CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = bio.ifBlank { "Nenhuma biografia cadastrada ainda. Apresente sua trajetória aos estabelecimentos." },
                    style = FrilaTipo.corpo,
                    color = if (bio.isBlank()) cores.tintaSuave else cores.tinta,
                )
            }
        }
    }
}

/** RF02: seleção de especialidades em chips (seleção múltipla), com a escolha dita ao leitor de tela. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BlocoDeEspecialidades(
    especialidades: List<String>,
    selecionadas: Set<String>,
    aoAlternar: (String) -> Unit,
) {
    SecaoDoPerfil("Especialidades") {
        Text(
            text = "Destaque suas habilidades para estabelecimentos parceiros:",
            style = FrilaTipo.apoio,
            color = FrilaTema.cores.tintaSuave,
        )
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            especialidades.forEach { especialidade ->
                val selecionada = selecionadas.contains(especialidade)
                ChipFrila(
                    texto = especialidade,
                    selecionado = selecionada,
                    aoClicar = { aoAlternar(especialidade) },
                    modifier = Modifier.semantics {
                        stateDescription = if (selecionada) "selecionada" else "não selecionada"
                    },
                )
            }
        }
    }
}

/** As funções do perfil, só para ler: quem edita as funções é a tela de preferências e serviços. */
@Composable
private fun BlocoDeFuncoes(funcoes: List<FuncaoDto>) {
    val cores = FrilaTema.cores
    SecaoDoPerfil("Funções cadastradas") {
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            if (funcoes.isEmpty()) {
                Text(text = "Nenhuma função cadastrada ainda.", style = FrilaTipo.corpo, color = cores.tintaSuave)
            } else {
                Column {
                    funcoes.forEachIndexed { indice, funcao ->
                        if (indice > 0) FrilaDivisoria(modifier = Modifier.padding(vertical = FrilaEspacamento.item))
                        Text(text = funcao.nome, style = FrilaTipo.corpo, color = cores.tinta)
                    }
                }
            }
        }
    }
}

/**
 * Atalhos da casa, na ordem em que aparecem: cada um só entra se quem abriu a tela informou o callback (as chaves e as
 * condições de cada atalho são do chamador). O mesmo conjunto vale no perfil carregado e no perfil em erro.
 */
private fun EscopoDoGrupoDeLinhas.atalhosDaCasa(
    aoAbrirEquipe: (() -> Unit)?,
    aoMinhasVagas: (() -> Unit)?,
    aoPublicarVaga: (() -> Unit)?,
    aoCadastrarEstabelecimento: (() -> Unit)?,
    aoEncontrarProfissional: (() -> Unit)?,
) {
    if (aoAbrirEquipe != null) {
        linha { FrilaLinhaDeNavegacao("Equipe de confiança", aoAbrirEquipe, Modifier.testTag("perfil-equipe")) }
    }
    if (aoMinhasVagas != null) {
        linha { FrilaLinhaDeNavegacao("Minhas vagas", aoMinhasVagas, Modifier.testTag("perfil-minhas-vagas")) }
    }
    if (aoPublicarVaga != null) {
        linha { FrilaLinhaDeNavegacao("Publicar vaga", aoPublicarVaga, Modifier.testTag("perfil-publicar-vaga")) }
    }
    if (aoCadastrarEstabelecimento != null) {
        linha {
            FrilaLinhaDeNavegacao("Cadastrar estabelecimento", aoCadastrarEstabelecimento, Modifier.testTag("perfil-cadastrar-estabelecimento"))
        }
    }
    if (aoEncontrarProfissional != null) {
        linha { FrilaLinhaDeNavegacao("Encontrar profissional", aoEncontrarProfissional, Modifier.testTag("perfil-encontrar-profissional")) }
    }
}

/** Sair e excluir a conta: ações discretas no fim da tela, uma por linha. Excluir tem a sua confirmação própria. */
@Composable
private fun AcoesDeEncerrarConta(aoDeslogar: () -> Unit, aoAbrirExclusao: () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        AcaoDiscreta(texto = "Sair da conta", aoClicar = aoDeslogar)
        AcaoDiscreta(texto = "Excluir conta", aoClicar = aoAbrirExclusao)
    }
}

/**
 * Os atalhos da conta num grupo de linhas e, 32dp abaixo, sair e excluir como ações discretas. Cada atalho só entra
 * quando o chamador informa o callback; a lista e as condições não mudam com o desenho.
 */
@Composable
private fun BlocoDeConta(
    aoDeslogar: () -> Unit,
    aoAbrirExclusao: () -> Unit,
    biometriaAtivada: Boolean,
    disponibilidadeBiometrica: DisponibilidadeBiometrica,
    mensagemErroBiometria: String?,
    aoAlternarBiometria: (Boolean) -> Unit,
    mostrarBiometria: Boolean = false,
    aoAbrirAjuda: () -> Unit = {},
    aoAbrirEquipe: (() -> Unit)? = null,
    aoPublicarVaga: (() -> Unit)? = null,
    aoMinhasVagas: (() -> Unit)? = null,
    aoCadastrarEstabelecimento: (() -> Unit)? = null,
    aoAbrirChamadasDiretas: (() -> Unit)? = null,
    /** L1-7c: atalhos do profissional para "Apresentação e regiões" e "Foto de perfil". Nulo esconde o atalho (chaves `perfil_rico` e `foto_de_perfil`). */
    aoAbrirApresentacao: (() -> Unit)? = null,
    aoAbrirFotoDePerfil: (() -> Unit)? = null,
    /** Atalho do profissional para o ponto base. Nulo esconde o atalho. */
    aoAbrirPontoBase: (() -> Unit)? = null,
    aoEncontrarProfissional: (() -> Unit)? = null,
    atalhosExtras: List<AtalhoDaConta> = emptyList(),
    relatoriosDeFalhasAtivados: Boolean = false,
    aoAlternarRelatoriosDeFalhas: ((Boolean) -> Unit)? = null,
) {
    val cores = FrilaTema.cores
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.secao)) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            FrilaGrupoDeLinhas {
                // C0-11: o iOS não tem desbloqueio por biometria; só aparece com a trava ligada, que nada no app liga.
                if (mostrarBiometria) {
                    linha {
                        LinhaDeInterruptor(
                            rotulo = "Desbloqueio rápido por biometria",
                            ativada = biometriaAtivada,
                            aoAlternar = aoAlternarBiometria,
                            // MEDIDO (Shisui, PR #591): desligar precisa ser sempre possível, mesmo se o
                            // hardware ficou indisponível depois de ativada — senão o switch trava em ON.
                            habilitada = disponibilidadeBiometrica == DisponibilidadeBiometrica.DISPONIVEL || biometriaAtivada,
                            modifier = Modifier.testTag("toggle-biometria"),
                        )
                    }
                }
                if (aoAlternarRelatoriosDeFalhas != null) {
                    linha {
                        LinhaDeInterruptor(
                            rotulo = "Enviar relatórios de falhas",
                            subtitulo = "Ajuda a corrigir erros técnicos no app",
                            ativada = relatoriosDeFalhasAtivados,
                            aoAlternar = aoAlternarRelatoriosDeFalhas,
                            modifier = Modifier.testTag("toggle-relatorios-falhas"),
                        )
                    }
                }
                atalhosDaCasa(aoAbrirEquipe, aoMinhasVagas, aoPublicarVaga, aoCadastrarEstabelecimento, aoEncontrarProfissional)
                if (aoAbrirPontoBase != null) {
                    linha { FrilaLinhaDeNavegacao(TextosPontoBase.TITULO, aoAbrirPontoBase, Modifier.testTag("perfil-ponto-base")) }
                }
                if (aoAbrirApresentacao != null) {
                    linha { FrilaLinhaDeNavegacao(TextosApresentacaoERegioes.TITULO, aoAbrirApresentacao, Modifier.testTag("perfil-apresentacao")) }
                }
                if (aoAbrirFotoDePerfil != null) {
                    linha { FrilaLinhaDeNavegacao(TextosDaFotoDePerfil.TITULO, aoAbrirFotoDePerfil, Modifier.testTag("perfil-foto")) }
                }
                if (aoAbrirChamadasDiretas != null) {
                    linha { FrilaLinhaDeNavegacao("Preferências de chamadas", aoAbrirChamadasDiretas, Modifier.testTag("perfil-chamadas-diretas")) }
                }
                atalhosExtras.forEach { atalho ->
                    linha { FrilaLinhaDeNavegacao(atalho.rotulo, atalho.aoAbrir, Modifier.testTag(atalho.tag)) }
                }
                linha { FrilaLinhaDeNavegacao("Ajuda", aoAbrirAjuda, Modifier.testTag("perfil-ajuda")) }
            }
            if (mostrarBiometria && disponibilidadeBiometrica != DisponibilidadeBiometrica.DISPONIVEL) {
                Text(
                    text = textoIndisponibilidadeBiometrica(disponibilidadeBiometrica),
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
            }
            if (mostrarBiometria && mensagemErroBiometria != null) {
                // Problema não tem cor: o erro vai escrito em tinta, e o leitor de tela o anuncia na hora.
                Text(
                    text = mensagemErroBiometria,
                    style = FrilaTipo.corpo,
                    color = cores.tinta,
                    modifier = Modifier.semantics {
                        liveRegion = LiveRegionMode.Assertive
                        error(mensagemErroBiometria)
                    },
                )
            }
        }
        AcoesDeEncerrarConta(aoDeslogar = aoDeslogar, aoAbrirExclusao = aoAbrirExclusao)
    }
}

private fun textoIndisponibilidadeBiometrica(disponibilidade: DisponibilidadeBiometrica): String = when (disponibilidade) {
    DisponibilidadeBiometrica.SEM_HARDWARE -> "Este aparelho não tem biometria disponível."
    DisponibilidadeBiometrica.HARDWARE_INDISPONIVEL -> "O sensor biométrico está indisponível agora."
    DisponibilidadeBiometrica.NAO_CADASTRADA -> "Cadastre uma biometria ou PIN nas configurações do aparelho para ativar."
    DisponibilidadeBiometrica.INDISPONIVEL, DisponibilidadeBiometrica.DISPONIVEL -> "Desbloqueio rápido indisponível neste aparelho."
}

/**
 * RF25/UC16: a única confirmação de excluir a conta, nativa, com a consequência escrita (irreversível, turnos futuros
 * cancelados e dados apagados em até 15 dias, como pede a LGPD). Sem vermelho: problema não tem cor.
 */
@Composable
private fun DialogoConfirmarExclusao(aoConfirmar: () -> Unit, aoCancelar: () -> Unit) {
    val cores = FrilaTema.cores
    AlertDialog(
        onDismissRequest = aoCancelar,
        containerColor = cores.superficie,
        shape = RoundedCornerShape(FrilaRaios.cartao),
        title = {
            Text(
                "Excluir conta definitivamente?",
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Text(
                "Esta ação não pode ser desfeita. Seus turnos futuros serão cancelados sem " +
                    "penalidade para você, e seus dados pessoais serão apagados em até 15 dias, " +
                    "conforme a LGPD.",
                style = FrilaTipo.corpo,
                color = cores.tinta,
            )
        },
        confirmButton = {
            TextButton(
                onClick = aoConfirmar,
                modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
            ) {
                Text("Sim, excluir minha conta", style = FrilaTipo.rotuloSecundario, color = cores.tinta)
            }
        },
        dismissButton = {
            TextButton(
                onClick = aoCancelar,
                modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
            ) { Text("Cancelar", style = FrilaTipo.rotuloSecundario, color = cores.tinta) }
        },
    )
}

@Composable
private fun DialogoExcluindo() {
    val cores = FrilaTema.cores
    AlertDialog(
        onDismissRequest = {},
        containerColor = cores.superficie,
        shape = RoundedCornerShape(FrilaRaios.cartao),
        title = { Text("Excluindo conta…", style = FrilaTipo.nome, color = cores.tinta, modifier = Modifier.semantics { heading() }) },
        text = {
            Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                IndicadorCarregando()
            }
        },
        confirmButton = {},
    )
}

@Composable
private fun DialogoErroExclusao(mensagem: String?, aoFechar: () -> Unit) {
    val cores = FrilaTema.cores
    AlertDialog(
        onDismissRequest = aoFechar,
        containerColor = cores.superficie,
        shape = RoundedCornerShape(FrilaRaios.cartao),
        title = {
            Text(
                "Não foi possível excluir a conta",
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            val textoErro = mensagem ?: "Tente de novo em instantes."
            Text(
                text = textoErro,
                style = FrilaTipo.corpo,
                color = cores.tinta,
                modifier = Modifier.semantics {
                    liveRegion = LiveRegionMode.Assertive
                    error(textoErro)
                },
            )
        },
        confirmButton = {
            TextButton(
                onClick = aoFechar,
                modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
            ) { Text("Entendi", style = FrilaTipo.rotuloSecundario, color = cores.tinta) }
        },
    )
}

@Composable
private fun Carregando(modifier: Modifier = Modifier) {
    EstadoCarregando(modifier = modifier)
}

@Composable
private fun Erro(
    mensagem: String?,
    aoTentarNovamente: () -> Unit,
    aoAbrirEquipe: (() -> Unit)? = null,
    aoPublicarVaga: (() -> Unit)? = null,
    aoMinhasVagas: (() -> Unit)? = null,
    aoEncontrarProfissional: (() -> Unit)? = null,
    aoDeslogar: () -> Unit = {},
    aoAbrirExclusao: () -> Unit = {},
    modifier: Modifier = Modifier,
    /** Bloqueados e contestar não dependem do perfil ter carregado: continuam ao alcance com o perfil em erro. */
    atalhosExtras: List<AtalhoDaConta> = emptyList(),
) {
    val temAtalhos = aoAbrirEquipe != null || aoMinhasVagas != null || aoPublicarVaga != null || aoEncontrarProfissional != null ||
        atalhosExtras.isNotEmpty()
    Column(
        modifier = modifier
            .fillMaxWidth()
            // Com os atalhos da casa mais sair e excluir, a coluna passa da altura da tela em fonte grande.
            .verticalScroll(rememberScrollState()),
    ) {
        val textoErro = mensagem ?: "Não foi possível carregar seu perfil."
        EstadoErro(
            titulo = textoErro,
            mensagem = null,
            aoTentarNovamente = aoTentarNovamente,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = FrilaEspacamento.grupo, end = FrilaEspacamento.grupo, bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.secao),
        ) {
            if (temAtalhos) {
                FrilaGrupoDeLinhas {
                    atalhosDaCasa(aoAbrirEquipe, aoMinhasVagas, aoPublicarVaga, null, aoEncontrarProfissional)
                    atalhosExtras.forEach { atalho ->
                        linha { FrilaLinhaDeNavegacao(atalho.rotulo, atalho.aoAbrir, Modifier.testTag(atalho.tag)) }
                    }
                }
            }
            // Sair e excluir não dependem do perfil: sem estes dois, uma conta em erro (casa sem rede, por exemplo) ficava presa.
            AcoesDeEncerrarConta(aoDeslogar = aoDeslogar, aoAbrirExclusao = aoAbrirExclusao)
        }
    }
}
