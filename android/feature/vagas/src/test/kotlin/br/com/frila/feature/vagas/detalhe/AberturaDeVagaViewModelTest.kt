package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/** Uma vaga como `detalhe_vaga` a devolve, para os testes de abrir a vaga pelo id. */
internal fun vagaDoServidor(
    estado: String = "publicada",
    posicoesAbertas: Int = 2,
    modo: String = "selecao",
    distanciaKm: Double? = 4.2,
    traje: String? = "Camisa preta",
    observacoes: String? = "Chegar 15 minutos antes",
    participaRateio: Boolean? = null,
) = VagaDto(
    id = "v1",
    estabelecimento = PerfilPublicoDto(id = "e1", tipo = "estabelecimento", nome = "Bar do Zé", reputacao = ReputacaoDto(7, 8, null, 8, 8)),
    funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "salao"),
    inicioEm = "2026-12-01T21:00:00Z",
    fimEm = "2026-12-02T03:00:00Z",
    local = "CLS 405 Bloco C",
    regiaoAdministrativa = "Plano Piloto",
    ponto = CoordenadaDto(-15.81, -47.89),
    distanciaKm = distanciaKm,
    valorCentavos = 16_000,
    posicoes = 3,
    posicoesAbertas = posicoesAbertas,
    inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
    responsavelLocal = "Procure a gerente no balcão",
    traje = traje,
    participaRateio = participaRateio,
    observacoes = observacoes,
    modo = modo,
    estado = estado,
    oculta = false,
    publicadoEm = "2026-11-17T12:00:00Z",
)

class AberturaDeVagaViewModelTest {

