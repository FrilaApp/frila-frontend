package br.com.frila.feature.chamadas.casa

import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ChamadaDiretaViewModelTest {

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val casa = "11111111-1111-1111-1111-111111111111"
    private val profissional = "22222222-2222-2222-2222-222222222222"
    private val garcom = "33333333-3333-3333-3333-333333333333"
    private val barman = "44444444-4444-4444-4444-444444444444"
    private val vaga = "55555555-5555-5555-5555-555555555555"

    private val casaJson =
        """{"id":"$casa","nome":"Bistrô Ipê","tipo":"pj","endereco":"SCS Quadra 2, Plano Piloto","regiao_administrativa":"Plano Piloto","ponto":{"latitude":-15.79,"longitude":-47.88},"papel":"administrador"}"""
    private val funcoesJson =
        """[{"id":"$garcom","nome":"Garçom","categoria":"salao"},{"id":"$barman","nome":"Barman","categoria":"bar"}]"""
    private val chamadaJson =
        """{"id":"66666666-6666-6666-6666-666666666666","vaga_id":"$vaga","profissional_id":"$profissional","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z"}"""

    private fun rede(): RedeDeTeste = RedeDeTeste().apply {
        ok("meu_estabelecimento", casaJson)
        ok("funcao", funcoesJson)
        ok("chamar_profissional", chamadaJson)
    }

    private fun viewModelCom(
        rede: RedeDeTeste,
        recurso: Boolean = true,
        regiaoId: Int? = null,
        prazoMs: Long = 5_000,
    ): ChamadaDiretaViewModel {
        var contador = 0
        return ChamadaDiretaViewModel(
            profissionalId = profissional,
            estabelecimentoId = casa,
            recursoHabilitado = { recurso },
            buscarCasa = rede.membros::meuEstabelecimento,
            buscarFuncoes = rede.vagas::listarFuncoes,
            chamar = rede.chamadas::chamarProfissional,
            regiaoId = regiaoId,
            relogio = { agora },
            novaChave = { "chave-${++contador}" },
            prazoMs = prazoMs,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    /** A folha carregada e com tudo o que o envio pede. */
    private suspend fun ChamadaDiretaViewModel.preenchida() = apply {
        carregar().join()
        definirValor("180")
        confirmarTotal(true)
    }

    private fun ChamadaDiretaViewModel.corpoEnviado(rede: RedeDeTeste, indice: Int = 0) =
        rede.doNome("chamar_profissional")[indice].corpo

    @Test
    fun `carregar preenche funcao, local da casa e responsavel, e libera a folha`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)

        vm.carregar().join()

        val tela = vm.estado.value
        assertTrue(tela.recursoHabilitado)
        assertFalse(tela.carregando)
        assertEquals(listOf("Garçom", "Barman"), tela.funcoes.map { it.nome })
        assertEquals(garcom, tela.funcaoId)
        assertEquals("SCS Quadra 2, Plano Piloto", tela.local)
        assertEquals("Bistrô Ipê", tela.responsavel)
        // O padrão do iOS: começa amanhã, com 4 h de duração.
        assertEquals(agora.plus(Duration.ofHours(24)), tela.inicio)
        assertEquals(Duration.ofHours(4), tela.duracao)
    }

    @Test
    fun `chave chamada_direta desligada mostra o texto de desligado sem ler a casa`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede, recurso = false)

        vm.carregar().join()

        assertEquals(TextosChamadaCasa.DESLIGADO, vm.estado.value.erro)
        assertFalse(vm.estado.value.recursoHabilitado)
        assertFalse(vm.estado.value.carregando)
        assertTrue(rede.pedidos.isEmpty())
        assertFalse(vm.estado.value.podeEnviar)
    }

    @Test
    fun `falha ao carregar a casa deixa tentar novamente e nao prende em carregando`() = runBlocking {
        val rede = rede().apply { recusa("meu_estabelecimento", HttpStatusCode.Forbidden, "sem_permissao") }
        val vm = viewModelCom(rede)

        vm.carregar().join()
        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.carregando)
        assertFalse(vm.estado.value.recursoHabilitado)

        rede.ok("meu_estabelecimento", casaJson)
        vm.carregar().join()
        assertNull(vm.estado.value.erro)
        assertTrue(vm.estado.value.recursoHabilitado)
    }

    @Test
    fun `prazo estourado ao carregar vira erro e nao fica carregando`() = runBlocking {
        val rede = rede().apply {
            rota("meu_estabelecimento") { delay(10_000); respond(casaJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
        }
        val vm = viewModelCom(rede, prazoMs = 100)

        vm.carregar().join()

        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.carregando)
    }

    @Test
    fun `o botao explica o que falta, na ordem do iOS, e so liga com tudo`() = runBlocking {
        val vm = viewModelCom(rede())
        vm.carregar().join()

        assertEquals(TextosChamadaCasa.FALTA_VALOR, vm.estado.value.oQueFalta)
        vm.definirValor("180")
        assertEquals(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL, vm.estado.value.oQueFalta)
        vm.confirmarTotal(true)
        assertNull(vm.estado.value.oQueFalta)
        assertTrue(vm.estado.value.podeEnviar)

        vm.definirResponsavel("   ")
        assertEquals(TextosChamadaCasa.FALTA_RESPONSAVEL, vm.estado.value.oQueFalta)
        assertFalse(vm.estado.value.podeEnviar)
    }

    @Test
    fun `mudar o valor desfaz a confirmacao do total, mas reescrever o mesmo valor nao`() = runBlocking {
        val vm = viewModelCom(rede()).preenchida()
        assertTrue(vm.estado.value.totalConfirmado)

        vm.definirValor("180,")
        assertTrue(vm.estado.value.totalConfirmado)

        vm.definirValor("200")
        assertFalse(vm.estado.value.totalConfirmado)
        assertEquals(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL, vm.estado.value.oQueFalta)
    }

    @Test
    fun `mudar o inicio leva o termino junto, com a mesma duracao dentro de 2 a 16 h`() = runBlocking {
        val vm = viewModelCom(rede())
        vm.carregar().join()
        val novoInicio = agora.plus(Duration.ofHours(30))

        vm.definirInicio(novoInicio)
        assertEquals(novoInicio.plus(Duration.ofHours(4)), vm.estado.value.fim)

        vm.definirFim(novoInicio.plus(Duration.ofHours(10)))
        vm.definirInicio(novoInicio.plus(Duration.ofHours(1)))
        assertEquals(Duration.ofHours(10), vm.estado.value.duracao)

        // Um término fora da faixa volta para dentro dela quando o início muda.
        vm.definirFim(vm.estado.value.inicio.plus(Duration.ofHours(20)))
        vm.definirInicio(vm.estado.value.inicio.plus(Duration.ofHours(1)))
        assertEquals(Duration.ofHours(16), vm.estado.value.duracao)
    }

    @Test
    fun `inicio a menos de 2 horas bloqueia o envio e o seletor so oferece a partir de agora mais 2 horas`() = runBlocking {
        val vm = viewModelCom(rede()).preenchida()
        assertEquals(agora.plus(Duration.ofHours(2)), vm.inicioMinimo())

        vm.definirInicio(agora.plus(Duration.ofMinutes(90)))
        assertEquals(TextosChamadaCasa.FALTA_ANTECEDENCIA, vm.estado.value.oQueFalta)
        vm.enviar().join()
        assertTrue(vm.estado.value.resultado == null)

        vm.definirInicio(agora.plus(Duration.ofHours(2)))
        assertTrue(vm.estado.value.podeEnviar)
    }

    @Test
    fun `duracao fora de 2 a 16 horas bloqueia o envio`() = runBlocking {
        val vm = viewModelCom(rede()).preenchida()
        val inicio = vm.estado.value.inicio

        vm.definirFim(inicio.plus(Duration.ofMinutes(90)))
        assertEquals(TextosChamadaCasa.FALTA_DURACAO, vm.estado.value.oQueFalta)
        assertFalse(vm.estado.value.podeEnviar)
        vm.definirFim(inicio.plus(Duration.ofHours(17)))
        assertFalse(vm.estado.value.podeEnviar)
        assertEquals(inicio.plus(Duration.ofHours(2))..inicio.plus(Duration.ofHours(16)), vm.faixaDoTermino())
    }

    @Test
    fun `recado com mais de 300 caracteres bloqueia o envio`() = runBlocking {
        val vm = viewModelCom(rede()).preenchida()

        vm.definirRecado("a".repeat(301))
        assertTrue(vm.estado.value.recadoLongo)
        assertFalse(vm.estado.value.podeEnviar)
        vm.definirRecado("a".repeat(300))
        assertTrue(vm.estado.value.podeEnviar)
    }

    @Test
    fun `enviar manda o corpo do contrato com a chave, o ponto da casa e o regiao_id da busca`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede, regiaoId = 7).preenchida()
        vm.definirFuncao(barman)
        vm.definirRefeicao(true)
        vm.definirRecado("Traga avental")
        vm.definirResponsavel("  Dona Rita ")

        vm.enviar().join()

        val corpo = vm.corpoEnviado(rede)
        assertEquals("chave-1", corpo["chave"]!!.jsonPrimitive.content)
        assertEquals(profissional, corpo["profissional_id"]!!.jsonPrimitive.content)
        assertEquals(casa, corpo["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals(barman, corpo["funcao_id"]!!.jsonPrimitive.content)
        assertEquals("2026-11-17T15:00:00Z", corpo["inicio_em"]!!.jsonPrimitive.content)
        assertEquals("2026-11-17T19:00:00Z", corpo["fim_em"]!!.jsonPrimitive.content)
        assertEquals("SCS Quadra 2, Plano Piloto", corpo["local"]!!.jsonPrimitive.content)
        assertEquals("Plano Piloto", corpo["regiao_administrativa"]!!.jsonPrimitive.content)
        assertEquals(7, corpo["regiao_id"]!!.jsonPrimitive.int)
        assertEquals(-15.79, corpo["ponto"]!!.jsonObject["latitude"]!!.jsonPrimitive.content.toDouble())
        assertEquals("18000", corpo["valor_centavos"]!!.jsonPrimitive.content)
        assertTrue(corpo["inclui_refeicao"]!!.jsonPrimitive.boolean)
        assertFalse(corpo["inclui_transporte"]!!.jsonPrimitive.boolean)
        assertFalse(corpo["exige_material_proprio"]!!.jsonPrimitive.boolean)
        assertEquals("Dona Rita", corpo["responsavel_local"]!!.jsonPrimitive.content)
        assertEquals("Traga avental", corpo["recado"]!!.jsonPrimitive.content)
        // Sem J7, o corpo nem leva o campo; e uma vaga nova (sem vaga_id).
        assertFalse("confirmo_recorrencia" in corpo)
        assertFalse("vaga_id" in corpo)
        assertNotNull(vm.estado.value.resultado)
        assertEquals("aberta", vm.estado.value.resultado!!.estado)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `recado em branco nao vai no corpo, e sem regiao da busca nao leva regiao_id`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede).preenchida()
        vm.definirRecado("   ")

        vm.enviar().join()

        val corpo = vm.corpoEnviado(rede)
        assertFalse("recado" in corpo)
        assertFalse("regiao_id" in corpo)
    }

    @Test
    fun `depois de enviada a folha nao envia de novo nem aceita edicao`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede).preenchida()

        vm.enviar().join()
        vm.enviar().join()
        vm.definirValor("999")

        assertEquals(1, rede.doNome("chamar_profissional").size)
        assertEquals("180", vm.estado.value.valorTexto)
        assertFalse(vm.estado.value.podeEnviar)
    }

    @Test
    fun `J7 pede a confirmacao e o reenvio leva a mesma chave com confirmo_recorrencia`() = runBlocking {
        val rede = rede().apply { recusa("chamar_profissional", HttpStatusCode.Conflict, "recorrencia_nao_confirmada") }
        val vm = viewModelCom(rede).preenchida()

        vm.enviar().join()

        assertTrue(vm.estado.value.mostrarJ7)
        assertTrue(vm.estado.value.travado)
        assertNull(vm.estado.value.resultado)
        assertNull(vm.estado.value.erro)
        assertFalse("confirmo_recorrencia" in vm.corpoEnviado(rede, 0))

        rede.ok("chamar_profissional", chamadaJson)
        vm.enviar(confirmoRecorrencia = true).join()

        val reenvio = vm.corpoEnviado(rede, 1)
        assertEquals("chave-1", reenvio["chave"]!!.jsonPrimitive.content)
        assertTrue(reenvio["confirmo_recorrencia"]!!.jsonPrimitive.boolean)
        assertFalse(vm.estado.value.mostrarJ7)
        assertNotNull(vm.estado.value.resultado)
    }

    @Test
    fun `confirmo_recorrencia sem a recusa J7 antes nao envia nada`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede).preenchida()

        vm.enviar(confirmoRecorrencia = true).join()

        assertTrue(rede.doNome("chamar_profissional").isEmpty())
    }

    @Test
    fun `fechar o aviso J7 nao envia nada e guarda o pedido`() = runBlocking {
        val rede = rede().apply { recusa("chamar_profissional", HttpStatusCode.Conflict, "recorrencia_nao_confirmada") }
        val vm = viewModelCom(rede).preenchida()
        vm.enviar().join()

        vm.dispensarJ7()

        assertFalse(vm.estado.value.mostrarJ7)
        assertEquals(1, rede.doNome("chamar_profissional").size)
        assertTrue(vm.estado.value.travado)
    }

    @Test
    fun `recusas do contrato viram as mensagens do iOS e destravam a folha com chave nova`() = runBlocking {
        val casos = listOf(
            Triple(HttpStatusCode.Conflict to "chamada_ja_aberta", null as String?, TextosChamadaCasa.JA_ABERTA),
            Triple(HttpStatusCode.UnprocessableEntity to "profissional_indisponivel", "agenda_cheia", TextosChamadaCasa.INDISPONIVEL),
            Triple(HttpStatusCode.NotFound to "nao_encontrado", null, TextosChamadaCasa.INDISPONIVEL),
            Triple(HttpStatusCode.UnprocessableEntity to "limite_de_chamadas", "por_dia", TextosChamadaCasa.LIMITE),
            Triple(HttpStatusCode.Forbidden to "sem_permissao", "recurso_desligado", TextosChamadaCasa.DESLIGADO),
            Triple(HttpStatusCode.Forbidden to "conta_suspensa", null, TextosChamadaCasa.ERRO),
            Triple(HttpStatusCode.Conflict to "vaga_encerrada", null, TextosChamadaCasa.ERRO),
        )
        for ((status, detalhes, esperada) in casos) {
            val rede = rede().apply { recusa("chamar_profissional", status.first, status.second, detalhes) }
            val vm = viewModelCom(rede).preenchida()

            vm.enviar().join()

            assertEquals(esperada, vm.estado.value.erro, "${status.second}/$detalhes")
            assertFalse(vm.estado.value.enviando)
            assertFalse(vm.estado.value.travado, "recusa do servidor destrava a folha: ${status.second}")
            assertNull(vm.estado.value.resultado)

            // Corrigido o problema, o reenvio nasce com uma chave nova.
            rede.ok("chamar_profissional", chamadaJson)
            vm.enviar().join()
            assertEquals("chave-2", vm.corpoEnviado(rede, 1)["chave"]!!.jsonPrimitive.content, status.second)
        }
    }

    @Test
    fun `sem rede mantem a chave e o reenvio devolve a mesma chamada, nunca uma segunda`() = runBlocking {
        var offline = true
        val rede = rede().apply {
            rota("chamar_profissional") {
                if (offline) throw ConnectTimeoutException("sem rota", null)
                respond(chamadaJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        val vm = viewModelCom(rede).preenchida()

        vm.enviar().join()

        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.erro)
        assertTrue(vm.estado.value.travado)
        assertFalse(vm.estado.value.enviando)
        // O formulário trava: nada muda o pedido que pode já ter chegado ao servidor.
        vm.definirValor("999")
        assertEquals("180", vm.estado.value.valorTexto)

        offline = false
        vm.enviar().join()

        assertEquals("chave-1", vm.corpoEnviado(rede, 0)["chave"]!!.jsonPrimitive.content)
        assertEquals("chave-1", vm.corpoEnviado(rede, 1)["chave"]!!.jsonPrimitive.content)
        assertEquals(vm.corpoEnviado(rede, 0)["valor_centavos"], vm.corpoEnviado(rede, 1)["valor_centavos"])
        assertNotNull(vm.estado.value.resultado)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `prazo estourado ao enviar solta o botao e o reenvio leva a mesma chave`() = runBlocking {
        var lento = true
        val rede = rede().apply {
            rota("chamar_profissional") {
                if (lento) delay(10_000)
                respond(chamadaJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        val vm = viewModelCom(rede, prazoMs = 100).preenchida()

        vm.enviar().join()

        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.enviando)
        assertTrue(vm.estado.value.travado)

        lento = false
        vm.enviar().join()
        assertEquals("chave-1", vm.corpoEnviado(rede, 1)["chave"]!!.jsonPrimitive.content)
        assertNotNull(vm.estado.value.resultado)
    }

    @Test
    fun `carregar le a casa e o catalogo de funcoes uma vez so, mesmo chamado de novo`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)

        vm.carregar().join()
        vm.carregar().join()

        assertEquals(listOf("meu_estabelecimento", "funcao"), rede.pedidos.map { it.nome })
    }

    @Test
    fun `valores fora da faixa de referencia nao bloqueiam o envio da chamada direta`() = runBlocking {
        for ((texto, centavos) in listOf("49,99" to "4999", "2000,01" to "200001")) {
            val rede = rede()
            val vm = viewModelCom(rede)
            vm.carregar().join()
            vm.definirValor(texto)
            vm.confirmarTotal(true)

            assertTrue(vm.estado.value.podeEnviar)
            vm.enviar().join()

            assertEquals(centavos, vm.corpoEnviado(rede)["valor_centavos"]!!.jsonPrimitive.content)
        }
    }
}
