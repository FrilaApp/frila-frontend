package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.AlteracaoDoPerfilProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.DadosDoPerfilProfissionalDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.PerfilProfissionalDto
import br.com.frila.core.rede.ReputacaoDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Ponto base (tela provisória): a região é escolhida numa lista do app e gravada como o iOS grava (criar ou atualizar o perfil). */
class PontoBaseViewModelTest {

    private val planoPiloto = OpcaoDePontoBase("Plano Piloto", Coordenada(-15.793889, -47.882778))
    private val taguatinga = OpcaoDePontoBase("Taguatinga", Coordenada(-15.833333, -48.056944))
    private val garcom = FuncaoDto(id = "f-garcom", nome = "garçom", categoria = "Salão")
    private val cozinheiro = FuncaoDto(id = "f-cozinheiro", nome = "cozinheiro", categoria = "Cozinha")

    private fun perfil(pontoBase: CoordenadaDto?) = PerfilProfissionalDto(
        id = "perfil-1",
        usuarioId = "usuario-1",
        funcoes = listOf(garcom),
        pontoBase = pontoBase,
        reputacao = ReputacaoDto(positivas = 0, total = 0, turnosConsiderados = 0, turnosRealizados = 0),
    )

    private fun erro(codigo: CodigoErroAPI) = ErroDaApi(codigo, codigo.name.lowercase(), null, "teste")

