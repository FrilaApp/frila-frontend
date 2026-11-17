package br.com.frila.feature.turnos.contratante

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CodigoDeCheckinDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-5: o código de chegada que a casa mostra (`gerar_codigo_checkin`, 0.2.68). Espelha `CodigoDaCasaViewModelTests` do iOS. */
class CodigoDaCasaViewModelTest {

    private fun codigo(digitos: String = "049215", restantes: Int = 272) =
        CodigoDeCheckinDto(turnoId = "t1", codigo = digitos, expiraEm = "2026-11-12T21:05:00Z", segundosRestantes = restantes)

    private fun erro(codigo: CodigoErroAPI, original: String, detalhes: String? = null) =
        ErroDaApi(codigo = codigo, codigoOriginal = original, detalhes = detalhes, mensagemCrua = "x")

    /**
     * Servidor falso: devolve a primeira resposta e depois a segunda (se houver); a última se repete.
     * Guarda os turnos pedidos. (Kotlin proíbe `vararg` de `Result`, por isso dois parâmetros.)
     */
    private class Servidor(primeira: Result<CodigoDeCheckinDto>, segunda: Result<CodigoDeCheckinDto>? = null) {
        private val fila = listOfNotNull(primeira, segunda).toMutableList()
        val turnosPedidos = mutableListOf<String>()
        suspend fun gerar(turnoId: String): Result<CodigoDeCheckinDto> {
            turnosPedidos += turnoId
            return if (fila.size > 1) fila.removeAt(0) else fila.first()
        }
    }

    private class Relogio(var ms: Long = 0) {
        fun agora() = ms
    }

    private fun viewModel(
        servidor: Servidor,
        relogio: Relogio = Relogio(),
        aoConfirmar: (() -> Unit)? = null,
    ) = CodigoDaCasaViewModel(
        turnoId = "t1",
        gerar = servidor::gerar,
        aoConfirmar = aoConfirmar,
        relogioMs = relogio::agora,
    )

    // ---- Carregar ----

    @Test
    fun `comeca carregando, sem pedir nada ao servidor antes da tela abrir`() {
        val servidor = Servidor(Result.success(codigo()))

        val vm = viewModel(servidor)

        assertEquals(EstadoDoCodigoDaCasa.Carregando, vm.estado.value.estado)
        assertTrue(servidor.turnosPedidos.isEmpty())
    }

    @Test
    fun `carregar mostra o codigo com o zero a esquerda e a validade que o servidor contou`() = runBlocking {
        val servidor = Servidor(Result.success(codigo("049215", restantes = 272)))
        val vm = viewModel(servidor)

        vm.carregar()

        assertEquals(EstadoDoCodigoDaCasa.Mostrando("049215"), vm.estado.value.estado)
        assertEquals(272, vm.estado.value.segundosRestantes)
        assertFalse(vm.estado.value.renovando)
        assertEquals(listOf("t1"), servidor.turnosPedidos)
    }

    @Test
    fun `duas chamadas ao mesmo tempo pedem o codigo uma vez so`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var chamadas = 0
        val vm = CodigoDaCasaViewModel(
            turnoId = "t1",
            gerar = {
                chamadas++
                liberar.await()
                Result.success(codigo())
            },
            relogioMs = { 0 },
        )

        val primeira = async(start = CoroutineStart.UNDISPATCHED) { vm.carregar() }
        yield()
        val segunda = async(start = CoroutineStart.UNDISPATCHED) { vm.carregar() }
        liberar.complete(Unit)
        primeira.await()
        segunda.await()

