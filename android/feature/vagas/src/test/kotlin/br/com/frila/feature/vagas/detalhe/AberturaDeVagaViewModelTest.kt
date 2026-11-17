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
}
