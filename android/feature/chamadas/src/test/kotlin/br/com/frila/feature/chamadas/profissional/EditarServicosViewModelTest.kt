package br.com.frila.feature.chamadas.profissional

import br.com.frila.core.rede.EspecialidadeDto
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class EditarServicosViewModelTest {

    private fun especialidades(funcaoId: String) = listOf(
        EspecialidadeDto(id = Fixtures.ESPECIALIDADE, funcaoId = funcaoId, nome = "Eventos", ativo = true),
        EspecialidadeDto(id = "99999999-9999-9999-9999-999999999999", funcaoId = funcaoId, nome = "Casamentos", ativo = true),
        EspecialidadeDto(id = "aaaaaaaa-0000-0000-0000-000000000000", funcaoId = funcaoId, nome = "Antiga", ativo = false),
        EspecialidadeDto(id = "bbbbbbbb-0000-0000-0000-000000000000", funcaoId = "outra-funcao", nome = "De outra função", ativo = true),
    )

    private fun viewModelCom(rede: RedeDeTeste, consultadas: MutableList<String> = mutableListOf()) = EditarServicosViewModel(
        carregarPerfil = rede.servico::meuPerfilDetalhado,
        listarEspecialidades = { consultadas += it; especialidades(it) },
        definir = rede.servico::definirServicos,
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun rede(funcoes: List<String> = listOf(Fixtures.funcaoJson), servicos: List<String> = emptyList()) = RedeDeTeste().apply {
        ok("/rpc/meu_perfil_detalhado", Fixtures.perfilDetalhadoJson(funcoes = funcoes, servicos = servicos))
        ok("/rpc/definir_servicos", Fixtures.perfilDetalhadoJson(funcoes = funcoes, servicos = servicos))
    }

    private fun RedeDeTeste.servicosEnviados(): JsonArray = doCaminho("/rpc/definir_servicos").last().corpo!!["servicos"]!!.jsonArray

    @Test
    fun `carregar monta uma linha por funcao, preenche o servico existente e so lista especialidades ativas da funcao`() = runBlocking {
        val consultadas = mutableListOf<String>()
        val rede = rede(
            funcoes = listOf(Fixtures.funcaoJson, Fixtures.barmanJson),
            servicos = listOf(Fixtures.servicoDiariaJson),
        )
        val vm = viewModelCom(rede, consultadas)
        assertTrue(vm.estado.value.carregando)

        vm.carregar().join()

        val tela = vm.estado.value
        assertFalse(tela.carregando)
        assertTrue(tela.carregou)
        assertEquals(listOf(Fixtures.FUNCAO, Fixtures.FUNCAO_BARMAN), consultadas)
        assertEquals(listOf("Garçom", "Barman"), tela.rascunhos.map { it.funcao.nome })
        val garcom = tela.rascunhos[0]
        assertTrue(garcom.habilitado)
        assertEquals("diaria", garcom.unidade)
        assertEquals("150,00", garcom.valor)
        assertEquals("8", garcom.horasIncluidas)
        assertEquals("nao", garcom.levaMaterial)
        assertEquals("Avental", garcom.inclui)
        assertEquals(setOf(Fixtures.ESPECIALIDADE), garcom.especialidadeIds)
        assertFalse(tela.rascunhos[1].habilitado)
        assertEquals(listOf("Eventos", "Casamentos"), tela.especialidades.getValue(Fixtures.FUNCAO).map { it.nome })
    }

    @Test
    fun `salvar substitui o conjunto com so as funcoes habilitadas e os campos da unidade`() = runBlocking {
        val rede = rede(funcoes = listOf(Fixtures.funcaoJson, Fixtures.barmanJson))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = true).comUnidade("diaria").copy(valor = "150,5", valorMaximo = "200", levaMaterial = "depende", inclui = "  Avental  ") }
        vm.alternarEspecialidade(Fixtures.FUNCAO, Fixtures.ESPECIALIDADE, true)
        vm.salvar().join()

        val enviados = rede.servicosEnviados()
        assertEquals(1, enviados.size)
        val servico = enviados[0].jsonObject
        assertEquals(Fixtures.FUNCAO, servico["funcao_id"]!!.jsonPrimitive.content)
        assertEquals("diaria", servico["unidade"]!!.jsonPrimitive.content)
        assertEquals(15050L, servico["valor_centavos"]!!.jsonPrimitive.content.toLong())
        assertEquals(20000L, servico["valor_max_centavos"]!!.jsonPrimitive.content.toLong())
        assertEquals(8, servico["horas_incluidas"]!!.jsonPrimitive.content.toInt())
        assertEquals("depende", servico["leva_material"]!!.jsonPrimitive.content)
        assertEquals("Avental", servico["inclui"]!!.jsonPrimitive.content)
        assertEquals(listOf(Fixtures.ESPECIALIDADE), servico["especialidade_ids"]!!.jsonArray.map { it.jsonPrimitive.content })
        // Campo que a unidade não pede nem vai no corpo.
        assertFalse(servico.containsKey("minimo_horas"))
        assertFalse(servico.containsKey("descricao_pacote"))
        assertTrue(vm.estado.value.sucesso)
        assertFalse(vm.estado.value.salvando)
    }

    @Test
    fun `a combinar vai sem valor e desmarcar tudo manda lista vazia, que limpa`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = true) }
        vm.salvar().join()
        val aCombinar = rede.servicosEnviados()[0].jsonObject
        assertEquals("a_combinar", aCombinar["unidade"]!!.jsonPrimitive.content)
        assertFalse(aCombinar.containsKey("valor_centavos"))

        vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = false) }
        vm.salvar().join()
        assertEquals(0, rede.servicosEnviados().size)
    }

    @Test
    fun `valor fora de 10 a 10 mil e valor maximo menor que o valor nao saem do aparelho`() = runBlocking {
        val casos = listOf(
            Triple("5", "", "valor_centavos"),
            Triple("10000,01", "", "valor_centavos"),
            Triple("abc", "", "valor_centavos"),
            Triple("", "", "valor_centavos"),
            Triple("100", "50", "valor_max_centavos"),
            Triple("100", "x", "valor_max_centavos"),
        )
        for ((valor, maximo, campo) in casos) {
            val rede = rede()
            val vm = viewModelCom(rede)
            vm.carregar().join()
            vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = true).comUnidade("hora").copy(valor = valor, valorMaximo = maximo) }

            vm.salvar().join()

            assertTrue(rede.doCaminho("/rpc/definir_servicos").isEmpty(), "$valor/$maximo")
            assertEquals(campo, vm.estado.value.campoComErro, "$valor/$maximo")
            assertEquals(Fixtures.FUNCAO, vm.estado.value.funcaoComErro)
            assertEquals(TextosChamadaProfissional.campo(campo), vm.estado.value.erro)
            assertFalse(vm.estado.value.salvando)
        }
    }

    @Test
    fun `regras da unidade valem no aparelho (diaria 4 a 12 h, pacote com descricao, por pessoa com minimo)`() = runBlocking {
        val casos = listOf(
            Triple("diaria", { l: ServicoEmEdicao -> l.copy(valor = "100", horasIncluidas = "13") }, "horas_incluidas"),
            Triple("diaria", { l: ServicoEmEdicao -> l.copy(valor = "100", horasIncluidas = "3") }, "horas_incluidas"),
            Triple("pacote", { l: ServicoEmEdicao -> l.copy(valor = "100", descricaoPacote = "  ") }, "descricao_pacote"),
            Triple("pacote", { l: ServicoEmEdicao -> l.copy(valor = "100", descricaoPacote = "x".repeat(121)) }, "descricao_pacote"),
            Triple("por_pessoa", { l: ServicoEmEdicao -> l.copy(valor = "100", minimoPessoas = "0") }, "minimo_pessoas"),
            Triple("hora", { l: ServicoEmEdicao -> l.copy(valor = "100", minimoHoras = "13") }, "minimo_horas"),
            Triple("evento", { l: ServicoEmEdicao -> l.copy(valor = "100", duracaoTipicaH = "25") }, "duracao_tipica_h"),
            Triple("evento", { l: ServicoEmEdicao -> l.copy(valor = "100", atePessoas = "2001") }, "ate_pessoas"),
            Triple("hora", { l: ServicoEmEdicao -> l.copy(valor = "100", inclui = "x".repeat(301)) }, "inclui"),
        )
        for ((unidade, ajuste, campo) in casos) {
            val rede = rede()
            val vm = viewModelCom(rede)
            vm.carregar().join()
            vm.editar(Fixtures.FUNCAO) { ajuste(it.copy(habilitado = true).comUnidade(unidade)).let { l -> if (unidade == "diaria" && l.horasIncluidas.isEmpty()) l.copy(horasIncluidas = "8") else l } }

            vm.salvar().join()

            assertEquals(campo, vm.estado.value.campoComErro, "$unidade/$campo")
            assertTrue(rede.doCaminho("/rpc/definir_servicos").isEmpty(), "$unidade/$campo")
        }
    }

    @Test
    fun `trocar a unidade zera o que era da anterior e poe o padrao da nova`() {
        val linha = ServicoEmEdicao(
            funcao = br.com.frila.core.rede.FuncaoDto(Fixtures.FUNCAO, "Garçom", "salao"),
            habilitado = true,
            unidade = "evento",
            valor = "300",
            valorMaximo = "400",
            duracaoTipicaH = "6",
            atePessoas = "100",
        )
        val diaria = linha.comUnidade("diaria")
        assertEquals("8", diaria.horasIncluidas)
        assertEquals("", diaria.duracaoTipicaH)
        assertEquals("", diaria.atePessoas)
        assertEquals("", diaria.valorMaximo)
        assertEquals("300", diaria.valor)
        assertEquals("1", linha.comUnidade("por_pessoa").minimoPessoas)
    }

    @Test
    fun `ate 8 especialidades por servico`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = true) }

        (1..10).forEach { vm.alternarEspecialidade(Fixtures.FUNCAO, "esp-$it", true) }
        assertEquals(8, vm.estado.value.rascunhos[0].especialidadeIds.size)
        vm.alternarEspecialidade(Fixtures.FUNCAO, "esp-1", false)
        assertEquals(7, vm.estado.value.rascunhos[0].especialidadeIds.size)
    }

    @Test
    fun `erros do contrato viram mensagem propria e destacam o campo`() = runBlocking {
        val casos = listOf(
            Triple(HttpStatusCode.UnprocessableEntity, Fixtures.erro("funcao_nao_marcada", Fixtures.FUNCAO), TextosChamadaProfissional.SERVICOS_FUNCAO_NAO_MARCADA),
            Triple(HttpStatusCode.UnprocessableEntity, Fixtures.erro("campo_invalido", "inclui"), TextosChamadaProfissional.campo("inclui")),
            Triple(HttpStatusCode.UnprocessableEntity, Fixtures.erro("campo_invalido", "valor_max_centavos"), TextosChamadaProfissional.campo("valor_max_centavos")),
            Triple(HttpStatusCode.Forbidden, Fixtures.erro("sem_permissao", "recurso_desligado"), TextosChamadaProfissional.DESLIGADO),
            Triple(HttpStatusCode.Forbidden, Fixtures.erro("conta_suspensa"), TextosChamadaProfissional.CONTA_SUSPENSA),
            Triple(HttpStatusCode.UnprocessableEntity, Fixtures.erro("perfil_incompativel"), TextosChamadaProfissional.SO_PROFISSIONAL),
            Triple(HttpStatusCode.BadGateway, "<html>502</html>", TextosChamadaProfissional.ERRO),
        )
        for ((status, corpo, esperado) in casos) {
            val rede = rede()
            rede.recusa("/rpc/definir_servicos", status, corpo)
            val vm = viewModelCom(rede)
            vm.carregar().join()
            vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = true) }

            vm.salvar().join()

            assertEquals(esperado, vm.estado.value.erro, corpo)
            assertFalse(vm.estado.value.salvando)
            assertFalse(vm.estado.value.sucesso)
        }
        val rede = rede()
        rede.recusa("/rpc/definir_servicos", HttpStatusCode.UnprocessableEntity, Fixtures.erro("campo_invalido", "inclui"))
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = true) }
        vm.salvar().join()
        assertEquals("inclui", vm.estado.value.campoComErro)
    }

    @Test
    fun `falha ao carregar deixa tentar de novo e nao deixa salvar`() = runBlocking {
        val rede = RedeDeTeste()
        rede.recusa("/rpc/meu_perfil_detalhado", HttpStatusCode.UnprocessableEntity, Fixtures.erro("perfil_incompativel"))
        val vm = viewModelCom(rede)

        vm.carregar().join()
        assertFalse(vm.estado.value.carregou)
        assertFalse(vm.estado.value.carregando)
        assertEquals(TextosChamadaProfissional.SO_PROFISSIONAL, vm.estado.value.erro)
        vm.salvar().join()
        assertTrue(rede.doCaminho("/rpc/definir_servicos").isEmpty())

        rede.ok("/rpc/meu_perfil_detalhado", Fixtures.perfilDetalhadoJson())
        vm.carregar().join()
        assertTrue(vm.estado.value.carregou)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `editar depois de salvar apaga o aviso de salvo`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.salvar().join()
        assertTrue(vm.estado.value.sucesso)

        vm.editar(Fixtures.FUNCAO) { it.copy(habilitado = true) }

        assertFalse(vm.estado.value.sucesso)
    }

    @Test
    fun `corpo enviado e um objeto com a chave servicos`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.salvar().join()
        val corpo: JsonObject = rede.doCaminho("/rpc/definir_servicos").single().corpo!!
        assertEquals(setOf("servicos"), corpo.keys)
    }
}

