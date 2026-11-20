// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EscopoDoGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

@Composable
fun TelaPorQueReceboVagas(
    viewModel: PorQueReceboVagasViewModel,
    aoVoltar: () -> Unit,
    aoContestar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }

    ConteudoPorQueReceboVagas(
        estado = estado,
        aoTentarRecarregar = { viewModel.carregar() },
        aoContestar = aoContestar,
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

@Composable
fun ConteudoPorQueReceboVagas(
    estado: EstadoPorQueReceboVagas,
    aoTentarRecarregar: () -> Unit,
    aoContestar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            RodapeAncorado {
                BotaoSecundario(
                    texto = "Voltar",
                    aoClicar = aoVoltar,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("botao-voltar-por-que-recebo"),
                )
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.respiro,
                    bottom = FrilaEspacamento.grupo,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(stringResource(R.string.por_que_recebo_vagas_titulo))

            Text(
                text = stringResource(R.string.por_que_recebo_vagas_explicacao),
                style = FrilaTipo.corpo,
                color = cores.tinta,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("perfil-explicacao-vagas"),
            )

            when (estado) {
                is EstadoPorQueReceboVagas.Carregando -> {
                    IndicadorCarregando(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = FrilaEspacamento.bloco)
                            .testTag("criterios-carregando"),
                    )
                }

                is EstadoPorQueReceboVagas.Vazio -> {
                    EstadoVazio(
                        titulo = stringResource(R.string.por_que_recebo_vagas_vazio_titulo),
                        mensagem = stringResource(R.string.por_que_recebo_vagas_vazio_mensagem),
                        modifier = Modifier.testTag("criterios-vazio"),
                    )
                    SecaoContestar(
                        protocolo = null,
                        contestacaoJaAberta = false,
                        aoContestar = aoContestar,
                    )
                }

                is EstadoPorQueReceboVagas.SemRede -> {
                    EstadoErro(
                        titulo = stringResource(R.string.por_que_recebo_vagas_erro_sem_rede),
                        mensagem = null,
                        aoTentarNovamente = aoTentarRecarregar,
                        modifier = Modifier.testTag("criterios-sem-rede"),
                    )
                }

                is EstadoPorQueReceboVagas.Erro -> {
                    EstadoErro(
                        titulo = stringResource(R.string.por_que_recebo_vagas_erro_carregar),
                        mensagem = estado.mensagem,
                        aoTentarNovamente = aoTentarRecarregar,
                        modifier = Modifier.testTag("criterios-erro"),
                    )
                }

                is EstadoPorQueReceboVagas.Conteudo -> {
                    val criterios = estado.criterios

                    // 1. Função
                    CartaoDeCriterio(
                        titulo = stringResource(R.string.por_que_recebo_vagas_secao_funcao),
                        identificador = "criterios-funcoes",
                    ) {
                        if (criterios.funcoes.isEmpty()) {
                            linha { LinhaDeLeitura(stringResource(R.string.por_que_recebo_vagas_sem_funcao)) }
                        } else {
                            criterios.funcoes.forEach { funcao ->
                                linha { LinhaDeLeitura(funcao.nome) }
                            }
                        }
                    }

                    // 2. Horários
                    val notaHorarios = if (criterios.disponibilidades.isEmpty()) null else stringResource(R.string.por_que_recebo_vagas_horarios_explicacao)
                    CartaoDeCriterio(
                        titulo = stringResource(R.string.por_que_recebo_vagas_secao_horarios),
                        identificador = "criterios-horarios",
                        nota = notaHorarios,
                    ) {
                        if (criterios.disponibilidades.isEmpty()) {
                            linha { LinhaDeLeitura(stringResource(R.string.por_que_recebo_vagas_sem_horarios)) }
                        } else {
                            criterios.disponibilidades.forEach { janela ->
                                linha { LinhaDeLeitura(PorQueReceboVagasViewModel.descricaoJanela(janela)) }
                            }
                        }
                    }

                    // 3. Distância
                    CartaoDeCriterio(
                        titulo = stringResource(R.string.por_que_recebo_vagas_secao_distancia),
                        identificador = "criterios-distancia",
                    ) {
                        val kmTexto = PorQueReceboVagasViewModel.descricaoDistancia(criterios.distanciaMaximaKm)
                        linha { LinhaDeLeitura(stringResource(R.string.por_que_recebo_vagas_distancia, kmTexto)) }
                    }

                    // 4. Equipes de confiança
                    val notaEquipes = if (criterios.equipesDeConfianca.isEmpty()) null else stringResource(R.string.por_que_recebo_vagas_equipes_explicacao)
                    CartaoDeCriterio(
                        titulo = stringResource(R.string.por_que_recebo_vagas_secao_equipes),
                        identificador = "criterios-equipes",
                        nota = notaEquipes,
                    ) {
                        if (criterios.equipesDeConfianca.isEmpty()) {
                            linha { LinhaDeLeitura(stringResource(R.string.por_que_recebo_vagas_sem_equipes)) }
                        } else {
                            criterios.equipesDeConfianca.forEach { equipe ->
                                linha { LinhaDeLeitura(equipe.nome) }
                            }
                        }
                    }

                    // 5. Frequência
                    CartaoDeCriterio(
                        titulo = stringResource(R.string.por_que_recebo_vagas_secao_frequencia),
                        identificador = "criterios-frequencia",
                    ) {
                        linha { LinhaDeLeitura(stringResource(R.string.por_que_recebo_vagas_frequencia, criterios.notificacoesNoMaximoACadaMin)) }
                    }

                    // Seção de contestação do despacho (ação secundária)
                    SecaoContestar(
                        protocolo = estado.protocolo,
                        contestacaoJaAberta = estado.contestacaoJaAberta,
                        aoContestar = aoContestar,
                    )
                }
            }
        }
    }
}