    /** Servidor de mentira: guarda o que foi pedido e responde o que o teste mandar. */
    private inner class Servidor(
        var perfilSalvo: PerfilProfissionalDto? = perfil(pontoBase = null),
        var falhaAoCarregar: ErroDaApi? = null,
        var falhaAoCriar: ErroDaApi? = null,
        var falhaAoAtualizar: ErroDaApi? = null,
    ) {
        val criacoes = mutableListOf<DadosDoPerfilProfissionalDto>()
        val alteracoes = mutableListOf<AlteracaoDoPerfilProfissionalDto>()
        var pedidosDeFuncoes = 0

        fun viewModel() = PontoBaseViewModel(
            opcoes = listOf(planoPiloto, taguatinga),
            carregarPerfil = { falhaAoCarregar?.let { throw it }; perfilSalvo ?: throw erro(CodigoErroAPI.NAO_ENCONTRADO) },
            carregarFuncoes = { pedidosDeFuncoes++; listOf(garcom, cozinheiro) },
            criarPerfil = { dados -> criacoes += dados; falhaAoCriar?.let { throw it }; perfil(dados.pontoBase) },
            atualizarPerfil = { alteracao -> alteracoes += alteracao; falhaAoAtualizar?.let { throw it }; perfil(alteracao.pontoBase) },
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `com perfil sem ponto base mostra as regioes e nenhuma escolhida`() = runBlocking {
        val servidor = Servidor()
        val viewModel = servidor.viewModel()

        viewModel.carregar().join()

        val estado = viewModel.estado.value
        assertFalse(estado.carregando)
        assertEquals(listOf(planoPiloto, taguatinga), estado.opcoes)
        assertNull(estado.escolhida)
        assertFalse(estado.temPontoBaseSalvo)
        assertFalse(estado.semPerfil)
        assertEquals(0, servidor.pedidosDeFuncoes)
    }

    @Test
    fun `ponto base ja salvo que e o centro de uma regiao vem escolhido`() = runBlocking {
        val servidor = Servidor(perfilSalvo = perfil(CoordenadaDto(-15.833333, -48.056944)))
        val viewModel = servidor.viewModel()

        viewModel.carregar().join()

        assertEquals(taguatinga, viewModel.estado.value.escolhida)
        assertTrue(viewModel.estado.value.temPontoBaseSalvo)
    }

    @Test
    fun `ponto base salvo fora da lista fica sem regiao escolhida mas avisa que ha um salvo`() = runBlocking {
        val servidor = Servidor(perfilSalvo = perfil(CoordenadaDto(-15.8280, -47.9780)))
        val viewModel = servidor.viewModel()

        viewModel.carregar().join()

        assertNull(viewModel.estado.value.escolhida)
        assertTrue(viewModel.estado.value.temPontoBaseSalvo)
    }

    @Test
    fun `salvar sem escolher regiao nao chama o servidor e pede o ponto base`() = runBlocking {
        val servidor = Servidor()
        val viewModel = servidor.viewModel()
        viewModel.carregar().join()

        viewModel.salvar().join()

        assertEquals(TextosPontoBase.ERRO_SEM_PONTO_BASE, viewModel.estado.value.erro)
        assertTrue(servidor.alteracoes.isEmpty() && servidor.criacoes.isEmpty())
        assertFalse(viewModel.estado.value.salvo)
    }

    @Test
    fun `com perfil, salvar manda so o ponto base em atualizar_perfil_profissional`() = runBlocking {
        val servidor = Servidor()
        val viewModel = servidor.viewModel()
        viewModel.carregar().join()
        viewModel.escolher(taguatinga)

        viewModel.salvar().join()

        assertEquals(
            listOf(AlteracaoDoPerfilProfissionalDto(pontoBase = CoordenadaDto(-15.833333, -48.056944))),
            servidor.alteracoes,
        )
        assertTrue(servidor.criacoes.isEmpty())
        assertTrue(viewModel.estado.value.salvo)
        assertNull(viewModel.estado.value.erro)
    }

    @Test
    fun `sem perfil a tela pede as funcoes e nao salva sem ao menos uma`() = runBlocking {
        val servidor = Servidor(perfilSalvo = null)
        val viewModel = servidor.viewModel()

        viewModel.carregar().join()
        viewModel.escolher(planoPiloto)
        viewModel.salvar().join()

        val estado = viewModel.estado.value
        assertTrue(estado.semPerfil)
        assertEquals(listOf(garcom, cozinheiro), estado.funcoes)
        assertEquals(TextosPontoBase.ERRO_SEM_FUNCAO, estado.erro)
        assertTrue(servidor.criacoes.isEmpty() && servidor.alteracoes.isEmpty())
    }

    @Test
    fun `sem perfil, salvar cria o perfil com as funcoes, o ponto base e a grade vazia`() = runBlocking {
        val servidor = Servidor(perfilSalvo = null)
        val viewModel = servidor.viewModel()
        viewModel.carregar().join()
        viewModel.escolher(planoPiloto)
        viewModel.alternarFuncao(garcom.id)
        viewModel.alternarFuncao(cozinheiro.id)
        viewModel.alternarFuncao(cozinheiro.id)

        viewModel.salvar().join()

        assertEquals(
            listOf(
                DadosDoPerfilProfissionalDto(
                    funcoes = listOf(garcom.id),
                    pontoBase = CoordenadaDto(-15.793889, -47.882778),
                    disponibilidades = emptyList(),
                ),
            ),
            servidor.criacoes,
        )
        assertTrue(servidor.alteracoes.isEmpty())
        assertTrue(viewModel.estado.value.salvo)
    }

    @Test
    fun `criar que responde perfil_ja_existe grava o ponto base pelo atualizar`() = runBlocking {
        val servidor = Servidor(perfilSalvo = null, falhaAoCriar = erro(CodigoErroAPI.PERFIL_JA_EXISTE))
        val viewModel = servidor.viewModel()
        viewModel.carregar().join()
        viewModel.escolher(taguatinga)
        viewModel.alternarFuncao(garcom.id)

        viewModel.salvar().join()

        assertEquals(
            listOf(AlteracaoDoPerfilProfissionalDto(pontoBase = CoordenadaDto(-15.833333, -48.056944))),
            servidor.alteracoes,
        )
        assertTrue(viewModel.estado.value.salvo)
    }

    @Test
    fun `atualizar que responde nao_encontrado passa a pedir as funcoes para criar o perfil`() = runBlocking {
        val servidor = Servidor(falhaAoAtualizar = erro(CodigoErroAPI.NAO_ENCONTRADO))
        val viewModel = servidor.viewModel()
        viewModel.carregar().join()
        viewModel.escolher(taguatinga)

        viewModel.salvar().join()

        val estado = viewModel.estado.value
        assertTrue(estado.semPerfil)
        assertEquals(listOf(garcom, cozinheiro), estado.funcoes)
        assertEquals(TextosPontoBase.ERRO_SEM_FUNCAO, estado.erro)
        assertFalse(estado.salvo)
        assertEquals(taguatinga, estado.escolhida)
    }

    @Test
    fun `falha ao carregar o perfil mostra o erro e nao trava a tela em carregando`() = runBlocking {
        val servidor = Servidor(falhaAoCarregar = erro(CodigoErroAPI.SEM_REDE))
        val viewModel = servidor.viewModel()

        viewModel.carregar().join()

        assertFalse(viewModel.estado.value.carregando)
        assertEquals(TextosPontoBase.ERRO_SEM_REDE, viewModel.estado.value.erro)
    }

    @Test
    fun `falha ao salvar mostra o erro, sai de salvando e deixa tentar de novo`() = runBlocking {
        val servidor = Servidor(falhaAoAtualizar = erro(CodigoErroAPI.SEM_REDE))
        val viewModel = servidor.viewModel()
        viewModel.carregar().join()
        viewModel.escolher(planoPiloto)

        viewModel.salvar().join()
        assertEquals(TextosPontoBase.ERRO_SEM_REDE, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.salvando)
        assertFalse(viewModel.estado.value.salvo)

        servidor.falhaAoAtualizar = null
        viewModel.salvar().join()
        assertTrue(viewModel.estado.value.salvo)
        assertNull(viewModel.estado.value.erro)
    }

    @Test
    fun `resposta que nao e erro da API ao salvar vira mensagem e nao sobe crua`() = runBlocking {
        val viewModel = PontoBaseViewModel(
            opcoes = listOf(planoPiloto),
            carregarPerfil = { perfil(pontoBase = null) },
            carregarFuncoes = { emptyList() },
            criarPerfil = { error("não deve criar") },
            atualizarPerfil = { throw IllegalStateException("resposta ilegível") },
            escopo = CoroutineScope(Dispatchers.Default),
        )
        viewModel.carregar().join()
        viewModel.escolher(planoPiloto)

        viewModel.salvar().join()

        assertEquals(TextosPontoBase.ERRO_SALVAR, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.salvando)
        assertFalse(viewModel.estado.value.salvo)
    }
}
