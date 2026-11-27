package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ResultadoRegistroDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.yield
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-4: o profissional digita o código da casa (`validar_codigo_checkin`, 0.2.68). Espelha `ValidacaoDoCodigoViewModel` do iOS. */
class ValidacaoDoCodigoViewModelTest {

    private val registro = ResultadoRegistroDto(
        turnoId = "t1", tipo = "codigo", verificacao = "verificado", registradoEm = "2026-11-02T01:00:00Z", distanciaM = 30,
    )

    private class Tentativa(val codigo: String, val distancia: Int?)

    private class Cenario(val resposta: Result<ResultadoRegistroDto>, val distancia: Int? = 30) {
        val enviadas = mutableListOf<Tentativa>()
        var medicoes = 0
        var avisos = 0
        val vm = ValidacaoDoCodigoViewModel(
            turnoId = "t1",
            validar = { _, codigo, distancia -> enviadas += Tentativa(codigo, distancia); resposta },
            medirDistancia = { medicoes++; distancia },
            aoPresencaVerificada = { avisos++ },
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun erro(codigo: CodigoErroAPI, original: String, detalhes: String? = null) =
        ErroDaApi(codigo = codigo, codigoOriginal = original, detalhes = detalhes, mensagemCrua = "x")

    @Test
    fun `comeca aguardando, sem pedir nada`() {
        val c = Cenario(Result.success(registro))

        assertEquals(ResultadoDaValidacao.Aguardando, c.vm.estado.value)
        assertTrue(c.enviadas.isEmpty())
        assertEquals(0, c.medicoes)
    }

    @Test
    fun `codigo certo a ate 50 metros envia so a distancia e fica verificado, avisando a tela`() = runBlocking {
        val c = Cenario(Result.success(registro), distancia = 30)

        c.vm.validar("049215").join()

        assertEquals(ResultadoDaValidacao.Verificado(registro), c.vm.estado.value)
        assertEquals(listOf("049215"), c.enviadas.map { it.codigo })
        assertEquals(listOf<Int?>(30), c.enviadas.map { it.distancia })
        assertEquals(1, c.avisos)
    }

    @Test
    fun `exatamente 50 metros ainda envia`() = runBlocking {
        val c = Cenario(Result.success(registro), distancia = 50)

        c.vm.validar("049215").join()

        assertEquals(1, c.enviadas.size)
    }

    @Test
    fun `formato errado nem le a localizacao nem envia`() = runBlocking {
        for (ruim in listOf("", "12345", "1234567", "12345a")) {
            val c = Cenario(Result.success(registro))

            c.vm.validar(ruim).join()

            assertEquals(ResultadoDaValidacao.FormatoInvalido, c.vm.estado.value, "'$ruim'")
            assertTrue(c.enviadas.isEmpty())
            assertEquals(0, c.medicoes)
        }
    }

    @Test
    fun `acima de 50 metros pede para chegar mais perto e nao gasta tentativa`() = runBlocking {
        val c = Cenario(Result.success(registro), distancia = 80)

        c.vm.validar("049215").join()

        assertEquals(ResultadoDaValidacao.ChegueMaisPerto(80), c.vm.estado.value)
        assertTrue(c.enviadas.isEmpty())
    }

    @Test
    fun `sem localizacao nao envia e manda pedir a confirmacao da casa`() = runBlocking {
        val c = Cenario(Result.success(registro), distancia = null)

        c.vm.validar("049215").join()

        assertEquals(ResultadoDaValidacao.SemLocalizacao, c.vm.estado.value)
        assertTrue(c.enviadas.isEmpty())
    }

    @Test
    fun `cada recusa do servidor vira o resultado certo`() = runBlocking {
        val casos = listOf(
            Triple(erro(CodigoErroAPI.CODIGO_INVALIDO, "codigo_invalido"), ResultadoDaValidacao.Invalido, "codigo_invalido"),
            Triple(erro(CodigoErroAPI.CODIGO_BLOQUEADO, "codigo_bloqueado", "temporario"), ResultadoDaValidacao.Bloqueado(BloqueioDoCodigo.TEMPORARIO), "temporario"),
            Triple(erro(CodigoErroAPI.CODIGO_BLOQUEADO, "codigo_bloqueado", "encerrado"), ResultadoDaValidacao.Bloqueado(BloqueioDoCodigo.ENCERRADO), "encerrado"),
            // Sem `details` conhecido vale o mais restritivo: o app não promete tentativa que o servidor não dá.
            Triple(erro(CodigoErroAPI.CODIGO_BLOQUEADO, "codigo_bloqueado"), ResultadoDaValidacao.Bloqueado(BloqueioDoCodigo.ENCERRADO), "bloqueio sem details"),
            Triple(erro(CodigoErroAPI.FORA_DO_RAIO, "fora_do_raio"), ResultadoDaValidacao.ForaDoRaio, "fora_do_raio"),
            Triple(erro(CodigoErroAPI.SEM_LOCALIZACAO, "sem_localizacao"), ResultadoDaValidacao.SemLocalizacao, "sem_localizacao"),
            // O que vale é o `codigo` do domínio, não o texto cru do servidor (`codigoOriginal` qualquer): sem comparar string solta.
            Triple(erro(CodigoErroAPI.CODIGO_INVALIDO, "qualquer"), ResultadoDaValidacao.Invalido, "so o codigo: invalido"),
            Triple(erro(CodigoErroAPI.CODIGO_BLOQUEADO, "qualquer", "temporario"), ResultadoDaValidacao.Bloqueado(BloqueioDoCodigo.TEMPORARIO), "so o codigo: bloqueado"),
            Triple(erro(CodigoErroAPI.FORA_DO_RAIO, "qualquer"), ResultadoDaValidacao.ForaDoRaio, "so o codigo: fora do raio"),
            Triple(erro(CodigoErroAPI.SEM_LOCALIZACAO, "qualquer"), ResultadoDaValidacao.SemLocalizacao, "so o codigo: sem localizacao"),
            Triple(erro(CodigoErroAPI.RECURSO_DESLIGADO, "qualquer"), ResultadoDaValidacao.RecursoDesligado, "so o codigo: recurso desligado"),
            Triple(erro(CodigoErroAPI.DESCONHECIDO, "fora_do_raio"), ResultadoDaValidacao.Falhou, "texto cru sem o codigo nao vale"),
            Triple(erro(CodigoErroAPI.CAMPO_INVALIDO, "campo_invalido"), ResultadoDaValidacao.FormatoInvalido, "campo_invalido"),
            Triple(erro(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "recurso_desligado"), ResultadoDaValidacao.RecursoDesligado, "recurso desligado"),
            Triple(erro(CodigoErroAPI.SEM_REDE, "sem_rede"), ResultadoDaValidacao.RespostaPerdida, "sem rede"),
            Triple(erro(CodigoErroAPI.CHECKIN_PENDENTE, "checkin_pendente"), ResultadoDaValidacao.Falhou, "checkin_pendente"),
            Triple(erro(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "conta_suspensa"), ResultadoDaValidacao.Falhou, "conta suspensa"),
        )
        for ((falha, esperado, nome) in casos) {
            val c = Cenario(Result.failure(falha))

            c.vm.validar("049215").join()

            assertEquals(esperado, c.vm.estado.value, nome)
            assertEquals(0, c.avisos, nome)
        }
    }

    @Test
    fun `leitura que chegou antes ja verificou a presenca, entao avisa a tela para reler o turno`() = runBlocking {
        val c = Cenario(Result.failure(erro(CodigoErroAPI.CHECKIN_JA_CONFIRMADO, "checkin_ja_confirmado")))

        c.vm.validar("049215").join()

        assertEquals(ResultadoDaValidacao.JaVerificado, c.vm.estado.value)
        assertEquals(1, c.avisos)
    }

    @Test
    fun `resposta perdida nao repete sozinha, a tentativa errada ja pode ter sido gravada`() = runBlocking {
        val c = Cenario(Result.failure(java.io.IOException("tempo esgotado")))

        c.vm.validar("049215").join()

        assertEquals(ResultadoDaValidacao.RespostaPerdida, c.vm.estado.value)
        assertEquals(1, c.enviadas.size)
    }

    @Test
    fun `excecao que escapa de validar vira resposta perdida, sem prender o botao`() = runBlocking {
        val vm = ValidacaoDoCodigoViewModel(
            turnoId = "t1",
            validar = { _, _, _ -> throw IllegalStateException("escapou") },
            medirDistancia = { 10 },
            escopo = CoroutineScope(Dispatchers.Default),
        )

        vm.validar("049215").join()

        assertEquals(ResultadoDaValidacao.RespostaPerdida, vm.estado.value)
    }

    @Test
    fun `dois toques com a chamada em voo enviam uma tentativa so`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var envios = 0
        val vm = ValidacaoDoCodigoViewModel(
            turnoId = "t1",
            validar = { _, _, _ -> envios++; liberar.await(); Result.success(registro) },
            medirDistancia = { 10 },
            escopo = CoroutineScope(Dispatchers.Default),
        )

        val primeiro = vm.validar("049215")
        withTimeout(5_000) { while (vm.estado.value != ResultadoDaValidacao.Enviando || envios == 0) yield() }
        val segundo = vm.validar("049215")
        liberar.complete(Unit)
        primeiro.join()
        segundo.join()

        assertEquals(1, envios)
    }

    @Test
    fun `depois de uma recusa da para digitar de novo`() = runBlocking {
        var chamadas = 0
        val vm = ValidacaoDoCodigoViewModel(
            turnoId = "t1",
            validar = { _, _, _ ->
                chamadas++
                if (chamadas == 1) Result.failure(erro(CodigoErroAPI.CODIGO_INVALIDO, "codigo_invalido")) else Result.success(registro)
            },
            medirDistancia = { 10 },
            escopo = CoroutineScope(Dispatchers.Default),
        )
        vm.validar("111111").join()

        vm.validar("049215").join()

        assertEquals(ResultadoDaValidacao.Verificado(registro), vm.estado.value)
        assertEquals(2, chamadas)
    }
}
