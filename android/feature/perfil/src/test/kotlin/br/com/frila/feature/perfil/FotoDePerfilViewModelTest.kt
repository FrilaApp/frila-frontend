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
            FotoDePerfilViewModel.mensagemDaFalha(erroDaApi(CodigoErroAPI.DESCONHECIDO, "midia_invalida", "formato")),
        )
        assertEquals(TextosDaFotoDePerfil.ERRO_INDISPONIVEL_AGORA, FotoDePerfilViewModel.mensagemDaFalha(IllegalStateException("x")))
    }
}
