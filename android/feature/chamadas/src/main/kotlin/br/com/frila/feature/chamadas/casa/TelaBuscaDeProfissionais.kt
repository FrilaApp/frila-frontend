// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import br.com.frila.core.rede.CartaoProfissionalDto
import java.time.Duration
import java.time.Instant

/**
 * Liga o [BuscaDeProfissionaisViewModel] ao [ConteudoBuscaDeProfissionais]. [aoAbrirPerfil] leva ao perfil público
 * que já existe; [aoPublicarParaTodos] recebe o rascunho da busca vazia para abrir a publicação de vaga.
 */
@Composable
fun TelaBuscaDeProfissionais(
    viewModel: BuscaDeProfissionaisViewModel,
    aoVoltar: () -> Unit,
    aoAbrirPerfil: (profissionalId: String) -> Unit,
    aoPublicarParaTodos: (RascunhoDeVagaDaBusca) -> Unit,
    modifier: Modifier = Modifier,
    relogio: () -> Instant = Instant::now,
    /** Abre os Termos de Uso (o link que o app já usa) para quem vai aceitá-los antes de buscar (0.2.90). */
    aoAbrirTermos: () -> Unit = {},
    carregarFoto: CarregadorDeFoto = ::carregarFotoPorUrl,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregarCatalogos() }
    ConteudoBuscaDeProfissionais(
        estado = estado,
        aoVoltar = aoVoltar,
        aoEscolherFuncao = viewModel::definirFuncao,
        aoEscolherRegiao = viewModel::definirRegiao,
        aoDefinirHorario = viewModel::definirHorario,
        aoBuscar = { viewModel.buscar() },
        aoCarregarMais = { viewModel.carregarMais() },
        aoTentarCatalogosDeNovo = { viewModel.carregarCatalogos() },
        aoAlternarSelecao = { viewModel.alternarSelecao(it) },
        aoAbrirPerfil = aoAbrirPerfil,
        aoPublicarParaTodos = aoPublicarParaTodos,
        aoChamar = { trabalho, recado -> viewModel.chamar(trabalho, recado) },
        aoReenviar = { viewModel.reenviar() },
        aoConfirmarJ7 = { viewModel.confirmarJ7() },
        modifier = modifier,
        relogio = relogio,
        aoAbrirTermos = aoAbrirTermos,
        aoAceitarTermos = { viewModel.aceitarTermosEBuscar() },
        carregarFoto = carregarFoto,
    )
}

