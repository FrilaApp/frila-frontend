package br.com.frila.feature.perfil

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import android.content.Intent
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
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import androidx.core.content.FileProvider
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.ReputacaoDto
import kotlin.math.roundToInt

/**
 * Perfil do profissional (RF02/RF03/RF16/RF25/RN15/RNF08, UC09/UC16):
 * - RF02: Bio profissional limitada a 280 caracteres com contador e especialidades em FlowRow com FilterChip.
 * - Reputação sempre com denominador (RN08), nunca uma média sem contexto (RN07).
 * - Logout e exclusão de conta locais primeiro (RN15) — a sessão só é limpa depois da confirmação
 *   (logout) ou do sucesso da Edge Function (exclusão), nunca antes.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TelaPerfil(
    viewModel: PerfilViewModel,
    modifier: Modifier = Modifier,
    aoDeslogar: () -> Unit = {},
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
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val contexto = LocalContext.current
    val disponibilidadeBiometrica = remember { verificarDisponibilidadeBiometrica(contexto) }
    var mensagemErroBiometria by remember { mutableStateOf<String?>(null) }

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
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Meu Perfil", modifier = Modifier.semantics { heading() }) },
            )
        },
    ) { paddingInterno ->
        when (estado.status) {
            StatusPerfil.CARREGANDO -> Carregando(paddingInterno)
            StatusPerfil.ERRO -> Erro(
                mensagem = estado.mensagemErro,
                aoTentarNovamente = viewModel::carregar,
                paddingValues = paddingInterno,
            )
            StatusPerfil.SUCESSO -> ConteudoDoPerfil(
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
                aoAbrirExclusao = viewModel::abrirDialogoExclusao,
                biometriaAtivada = estado.biometriaAtivada,
                disponibilidadeBiometrica = disponibilidadeBiometrica,
                mensagemErroBiometria = mensagemErroBiometria,
                aoAlternarBiometria = { marcado ->
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
                },
                paddingValues = paddingInterno,
            )
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

@Composable
private fun ConteudoDoPerfil(
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
    paddingValues: PaddingValues,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(paddingValues)
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        BlocoDeAvatar(
            fotoLocalPath = fotoLocalPath,
            statusFoto = statusFoto,
            mensagemErroFoto = mensagemErroFoto,
            aoSelecionarFoto = aoSelecionarFoto,
        )
        BlocoDeReputacao(reputacao)
        BlocoDeRemuneracoes(resumoFinanceiro, aoExportarExtrato)
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
        BlocoDeConta(
            aoDeslogar = aoDeslogar,
            aoAbrirExclusao = aoAbrirExclusao,
            biometriaAtivada = biometriaAtivada,
            disponibilidadeBiometrica = disponibilidadeBiometrica,
            mensagemErroBiometria = mensagemErroBiometria,
            aoAlternarBiometria = aoAlternarBiometria,
        )
    }
}

/**
 * RF03/RNF04: avatar do profissional, selecionável via Android Photo Picker
 * (`ActivityResultContracts.PickVisualMedia`, sem permissão de storage) e comprimido
 * defensivamente antes de exibir (ver [CompressorDeFotoPerfil]). Sem foto cadastrada, mostra um
 * placeholder circular neutro — nunca um espaço vazio sem explicação.
 */
