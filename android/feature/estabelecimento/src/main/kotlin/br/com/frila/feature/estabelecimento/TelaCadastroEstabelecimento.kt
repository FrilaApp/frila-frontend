package br.com.frila.feature.estabelecimento

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.EstabelecimentoDto

/** Liga o [CadastroEstabelecimentoViewModel] ao [ConteudoCadastroEstabelecimento]. */
@Composable
fun TelaCadastroEstabelecimento(
    viewModel: CadastroEstabelecimentoViewModel,
    aoConcluir: (EstabelecimentoDto) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(estado.estabelecimentoCriado) {
        estado.estabelecimentoCriado?.let(aoConcluir)
    }
    ConteudoCadastroEstabelecimento(
        estado = estado,
        aoEditarNome = viewModel::editarNome,
        aoEditarDocumento = viewModel::editarDocumento,
        aoEscolherTipo = viewModel::escolherTipo,
        aoEditarEndereco = viewModel::editarEndereco,
        aoEscolherRegiao = viewModel::escolherRegiao,
        aoEditarLatitude = viewModel::editarLatitude,
        aoEditarLongitude = viewModel::editarLongitude,
        aoCadastrar = { viewModel.cadastrar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Cadastro do estabelecimento do contratante (RF02, UC10; paridade com `TelaCadastroEstabelecimento.swift`,
 * sem mapa: o ponto vem de latitude e longitude digitadas). Cada campo mostra o próprio erro; o erro
 * global e o botão de envio ficam juntos no fim.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoCadastroEstabelecimento(
    estado: EstadoCadastroEstabelecimento,
    aoEditarNome: (String) -> Unit,
    aoEditarDocumento: (String) -> Unit,
    aoEscolherTipo: (TipoEstabelecimento) -> Unit,
    aoEditarEndereco: (String) -> Unit,
    aoEscolherRegiao: (String) -> Unit,
    aoEditarLatitude: (String) -> Unit,
    aoEditarLongitude: (String) -> Unit,
    aoCadastrar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var seletorDeRegiaoAberto by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosCadastroEstabelecimento.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        enabled = !estado.enviando,
                        modifier = Modifier.sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosCadastroEstabelecimento.ROTULO_VOLTAR,
                        )
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
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Text(
                text = TextosCadastroEstabelecimento.SUBTITULO,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Campo(
                rotulo = TextosCadastroEstabelecimento.NOME,
                valor = estado.nome,
                aoMudar = aoEditarNome,
                erro = estado.errosDeCampo[CampoCadastro.NOME],
                habilitado = estado.podeEditar,
            )

            Text(
                text = TextosCadastroEstabelecimento.TIPO,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            Column(modifier = Modifier.selectableGroup()) {
                TipoEstabelecimento.entries.forEach { tipo ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                            .selectable(
                                selected = estado.tipo == tipo,
                                enabled = estado.podeEditar,
                                role = Role.RadioButton,
                                onClick = { aoEscolherTipo(tipo) },
                            ),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                    ) {
                        // O clique é do Row (selectable): o botão de rádio só reflete o estado.
                        RadioButton(selected = estado.tipo == tipo, onClick = null)
                        Text(text = tipo.rotulo, style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }

            Campo(
                rotulo = TextosCadastroEstabelecimento.DOCUMENTO,
                valor = estado.documento,
                aoMudar = aoEditarDocumento,
                erro = estado.errosDeCampo[CampoCadastro.DOCUMENTO],
                habilitado = estado.podeEditar,
                ajuda = TextosCadastroEstabelecimento.DOCUMENTO_AJUDA,
                teclado = KeyboardType.Number,
            )

            Campo(
                rotulo = TextosCadastroEstabelecimento.ENDERECO,
                valor = estado.endereco,
                aoMudar = aoEditarEndereco,
                erro = estado.errosDeCampo[CampoCadastro.ENDERECO],
                habilitado = estado.podeEditar,
                ajuda = TextosCadastroEstabelecimento.ENDERECO_AJUDA,
            )

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                Text(
                    text = TextosCadastroEstabelecimento.REGIAO,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.semantics { heading() },
                )
                BotaoSecundario(
                    texto = estado.regiaoAdministrativa.ifEmpty { TextosCadastroEstabelecimento.REGIAO_SELECIONAR },
                    aoClicar = { seletorDeRegiaoAberto = true },
                    habilitado = estado.podeEditar,
                    modifier = Modifier.fillMaxWidth(),
                )
                val erroDaRegiao = estado.errosDeCampo[CampoCadastro.REGIAO_ADMINISTRATIVA]
                Text(
                    text = erroDaRegiao ?: TextosCadastroEstabelecimento.REGIAO_AJUDA,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (erroDaRegiao != null) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = TextosCadastroEstabelecimento.PONTO,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = TextosCadastroEstabelecimento.PONTO_AJUDA,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Campo(
                rotulo = TextosCadastroEstabelecimento.LATITUDE,
                valor = estado.latitude,
                aoMudar = aoEditarLatitude,
                erro = estado.errosDeCampo[CampoCadastro.LATITUDE],
                habilitado = estado.podeEditar,
                teclado = KeyboardType.Decimal,
            )
            Campo(
                rotulo = TextosCadastroEstabelecimento.LONGITUDE,
                valor = estado.longitude,
                aoMudar = aoEditarLongitude,
                erro = estado.errosDeCampo[CampoCadastro.LONGITUDE],
                habilitado = estado.podeEditar,
                teclado = KeyboardType.Decimal,
            )

            estado.erro?.let { erro ->
                Text(
                    text = erro.mensagem,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                )
            }
            if (estado.concluido) {
                Text(
                    text = TextosCadastroEstabelecimento.CONCLUIDO,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                BotaoPrimario(
                    texto = if (estado.enviando) TextosCadastroEstabelecimento.CADASTRANDO else TextosCadastroEstabelecimento.CADASTRAR,
                    aoClicar = aoCadastrar,
                    habilitado = estado.podeEditar,
                    modifier = Modifier.weight(1f),
                )
                if (estado.enviando) CircularProgressIndicator(modifier = Modifier.size(24.dp))
            }
        }
    }

    if (seletorDeRegiaoAberto) {
        AlertDialog(
            onDismissRequest = { seletorDeRegiaoAberto = false },
            title = {
                Text(text = TextosCadastroEstabelecimento.REGIAO_SELECIONAR, modifier = Modifier.semantics { heading() })
            },
            text = {
                LazyColumn(modifier = Modifier.selectableGroup()) {
                    items(REGIOES_ADMINISTRATIVAS_DF, key = { it }) { regiao ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                                .selectable(
                                    selected = estado.regiaoAdministrativa == regiao,
                                    role = Role.RadioButton,
                                    onClick = {
                                        aoEscolherRegiao(regiao)
                                        seletorDeRegiaoAberto = false
                                    },
                                ),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                        ) {
                            RadioButton(selected = estado.regiaoAdministrativa == regiao, onClick = null)
                            Text(text = regiao, style = MaterialTheme.typography.bodyLarge)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = { seletorDeRegiaoAberto = false },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) { Text(TextosCadastroEstabelecimento.CANCELAR) }
            },
        )
    }
}

@Composable
private fun Campo(
    rotulo: String,
    valor: String,
    aoMudar: (String) -> Unit,
    erro: String?,
    habilitado: Boolean,
    modifier: Modifier = Modifier,
    ajuda: String? = null,
    teclado: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = valor,
        onValueChange = aoMudar,
        enabled = habilitado,
        label = { Text(rotulo) },
        isError = erro != null,
        supportingText = (erro ?: ajuda)?.let { texto -> { Text(texto) } },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = teclado),
        modifier = modifier.fillMaxWidth(),
    )
}