/**
 * A busca da casa em Compose/Material3 nativo, sem estilo: filtros (serviço, região e horário opcionais), lista na
 * ordem do servidor com o selo "Disponível nesse horário", seleção de até 3 e a folha de chamar. Provisória, atrás da
 * chave `busca_profissionais`; o desenho do Fabrício substitui esta tela.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoBuscaDeProfissionais(
    estado: EstadoBusca,
    aoVoltar: () -> Unit,
    aoEscolherFuncao: (String?) -> Unit,
    aoEscolherRegiao: (Int?) -> Unit,
    aoDefinirHorario: (HorarioDaBusca?) -> Unit,
    aoBuscar: () -> Unit,
    aoCarregarMais: () -> Unit,
    aoTentarCatalogosDeNovo: () -> Unit,
    aoAlternarSelecao: (String) -> Unit,
    aoAbrirPerfil: (String) -> Unit,
    aoPublicarParaTodos: (RascunhoDeVagaDaBusca) -> Unit,
    aoChamar: (TrabalhoDaChamada, String?) -> Unit,
    aoReenviar: () -> Unit,
    aoConfirmarJ7: () -> Unit,
    modifier: Modifier = Modifier,
    relogio: () -> Instant = Instant::now,
    aoAbrirTermos: () -> Unit = {},
    aoAceitarTermos: () -> Unit = {},
    carregarFoto: CarregadorDeFoto = ::carregarFotoPorUrl,
) {
    var folhaAberta by rememberSaveable { mutableStateOf(false) }
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text(TextosChamadaCasa.BUSCA_TITULO, modifier = Modifier.semantics { heading() }) },
                navigationIcon = {
                    IconButton(onClick = if (folhaAberta) ({ folhaAberta = false }) else aoVoltar) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = TextosChamadaCasa.VOLTAR)
                    }
                },
            )
        },
    ) { preenchimento ->
        if (folhaAberta) {
            FolhaDeChamadaDaBusca(
                estado = estado,
                relogio = relogio,
                aoChamar = aoChamar,
                aoReenviar = aoReenviar,
                aoConfirmarJ7 = aoConfirmarJ7,
                aoFechar = { folhaAberta = false },
                modifier = Modifier.padding(preenchimento),
            )
        } else {
            ListaDaBusca(
                estado = estado,
                relogio = relogio,
                aoEscolherFuncao = aoEscolherFuncao,
                aoEscolherRegiao = aoEscolherRegiao,
                aoDefinirHorario = aoDefinirHorario,
                aoBuscar = aoBuscar,
                aoCarregarMais = aoCarregarMais,
                aoTentarCatalogosDeNovo = aoTentarCatalogosDeNovo,
                aoAlternarSelecao = aoAlternarSelecao,
                aoAbrirPerfil = aoAbrirPerfil,
                aoPublicarParaTodos = aoPublicarParaTodos,
                aoAbrirFolha = { folhaAberta = true },
                aoAbrirTermos = aoAbrirTermos,
                aoAceitarTermos = aoAceitarTermos,
                carregarFoto = carregarFoto,
                modifier = Modifier.padding(preenchimento),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ListaDaBusca(
    estado: EstadoBusca,
    relogio: () -> Instant,
    aoEscolherFuncao: (String?) -> Unit,
    aoEscolherRegiao: (Int?) -> Unit,
    aoDefinirHorario: (HorarioDaBusca?) -> Unit,
    aoBuscar: () -> Unit,
    aoCarregarMais: () -> Unit,
    aoTentarCatalogosDeNovo: () -> Unit,
    aoAlternarSelecao: (String) -> Unit,
    aoAbrirPerfil: (String) -> Unit,
    aoPublicarParaTodos: (RascunhoDeVagaDaBusca) -> Unit,
    aoAbrirFolha: () -> Unit,
    aoAbrirTermos: () -> Unit,
    aoAceitarTermos: () -> Unit,
    carregarFoto: CarregadorDeFoto,
    modifier: Modifier = Modifier,
) {
    var usarHorario by rememberSaveable { mutableStateOf(false) }
    var inicioTexto by rememberSaveable { mutableStateOf("") }
    var fimTexto by rememberSaveable { mutableStateOf("") }
    val inicio = lerDataEHora(inicioTexto)
    val fim = lerDataEHora(fimTexto)
    val horarioLegivel = !usarHorario || (inicio != null && fim != null)
    val horarioNaOrdem = !usarHorario || inicio == null || fim == null || fim.isAfter(inicio)

    // O horário do filtro só vale com os dois instantes legíveis; senão a busca fica desligada (podeBuscarAgora).
    LaunchedEffect(usarHorario, inicioTexto, fimTexto) {
        aoDefinirHorario(if (usarHorario && inicio != null && fim != null) HorarioDaBusca(inicio, fim) else null)
    }

    var funcaoAberta by rememberSaveable { mutableStateOf(false) }
    var regiaoAberta by rememberSaveable { mutableStateOf(false) }
    val funcaoEscolhida = estado.funcoes.firstOrNull { it.id == estado.funcaoId }
    val regiaoEscolhida = estado.regioes.firstOrNull { it.id == estado.regiaoId }
    val podeBuscarAgora = estado.podeBuscar && horarioLegivel && horarioNaOrdem

    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 16.dp).testTag("busca-lista"),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                when {
                    estado.carregandoCatalogos -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CircularProgressIndicator(modifier = Modifier.padding(4.dp))
                        Text(TextosChamadaCasa.CARREGANDO)
                    }
                    estado.falhaDeCatalogos -> {
                        Text(TextosChamadaCasa.BUSCA_CATALOGO_ERRO, color = MaterialTheme.colorScheme.error)
                        OutlinedButton(onClick = aoTentarCatalogosDeNovo, modifier = Modifier.testTag("busca-catalogos-de-novo")) {
                            Text(TextosChamadaCasa.TENTAR_NOVAMENTE)
                        }
                    }
                }

                ExposedDropdownMenuBox(expanded = funcaoAberta, onExpandedChange = { funcaoAberta = it }) {
                    OutlinedTextField(
                        value = funcaoEscolhida?.nome.orEmpty(),
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(TextosChamadaCasa.BUSCA_FUNCAO) },
                        placeholder = { Text(TextosChamadaCasa.BUSCA_ESCOLHA_FUNCAO) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = funcaoAberta) },
                        modifier = Modifier
                            .menuAnchor()
                            .fillMaxWidth()
                            .testTag("busca-funcao"),
                    )
                    ExposedDropdownMenu(expanded = funcaoAberta, onDismissRequest = { funcaoAberta = false }) {
                        estado.funcoes.forEach { funcao ->
                            DropdownMenuItem(
                                text = { Text(funcao.nome) },
                                onClick = {
                                    aoEscolherFuncao(funcao.id)
                                    funcaoAberta = false
                                },
                            )
                        }
                    }
                }

                if (estado.regioes.isNotEmpty()) {
                    ExposedDropdownMenuBox(expanded = regiaoAberta, onExpandedChange = { regiaoAberta = it }) {
                        OutlinedTextField(
                            value = regiaoEscolhida?.nome ?: TextosChamadaCasa.BUSCA_QUALQUER_REGIAO,
                            onValueChange = {},
                            readOnly = true,
                            label = { Text(TextosChamadaCasa.BUSCA_REGIAO) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = regiaoAberta) },
                            modifier = Modifier
                                .menuAnchor()
                                .fillMaxWidth()
                                .testTag("busca-regiao"),
                        )
                        ExposedDropdownMenu(expanded = regiaoAberta, onDismissRequest = { regiaoAberta = false }) {
                            DropdownMenuItem(
                                text = { Text(TextosChamadaCasa.BUSCA_QUALQUER_REGIAO) },
                                onClick = {
                                    aoEscolherRegiao(null)
                                    regiaoAberta = false
                                },
                            )
                            estado.regioes.forEach { regiao ->
                                DropdownMenuItem(
                                    text = { Text(regiao.nome) },
                                    onClick = {
                                        aoEscolherRegiao(regiao.id)
                                        regiaoAberta = false
                                    },
                                )
                            }
                        }
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(
                        checked = usarHorario,
                        onCheckedChange = { marcado ->
                            usarHorario = marcado
                            if (marcado && inicioTexto.isEmpty()) {
                                val comeco = relogio().plus(Duration.ofHours(24))
                                inicioTexto = dataEHora(comeco)
                                fimTexto = dataEHora(comeco.plus(Duration.ofHours(4)))
                            }
                        },
                        modifier = Modifier.testTag("busca-usar-horario"),
                    )
                    Text(TextosChamadaCasa.BUSCA_FILTRAR_HORARIO)
                }
                if (usarHorario) {
                    OutlinedTextField(
                        value = inicioTexto,
                        onValueChange = { inicioTexto = it },
                        label = { Text(TextosChamadaCasa.BUSCA_INICIO) },
                        isError = inicio == null,
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().testTag("busca-inicio"),
                    )
                    OutlinedTextField(
                        value = fimTexto,
                        onValueChange = { fimTexto = it },
                        label = { Text(TextosChamadaCasa.BUSCA_TERMINO) },
                        isError = fim == null,
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().testTag("busca-fim"),
                    )
                    when {
                        !horarioLegivel -> Text(TextosChamadaCasa.BUSCA_DATA_INVALIDA, color = MaterialTheme.colorScheme.error)
                        !horarioNaOrdem -> Text(TextosChamadaCasa.BUSCA_HORARIO_INVALIDO, color = MaterialTheme.colorScheme.error)
                    }
                }

                if (estado.temEnvioPendente) {
                    Text(
                        TextosChamadaCasa.BUSCA_ENVIO_PENDENTE,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.testTag("busca-envio-pendente"),
                    )
                }
                Button(
                    onClick = aoBuscar,
                    enabled = podeBuscarAgora,
                    modifier = Modifier.fillMaxWidth().testTag("busca-buscar"),
                ) { Text(TextosChamadaCasa.BUSCA_BUSCAR) }
                HorizontalDivider()
            }
        }

        if (estado.temEnvioPendente && estado.estado != EstadoDaBusca.Resultados) {
            // Lista em erro, indisponível ou 429 com envio pendente: o reenvio continua ao alcance (não depende da lista).
            item {
                Button(
                    onClick = aoAbrirFolha,
                    enabled = estado.podeChamar,
                    modifier = Modifier.fillMaxWidth().testTag("busca-ver-envio-pendente"),
                ) { Text(TextosChamadaCasa.BUSCA_VER_ENVIO_PENDENTE) }
            }
        }

        when (val situacao = estado.estado) {
            EstadoDaBusca.Ocioso -> Unit
            EstadoDaBusca.Carregando -> item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CircularProgressIndicator(modifier = Modifier.padding(4.dp))
                    Text(TextosChamadaCasa.CARREGANDO)
                }
            }
            EstadoDaBusca.Indisponivel -> item {
                Text(TextosChamadaCasa.BUSCA_INDISPONIVEL, modifier = Modifier.testTag("busca-indisponivel"))
            }
            is EstadoDaBusca.TermosPendentes -> item {
                // TELA PROVISÓRIA: substituir pelo high-fi do Fabrício. A busca só volta depois do aceite.
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.testTag("busca-termos-pendentes"),
                ) {
                    Text(TextosChamadaCasa.BUSCA_TERMOS_EXPLICACAO)
                    OutlinedButton(onClick = aoAbrirTermos, modifier = Modifier.testTag("busca-termos-ler")) {
                        Text(TextosChamadaCasa.BUSCA_TERMOS_LER)
                    }
                    situacao.erro?.let {
                        Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("busca-termos-erro"))
                    }
                    if (situacao.aceitando) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            CircularProgressIndicator(modifier = Modifier.padding(4.dp))
                            Text(TextosChamadaCasa.BUSCA_TERMOS_ACEITANDO)
                        }
                    }
                    Button(
                        onClick = aoAceitarTermos,
                        enabled = !situacao.aceitando,
                        modifier = Modifier.fillMaxWidth().testTag("busca-termos-aceitar"),
                    ) { Text(TextosChamadaCasa.BUSCA_TERMOS_ACEITAR) }
                }
            }
            is EstadoDaBusca.Erro -> item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(situacao.mensagem, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("busca-erro"))
                    OutlinedButton(onClick = aoBuscar, enabled = podeBuscarAgora) { Text(TextosChamadaCasa.TENTAR_NOVAMENTE) }
                }
            }
            EstadoDaBusca.Vazio -> item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(TextosChamadaCasa.BUSCA_VAZIO, modifier = Modifier.testTag("busca-vazio"))
                    estado.rascunhoParaPublicarParaTodos?.let { rascunho ->
                        Text(TextosChamadaCasa.PUBLICAR_PARA_TODOS_EXPLICACAO)
                        Button(
                            onClick = { aoPublicarParaTodos(rascunho) },
                            modifier = Modifier.fillMaxWidth().testTag("busca-publicar-para-todos"),
                        ) { Text(TextosChamadaCasa.PUBLICAR_PARA_TODOS) }
                    }
                }
            }
            EstadoDaBusca.Resultados -> {
                items(estado.resultados, key = { it.id }) { cartao ->
                    CartaoDoProfissional(
                        cartao = cartao,
                        selecionado = estado.estaSelecionado(cartao.id),
                        travado = estado.selecaoTravada,
                        aoAlternarSelecao = { aoAlternarSelecao(cartao.id) },
                        aoAbrirPerfil = { aoAbrirPerfil(cartao.id) },
                        carregarFoto = carregarFoto,
                    )
                }
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        estado.erroAoCarregarMais?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                        if (estado.temMais) {
                            OutlinedButton(
                                onClick = aoCarregarMais,
                                enabled = !estado.carregandoMais,
                                modifier = Modifier.fillMaxWidth().testTag("busca-carregar-mais"),
                            ) { Text(if (estado.carregandoMais) TextosChamadaCasa.CARREGANDO else TextosChamadaCasa.BUSCA_CARREGAR_MAIS) }
                        }
                        estado.avisoDeLimiteDeSelecao?.let {
                            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("busca-aviso-limite"))
                        }
                        Text(TextosChamadaCasa.buscaSelecionados(estado.selecionados.size))
                        Button(
                            onClick = aoAbrirFolha,
                            enabled = estado.podeChamar,
                            modifier = Modifier.fillMaxWidth().testTag("busca-chamar"),
                        ) { Text(TextosChamadaCasa.buscaChamar(estado.selecionados.size)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun CartaoDoProfissional(
    cartao: CartaoProfissionalDto,
    selecionado: Boolean,
    travado: Boolean,
    aoAlternarSelecao: () -> Unit,
    aoAbrirPerfil: () -> Unit,
    carregarFoto: CarregadorDeFoto,
) {
    Row(
        modifier = Modifier.fillMaxWidth().testTag("busca-cartao-${cartao.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Checkbox(
            checked = selecionado,
            onCheckedChange = { aoAlternarSelecao() },
            enabled = !travado,
            modifier = Modifier.testTag("busca-selecionar-${cartao.id}"),
        )
        FotoDoCartao(id = cartao.id, nome = cartao.nome, fotoUrl = cartao.fotoUrl, carregar = carregarFoto)
        Spacer(Modifier.width(8.dp))
        Column(modifier = Modifier.weight(1f).clickable(onClick = aoAbrirPerfil).padding(vertical = 8.dp)) {
            Text(cartao.nome, style = MaterialTheme.typography.titleMedium)
            Text("${cartao.servico.funcao.nome}: ${resumoDoServico(cartao.servico).orEmpty()}")
            Text(
                if (cartao.atendeTodoDf) TextosChamadaCasa.TODO_O_DF else cartao.regioes.joinToString(", ") { it.nome },
            )
            Text(TextosChamadaCasa.reputacao(cartao.reputacao.positivas, cartao.reputacao.total))
            if (cartao.disponivelNoHorario == true) {
                Text(TextosChamadaCasa.BUSCA_DISPONIVEL, color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

/**
 * A folha de chamar os selecionados: valor total com confirmação, horário, responsável e recado, uma vez para
 * todos. Depois do envio mostra o resultado de cada pessoa (enviada, aviso J7 para confirmar ou erro).
 */
