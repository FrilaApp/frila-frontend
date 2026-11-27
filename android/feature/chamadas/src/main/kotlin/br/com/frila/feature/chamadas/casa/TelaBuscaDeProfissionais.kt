package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.designsystem.componentes.focoAcessivelFrila
import br.com.frila.core.designsystem.tema.FrilaRaios
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
    /** Abre a Política de Privacidade: a versão aceita (2026-11-16) cobre os Termos 1.2 e a Política 1.3. */
    aoAbrirPolitica: () -> Unit = {},
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
        aoAbrirPolitica = aoAbrirPolitica,
        aoAceitarTermos = { viewModel.aceitarTermosEBuscar() },
        carregarFoto = carregarFoto,
        aoConfirmarTermosDaVaga = { viewModel.confirmarTermosDaVagaAberta() },
        aoCancelarTermosDaVaga = viewModel::cancelarTermosDaVagaAberta,
    )
}

/**
 * A busca da casa: tela de escolha. Filtros (serviço, região e horário opcionais), lista na ordem do servidor com um
 * cartão por pessoa e o selo "Disponível nesse horário", seleção de até 3 e a folha de chamar. Sem laranja na lista: o
 * único primário é o "Chamar" do rodapé, que só aparece com resultados (e o "Aceitar", quando faltam os Termos). Atrás
 * da chave `busca_profissionais`.
 */
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
    aoAbrirPolitica: () -> Unit = {},
    aoAceitarTermos: () -> Unit = {},
    carregarFoto: CarregadorDeFoto = ::carregarFotoPorUrl,
    aoConfirmarTermosDaVaga: () -> Unit = {},
    aoCancelarTermosDaVaga: () -> Unit = {},
) {
    var folhaAberta by rememberSaveable { mutableStateOf(false) }
    // 0.2.95: fechar a folha com os termos da vaga aberta por confirmar vale Cancelar, como no iOS. Sem isso, o "Chamar"
    // fica desligado (podeChamar) e a casa não volta à folha para responder.
    val fecharFolha: () -> Unit = {
        if (estado.termosParaConfirmar != null) aoCancelarTermosDaVaga()
        folhaAberta = false
    }
    // Busca que já teve envio (serviço e horário): "Chamar" repete o trabalho guardado, sem folha nova nem 2ª vaga.
    // 0.2.95: com termos da vaga aberta por confirmar (o 409 chegou com a folha já fechada), o botão reabre a folha,
    // que é onde estão o Confirmar e o Cancelar.
    val chamar = if (estado.trabalhoEnviadoDaBusca != null && estado.termosParaConfirmar == null) aoReenviar else ({ folhaAberta = true })

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            if (estado.estado == EstadoDaBusca.Resultados) {
                RodapeAncorado {
                    estado.avisoDeLimiteDeSelecao?.let { MensagemJuntoAoBotao(it, modifier = Modifier.testTag("busca-aviso-limite")) }
                    Text(
                        text = TextosChamadaCasa.buscaSelecionados(estado.selecionados.size),
                        style = FrilaTipo.apoio,
                        color = FrilaTema.cores.tintaSuave,
                    )
                    BotaoPrimario(
                        texto = TextosChamadaCasa.buscaChamar(estado.selecionados.size),
                        aoClicar = chamar,
                        habilitado = estado.podeChamar || estado.termosParaConfirmar != null,
                        modifier = Modifier.fillMaxWidth().testTag("busca-chamar"),
                    )
                }
            }
        },
    ) { preenchimento ->
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
            aoReenviar = aoReenviar,
            aoAbrirTermos = aoAbrirTermos,
            aoAbrirPolitica = aoAbrirPolitica,
            aoAceitarTermos = aoAceitarTermos,
            carregarFoto = carregarFoto,
            modifier = Modifier.padding(preenchimento),
        )
    }

    if (folhaAberta) {
        FolhaDeChamadaDaBusca(
            estado = estado,
            relogio = relogio,
            aoChamar = aoChamar,
            aoReenviar = aoReenviar,
            aoConfirmarJ7 = aoConfirmarJ7,
            aoFechar = fecharFolha,
            aoConfirmarTermos = aoConfirmarTermosDaVaga,
            aoCancelarTermos = aoCancelarTermosDaVaga,
        )
    }
}

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
    aoReenviar: () -> Unit,
    aoAbrirTermos: () -> Unit,
    aoAbrirPolitica: () -> Unit,
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
        modifier = modifier.fillMaxSize().padding(horizontal = FrilaEspacamento.grupo).testTag("busca-lista"),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
    ) {
        item { TituloDaTela(TextosChamadaCasa.BUSCA_TITULO) }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                when {
                    estado.carregandoCatalogos -> Row(
                        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        IndicadorCarregando(modifier = Modifier.height(20.dp).width(20.dp))
                        Text(TextosChamadaCasa.CARREGANDO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                    }
                    estado.falhaDeCatalogos -> {
                        AvisoFrila(tom = TomAviso.ERRO, mensagem = TextosChamadaCasa.BUSCA_CATALOGO_ERRO)
                        BotaoSecundario(
                            texto = TextosChamadaCasa.TENTAR_NOVAMENTE,
                            aoClicar = aoTentarCatalogosDeNovo,
                            modifier = Modifier.testTag("busca-catalogos-de-novo"),
                        )
                    }
                }

                CampoDeEscolha(
                    rotulo = TextosChamadaCasa.BUSCA_FUNCAO,
                    valor = funcaoEscolhida?.nome,
                    dica = TextosChamadaCasa.BUSCA_ESCOLHA_FUNCAO,
                    aberto = funcaoAberta,
                    aoMudarAberto = { funcaoAberta = it },
                    opcoes = estado.funcoes.map { funcao -> OpcaoDeEscolha(funcao.nome) { aoEscolherFuncao(funcao.id) } },
                    modifier = Modifier.testTag("busca-funcao"),
                )

                if (estado.regioes.isNotEmpty()) {
                    CampoDeEscolha(
                        rotulo = TextosChamadaCasa.BUSCA_REGIAO,
                        valor = regiaoEscolhida?.nome ?: TextosChamadaCasa.BUSCA_QUALQUER_REGIAO,
                        dica = TextosChamadaCasa.BUSCA_QUALQUER_REGIAO,
                        aberto = regiaoAberta,
                        aoMudarAberto = { regiaoAberta = it },
                        opcoes = listOf(OpcaoDeEscolha(TextosChamadaCasa.BUSCA_QUALQUER_REGIAO) { aoEscolherRegiao(null) }) +
                            estado.regioes.map { regiao -> OpcaoDeEscolha(regiao.nome) { aoEscolherRegiao(regiao.id) } },
                        modifier = Modifier.testTag("busca-regiao"),
                    )
                }

                ChipFrila(
                    texto = TextosChamadaCasa.BUSCA_FILTRAR_HORARIO,
                    selecionado = usarHorario,
                    aoClicar = {
                        usarHorario = !usarHorario
                        if (usarHorario && inicioTexto.isEmpty()) {
                            val comeco = relogio().plus(Duration.ofHours(24))
                            inicioTexto = dataEHora(comeco)
                            fimTexto = dataEHora(comeco.plus(Duration.ofHours(4)))
                        }
                    },
                    modifier = Modifier.testTag("busca-usar-horario"),
                )
                if (usarHorario) {
                    CampoDeTexto(
                        valor = inicioTexto,
                        aoMudar = { inicioTexto = it },
                        rotulo = TextosChamadaCasa.BUSCA_INICIO,
                        erro = if (inicio == null) TextosChamadaCasa.BUSCA_DATA_INVALIDA else null,
                        modifier = Modifier.testTag("busca-inicio"),
                    )
                    CampoDeTexto(
                        valor = fimTexto,
                        aoMudar = { fimTexto = it },
                        rotulo = TextosChamadaCasa.BUSCA_TERMINO,
                        erro = when {
                            inicio == null -> null
                            fim == null -> TextosChamadaCasa.BUSCA_DATA_INVALIDA
                            !horarioNaOrdem -> TextosChamadaCasa.BUSCA_HORARIO_INVALIDO
                            else -> null
                        },
                        modifier = Modifier.testTag("busca-fim"),
                    )
                }

                if (estado.temEnvioPendente) {
                    AvisoFrila(
                        tom = TomAviso.ALERTA,
                        mensagem = TextosChamadaCasa.BUSCA_ENVIO_PENDENTE,
                        modifier = Modifier.testTag("busca-envio-pendente"),
                    )
                }
                BotaoSecundario(
                    texto = TextosChamadaCasa.BUSCA_BUSCAR,
                    aoClicar = aoBuscar,
                    habilitado = podeBuscarAgora,
                    modifier = Modifier.fillMaxWidth().testTag("busca-buscar"),
                )
            }
        }

        if (estado.temEnvioPendente && estado.estado != EstadoDaBusca.Resultados) {
            // Lista em erro, indisponível ou 429 com envio pendente: o reenvio continua ao alcance (não depende da lista).
            item {
                BotaoSecundario(
                    texto = TextosChamadaCasa.BUSCA_VER_ENVIO_PENDENTE,
                    aoClicar = aoAbrirFolha,
                    habilitado = estado.podeChamar,
                    modifier = Modifier.fillMaxWidth().testTag("busca-ver-envio-pendente"),
                )
            }
        }

        when (val situacao = estado.estado) {
            EstadoDaBusca.Ocioso -> Unit
            EstadoDaBusca.Carregando -> item { EstadoCarregando(mensagem = TextosChamadaCasa.CARREGANDO) }
            EstadoDaBusca.Indisponivel -> item {
                EstadoVazio(titulo = TextosChamadaCasa.BUSCA_INDISPONIVEL, modifier = Modifier.testTag("busca-indisponivel"))
            }
            is EstadoDaBusca.TermosPendentes -> item {
                // O aceite vem antes da primeira busca: a busca só volta depois dele.
                Column(
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
                    modifier = Modifier.testTag("busca-termos-pendentes"),
                ) {
                    Text(TextosChamadaCasa.BUSCA_TERMOS_EXPLICACAO, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
                    Column {
                        LinkFrila(
                            texto = TextosChamadaCasa.BUSCA_TERMOS_LER,
                            aoClicar = aoAbrirTermos,
                            modifier = Modifier.testTag("busca-termos-ler"),
                        )
                        LinkFrila(
                            texto = TextosChamadaCasa.BUSCA_TERMOS_POLITICA,
                            aoClicar = aoAbrirPolitica,
                            modifier = Modifier.testTag("busca-termos-politica"),
                        )
                    }
                    if (situacao.aceitando) {
                        Text(TextosChamadaCasa.BUSCA_TERMOS_ACEITANDO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                    }
                    situacao.erro?.let { MensagemJuntoAoBotao(it, modifier = Modifier.testTag("busca-termos-erro")) }
                    BotaoPrimario(
                        texto = TextosChamadaCasa.BUSCA_TERMOS_ACEITAR,
                        aoClicar = aoAceitarTermos,
                        habilitado = !situacao.aceitando,
                        modifier = Modifier.fillMaxWidth().testTag("busca-termos-aceitar"),
                    )
                }
            }
            is EstadoDaBusca.Erro -> item {
                EstadoErro(
                    titulo = situacao.mensagem,
                    mensagem = null,
                    aoTentarNovamente = if (podeBuscarAgora) aoBuscar else null,
                    modifier = Modifier.testTag("busca-erro"),
                )
            }
            EstadoDaBusca.Vazio -> item {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    EstadoVazio(
                        titulo = TextosChamadaCasa.BUSCA_VAZIO,
                        mensagem = estado.rascunhoParaPublicarParaTodos?.let { TextosChamadaCasa.PUBLICAR_PARA_TODOS_EXPLICACAO },
                        modifier = Modifier.testTag("busca-vazio"),
                    )
                    estado.rascunhoParaPublicarParaTodos?.let { rascunho ->
                        BotaoSecundario(
                            texto = TextosChamadaCasa.PUBLICAR_PARA_TODOS,
                            aoClicar = { aoPublicarParaTodos(rascunho) },
                            modifier = Modifier.testTag("busca-publicar-para-todos"),
                        )
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
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                        estado.erroAoCarregarMais?.let { AvisoFrila(tom = TomAviso.ERRO, mensagem = it) }
                        if (estado.temMais) {
                            BotaoSecundario(
                                texto = if (estado.carregandoMais) TextosChamadaCasa.CARREGANDO else TextosChamadaCasa.BUSCA_CARREGAR_MAIS,
                                aoClicar = aoCarregarMais,
                                habilitado = !estado.carregandoMais,
                                modifier = Modifier.fillMaxWidth().testTag("busca-carregar-mais"),
                            )
                        }
                        Spacer(Modifier.height(FrilaEspacamento.grupo))
                    }
                }
            }
        }
    }
}