        assertEquals(1, chamadas)
        assertEquals(EstadoDoCodigoDaCasa.Mostrando("049215"), vm.estado.value.estado)
    }

    // ---- Contagem e renovação ----

    @Test
    fun `passo conta a validade pelo relogio monotonico e arredonda para cima`() = runBlocking {
        val relogio = Relogio()
        val vm = viewModel(Servidor(Result.success(codigo(restantes = 272))), relogio)
        vm.carregar()

        relogio.ms = 10_400
        vm.passo()

        assertEquals(262, vm.estado.value.segundosRestantes)
    }

    @Test
    fun `no zero pede outro codigo, mostra a renovacao e troca o codigo`() = runBlocking {
        val relogio = Relogio()
        val servidor = Servidor(Result.success(codigo("111111", restantes = 5)), Result.success(codigo("222222", restantes = 300)))
        val vm = viewModel(servidor, relogio)
        vm.carregar()

        relogio.ms = 5_000
        vm.passo()

        assertEquals(EstadoDoCodigoDaCasa.Mostrando("222222"), vm.estado.value.estado)
        assertEquals(300, vm.estado.value.segundosRestantes)
        assertFalse(vm.estado.value.renovando)
        assertEquals(2, servidor.turnosPedidos.size)
    }

    @Test
    fun `durante a renovacao o cartao avisa que gera outro codigo`() = runBlocking {
        val relogio = Relogio()
        val liberar = CompletableDeferred<Unit>()
        var chamadas = 0
        val vm = CodigoDaCasaViewModel(
            turnoId = "t1",
            gerar = {
                chamadas++
                if (chamadas == 1) {
                    Result.success(codigo("111111", restantes = 5))
                } else {
                    liberar.await()
                    Result.success(codigo("222222"))
                }
            },
            relogioMs = relogio::agora,
        )
        vm.carregar()
        relogio.ms = 5_000

        val renovacao = async(start = CoroutineStart.UNDISPATCHED) { vm.passo() }

        assertTrue(vm.estado.value.renovando)
        assertEquals(0, vm.estado.value.segundosRestantes)
        liberar.complete(Unit)
        renovacao.await()
        assertFalse(vm.estado.value.renovando)
    }

    @Test
    fun `passo sem codigo na tela nao pede nada`() = runBlocking {
        val servidor = Servidor(Result.failure(erro(CodigoErroAPI.CHECKIN_PENDENTE, "checkin_pendente")))
        val vm = viewModel(servidor)
        vm.carregar()

        vm.passo()

        assertEquals(1, servidor.turnosPedidos.size)
    }

    // ---- Recusas ----

    @Test
    fun `cada recusa do servidor vira o estado certo`() = runBlocking {
        val casos = listOf(
            Triple(erro(CodigoErroAPI.CHECKIN_PENDENTE, "checkin_pendente"), EstadoDoCodigoDaCasa.SemCodigoParaEsteCheckin, "checkin_pendente"),
            Triple(erro(CodigoErroAPI.FORA_DA_JANELA, "fora_da_janela"), EstadoDoCodigoDaCasa.ForaDaJanela, "fora_da_janela"),
            Triple(erro(CodigoErroAPI.DESCONHECIDO, "codigo_bloqueado", "encerrado"), EstadoDoCodigoDaCasa.Encerrado, "bloqueado encerrado"),
            // Sem `details` conhecido vale o mais restritivo, como o iOS.
            Triple(erro(CodigoErroAPI.DESCONHECIDO, "codigo_bloqueado"), EstadoDoCodigoDaCasa.Encerrado, "bloqueado sem details"),
            Triple(erro(CodigoErroAPI.CHECKIN_JA_CONFIRMADO, "checkin_ja_confirmado"), EstadoDoCodigoDaCasa.JaVerificado, "ja confirmado"),
            Triple(erro(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "recurso_desligado"), EstadoDoCodigoDaCasa.Indisponivel, "recurso desligado"),
            Triple(erro(CodigoErroAPI.DESCONHECIDO, "recurso_desligado"), EstadoDoCodigoDaCasa.Indisponivel, "recurso desligado solto"),
            Triple(erro(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao"), EstadoDoCodigoDaCasa.Falhou, "sem permissao"),
            Triple(erro(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "conta_suspensa"), EstadoDoCodigoDaCasa.Falhou, "conta suspensa"),
            Triple(erro(CodigoErroAPI.NAO_ENCONTRADO, "nao_encontrado"), EstadoDoCodigoDaCasa.Falhou, "nao encontrado"),
            Triple(erro(CodigoErroAPI.SEM_REDE, "sem_rede"), EstadoDoCodigoDaCasa.Falhou, "sem rede"),
        )
        for ((falha, esperado, nome) in casos) {
            val vm = viewModel(Servidor(Result.failure(falha)))

            vm.carregar()

            assertEquals(esperado, vm.estado.value.estado, nome)
            assertEquals(0, vm.estado.value.segundosRestantes, nome)
        }
    }

    @Test
    fun `presenca ja verificada avisa a tela do turno uma vez`() = runBlocking {
        var avisos = 0
        val vm = viewModel(
            Servidor(Result.failure(erro(CodigoErroAPI.CHECKIN_JA_CONFIRMADO, "checkin_ja_confirmado"))),
            aoConfirmar = { avisos++ },
        )

        vm.carregar()

        assertEquals(1, avisos)
    }

    @Test
    fun `falha que nao e da API e excecao inesperada viram falha sem prender o cartao`() = runBlocking {
        val semJson = viewModel(Servidor(Result.failure(IllegalStateException("corpo ilegivel"))))
        val lancou = CodigoDaCasaViewModel(turnoId = "t1", gerar = { throw IllegalStateException("escapou") }, relogioMs = { 0 })

        semJson.carregar()
        lancou.carregar()

        assertEquals(EstadoDoCodigoDaCasa.Falhou, semJson.estado.value.estado)
        assertEquals(EstadoDoCodigoDaCasa.Falhou, lancou.estado.value.estado)
    }

    @Test
    fun `tentar de novo sai da falha e mostra o codigo`() = runBlocking {
        val servidor = Servidor(
            Result.failure(erro(CodigoErroAPI.SEM_REDE, "sem_rede")),
            Result.success(codigo("123456")),
        )
        val vm = viewModel(servidor)
        vm.carregar()

        vm.tentarDeNovo()

        assertEquals(EstadoDoCodigoDaCasa.Mostrando("123456"), vm.estado.value.estado)
    }

    // ---- Releitura de 5 s ----

    @Test
    fun `releitura com o codigo na tela detecta a confirmacao do profissional`() = runBlocking {
        var avisos = 0
        val servidor = Servidor(
            Result.success(codigo()),
            Result.failure(erro(CodigoErroAPI.CHECKIN_JA_CONFIRMADO, "checkin_ja_confirmado")),
        )
        val vm = viewModel(servidor, aoConfirmar = { avisos++ })
        vm.carregar()

        vm.verificarConfirmacao()

        assertEquals(EstadoDoCodigoDaCasa.JaVerificado, vm.estado.value.estado)
        assertEquals(1, avisos)
    }

    @Test
    fun `erro de rede na releitura nao tira o codigo da tela`() = runBlocking {
        val servidor = Servidor(
            Result.success(codigo("049215")),
            Result.failure(erro(CodigoErroAPI.SEM_REDE, "sem_rede")),
        )
        val vm = viewModel(servidor)
        vm.carregar()

        vm.verificarConfirmacao()

        assertEquals(EstadoDoCodigoDaCasa.Mostrando("049215"), vm.estado.value.estado)
        assertTrue(vm.estado.value.segundosRestantes > 0)
    }

    @Test
    fun `sem codigo para este check-in a releitura passa a mostrar o codigo quando o profissional chega perto`() = runBlocking {
        val servidor = Servidor(
            Result.failure(erro(CodigoErroAPI.CHECKIN_PENDENTE, "checkin_pendente")),
            Result.success(codigo("654321")),
        )
        val vm = viewModel(servidor)
        vm.carregar()

        vm.verificarConfirmacao()

        assertEquals(EstadoDoCodigoDaCasa.Mostrando("654321"), vm.estado.value.estado)
    }

    @Test
    fun `releitura so acontece com codigo ou aviso de sem codigo na tela`() = runBlocking {
        val servidor = Servidor(Result.failure(erro(CodigoErroAPI.FORA_DA_JANELA, "fora_da_janela")))
        val vm = viewModel(servidor)
        vm.carregar()

        vm.verificarConfirmacao()

        assertEquals(1, servidor.turnosPedidos.size)
    }

    // ---- Formato ----

    @Test
    fun `formata a validade como minutos e segundos`() {
        assertEquals("4:32", CodigoDaCasaViewModel.formatar(272))
        assertEquals("5:00", CodigoDaCasaViewModel.formatar(300))
        assertEquals("0:05", CodigoDaCasaViewModel.formatar(5))
        assertEquals("0:00", CodigoDaCasaViewModel.formatar(0))
        assertEquals("0:00", CodigoDaCasaViewModel.formatar(-3))
    }
}