    private val pedidos = mutableListOf<String>()

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(buscar: suspend () -> VagaDto) = AberturaDeVagaViewModel(
        vagaId = "v1",
        buscarDetalhe = { id -> pedidos += id; buscar() },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun aoAbrir(buscar: suspend () -> VagaDto): EstadoAberturaDeVaga = viewModel(buscar).apply { carregar() }.estado.value

    @Test
    fun `vaga publicada com posicao aberta abre com o detalhe lido do servidor pelo id`() {
        val vaga = vagaDoServidor()

        assertEquals(EstadoAberturaDeVaga.Aberta(vaga), aoAbrir { vaga })
        assertEquals(listOf("v1"), pedidos)
    }

    @Test
    fun `so ha candidatura com publicada e posicao aberta - o resto e vaga indisponivel, com o motivo que o servidor da`() {
        val preenchida = aoAbrir { vagaDoServidor(estado = "preenchida", posicoesAbertas = 0) }
        val semPosicao = aoAbrir { vagaDoServidor(estado = "publicada", posicoesAbertas = 0, modo = "urgencia") }
        val encerrada = aoAbrir { vagaDoServidor(estado = "encerrada") }
        val cancelada = aoAbrir { vagaDoServidor(estado = "cancelada") }

        assertEquals(EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.PREENCHIDA, ModoPreenchimentoVaga.SELECAO), preenchida)
        assertEquals(EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.ENCERRADA, ModoPreenchimentoVaga.URGENCIA), semPosicao)
        assertEquals(EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.ENCERRADA, ModoPreenchimentoVaga.SELECAO), encerrada)
        assertEquals(
            EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.ENCERRADA, ModoPreenchimentoVaga.SELECAO, vagaCancelada = true),
            cancelada,
        )
    }

    @Test
    fun `404 e vaga nao encontrada, e nao erro`() {
        assertEquals(
            EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.NAO_ENCONTRADA),
            aoAbrir { throw erro(CodigoErroAPI.NAO_ENCONTRADO) },
        )
    }

    @Test
    fun `cada falha vira texto do Frila, e so a passageira oferece tentar de novo`() {
        val casos = listOf(
            erro(CodigoErroAPI.SEM_REDE) to EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.SEM_REDE, podeTentarDeNovo = true),
            erro(CodigoErroAPI.NAO_AUTENTICADO) to EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.SESSAO_EXPIRADA, podeTentarDeNovo = false),
            erro(CodigoErroAPI.PERFIL_INCOMPATIVEL) to EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.CONTA_NAO_PODE, podeTentarDeNovo = false),
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.CONTA_NAO_PODE, podeTentarDeNovo = false),
            erro(CodigoErroAPI.DESCONHECIDO) to EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.ERRO_GENERICO, podeTentarDeNovo = true),
            IllegalStateException("corpo que não é JSON") to EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.ERRO_GENERICO, podeTentarDeNovo = true),
        )
        for ((falha, esperado) in casos) {
            assertEquals(esperado, aoAbrir { throw falha }, falha.toString())
        }
    }

    @Test
    fun `tentar de novo depois da falha le outra vez, e uma leitura em voo nao dispara outra`() {
        var tentativas = 0
        val resposta = CompletableDeferred<VagaDto>()
        val vm = viewModel { if (tentativas++ == 0) throw erro(CodigoErroAPI.SEM_REDE) else resposta.await() }

        vm.carregar()
        vm.carregar()
        assertEquals(EstadoAberturaDeVaga.Carregando, vm.estado.value)
        vm.carregar()
        resposta.complete(vagaDoServidor())

        assertEquals(2, pedidos.size)
        assertEquals(EstadoAberturaDeVaga.Aberta(vagaDoServidor()), vm.estado.value)
    }

    @Test
    fun `a vaga do detalhe vira a vaga da lista com os mesmos campos, e distancia ausente vira zero`() {
        val comDistancia = vagaDoServidor().paraVagaAberta()
        val semDistancia = vagaDoServidor(distanciaKm = null).paraVagaAberta()

        assertEquals("v1", comDistancia.id)
        assertEquals("Garçom", comDistancia.funcao.nome)
        assertEquals("Bar do Zé", comDistancia.estabelecimento.nome)
        assertEquals("2026-12-01T21:00:00Z", comDistancia.inicioEm)
        assertEquals("2026-12-02T03:00:00Z", comDistancia.fimEm)
        assertEquals("CLS 405 Bloco C", comDistancia.local)
        assertEquals("Plano Piloto", comDistancia.regiaoAdministrativa)
        assertEquals(4.2, comDistancia.distanciaKm)
        assertEquals(16_000L, comDistancia.valorCentavos)
        assertEquals(2, comDistancia.posicoesAbertas)
        assertEquals(true, comDistancia.inclusos.incluiRefeicao)
        assertEquals("selecao", comDistancia.modo)
        assertEquals(0.0, semDistancia.distanciaKm)
    }

    // ---- xdvUylw7 (item 271): com a vaga indisponível, a candidatura recusada ou expirada da conta muda o texto ----

    private var leiturasDeCandidaturas = 0

    private fun candidatura(estado: String, vagaId: String = "v1") = br.com.frila.core.rede.CandidaturaDto(
        id = "c-$vagaId-$estado",
        vaga = br.com.frila.core.rede.VagaResumoDto(
            id = vagaId, funcao = "Garçom", local = "CLS 405 Bloco C", regiaoAdministrativa = "Plano Piloto",
            inicioEm = "2026-12-01T21:00:00Z", fimEm = "2026-12-02T03:00:00Z", valorCentavos = 16_000,
        ),
        estado = estado,
        criadaEm = "2026-11-17T12:00:00Z",
    )

    private fun abrirCom(
        vaga: suspend () -> VagaDto,
        candidaturas: suspend () -> List<br.com.frila.core.rede.CandidaturaDto>,
    ): EstadoAberturaDeVaga = AberturaDeVagaViewModel(
        vagaId = "v1",
        buscarDetalhe = { vaga() },
        buscarMinhasCandidaturas = { leiturasDeCandidaturas++; candidaturas() },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    ).apply { carregar() }.estado.value

    private val preenchida: suspend () -> VagaDto = { vagaDoServidor(estado = "preenchida", posicoesAbertas = 0) }

    @Test
    fun `vaga preenchida com a candidatura recusada leva a recusada a tela`() {
        val estado = abrirCom(preenchida) { listOf(candidatura("recusada")) }

        assertEquals(
            EstadoAberturaDeVaga.Indisponivel(
                MotivoIndisponibilidadeVaga.PREENCHIDA, ModoPreenchimentoVaga.SELECAO,
                candidatura = br.com.frila.core.dominio.modelo.EstadoCandidatura.RECUSADA,
            ),
            estado,
        )
    }

    @Test
    fun `vaga encerrada com a candidatura expirada leva a expirada, e a cancelada leva os dois`() {
        val encerrada = abrirCom({ vagaDoServidor(estado = "encerrada") }) { listOf(candidatura("expirada")) }
        val cancelada = abrirCom({ vagaDoServidor(estado = "cancelada") }) { listOf(candidatura("expirada")) }

        assertEquals(
            EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.ENCERRADA, ModoPreenchimentoVaga.SELECAO, candidaturaExpirada = true),
            encerrada,
        )
        assertEquals(
            EstadoAberturaDeVaga.Indisponivel(
                MotivoIndisponibilidadeVaga.ENCERRADA, ModoPreenchimentoVaga.SELECAO, vagaCancelada = true, candidaturaExpirada = true,
            ),
            cancelada,
        )
    }

    @Test
    fun `404 com a candidatura recusada tambem explica a recusa`() {
        val estado = abrirCom({ throw erro(CodigoErroAPI.NAO_ENCONTRADO) }) { listOf(candidatura("recusada")) }

        assertEquals(
            EstadoAberturaDeVaga.Indisponivel(
                MotivoIndisponibilidadeVaga.NAO_ENCONTRADA, candidatura = br.com.frila.core.dominio.modelo.EstadoCandidatura.RECUSADA,
            ),
            estado,
        )
    }

    @Test
    fun `so a candidatura desta vaga conta, e so a recusada ou a expirada mudam o texto`() {
        val semEfeito = EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.PREENCHIDA, ModoPreenchimentoVaga.SELECAO)

        assertEquals(semEfeito, abrirCom(preenchida) { listOf(candidatura("recusada", vagaId = "outra-vaga")) }, "candidatura de outra vaga")
        for (estado in listOf("pendente", "aceita", "retirada", "estado_novo")) {
            assertEquals(semEfeito, abrirCom(preenchida) { listOf(candidatura(estado)) }, estado)
        }
        assertEquals(semEfeito, abrirCom(preenchida) { emptyList() }, "sem candidatura")
    }

    @Test
    fun `se a leitura das candidaturas falhar, fica o texto da vaga`() {
        val estado = abrirCom(preenchida) { throw erro(CodigoErroAPI.SEM_REDE) }

        assertEquals(EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.PREENCHIDA, ModoPreenchimentoVaga.SELECAO), estado)
    }

    @Test
    fun `vaga aberta e falha da vaga nao leem as candidaturas`() {
        abrirCom({ vagaDoServidor() }) { error("não deveria ler") }
        abrirCom({ throw erro(CodigoErroAPI.SEM_REDE) }) { error("não deveria ler") }

        assertEquals(0, leiturasDeCandidaturas)
    }

    @Test
    fun `enquanto as candidaturas nao chegam a tela segue carregando, sem mostrar o texto da vaga antes`() {
        val resposta = CompletableDeferred<List<br.com.frila.core.rede.CandidaturaDto>>()
        val vm = AberturaDeVagaViewModel(
            vagaId = "v1",
            buscarDetalhe = { preenchida() },
            buscarMinhasCandidaturas = { resposta.await() },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar()

        assertEquals(EstadoAberturaDeVaga.Carregando, vm.estado.value)

        resposta.complete(listOf(candidatura("recusada")))
        assertEquals(br.com.frila.core.dominio.modelo.EstadoCandidatura.RECUSADA, (vm.estado.value as EstadoAberturaDeVaga.Indisponivel).candidatura)
    }
}