/** Uma pessoa na lista: foto, nome, serviço, região, reputação (fato escrito) e o selo de disponibilidade. Sem laranja. */
@Composable
private fun CartaoDoProfissional(
    cartao: CartaoProfissionalDto,
    selecionado: Boolean,
    travado: Boolean,
    aoAlternarSelecao: () -> Unit,
    aoAbrirPerfil: () -> Unit,
    carregarFoto: CarregadorDeFoto,
) {
    CartaoFrila(modifier = Modifier.fillMaxWidth().testTag("busca-cartao-${cartao.id}")) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            FotoDoCartao(id = cartao.id, nome = cartao.nome, fotoUrl = cartao.fotoUrl, carregar = carregarFoto)
            Column(
                // Como o `CartaoDeVagaDoFeed`: o leitor de tela anuncia um botão com a ação ("Ver perfil de …"), não só o texto.
                modifier = Modifier
                    .weight(1f)
                    .focoAcessivelFrila(forma = RoundedCornerShape(FrilaRaios.interno))
                    .clickable(
                        onClickLabel = TextosChamadaCasa.buscaVerPerfil(cartao.nome),
                        role = Role.Button,
                        onClick = aoAbrirPerfil,
                    )
                    .testTag("busca-abrir-perfil-${cartao.id}")
                    .padding(vertical = FrilaEspacamento.item),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
            ) {
                Text(cartao.nome, style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
                Text(
                    "${cartao.servico.funcao.nome}: ${resumoDoServico(cartao.servico).orEmpty()}",
                    style = FrilaTipo.corpo,
                    color = FrilaTema.cores.tinta,
                )
                Text(
                    if (cartao.atendeTodoDf) TextosChamadaCasa.TODO_O_DF else cartao.regioes.joinToString(", ") { it.nome },
                    style = FrilaTipo.apoio,
                    color = FrilaTema.cores.tintaSuave,
                )
                Text(
                    TextosChamadaCasa.reputacao(cartao.reputacao.positivas, cartao.reputacao.total),
                    style = FrilaTipo.apoio,
                    color = FrilaTema.cores.tintaSuave,
                )
                if (cartao.disponivelNoHorario == true) {
                    SeloDeStatus(texto = TextosChamadaCasa.BUSCA_DISPONIVEL, estilo = EstiloDoSelo.CONTORNO)
                }
            }
            Checkbox(
                checked = selecionado,
                onCheckedChange = { aoAlternarSelecao() },
                enabled = !travado,
                modifier = Modifier
                    .testTag("busca-selecionar-${cartao.id}")
                    .semantics { contentDescription = TextosChamadaCasa.buscaSelecionar(cartao.nome) },
            )
        }
    }
}
