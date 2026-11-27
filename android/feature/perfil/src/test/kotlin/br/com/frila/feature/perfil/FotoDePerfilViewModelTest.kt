package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MidiaDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-3b: escolher a foto, preparar, conferir no aparelho e enviar; sem rosto avisa e deixa "enviar mesmo assim". */
class FotoDePerfilViewModelTest {

    private val jpeg = byteArrayOf(9, 8, 7)
    private val midia = MidiaDto(id = "m1", tipo = "foto_perfil", estado = "em_analise", podePedirNovaAnalise = false)

    private class Chamadas {
        val preparos = mutableListOf<String>()
        val envios = mutableListOf<Pair<List<Byte>, Boolean>>()
    }

    private fun viewModel(
        chamadas: Chamadas,
        preparar: suspend (String) -> ByteArray = { jpegPronto -> byteArrayOf(9, 8, 7).also { chamadas.preparos += jpegPronto } },
        enviar: suspend (ByteArray, Boolean) -> SaidaDoEnvioDaFoto,
    ) = FotoDePerfilViewModel(
        prepararJpeg = preparar,
        enviar = { bytes, mesmoAssim ->
            chamadas.envios += bytes.toList() to mesmoAssim
            enviar(bytes, mesmoAssim)
        },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `escolher prepara, envia sem forcar e termina em analise`() = runBlocking {
        val c = Chamadas()
        val vm = viewModel(c) { _, _ -> SaidaDoEnvioDaFoto.Enviada(midia) }
        vm.escolher("content://foto/1")
        assertEquals(EtapaDaFoto.Enviada(midia), vm.etapa.value)
        assertEquals(listOf("content://foto/1"), c.preparos)
        assertEquals(listOf(jpeg.toList() to false), c.envios)
    }

    @Test
    fun `durante o envio a etapa e Enviando e um segundo toque nao envia de novo`() = runBlocking {
        val c = Chamadas()
        val porta = CompletableDeferred<SaidaDoEnvioDaFoto>()
        val vm = viewModel(c) { _, _ -> porta.await() }
        vm.escolher("content://foto/1")
        assertEquals(EtapaDaFoto.Enviando, vm.etapa.value)
        vm.escolher("content://foto/2")
        vm.enviarMesmoAssim()
        vm.tentarDeNovo()
        assertEquals(1, c.envios.size)
        assertEquals(listOf("content://foto/1"), c.preparos)
        porta.complete(SaidaDoEnvioDaFoto.Enviada(midia))
        withTimeout(5_000) { while (vm.etapa.value == EtapaDaFoto.Enviando) kotlinx.coroutines.yield() }
        assertEquals(EtapaDaFoto.Enviada(midia), vm.etapa.value)
    }

    @Test
    fun `sem rosto avisa, e enviar mesmo assim manda a mesma foto forcando, sem preparar de novo`() = runBlocking {
        val c = Chamadas()
        var resposta: SaidaDoEnvioDaFoto = SaidaDoEnvioDaFoto.AvisoSemRosto
        val vm = viewModel(c) { _, _ -> resposta }
        vm.escolher("content://foto/1")
        assertEquals(EtapaDaFoto.AvisoSemRosto, vm.etapa.value)
        resposta = SaidaDoEnvioDaFoto.Enviada(midia)
        vm.enviarMesmoAssim()
        assertEquals(EtapaDaFoto.Enviada(midia), vm.etapa.value)
        assertEquals(listOf(jpeg.toList() to false, jpeg.toList() to true), c.envios)
        assertEquals(1, c.preparos.size)
    }

    @Test
    fun `escolher outra no aviso descarta a foto e enviar mesmo assim deixa de valer`() = runBlocking {
        val c = Chamadas()
        val vm = viewModel(c) { _, _ -> SaidaDoEnvioDaFoto.AvisoSemRosto }
        vm.escolher("content://foto/1")
        vm.escolherOutra()
        assertEquals(EtapaDaFoto.Parada, vm.etapa.value)
        vm.enviarMesmoAssim()
        assertEquals(EtapaDaFoto.Parada, vm.etapa.value)
        assertEquals(1, c.envios.size)
    }

    @Test
    fun `mais de um rosto bloqueia e enviar mesmo assim nao faz nada`() = runBlocking {
        val c = Chamadas()
        val vm = viewModel(c) { _, _ -> SaidaDoEnvioDaFoto.Bloqueada(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS) }
        vm.escolher("content://foto/1")
        assertEquals(EtapaDaFoto.Bloqueada(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS), vm.etapa.value)
        vm.enviarMesmoAssim()
        assertEquals(1, c.envios.size)
    }

    @Test
    fun `foto ilegivel falha sem enviar nada`() = runBlocking {
        val c = Chamadas()
        val vm = viewModel(c, preparar = { error("não abriu") }) { _, _ -> SaidaDoEnvioDaFoto.Enviada(midia) }
        vm.escolher("content://foto/1")
        assertEquals(EtapaDaFoto.Falhou(TextosDaFotoDePerfil.ERRO_IMAGEM_INVALIDA), vm.etapa.value)
        assertTrue(c.envios.isEmpty())
        vm.tentarDeNovo() // sem foto guardada, "tentar de novo" volta ao começo para escolher outra
        assertEquals(EtapaDaFoto.Parada, vm.etapa.value)
    }

    @Test
    fun `falha de rede mostra a mensagem e tentar de novo reenvia a mesma foto`() = runBlocking {
        val c = Chamadas()
        var resposta: SaidaDoEnvioDaFoto = SaidaDoEnvioDaFoto.Falhou(erroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede"))
        val vm = viewModel(c) { _, _ -> resposta }
        vm.escolher("content://foto/1")
        assertEquals(EtapaDaFoto.Falhou(TextosDaFotoDePerfil.ERRO_SEM_REDE), vm.etapa.value)
        resposta = SaidaDoEnvioDaFoto.Enviada(midia)
        vm.tentarDeNovo()
        assertEquals(EtapaDaFoto.Enviada(midia), vm.etapa.value)
        assertEquals(1, c.preparos.size)
        assertEquals(2, c.envios.size)
    }

    private fun erroDaApi(codigo: CodigoErroAPI, original: String, detalhes: String? = null) =
        ErroDaApi(codigo, original, detalhes, "")

    @Test
    fun `as recusas do servidor viram o texto do iOS`() {
        assertEquals(
            TextosDaFotoDePerfil.ERRO_RECURSO_DESLIGADO,
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "recurso_desligado")),
        )
        assertEquals(
            TextosDaFotoDePerfil.ERRO_CONTA_SUSPENSA,
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.CONTA_SUSPENSA, "conta_suspensa")),
        )
        assertEquals(
            TextosDaFotoDePerfil.ERRO_CONTA_SUSPENSA,
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "conta_suspensa")),
        )
        assertEquals(
            TextosDaFotoDePerfil.ERRO_RECUSADA_PELO_SERVIDOR,
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.MIDIA_INVALIDA, "midia_invalida", "formato")),
        )
        assertEquals(TextosDaFotoDePerfil.ERRO_INDISPONIVEL_AGORA, FotoDePerfilViewModel.mensagemDaFalha(IllegalStateException("x")))
    }

    @Test
    fun `recurso desligado so vale no par do backend, 403 sem_permissao com details recurso_desligado`() {
        // O mesmo `details` sob outro code, ou o texto solto como code, não é o recurso desligado.
        assertEquals(
            TextosDaFotoDePerfil.ERRO_INDISPONIVEL_AGORA,
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.CAMPO_INVALIDO, "campo_invalido", "recurso_desligado")),
        )
        assertEquals(
            TextosDaFotoDePerfil.ERRO_INDISPONIVEL_AGORA,
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.RECURSO_DESLIGADO, "recurso_desligado")),
        )
        assertEquals(
            TextosDaFotoDePerfil.ERRO_RECURSO_DESLIGADO,
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "recurso_desligado")),
        )
    }

    // ---- Foto recusada ou não publicada: ver o estado e pedir nova análise (cartão 1dRm7FAH, fatia 1) ----

    private fun foto(
        id: String = "m1",
        estado: String = "recusada",
        motivo: String? = "foto_inadequada",
        podePedir: Boolean = true,
        enviadaEm: String = "2026-11-20T10:00:00Z",
        tipo: String = "foto_perfil",
        estabelecimentoId: String? = null,
    ) = MidiaDto(
        id = id, tipo = tipo, estado = estado, motivoRecusa = motivo, podePedirNovaAnalise = podePedir,
        estabelecimentoId = estabelecimentoId, enviadaEm = enviadaEm,
    )

    private fun viewModelDeMidias(
        listar: suspend () -> List<MidiaDto>,
        pedir: suspend (String) -> MidiaDto = { throw AssertionError("não devia pedir nova análise") },
    ) = FotoDePerfilViewModel(
        prepararJpeg = { byteArrayOf() },
        enviar = { _, _ -> throw AssertionError("não devia enviar") },
        listarMidias = listar,
        pedirNovaAnaliseMidia = pedir,
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `carregar mostra a foto recusada e oferece a nova analise`() = runBlocking {
        val vm = viewModelDeMidias(listar = { listOf(foto()) })

        vm.carregar().join()

        assertEquals("m1", vm.situacao.value.midia?.id)
        assertEquals("recusada", vm.situacao.value.midia?.estado)
        assertTrue(vm.situacao.value.podePedirNovaAnalise)
    }

    @Test
    fun `carregar fica com a foto de perfil mais recente da conta, sem a removida nem a da casa`() = runBlocking {
        val vm = viewModelDeMidias(
            listar = {
                listOf(
                    foto(id = "velha", estado = "aprovada", enviadaEm = "2026-11-01T10:00:00Z"),
                    foto(id = "nova", enviadaEm = "2026-11-20T10:00:00Z"),
                    foto(id = "removida", estado = "removida", enviadaEm = "2026-11-25T10:00:00Z"),
                    foto(id = "da-casa", estabelecimentoId = "e1", enviadaEm = "2026-11-26T10:00:00Z"),
                    foto(id = "outro-tipo", tipo = "logo", enviadaEm = "2026-11-27T10:00:00Z"),
                )
            },
        )

        vm.carregar().join()

        assertEquals("nova", vm.situacao.value.midia?.id)
    }

    @Test
    fun `nova analise so vale para recusada ou nao publicada que o servidor deixa pedir`() = runBlocking {
        val casos = listOf(
            foto(estado = "recusada") to true,
            foto(estado = "nao_publicada", motivo = null) to true,
            foto(estado = "nao_publicada", motivo = null, podePedir = false) to false,
            foto(estado = "recusada", podePedir = false) to false,
            foto(estado = "aprovada", motivo = null) to false,
            foto(estado = "em_analise", motivo = null) to false,
            foto(estado = "ocultada", motivo = null) to false,
        )
        for ((midia, esperado) in casos) {
            val pedidos = mutableListOf<String>()
            val vm = viewModelDeMidias(listar = { listOf(midia) }, pedir = { pedidos += it; midia })
            vm.carregar().join()
            val rotulo = "${midia.estado} pode=${midia.podePedirNovaAnalise}"
            assertEquals(esperado, vm.situacao.value.podePedirNovaAnalise, rotulo)

            vm.pedirNovaAnalise().join()

            assertEquals(if (esperado) listOf("m1") else emptyList<String>(), pedidos, rotulo)
        }
    }

    @Test
    fun `pedir a nova analise manda o id da foto e a foto vai a em analise, uma vez so`() = runBlocking {
        val pedidos = mutableListOf<String>()
        val vm = viewModelDeMidias(
            listar = { listOf(foto()) },
            pedir = { pedidos += it; foto(estado = "em_analise", motivo = null, podePedir = false) },
        )
        vm.carregar().join()

        vm.pedirNovaAnalise().join()

        assertEquals(listOf("m1"), pedidos)
        assertEquals("em_analise", vm.situacao.value.midia?.estado)
        assertTrue(vm.situacao.value.novaAnaliseJaPedida)
        assertEquals(false, vm.situacao.value.podePedirNovaAnalise)
        assertEquals(false, vm.situacao.value.pedindoNovaAnalise)
        assertEquals(null, vm.situacao.value.aviso)
    }

    @Test
    fun `a nova analise ja pedida continua valendo se a foto voltar recusada ao reler`() = runBlocking {
        val vm = viewModelDeMidias(
            listar = { listOf(foto()) },
            pedir = { foto(estado = "em_analise", motivo = null, podePedir = false) },
        )
        vm.carregar().join()
        vm.pedirNovaAnalise().join()

        vm.carregar().join() // a análise recusou de novo

        assertEquals("recusada", vm.situacao.value.midia?.estado)
        assertTrue(vm.situacao.value.novaAnaliseJaPedida)
        assertEquals(false, vm.situacao.value.podePedirNovaAnalise)
    }

    @Test
    fun `dois toques seguidos em pedir nova analise mandam um pedido so`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val pedidos = java.util.concurrent.atomic.AtomicInteger(0)
        val vm = FotoDePerfilViewModel(
            prepararJpeg = { byteArrayOf() },
            enviar = { _, _ -> throw AssertionError("não devia enviar") },
            listarMidias = { listOf(foto()) },
            pedirNovaAnaliseMidia = { pedidos.incrementAndGet(); liberar.await(); foto(estado = "em_analise", motivo = null, podePedir = false) },
            escopo = CoroutineScope(Dispatchers.Default),
        )
        vm.carregar().join()

        val primeiro = vm.pedirNovaAnalise()
        val segundo = vm.pedirNovaAnalise() // com o primeiro em voo
        assertTrue(vm.situacao.value.pedindoNovaAnalise)
        liberar.complete(Unit)
        primeiro.join()
        segundo.join()

        assertEquals(1, pedidos.get())
        assertEquals(false, vm.situacao.value.pedindoNovaAnalise)
    }

    @Test
    fun `falha ao pedir mostra o aviso, relê as midias e deixa pedir de novo`() = runBlocking {
        var leituras = 0
        val vm = viewModelDeMidias(
            listar = { leituras++; listOf(foto()) },
            pedir = { throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x") },
        )
        vm.carregar().join()

        vm.pedirNovaAnalise().join()

        assertEquals(TextosDaFotoDePerfil.ERRO_SEM_REDE, vm.situacao.value.aviso)
        assertEquals(2, leituras)
        assertEquals(false, vm.situacao.value.pedindoNovaAnalise)
        assertEquals(false, vm.situacao.value.novaAnaliseJaPedida)
        assertTrue(vm.situacao.value.podePedirNovaAnalise)
    }

    @Test
    fun `falha ao ler as midias nao derruba nada e deixa a tela sem foto`() = runBlocking {
        val vm = viewModelDeMidias(listar = { throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x") })

        vm.carregar().join()

        assertEquals(null, vm.situacao.value.midia)
        assertEquals(false, vm.situacao.value.podePedirNovaAnalise)
    }
}
