package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CriteriosDeNotificacaoDto
import br.com.frila.core.rede.EquipeDeConfiancaCriterioDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import br.com.frila.core.rede.ProtocoloDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes unitários do [PorQueReceboVagasViewModel] (Item #34 da Paridade, Lote C).
 * Cobre todos os estados: carregando, conteúdo, vazio, semRede, erro e contestação já aberta.
 */
class PorQueReceboVagasViewModelTest {

    private val garcom = FuncaoDto(id = "f-garcom", nome = "Garçom", categoria = "Salão")
    private val cozinheiro = FuncaoDto(id = "f-cozinheiro", nome = "Cozinheiro", categoria = "Cozinha")
    private val janelaSegunda = JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00")
    private val janelaSextaNoturna = JanelaDeDisponibilidadeDto(diaSemana = 5, inicio = "18:00", fim = "02:00")
    private val equipeBar = EquipeDeConfiancaCriterioDto(estabelecimentoId = "est-1", nome = "Bar do Zé")

    private fun criteriosExemplo(
        funcoes: List<FuncaoDto> = listOf(garcom, cozinheiro),
        janelas: List<JanelaDeDisponibilidadeDto> = listOf(janelaSegunda),
        distancia: Double = 15.0,
        equipes: List<EquipeDeConfiancaCriterioDto> = listOf(equipeBar),
        frequencia: Int = 30,
        contestacao: ProtocoloDto? = null,
    ) = CriteriosDeNotificacaoDto(
        funcoes = funcoes,
        disponibilidades = janelas,
        distanciaMaximaKm = distancia,
        equipesDeConfianca = equipes,
        notificacoesNoMaximoACadaMin = frequencia,
        contestacao = contestacao,
    )

    private fun erroApi(codigo: CodigoErroAPI, msg: String = "Erro") =
        ErroDaApi(codigo = codigo, codigoOriginal = codigo.name.lowercase(), detalhes = msg, mensagemCrua = msg)

    @Test
    fun `estado inicial eh carregando`() {
        val vm = PorQueReceboVagasViewModel(carregarCriterios = { criteriosExemplo() }, escopo = CoroutineScope(Dispatchers.Default))
        assertEquals(EstadoPorQueReceboVagas.Carregando, vm.estado.value)
    }

    @Test
    fun `carrega com sucesso e vai para estado conteudo`() = runBlocking {
        val vm = PorQueReceboVagasViewModel(carregarCriterios = { criteriosExemplo() }, escopo = this)
        vm.carregar().join()

        val estado = vm.estado.value
        assertTrue(estado is EstadoPorQueReceboVagas.Conteudo)
        val conteudo = estado as EstadoPorQueReceboVagas.Conteudo
        assertEquals(2, conteudo.criterios.funcoes.size)
        assertEquals(1, conteudo.criterios.disponibilidades.size)
        assertEquals(15.0, conteudo.criterios.distanciaMaximaKm, 0.001)
        assertEquals(1, conteudo.criterios.equipesDeConfianca.size)
        assertFalse(conteudo.contestacaoJaAberta)
        assertNull(conteudo.protocolo)
    }

    @Test
    fun `criterios vazios vai para estado vazio`() = runBlocking {
        val vm = PorQueReceboVagasViewModel(
            carregarCriterios = {
                CriteriosDeNotificacaoDto(
                    funcoes = emptyList(),
                    disponibilidades = emptyList(),
                    equipesDeConfianca = emptyList(),
                )
            },
            escopo = this,
        )
        vm.carregar().join()
        assertEquals(EstadoPorQueReceboVagas.Vazio, vm.estado.value)
    }

    @Test
    fun `erro 404 nao encontrado vai para estado vazio`() = runBlocking {
        val vm = PorQueReceboVagasViewModel(
            carregarCriterios = { throw erroApi(CodigoErroAPI.NAO_ENCONTRADO, "Sem perfil") },
            escopo = this,
        )
        vm.carregar().join()
        assertEquals(EstadoPorQueReceboVagas.Vazio, vm.estado.value)
    }

    @Test
    fun `erro sem rede vai para estado semRede`() = runBlocking {
        val vm = PorQueReceboVagasViewModel(
            carregarCriterios = { throw erroApi(CodigoErroAPI.SEM_REDE, "Offline") },
            escopo = this,
        )
        vm.carregar().join()
        assertEquals(EstadoPorQueReceboVagas.SemRede, vm.estado.value)
    }

    @Test
    fun `erro inesperado vai para estado erro`() = runBlocking {
        val vm = PorQueReceboVagasViewModel(
            carregarCriterios = { throw erroApi(CodigoErroAPI.SEM_PERMISSAO, "Falha interna") },
            escopo = this,
        )
        vm.carregar().join()
        assertTrue(vm.estado.value is EstadoPorQueReceboVagas.Erro)
        val erro = vm.estado.value as EstadoPorQueReceboVagas.Erro
        assertEquals("Falha interna", erro.mensagem)
    }

    @Test
    fun `contestacao ja aberta preenche protocolo e sinaliza contestacaoJaAberta`() = runBlocking {
        val protocoloDto = ProtocoloDto(
            ocorrenciaId = "12345678-abcd-ef01-2345-6789abcdef01",
            tipo = "revisao_despacho",
            criadaEm = "2026-11-20T10:00:00Z",
            prazoRespostaAte = "2026-11-27T18:00:00Z",
        )
        val vm = PorQueReceboVagasViewModel(
            carregarCriterios = { criteriosExemplo(contestacao = protocoloDto) },
            escopo = this,
        )
        vm.carregar().join()

        val estado = vm.estado.value
        assertTrue(estado is EstadoPorQueReceboVagas.Conteudo)
        val conteudo = estado as EstadoPorQueReceboVagas.Conteudo
        assertTrue(conteudo.contestacaoJaAberta)
        assertNotNull(conteudo.protocolo)
        assertEquals("12345678", conteudo.protocolo?.numero)
        assertEquals("20/11/2026", conteudo.protocolo?.enviadoEm)
        assertEquals("27/11/2026", conteudo.protocolo?.prazoRespostaAte)
    }

    @Test
    fun `formatador de janela de disponibilidade formata diurna e noturna`() {
        val descDiurna = PorQueReceboVagasViewModel.descricaoJanela(janelaSegunda)
        assertEquals("Segunda-feira: 08:00 às 16:00", descDiurna)

        val descNoturna = PorQueReceboVagasViewModel.descricaoJanela(janelaSextaNoturna)
        assertEquals("Sexta-feira: 18:00 às 02:00 (até o dia seguinte)", descNoturna)
    }

    @Test
    fun `formatador de distancia formata inteiro e decimal`() {
        assertEquals("15", PorQueReceboVagasViewModel.descricaoDistancia(15.0))
        assertEquals("12,5", PorQueReceboVagasViewModel.descricaoDistancia(12.5))
    }
}
