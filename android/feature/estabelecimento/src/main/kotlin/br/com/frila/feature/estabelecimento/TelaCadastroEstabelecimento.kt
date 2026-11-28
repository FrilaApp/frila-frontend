package br.com.frila.feature.estabelecimento

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
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
        aoBuscarEndereco = { viewModel.buscarEndereco() },
        aoEscolherEndereco = viewModel::escolherEndereco,
        aoCadastrar = { viewModel.cadastrar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}


/**
 * Cadastro do estabelecimento do contratante (RF02, UC10; paridade com `TelaCadastroEstabelecimento.swift`,
 * sem mapa: o ponto vem de latitude e longitude digitadas). Tela de entrada: título, campos com o rótulo
 * acima, a escolha do tipo em lista com check e UM botão primário ancorado embaixo. Cada campo mostra o
 * próprio erro; o erro global fica junto ao botão.
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
    aoBuscarEndereco: () -> Unit = {},
    aoEscolherEndereco: (EnderecoEncontrado) -> Unit = {},
) {
    var seletorDeRegiaoAberto by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = {
            BarraDeTopoDoFormulario(
                aoVoltar = aoVoltar,
                rotuloDoVoltar = TextosCadastroEstabelecimento.ROTULO_VOLTAR,
                habilitado = !estado.enviando,
            )
        },
        bottomBar = {
            RodapeAncorado {
                estado.erro?.let { MensagemJuntoAoBotao(it.mensagem) }
                if (estado.concluido) MensagemJuntoAoBotao(TextosCadastroEstabelecimento.CONCLUIDO)
                BotaoPrimario(
                    texto = if (estado.enviando) TextosCadastroEstabelecimento.CADASTRANDO else TextosCadastroEstabelecimento.CADASTRAR,
                    aoClicar = aoCadastrar,
                    habilitado = estado.podeEditar,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                TituloDaTela(TextosCadastroEstabelecimento.TITULO)
                Text(text = TextosCadastroEstabelecimento.SUBTITULO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            }

            CampoDeTexto(
                valor = estado.nome,
                aoMudar = aoEditarNome,
                rotulo = TextosCadastroEstabelecimento.NOME,
                erro = estado.errosDeCampo[CampoCadastro.NOME],
                habilitado = estado.podeEditar,
            )

            FrilaGrupoDeLinhas(titulo = TextosCadastroEstabelecimento.TIPO) {
                TipoEstabelecimento.entries.forEach { tipo ->
                    linha {
                        FrilaLinhaDeOpcao(
                            titulo = tipo.rotulo,
                            marcada = estado.tipo == tipo,
                            aoClicar = { aoEscolherTipo(tipo) },
                            habilitada = estado.podeEditar,
                        )
                    }
                }
            }

            CampoDeTexto(
                valor = estado.documento,
                aoMudar = aoEditarDocumento,
                rotulo = TextosCadastroEstabelecimento.DOCUMENTO,
                apoio = TextosCadastroEstabelecimento.DOCUMENTO_AJUDA,
                erro = estado.errosDeCampo[CampoCadastro.DOCUMENTO],
                habilitado = estado.podeEditar,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )

            CampoDeTexto(
                valor = estado.endereco,
                aoMudar = aoEditarEndereco,
                rotulo = TextosCadastroEstabelecimento.ENDERECO,
                apoio = TextosCadastroEstabelecimento.ENDERECO_AJUDA,
                erro = estado.errosDeCampo[CampoCadastro.ENDERECO],
                habilitado = estado.podeEditar,
            )

            BuscaDeEnderecoNaTela(estado = estado, aoBuscar = aoBuscarEndereco, aoEscolher = aoEscolherEndereco)

            CampoDeSelecao(
                rotulo = TextosCadastroEstabelecimento.REGIAO,
                valor = estado.regiaoAdministrativa.ifEmpty { TextosCadastroEstabelecimento.REGIAO_SELECIONAR },
                aoClicar = { seletorDeRegiaoAberto = true },
                habilitado = estado.podeEditar,
                apoio = TextosCadastroEstabelecimento.REGIAO_AJUDA,
                erro = estado.errosDeCampo[CampoCadastro.REGIAO_ADMINISTRATIVA],
            )

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosCadastroEstabelecimento.PONTO)
                Text(text = TextosCadastroEstabelecimento.PONTO_AJUDA, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            }
            CampoDeTexto(
                valor = estado.latitude,
                aoMudar = aoEditarLatitude,
                rotulo = TextosCadastroEstabelecimento.LATITUDE,
                erro = estado.errosDeCampo[CampoCadastro.LATITUDE],
                habilitado = estado.podeEditar,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            )
            CampoDeTexto(
                valor = estado.longitude,
                aoMudar = aoEditarLongitude,
                rotulo = TextosCadastroEstabelecimento.LONGITUDE,
                erro = estado.errosDeCampo[CampoCadastro.LONGITUDE],
                habilitado = estado.podeEditar,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            )
        }
    }

    if (seletorDeRegiaoAberto) {
        FrilaBottomSheet(
            onDismissRequest = { seletorDeRegiaoAberto = false },
            titulo = TextosCadastroEstabelecimento.REGIAO_SELECIONAR,
            aoFechar = null,
        ) {
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            ) {
                FrilaGrupoDeLinhas {
                    REGIOES_ADMINISTRATIVAS_DF.forEach { regiao ->
                        linha {
                            FrilaLinhaDeOpcao(
                                titulo = regiao,
                                marcada = estado.regiaoAdministrativa == regiao,
                                aoClicar = {
                                    aoEscolherRegiao(regiao)
                                    seletorDeRegiaoAberto = false
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * "Buscar endereço" abaixo do campo (paridade com o iOS, sem mapa). Sem serviço de geocodificação no aparelho a seção só avisa
 * que a coordenada é digitada; os campos de latitude e longitude seguem como plano B nos três casos.
 */
@Composable
private fun BuscaDeEnderecoNaTela(
    estado: EstadoCadastroEstabelecimento,
    aoBuscar: () -> Unit,
    aoEscolher: (EnderecoEncontrado) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        if (!estado.buscaDisponivel) {
            Text(text = TextosCadastroEstabelecimento.ENDERECO_BUSCA_INDISPONIVEL, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            return@Column
        }
        BotaoSecundario(
            texto = if (estado.buscando) TextosCadastroEstabelecimento.BUSCANDO_ENDERECO else TextosCadastroEstabelecimento.BUSCAR_ENDERECO,
            aoClicar = aoBuscar,
            habilitado = estado.podeEditar && !estado.buscando && estado.endereco.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        )
        if (estado.buscaSemResultado) AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = TextosCadastroEstabelecimento.ENDERECO_SEM_RESULTADO)
        if (estado.erroDaBusca) AvisoFrila(tom = TomAviso.ERRO, mensagem = TextosCadastroEstabelecimento.ENDERECO_ERRO_DA_BUSCA)
        if (estado.resultadosDaBusca.isNotEmpty()) {
            FrilaGrupoDeLinhas(titulo = TextosCadastroEstabelecimento.ENDERECOS_ENCONTRADOS) {
                estado.resultadosDaBusca.forEach { encontrado ->
                    linha {
                        FrilaLinhaDeOpcao(
                            titulo = encontrado.texto,
                            marcada = false,
                            aoClicar = { aoEscolher(encontrado) },
                            habilitada = estado.podeEditar,
                        )
                    }
                }
            }
        }
    }
}
