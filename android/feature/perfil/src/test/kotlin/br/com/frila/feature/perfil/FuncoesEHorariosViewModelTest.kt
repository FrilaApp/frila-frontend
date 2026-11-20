package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.AlteracaoDoPerfilProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.DadosDoPerfilProfissionalDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import br.com.frila.core.rede.PerfilProfissionalDto
import br.com.frila.core.rede.ReputacaoDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes unitários do [FuncoesEHorariosViewModel] (Item #17 da Paridade, Lote B).
 * Cobre: estado inicial, sucesso, erro e validação de início < fim.
 */
class FuncoesEHorariosViewModelTest {

    private val garcom = FuncaoDto(id = "f-garcom", nome = "Garçom", categoria = "Salão")
    private val cozinheiro = FuncaoDto(id = "f-cozinheiro", nome = "Cozinheiro", categoria = "Cozinha")
    private val bartender = FuncaoDto(id = "f-bartender", nome = "Bartender", categoria = "Bar")

    private val janelaSegunda = JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00")

    private fun perfilExemplo(funcoes: List<FuncaoDto> = listOf(garcom), janelas: List<JanelaDeDisponibilidadeDto> = listOf(janelaSegunda)) =
        PerfilProfissionalDto(
            id = "perfil-teste",
            usuarioId = "usuario-teste",
            funcoes = funcoes,
            pontoBase = CoordenadaDto(-15.793889, -47.882778),
            disponibilidades = janelas,
            reputacao = ReputacaoDto(positivas = 10, total = 10, turnosConsiderados = 10, turnosRealizados = 10),
        )

    private fun erroApi(codigo: CodigoErroAPI, msg: String = "Erro") =
        ErroDaApi(codigo = codigo, codigoOriginal = codigo.name.lowercase(), detalhes = msg, mensagemCrua = msg)

    private inner class ServidorFalso(
        var perfilSalvo: PerfilProfissionalDto? = perfilExemplo(),
        var falhaCarregarPerfil: ErroDaApi? = null,
        var falhaCarregarFuncoes: ErroDaApi? = null,
        var falhaCriar: ErroDaApi? = null,
        var falhaAtualizar: ErroDaApi? = null,
    ) {
        val criacoes = mutableListOf<DadosDoPerfilProfissionalDto>()
        val atualizacoes = mutableListOf<AlteracaoDoPerfilProfissionalDto>()

        fun viewModel() = FuncoesEHorariosViewModel(
            carregarPerfil = {
                falhaCarregarPerfil?.let { throw it }
                perfilSalvo ?: throw erroApi(CodigoErroAPI.NAO_ENCONTRADO, "Perfil não encontrado")
            },
            carregarFuncoes = {
                falhaCarregarFuncoes?.let { throw it }
                listOf(garcom, cozinheiro, bartender)
            },
            criarPerfil = { dados ->
                criacoes += dados
                falhaCriar?.let { throw it }
                perfilExemplo(funcoes = dados.funcoes.map { FuncaoDto(it, it, "Geral") }, janelas = dados.disponibilidades)
            },
            atualizarPerfil = { alt ->
                atualizacoes += alt
                falhaAtualizar?.let { throw it }
                perfilExemplo(
                    funcoes = alt.funcoes?.map { FuncaoDto(it, it, "Geral") } ?: emptyList(),
                    janelas = alt.disponibilidades ?: emptyList(),
                )
            },
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `estado inicial antes e apos carregar perfil com dados`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()

        // Antes de carregar
        val estadoInicial = vm.estado.value
        assertFalse(estadoInicial.carregando)
        assertFalse(estadoInicial.salvo)
        assertNull(estadoInicial.erro)
        assertTrue(estadoInicial.funcoesDisponiveis.isEmpty())
        assertTrue(estadoInicial.funcoesSelecionadas.isEmpty())

        // Ao carregar
        vm.carregar().join()
        val estadoCarregado = vm.estado.value
        assertFalse(estadoCarregado.carregando)
        assertFalse(estadoCarregado.semPerfil)
        assertEquals(3, estadoCarregado.funcoesDisponiveis.size)
        assertEquals(setOf("f-garcom"), estadoCarregado.funcoesSelecionadas)
        assertEquals(1, estadoCarregado.disponibilidades.size)
        assertEquals(janelaSegunda, estadoCarregado.disponibilidades.first())
    }

    @Test
    fun `carregar quando perfil nao existe (404) marca semPerfil e exibe aviso de ponto base`() = runBlocking {
        val servidor = ServidorFalso(perfilSalvo = null)
        val vm = servidor.viewModel()

        vm.carregar().join()
        val estado = vm.estado.value
        assertFalse(estado.carregando)
        assertTrue(estado.semPerfil)
        assertTrue(estado.precisaDefinirPontoBase)
        assertEquals(TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE, estado.erro)
        assertEquals(3, estado.funcoesDisponiveis.size)
        assertTrue(estado.funcoesSelecionadas.isEmpty())
        assertTrue(estado.disponibilidades.isEmpty())
    }

    @Test
    fun `validacao aceita janelas noturnas que cruzam a meia-noite como 18h ate 02h`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        // 18:00 até 02:00 cruza a meia-noite e deve ser aceito conforme contrato OpenAPI
        val aceitou = vm.adicionarJanela(diaSemana = 6, inicio = "18:00", fim = "02:00")
        assertTrue(aceitou)
        assertNull(vm.estado.value.erroValidacaoHorario)
        assertTrue(vm.estado.value.disponibilidades.any { it.diaSemana == 6 && it.inicio == "18:00" && it.fim == "02:00" })
    }

    @Test
    fun `validacao recusa horarios iguais como 09h ate 09h`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        val resultadoIgual = vm.adicionarJanela(diaSemana = 1, inicio = "09:00", fim = "09:00")
        assertFalse(resultadoIgual)
        assertEquals(TextosFuncoesEHorarios.ERRO_HORARIOS_IGUAIS, vm.estado.value.erroValidacaoHorario)
    }

    @Test
    fun `validacao recusa dia da semana fora de 0 a 6`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        assertFalse(vm.adicionarJanela(diaSemana = -1, inicio = "08:00", fim = "16:00"))
        assertEquals(TextosFuncoesEHorarios.ERRO_DIA_INVALIDO, vm.estado.value.erroValidacaoHorario)

        assertFalse(vm.adicionarJanela(diaSemana = 7, inicio = "08:00", fim = "16:00"))
        assertEquals(TextosFuncoesEHorarios.ERRO_DIA_INVALIDO, vm.estado.value.erroValidacaoHorario)
    }

    @Test
    fun `adicionar janela duplicada identica e recusada`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        // Já existe janelaSegunda (dia 1, 08:00 até 16:00)
        val duplicada = vm.adicionarJanela(diaSemana = 1, inicio = "08:00", fim = "16:00")
        assertFalse(duplicada)
        assertEquals(TextosFuncoesEHorarios.ERRO_JANELA_DUPLICADA, vm.estado.value.erroValidacaoHorario)
    }

    @Test
    fun `adicionar janelas mantem lista ordenada por dia e inicio`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        // Remove a janela inicial
        vm.removerJanela(janelaSegunda)

        // Adiciona fora de ordem
        vm.adicionarJanela(diaSemana = 5, inicio = "18:00", fim = "02:00")
        vm.adicionarJanela(diaSemana = 0, inicio = "12:00", fim = "16:00")
        vm.adicionarJanela(diaSemana = 5, inicio = "08:00", fim = "12:00")
        vm.adicionarJanela(diaSemana = 2, inicio = "10:00", fim = "18:00")

        val ordenadas = vm.estado.value.disponibilidades
        assertEquals(4, ordenadas.size)
        assertEquals(0, ordenadas[0].diaSemana)
        assertEquals("12:00", ordenadas[0].inicio)

        assertEquals(2, ordenadas[1].diaSemana)
        assertEquals("10:00", ordenadas[1].inicio)

        assertEquals(5, ordenadas[2].diaSemana)
        assertEquals("08:00", ordenadas[2].inicio)

        assertEquals(5, ordenadas[3].diaSemana)
        assertEquals("18:00", ordenadas[3].inicio)
    }

    @Test
    fun `validacao de formato recusa entradas invalidas`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()

        val resultadoInvalido = vm.adicionarJanela(diaSemana = 1, inicio = "abc", fim = "16:00")
        assertFalse(resultadoInvalido)
        assertEquals("Informe horários válidos no formato HH:mm.", vm.estado.value.erroValidacaoHorario)
    }

    @Test
    fun `adicionar janela valida inclui nova faixa e limpa erro`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        val adicionou = vm.adicionarJanela(diaSemana = 2, inicio = "09:00", fim = "18:00")
        assertTrue(adicionou)
        assertNull(vm.estado.value.erroValidacaoHorario)
        assertEquals(2, vm.estado.value.disponibilidades.size)
        assertTrue(vm.estado.value.disponibilidades.any { it.diaSemana == 2 && it.inicio == "09:00" && it.fim == "18:00" })
    }

    @Test
    fun `remover janela remove da lista de disponibilidades`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        assertEquals(1, vm.estado.value.disponibilidades.size)
        vm.removerJanela(janelaSegunda)
        assertTrue(vm.estado.value.disponibilidades.isEmpty())
    }

    @Test
    fun `alternar funcao adiciona e remove do conjunto`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        // Já tinha f-garcom
        assertTrue("f-garcom" in vm.estado.value.funcoesSelecionadas)

        // Adiciona f-cozinheiro
        vm.alternarFuncao("f-cozinheiro")
        assertTrue("f-cozinheiro" in vm.estado.value.funcoesSelecionadas)
        assertEquals(2, vm.estado.value.funcoesSelecionadas.size)

        // Remove f-garcom
        vm.alternarFuncao("f-garcom")
        assertFalse("f-garcom" in vm.estado.value.funcoesSelecionadas)
        assertEquals(setOf("f-cozinheiro"), vm.estado.value.funcoesSelecionadas)
    }

    @Test
    fun `salvar sem funcoes selecionadas bloqueia e exibe erro`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        // Remove garçom ficando sem nenhuma função
        vm.alternarFuncao("f-garcom")
        assertTrue(vm.estado.value.funcoesSelecionadas.isEmpty())

        vm.salvar().join()
        assertEquals("Escolha ao menos uma função.", vm.estado.value.erro)
        assertFalse(vm.estado.value.salvo)
        assertTrue(servidor.atualizacoes.isEmpty())
    }

    @Test
    fun `salvar com sucesso atualiza perfil existente`() = runBlocking {
        val servidor = ServidorFalso()
        val vm = servidor.viewModel()
        vm.carregar().join()

        vm.alternarFuncao("f-bartender")
        vm.salvar().join()

        assertTrue(vm.estado.value.salvo)
        assertNull(vm.estado.value.erro)
        assertEquals(1, servidor.atualizacoes.size)
        val alt = servidor.atualizacoes.first()
        assertEquals(listOf("f-garcom", "f-bartender"), alt.funcoes)
        assertEquals(listOf(janelaSegunda), alt.disponibilidades)
    }

    @Test
    fun `salvar quando semPerfil e sem ponto base nao cria perfil e exibe erro`() = runBlocking {
        val servidor = ServidorFalso(perfilSalvo = null)
        val vm = servidor.viewModel()
        vm.carregar().join()

        vm.alternarFuncao("f-cozinheiro")
        vm.adicionarJanela(diaSemana = 5, inicio = "18:00", fim = "23:00")
        vm.salvar().join()

        assertFalse(vm.estado.value.salvo)
        assertEquals(TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE, vm.estado.value.erro)
        assertTrue(servidor.criacoes.isEmpty())
        assertTrue(servidor.atualizacoes.isEmpty())
    }

    @Test
    fun `erro da API ao carregar funcoes exibe mensagem de erro no estado`() = runBlocking {
        val servidor = ServidorFalso(falhaCarregarFuncoes = erroApi(CodigoErroAPI.SEM_REDE, "Sem conexão"))
        val vm = servidor.viewModel()

        vm.carregar().join()
        assertFalse(vm.estado.value.carregando)
        assertEquals("Sem conexão", vm.estado.value.erro)
    }

    @Test
    fun `erro da API ao salvar exibe mensagem de erro no estado`() = runBlocking {
        val servidor = ServidorFalso(falhaAtualizar = erroApi(CodigoErroAPI.SEM_PERMISSAO, "Não autorizado"))
        val vm = servidor.viewModel()
        vm.carregar().join()

        vm.salvar().join()
        assertFalse(vm.estado.value.salvo)
        assertEquals("Não autorizado", vm.estado.value.erro)
    }
}