class ServicoDeEspecialidadesTest {
    @Test
    fun `le a tabela especialidade filtrando pela funcao e so as ativas`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("/rest/v1/especialidade", Fixtures.especialidadesJson())
        val engineServico = ServicoDeEspecialidades(rede.cliente)

        val lista = engineServico.especialidadesDaFuncao(Fixtures.FUNCAO)

        assertEquals(listOf("Eventos", "Casamentos", "Antiga"), lista.map { it.nome })
        val pedido = rede.pedidos.single()
        assertEquals("GET", pedido.metodo)
        assertEquals("/rest/v1/especialidade", pedido.caminho)
        assertTrue(pedido.consulta.contains("funcao_id=eq.${Fixtures.FUNCAO}"))
        assertTrue(pedido.consulta.contains("ativo=eq.true"))
    }

    @Test
    fun `erro do servidor chega como ErroDaApi`() = runBlocking {
        val rede = RedeDeTeste()
        rede.recusa("/rest/v1/especialidade", HttpStatusCode.Unauthorized, Fixtures.erro("nao_autenticado"))
        val erro = runCatching { ServicoDeEspecialidades(rede.cliente).especialidadesDaFuncao(Fixtures.FUNCAO) }.exceptionOrNull()
        assertTrue(erro is br.com.frila.core.rede.ErroDaApi)
    }
}