@Composable
private fun CartaoDeCriterio(
    titulo: String,
    identificador: String,
    modifier: Modifier = Modifier,
    nota: String? = null,
    conteudo: EscopoDoGrupoDeLinhas.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag(identificador),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        FrilaGrupoDeLinhas(titulo = titulo, linhas = conteudo)
        if (nota != null) {
            Text(
                text = nota,
                style = FrilaTipo.apoio,
                color = FrilaTema.cores.tintaSuave,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun LinhaDeLeitura(texto: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = texto,
            style = FrilaTipo.corpo,
            color = FrilaTema.cores.tinta,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun SecaoContestar(
    protocolo: ProtocoloExibido?,
    contestacaoJaAberta: Boolean,
    aoContestar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        RotuloDeGrupo(stringResource(R.string.por_que_recebo_vagas_secao_contestar))
        when {
            protocolo != null -> {
                CartaoFrila(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("status-revisao-enviada"),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                        Text(
                            text = stringResource(R.string.por_que_recebo_vagas_pedido_enviado),
                            style = FrilaTipo.rotuloSecundario,
                            color = cores.tinta,
                        )
                        DadoDoProtocolo(
                            rotulo = stringResource(R.string.por_que_recebo_vagas_protocolo_numero),
                            valor = "#${protocolo.numero}",
                            tag = "protocolo-revisao-despacho",
                        )
                        DadoDoProtocolo(
                            rotulo = stringResource(R.string.por_que_recebo_vagas_protocolo_data),
                            valor = protocolo.enviadoEm,
                        )
                        DadoDoProtocolo(
                            rotulo = stringResource(R.string.por_que_recebo_vagas_prazo_resposta),
                            valor = protocolo.prazoRespostaAte,
                            tag = "prazo-resposta-revisao",
                        )
                        Text(
                            text = stringResource(R.string.por_que_recebo_vagas_mensagem_enviado),
                            style = FrilaTipo.apoio,
                            color = cores.tintaSuave,
                        )
                    }
                }
            }

            contestacaoJaAberta -> {
                CartaoFrila(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("status-revisao-ja-aberta"),
                ) {
                    Text(
                        text = stringResource(R.string.por_que_recebo_vagas_contestacao_ja_aberta),
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                }
            }

            else -> {
                Text(
                    text = stringResource(R.string.por_que_recebo_vagas_contestar_explicacao),
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
                BotaoPrimario(
                    texto = stringResource(R.string.por_que_recebo_vagas_botao_contestar),
                    aoClicar = aoContestar,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("botao-contestar-despacho"),
                )
            }
        }
    }
}

@Composable
private fun DadoDoProtocolo(rotulo: String, valor: String, tag: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
        Text(text = rotulo, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
        Text(
            text = valor,
            style = FrilaTipo.corpo,
            color = FrilaTema.cores.tinta,
            modifier = if (tag != null) Modifier.testTag(tag) else Modifier,
        )
    }
}