@Composable
private fun BlocoDeAvatar(
    fotoLocalPath: String?,
    statusFoto: StatusFotoPerfil,
    mensagemErroFoto: String?,
    aoSelecionarFoto: (Uri) -> Unit,
) {
    val lancadorDeSelecao = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri -> if (uri != null) aoSelecionarFoto(uri) }

    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Box(modifier = Modifier.size(72.dp), contentAlignment = Alignment.Center) {
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
                        modifier = Modifier.size(72.dp).clip(CircleShape),
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Person,
                            contentDescription = "Sem foto de perfil cadastrada",
                            modifier = Modifier.size(40.dp),
                        )
                    }
                }
                if (statusFoto == StatusFotoPerfil.COMPRIMINDO) {
                    CircularProgressIndicator(
                        modifier = Modifier
                            .size(72.dp)
                            .semantics { contentDescription = "Processando foto de perfil" },
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                TextButton(
                    onClick = {
                        lancadorDeSelecao.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) {
                    Text("Alterar foto de perfil")
                }
                if (statusFoto == StatusFotoPerfil.ERRO) {
                    val textoErro = mensagemErroFoto ?: "Não foi possível processar a foto."
                    Text(
                        text = textoErro,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
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

/** RN07/RN08: binária com denominador obrigatório. Nunca nota, nunca média sem "de quantas". */
@Composable
private fun BlocoDeReputacao(reputacao: ReputacaoDto?) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Reputação",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Column(
            modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
        ) {
            if (reputacao == null || reputacao.total == 0) {
                Text(text = "Sem histórico de avaliações", style = MaterialTheme.typography.bodyMedium)
            } else {
                Text(
                    text = "${reputacao.positivas} de ${reputacao.total} recomendariam de novo",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    text = "Taxa de comparecimento: ${formatarTaxa(reputacao.taxaComparecimento)}",
                    style = MaterialTheme.typography.bodySmall,
                )
                Text(
                    text = "${reputacao.turnosRealizados} turnos realizados",
                    style = MaterialTheme.typography.bodySmall,
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
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Remunerações acordadas",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(
            text = "Valores combinados diretamente com os estabelecimentos (RN09)",
            style = MaterialTheme.typography.bodySmall,
        )
        Column(
            modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
        ) {
            if (resumo == null || !resumo.temHistorico) {
                Text(
                    text = "Nenhum turno realizado ou agendado ainda",
                    style = MaterialTheme.typography.bodyMedium,
                )
            } else {
                Text(
                    text = "Concluído: ${resumo.totalConcluidoFormatado} (${resumo.turnosCumpridosQtd} turnos cumpridos)",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    text = "Pendente: ${resumo.totalPendenteFormatado} (${resumo.turnosAgendadosQtd} turnos agendados)",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    text = "Total acumulado: ${resumo.totalGeralFormatado}",
                    style = MaterialTheme.typography.bodyMedium,
                )
                BotaoSecundario(
                    texto = "Exportar extrato em PDF",
                    aoClicar = aoExportarExtrato,
                    modifier = Modifier
                        .padding(top = FrilaEspacamento.pequeno)
                        .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                )
            }
        }
    }
}

/** RF02: Biografia profissional com limite estrito de 280 caracteres e contador acessível. */
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
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Biografia profissional",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.semantics { heading() },
            )
            if (!estaEditandoBio) {
                TextButton(
                    onClick = aoIniciarEdicao,
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) {
                    Text(if (bio.isBlank()) "Adicionar" else "Editar")
                }
            }
        }

        if (estaEditandoBio) {
            OutlinedTextField(
                value = bioEmEdicao,
                onValueChange = aoAtualizarBio,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = FrilaEspacamento.pequeno)
                    .semantics {
                        contentDescription = "Campo de edição da biografia profissional. Limite de 280 caracteres."
                    },
                placeholder = {
                    Text("Ex.: Bartender com 5 anos de experiência em coquetelaria e grandes eventos no DF.")
                },
                minLines = 3,
                maxLines = 5,
                supportingText = {
                    Text(
                        text = "$caracteresRestantes caracteres restantes",
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.semantics {
                            contentDescription = "Restam $caracteresRestantes de 280 caracteres"
                        },
                    )
                },
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = FrilaEspacamento.pequeno),
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
            ) {
                BotaoPrimario(
                    texto = "Salvar",
                    aoClicar = aoSalvar,
                    modifier = Modifier.weight(1f),
                )
                BotaoSecundario(
                    texto = "Cancelar",
                    aoClicar = aoCancelar,
                    modifier = Modifier.weight(1f),
                )
            }
        } else {
            Text(
                text = bio.ifBlank { "Nenhuma biografia cadastrada ainda. Apresente sua trajetória aos estabelecimentos." },
                style = MaterialTheme.typography.bodyMedium,
                color = if (bio.isBlank()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            )
        }
    }
}

/** RF02: Seleção de especialidades com FilterChip Material 3 em FlowRow. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BlocoDeEspecialidades(
    especialidades: List<String>,
    selecionadas: Set<String>,
    aoAlternar: (String) -> Unit,
) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Especialidades",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(
            text = "Destaque suas habilidades para estabelecimentos parceiros:",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = FrilaEspacamento.minimo),
        )
        FlowRow(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = FrilaEspacamento.pequeno),
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
        ) {
            especialidades.forEach { especialidade ->
                val selecionada = selecionadas.contains(especialidade)
                FilterChip(
                    selected = selecionada,
                    onClick = { aoAlternar(especialidade) },
                    label = { Text(especialidade) },
                    modifier = Modifier
                        .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                        .semantics {
                            stateDescription = if (selecionada) "selecionada" else "não selecionada"
                        },
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BlocoDeFuncoes(funcoes: List<FuncaoDto>) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Funções cadastradas",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        if (funcoes.isEmpty()) {
            Text(
                text = "Nenhuma função cadastrada ainda.",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            )
        } else {
            FlowRow(
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
            ) {
                funcoes.forEach { funcao ->
                    Surface(
                        shape = MaterialTheme.shapes.small,
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Text(
                            text = funcao.nome,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(
                                horizontal = FrilaEspacamento.pequeno,
                                vertical = FrilaEspacamento.minimo,
                            ),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BlocoDeConta(
    aoDeslogar: () -> Unit,
    aoAbrirExclusao: () -> Unit,
    biometriaAtivada: Boolean,
    disponibilidadeBiometrica: DisponibilidadeBiometrica,
    mensagemErroBiometria: String?,
    aoAlternarBiometria: (Boolean) -> Unit,
) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Conta",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = FrilaEspacamento.pequeno)
                .sizeIn(minHeight = FrilaMetricas.alvoMinimo),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Desbloqueio rápido por biometria",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = biometriaAtivada,
                onCheckedChange = aoAlternarBiometria,
                enabled = disponibilidadeBiometrica == DisponibilidadeBiometrica.DISPONIVEL,
                modifier = Modifier
                    .testTag("toggle-biometria")
                    .semantics {
                        contentDescription = "Desbloqueio rápido por biometria"
                    },
            )
        }
        if (disponibilidadeBiometrica != DisponibilidadeBiometrica.DISPONIVEL) {
            Text(
                text = textoIndisponibilidadeBiometrica(disponibilidadeBiometrica),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (mensagemErroBiometria != null) {
            Text(
                text = mensagemErroBiometria,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.semantics {
                    liveRegion = LiveRegionMode.Assertive
                    error(mensagemErroBiometria)
                },
            )
        }
        BotaoSecundario(
            texto = "Sair da conta",
            aoClicar = aoDeslogar,
            modifier = Modifier.fillMaxWidth().padding(top = FrilaEspacamento.pequeno),
        )
        BotaoDestrutivo(
            texto = "Excluir conta",
            aoClicar = aoAbrirExclusao,
            modifier = Modifier.fillMaxWidth().padding(top = FrilaEspacamento.pequeno),
        )
    }
}

private fun textoIndisponibilidadeBiometrica(disponibilidade: DisponibilidadeBiometrica): String = when (disponibilidade) {
    DisponibilidadeBiometrica.SEM_HARDWARE -> "Este aparelho não tem biometria disponível."
    DisponibilidadeBiometrica.HARDWARE_INDISPONIVEL -> "O sensor biométrico está indisponível agora."
    DisponibilidadeBiometrica.NAO_CADASTRADA -> "Cadastre uma biometria ou PIN nas configurações do aparelho para ativar."
    DisponibilidadeBiometrica.INDISPONIVEL, DisponibilidadeBiometrica.DISPONIVEL -> "Desbloqueio rápido indisponível neste aparelho."
}

/**
 * Botão de ação destrutiva: cores `error`/`onError` do tema, mesmo alvo mínimo 48dp dos
 * demais botões do design system (RNF10). Não há um componente de design system para isto
 * ainda — só `BotaoPrimario`/`BotaoSecundario`, nenhum em tom de perigo.
 */
