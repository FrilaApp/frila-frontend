package br.com.frila.feature.chamadas.profissional

import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.LocalDate

class PreferenciasChamadaViewModelTest {

    private val hoje = LocalDate.of(2026, 11, 16)

    private fun viewModelCom(rede: RedeDeTeste) = PreferenciasChamadaViewModel(
        carregarPerfil = rede.servico::meuPerfilDetalhado,
        definirPreferencias = rede.servico::definirPreferenciaChamadas,
        hoje = { hoje },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun rede(preferencia: String = Fixtures.preferenciaJson()) = RedeDeTeste().apply {
        ok("/rpc/meu_perfil_detalhado", Fixtures.perfilDetalhadoJson(preferencia = preferencia))
    }

    @Test
    fun `comeca carregando e carregar le a preferencia de meu_perfil_detalhado`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(aceitaChamadas = true, antecedencia = 24, aceitaDe = "so_cnpj", pendencias = listOf("sem_regiao")))
        val vm = viewModelCom(rede)
        assertTrue(vm.estado.value.carregando)

        vm.carregar().join()

        val tela = vm.estado.value
        assertFalse(tela.carregando)
        assertTrue(tela.carregou)
        assertTrue(tela.aceitaChamadas)
        assertEquals(24, tela.antecedenciaMinimaH)
        assertEquals("so_cnpj", tela.aceitaDe)
        assertEquals(listOf("sem_regiao"), tela.pendencias)
        assertEquals("/rest/v1/rpc/meu_perfil_detalhado", rede.pedidos.single().caminho)
    }

    @Test
    fun `ligar aceito chamadas envia aceita_chamadas e a versao do texto, so o que mudou`() = runBlocking {
        val rede = rede()
        rede.ok(
            "/rpc/definir_preferencia_chamadas",
            Fixtures.preferenciaJson(aceitaChamadas = true, pendencias = listOf("sem_servico_com_preco", "sem_regiao")),
        )
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.alternarAceitaChamadas(true)
        vm.salvar().join()

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals(setOf("aceita_chamadas", "versao_texto_busca"), corpo.keys)
        assertEquals("true", corpo["aceita_chamadas"]!!.jsonPrimitive.content)
        assertEquals("busca-v1", corpo["versao_texto_busca"]!!.jsonPrimitive.content)
        val tela = vm.estado.value
        assertTrue(tela.sucesso)
        assertFalse(tela.salvando)
        assertEquals(listOf("sem_servico_com_preco", "sem_regiao"), tela.pendencias)
    }

    @Test
    fun `quem ja aceita nao reenvia aceita_chamadas ao mudar outro campo`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(aceitaChamadas = true))
        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(aceitaChamadas = true, antecedencia = 48))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.escolherAntecedencia(48)
        vm.salvar().join()

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals(setOf("antecedencia_minima_h"), corpo.keys)
        assertEquals(48, vm.estado.value.antecedenciaMinimaH)
    }

    @Test
    fun `desligar envia aceita_chamadas false sem versao do texto`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(aceitaChamadas = true))
        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(aceitaChamadas = false))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.alternarAceitaChamadas(false)
        vm.salvar().join()

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals(setOf("aceita_chamadas"), corpo.keys)
        assertEquals("false", corpo["aceita_chamadas"]!!.jsonPrimitive.content)
        assertFalse(vm.estado.value.aceitaChamadas)
    }

    @Test
    fun `sem nenhuma mudanca nao chama o servidor, que recusaria o pedido vazio`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.salvar().join()

        assertTrue(rede.doCaminho("/rpc/definir_preferencia_chamadas").isEmpty())
        assertTrue(vm.estado.value.sucesso)
    }

    @Test
    fun `pausar manda a data e tirar a pausa manda null explicito`() = runBlocking {
        val rede = rede()
        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(pausadoAte = "2026-11-20", pendencias = listOf("pausado")))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.alternarPausa(true)
        vm.escolherDataDaPausa(LocalDate.of(2026, 11, 20))
        vm.salvar().join()

        val pedidoDaPausa = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals("2026-11-20", pedidoDaPausa["pausado_ate"]!!.jsonPrimitive.content)
        assertTrue(vm.estado.value.pausar)
        assertEquals(LocalDate.of(2026, 11, 20), vm.estado.value.pausadoAte)
        assertEquals(LocalDate.of(2026, 11, 21), vm.estado.value.diaDaRetomada)

        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(pausadoAte = null))
        vm.alternarPausa(false)
        vm.salvar().join()

        val pedidoSemPausa = rede.doCaminho("/rpc/definir_preferencia_chamadas").last().corpo!!
        assertEquals(setOf("pausado_ate"), pedidoSemPausa.keys)
        assertEquals(JsonNull, pedidoSemPausa["pausado_ate"])
        assertFalse(vm.estado.value.pausar)
    }

    @Test
    fun `data da pausa de hoje ou do passado nao sai do aparelho`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.alternarPausa(true)
        vm.escolherDataDaPausa(hoje)
        vm.salvar().join()

        assertTrue(rede.doCaminho("/rpc/definir_preferencia_chamadas").isEmpty())
        assertEquals(TextosChamadaProfissional.DATA_DA_PAUSA_INVALIDA, vm.estado.value.erro)
        assertFalse(vm.estado.value.salvando)
    }

    @Test
    fun `pausa ja vencida vinda do servidor conta como sem pausa e nao trava o salvar`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(pausadoAte = "2026-11-15"))
        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(pausadoAte = "2026-11-15", antecedencia = 24))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        assertFalse(vm.estado.value.pausar)

        vm.escolherAntecedencia(24)
        vm.salvar().join()

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals(setOf("antecedencia_minima_h"), corpo.keys)
        assertNull(vm.estado.value.erro)
        assertTrue(vm.estado.value.sucesso)
        assertFalse(vm.estado.value.pausar)
    }

    @Test
    fun `pausa que acaba hoje continua em vigor, aparece ligada e a pessoa pode tirar com pausado_ate null`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(pausadoAte = "2026-11-16"))
        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(pausadoAte = null))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        assertTrue(vm.estado.value.pausar)
        assertEquals(hoje, vm.estado.value.pausadoAte)

        vm.alternarPausa(false)
        vm.salvar().join()

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals(setOf("pausado_ate"), corpo.keys)
        assertEquals(JsonNull, corpo["pausado_ate"])
        assertNull(vm.estado.value.erro)
        assertFalse(vm.estado.value.pausar)
    }

    @Test
    fun `pausa que acaba hoje no servidor nao bloqueia salvar outro campo nem manda a data de volta`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(pausadoAte = "2026-11-16"))
        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(pausadoAte = "2026-11-16", antecedencia = 24))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.escolherAntecedencia(24)
        vm.salvar().join()

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals(setOf("antecedencia_minima_h"), corpo.keys)
        assertNull(vm.estado.value.erro)
        assertTrue(vm.estado.value.pausar)
    }

    @Test
    fun `pausa que acabou ontem no servidor volta como sem pausa`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(pausadoAte = "2026-11-15"))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        assertFalse(vm.estado.value.pausar)
        assertEquals(hoje.plusDays(1), vm.estado.value.pausadoAte)
    }

    @Test
    fun `trocar a pausa do servidor por hoje continua recusado, so vale a partir de amanha`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(pausadoAte = "2026-11-18"))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.escolherDataDaPausa(hoje)
        vm.salvar().join()

        assertTrue(rede.doCaminho("/rpc/definir_preferencia_chamadas").isEmpty())
        assertEquals(TextosChamadaProfissional.DATA_DA_PAUSA_INVALIDA, vm.estado.value.erro)
    }

    @Test
    fun `pausa vencida no servidor, a pessoa escolhe nova data de amanha e ela vai no pedido`() = runBlocking {
        val rede = rede(Fixtures.preferenciaJson(pausadoAte = "2026-11-15"))
        rede.ok("/rpc/definir_preferencia_chamadas", Fixtures.preferenciaJson(pausadoAte = "2026-11-17", pendencias = listOf("pausado")))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.alternarPausa(true)
        vm.escolherDataDaPausa(LocalDate.of(2026, 11, 17))
        vm.salvar().join()

        val corpo = rede.doCaminho("/rpc/definir_preferencia_chamadas").single().corpo!!
        assertEquals("2026-11-17", corpo["pausado_ate"]!!.jsonPrimitive.content)
    }

    @Test
    fun `recurso desligado, conta suspensa, contratante e data recusada viram mensagem propria`() = runBlocking {
        val casos = listOf(
            Triple(HttpStatusCode.Forbidden, Fixtures.erro("sem_permissao", "recurso_desligado"), TextosChamadaProfissional.DESLIGADO),
            Triple(HttpStatusCode.Forbidden, Fixtures.erro("conta_suspensa"), TextosChamadaProfissional.CONTA_SUSPENSA),
            Triple(HttpStatusCode.Forbidden, Fixtures.erro("sem_permissao", "conta_suspensa"), TextosChamadaProfissional.CONTA_SUSPENSA),
            Triple(HttpStatusCode.UnprocessableEntity, Fixtures.erro("perfil_incompativel"), TextosChamadaProfissional.SO_PROFISSIONAL),
            Triple(HttpStatusCode.UnprocessableEntity, Fixtures.erro("campo_invalido", "pausado_ate"), TextosChamadaProfissional.DATA_DA_PAUSA_INVALIDA),
            Triple(HttpStatusCode.UnprocessableEntity, Fixtures.erro("campo_obrigatorio", "versao_texto_busca"), TextosChamadaProfissional.ERRO),
        )
        for ((status, corpo, esperado) in casos) {
            val rede = rede()
            rede.recusa("/rpc/definir_preferencia_chamadas", status, corpo)
            val vm = viewModelCom(rede)
            vm.carregar().join()
            vm.alternarAceitaChamadas(true)

            vm.salvar().join()

            assertEquals(esperado, vm.estado.value.erro, corpo)
            assertFalse(vm.estado.value.salvando)
            assertFalse(vm.estado.value.sucesso)
        }
    }

    @Test
    fun `sem rede e corpo nao JSON nunca deixam a tela salvando`() = runBlocking {
        val rede = rede()
        rede.resposta("/rpc/definir_preferencia_chamadas") { throw ConnectTimeoutException("sem rede") }
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.alternarAceitaChamadas(true)
        vm.salvar().join()
        assertEquals(TextosChamadaProfissional.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.salvando)

        val corrompida = rede()
        corrompida.ok("/rpc/definir_preferencia_chamadas", "<html>502</html>")
        val vm2 = viewModelCom(corrompida)
        vm2.carregar().join()
        vm2.alternarAceitaChamadas(true)
        vm2.salvar().join()
        assertEquals(TextosChamadaProfissional.ERRO, vm2.estado.value.erro)
        assertFalse(vm2.estado.value.salvando)
    }

    @Test
    fun `falha ao carregar deixa tentar de novo e nao deixa salvar valores inventados`() = runBlocking {
        val rede = RedeDeTeste()
        rede.recusa("/rpc/meu_perfil_detalhado", HttpStatusCode.Forbidden, Fixtures.erro("sem_permissao", "recurso_desligado"))
        val vm = viewModelCom(rede)

        vm.carregar().join()

        assertFalse(vm.estado.value.carregou)
        assertFalse(vm.estado.value.carregando)
        assertEquals(TextosChamadaProfissional.DESLIGADO, vm.estado.value.erro)
        vm.alternarAceitaChamadas(true)
        vm.salvar().join()
        assertTrue(rede.doCaminho("/rpc/definir_preferencia_chamadas").isEmpty())

        rede.ok("/rpc/meu_perfil_detalhado", Fixtures.perfilDetalhadoJson())
        vm.carregar().join()
        assertTrue(vm.estado.value.carregou)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `perfil sem preferencia (conta que nao e profissional) mostra erro e nao quebra`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("/rpc/meu_perfil_detalhado", Fixtures.perfilDetalhadoJson(preferencia = null))
        val vm = viewModelCom(rede)

        vm.carregar().join()

        assertFalse(vm.estado.value.carregou)
        assertNotNull(vm.estado.value.erro)
    }

    @Test
    fun `segundo toque em salvar com um pedido em voo nao dispara outro`() = runBlocking {
        val rede = rede()
        val liberar = CompletableDeferred<Unit>()
        rede.resposta("/rpc/definir_preferencia_chamadas") {
            liberar.await()
            respond(Fixtures.preferenciaJson(aceitaChamadas = true), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val escopo = CoroutineScope(Dispatchers.Default)
        val vm = PreferenciasChamadaViewModel(rede.servico::meuPerfilDetalhado, rede.servico::definirPreferenciaChamadas, { hoje }, escopo)
        vm.carregar().join()
        vm.alternarAceitaChamadas(true)

        val primeiro = vm.salvar()
        assertTrue(vm.estado.value.salvando)
        val segundo = vm.salvar()
        liberar.complete(Unit)
        withTimeout(5_000) { primeiro.join(); segundo.join() }

        assertEquals(1, rede.doCaminho("/rpc/definir_preferencia_chamadas").size)
        assertFalse(vm.estado.value.salvando)
    }
}