@Composable
private fun FolhaDeChamadaDaBusca(
    estado: EstadoBusca,
    relogio: () -> Instant,
    aoChamar: (TrabalhoDaChamada, String?) -> Unit,
    aoReenviar: () -> Unit,
    aoConfirmarJ7: () -> Unit,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val horarioDoFiltro = estado.horario
    val comeco = horarioDoFiltro?.inicio ?: relogio().plus(Duration.ofHours(24))
    val termino = horarioDoFiltro?.fim ?: comeco.plus(Duration.ofHours(4))
    var valor by rememberSaveable { mutableStateOf("") }
    var totalConfirmado by rememberSaveable { mutableStateOf(false) }
    var inicioTexto by rememberSaveable { mutableStateOf(dataEHora(comeco)) }
    var fimTexto by rememberSaveable { mutableStateOf(dataEHora(termino)) }
    var responsavel by rememberSaveable { mutableStateOf(estado.casa?.nome.orEmpty()) }
    var recado by rememberSaveable { mutableStateOf("") }
    var faltando by rememberSaveable { mutableStateOf<String?>(null) }
    val travada = estado.enviando || estado.resultadosDaChamada.isNotEmpty()

    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            TextosChamadaCasa.BUSCA_FOLHA_TITULO,
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.semantics { heading() },
        )
        if (estado.casa == null) {
            Text(TextosChamadaCasa.BUSCA_SEM_CASA, color = MaterialTheme.colorScheme.error)
        }
        OutlinedTextField(
            value = valor,
            onValueChange = { valor = ValorEmReais.digitado(it, anterior = valor); totalConfirmado = false },
            enabled = !travada,
            label = { Text("${TextosChamadaCasa.VALOR_TOTAL} (${TextosChamadaCasa.MOEDA})") },
            placeholder = { Text(TextosChamadaCasa.VALOR_EXEMPLO) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("folha-valor"),
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(
                checked = totalConfirmado,
                onCheckedChange = { totalConfirmado = it },
                enabled = !travada,
                modifier = Modifier.testTag("folha-confirmar-total"),
            )
            Text(TextosChamadaCasa.CONFIRMAR_TOTAL, modifier = Modifier.weight(1f))
        }
        OutlinedTextField(
            value = inicioTexto,
            onValueChange = { inicioTexto = it },
            enabled = !travada,
            label = { Text(TextosChamadaCasa.BUSCA_INICIO) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("folha-inicio"),
        )
        OutlinedTextField(
            value = fimTexto,
            onValueChange = { fimTexto = it },
            enabled = !travada,
            label = { Text(TextosChamadaCasa.BUSCA_TERMINO) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("folha-fim"),
        )
        OutlinedTextField(
            value = responsavel,
            onValueChange = { responsavel = it },
            enabled = !travada,
            label = { Text(TextosChamadaCasa.RESPONSAVEL) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("folha-responsavel"),
        )
        OutlinedTextField(
            value = recado,
            onValueChange = { recado = it },
            enabled = !travada,
            label = { Text(TextosChamadaCasa.RECADO) },
            modifier = Modifier.fillMaxWidth().testTag("folha-recado"),
        )
        faltando?.let { motivo ->
            if (!travada) { Text(motivo, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("folha-falta")) }
        }
        if (!travada) {
            Button(
                onClick = {
                    val resultado = validarFolhaDaBusca(
                        funcaoId = estado.filtroDaBusca?.funcaoId,
                        casa = estado.casa,
                        valorTexto = valor,
                        totalConfirmado = totalConfirmado,
                        inicioTexto = inicioTexto,
                        fimTexto = fimTexto,
                        responsavel = responsavel,
                        recado = recado,
                        agora = relogio(),
                    )
                    when (resultado) {
                        is ResultadoDaFolha.Falta -> faltando = resultado.motivo
                        is ResultadoDaFolha.Pronto -> {
                            faltando = null
                            aoChamar(resultado.trabalho, resultado.recado)
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().testTag("folha-enviar"),
            ) { Text(TextosChamadaCasa.BUSCA_FOLHA_ENVIAR) }
        }
        if (estado.enviando) {
            Text(TextosChamadaCasa.CARREGANDO)
        }
        if (estado.resultadosDaChamada.isNotEmpty()) {
            Text(TextosChamadaCasa.RESUMO_DA_CHAMADA, style = MaterialTheme.typography.titleMedium)
            estado.selecionados.forEach { id ->
                val nome = estado.resultados.firstOrNull { it.id == id }?.nome ?: id
                val texto = when (val resultado = estado.resultadosDaChamada[id]) {
                    is ResultadoDaChamadaDaBusca.Enviada -> TextosChamadaCasa.BUSCA_RESULTADO_ENVIADA
                    ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia -> TextosChamadaCasa.BUSCA_RESULTADO_J7
                    ResultadoDaChamadaDaBusca.NaoEnviada -> TextosChamadaCasa.BUSCA_RESULTADO_NAO_ENVIADA
                    is ResultadoDaChamadaDaBusca.Erro -> resultado.mensagem
                    null -> TextosChamadaCasa.CARREGANDO
                }
                Text("$nome: $texto", modifier = Modifier.testTag("folha-resultado-$id"))
            }
        }
        if (estado.podeReenviar) {
            // Mesmo trabalho e mesma chave: os campos seguem travados para o servidor devolver a chamada já criada.
            Button(
                onClick = aoReenviar,
                modifier = Modifier.fillMaxWidth().testTag("folha-reenviar"),
            ) { Text(TextosChamadaCasa.BUSCA_REENVIAR) }
        }
        if (estado.mostrarJ7) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(TextosChamadaCasa.J7_TITULO, style = MaterialTheme.typography.titleMedium)
                Text(TextosChamadaCasa.J7_MENSAGEM)
                // Com envio incerto pendente a vaga pode já existir: confirmar agora poderia criar outra.
                if (estado.podeReenviar) Text(TextosChamadaCasa.BUSCA_CONFIRMAR_DEPOIS, color = MaterialTheme.colorScheme.error)
                Button(
                    onClick = aoConfirmarJ7,
                    enabled = !estado.enviando && !estado.podeReenviar,
                    modifier = Modifier.fillMaxWidth().testTag("folha-confirmar-j7"),
                ) { Text(TextosChamadaCasa.J7_CONFIRMAR) }
            }
        }
        OutlinedButton(
            onClick = aoFechar,
            modifier = Modifier.fillMaxWidth().testTag("folha-fechar"),
        ) { Text(if (travada) TextosChamadaCasa.FECHAR else TextosChamadaCasa.CANCELAR) }
    }
}