@Composable
private fun BotaoDestrutivo(texto: String, aoClicar: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = aoClicar,
        modifier = modifier
            .sizeIn(
                minWidth = FrilaMetricas.alvoMinimo,
                minHeight = FrilaMetricas.alvoMinimo,
            )
            .heightIn(min = FrilaMetricas.alturaBotao)
            .widthIn(min = FrilaMetricas.alvoMinimo),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.error,
            contentColor = MaterialTheme.colorScheme.onError,
        ),
    ) {
        Text(text = texto, style = MaterialTheme.typography.titleSmall)
    }
}

/** RF25/UC16: confirmação explícita, com o alerta de irreversibilidade exigido pela LGPD. */
@Composable
private fun DialogoConfirmarExclusao(aoConfirmar: () -> Unit, aoCancelar: () -> Unit) {
    AlertDialog(
        onDismissRequest = aoCancelar,
        title = {
            Text(
                "Excluir conta definitivamente?",
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Text(
                "Esta ação não pode ser desfeita. Seus turnos futuros serão cancelados sem " +
                    "penalidade para você, e seus dados pessoais serão apagados em até 15 dias, " +
                    "conforme a LGPD.",
            )
        },
        confirmButton = {
            TextButton(
                onClick = aoConfirmar,
                modifier = Modifier.sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                ),
            ) {
                Text("Sim, excluir minha conta", color = MaterialTheme.colorScheme.error)
            }
        },
        dismissButton = {
            TextButton(
                onClick = aoCancelar,
                modifier = Modifier.sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                ),
            ) { Text("Cancelar") }
        },
    )
}

@Composable
private fun DialogoExcluindo() {
    AlertDialog(
        onDismissRequest = {},
        title = { Text("Excluindo conta…", modifier = Modifier.semantics { heading() }) },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator()
            }
        },
        confirmButton = {},
    )
}

@Composable
private fun DialogoErroExclusao(mensagem: String?, aoFechar: () -> Unit) {
    AlertDialog(
        onDismissRequest = aoFechar,
        title = {
            Text(
                "Não foi possível excluir a conta",
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            val textoErro = mensagem ?: "Tente de novo em instantes."
            Text(
                text = textoErro,
                modifier = Modifier.semantics {
                    liveRegion = LiveRegionMode.Assertive
                    error(textoErro)
                },
            )
        },
        confirmButton = {
            TextButton(
                onClick = aoFechar,
                modifier = Modifier.sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                ),
            ) { Text("Entendi") }
        },
    )
}

@Composable
private fun Carregando(paddingValues: PaddingValues) {
    Box(
        modifier = Modifier.fillMaxSize().padding(paddingValues),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun Erro(
    mensagem: String?,
    aoTentarNovamente: () -> Unit,
    paddingValues: PaddingValues,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(paddingValues).padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        val textoErro = mensagem ?: "Não foi possível carregar seu perfil."
        Text(
            text = textoErro,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics {
                liveRegion = LiveRegionMode.Assertive
                error(textoErro)
            },
        )
        BotaoSecundario(texto = "Tentar novamente", aoClicar = aoTentarNovamente)
    }
}
