package br.com.frila.feature.equipe.casa

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.AdministracaoTransferidaDto
import br.com.frila.core.rede.ConviteMembroDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MembroDoEstabelecimentoDto
import br.com.frila.core.rede.MembroRemovidoDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class EquipeDaCasaViewModelTest {

    private val casa = "11111111-1111-4111-8111-111111111111"
    private val token = "ab".repeat(32)

    private val ana = MembroDoEstabelecimentoDto("m-ana", "Ana Souza", "administrador", "2026-10-01T12:00:00Z", true)
    private val beto = MembroDoEstabelecimentoDto("m-beto", "Beto Lima", "operador", "2026-11-02T09:30:00Z", false)
    private val carla = MembroDoEstabelecimentoDto("m-carla", "Carla Dias", "administrador", "2026-10-15T09:30:00Z", false)

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    /** Servidor falso: tudo é configurável por teste, e cada chamada fica anotada. */
    private class Servidor {
        var membros: List<MembroDoEstabelecimentoDto> = emptyList()
        var falhaDaLista: Throwable? = null
        var falhaDoConvite: Throwable? = null
        var falhaDaAcao: Throwable? = null
        var tokenDoConvite: String = ""
        val leituras = mutableListOf<String>()
        val convites = mutableListOf<Triple<String, String, String>>()
        val remocoes = mutableListOf<Pair<String, String>>()
        val transferencias = mutableListOf<Pair<String, String>>()
    }

    private fun viewModel(
        servidor: Servidor,
        papel: PapelMembro? = PapelMembro.ADMINISTRADOR,
        links: MutableList<String> = mutableListOf(),
    ) = EquipeDaCasaViewModel(
        estabelecimentoId = casa,
        papel = papel,
        listar = { id ->
            servidor.leituras += id
            servidor.falhaDaLista?.let { throw it }
            servidor.membros
        },
        convidar = { id, email, papelConvidado ->
            servidor.convites += Triple(id, email, papelConvidado)
            servidor.falhaDoConvite?.let { throw it }
            ConviteMembroDto("c1", servidor.tokenDoConvite, "2026-11-25T15:00:00Z", id, email, papelConvidado)
        },
        remover = { id, membro ->
            servidor.remocoes += id to membro
            servidor.falhaDaAcao?.let { throw it }
            MembroRemovidoDto("membro_removido", true, id, membro)
        },
        transferir = { id, novo ->
            servidor.transferencias += id to novo
            servidor.falhaDaAcao?.let { throw it }
            AdministracaoTransferidaDto("administracao_transferida", id, novo, null, "administrador")
        },
        montarLink = { token -> links += token; "https://frilabr.com/app/convite#$token" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun servidorComEquipe() = Servidor().apply {
        membros = listOf(ana, carla, beto)
        tokenDoConvite = token
    }

    // ---- Lista ----

    @Test
    fun `administrador ve a lista com o papel e quem e voce`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor)

        vm.carregar().join()

        val lista = vm.estado.value.lista as ListaDaEquipe.Conteudo
        assertEquals(listOf("Ana Souza", "Carla Dias", "Beto Lima"), lista.membros.map { it.nome })
        assertEquals(listOf(PapelMembro.ADMINISTRADOR, PapelMembro.ADMINISTRADOR, PapelMembro.OPERADOR), lista.membros.map { it.papel })
        assertEquals(listOf(true, false, false), lista.membros.map { it.eVoce })
        assertNotNull(lista.membros[0].desde)
        assertEquals(listOf(casa), servidor.leituras)
        assertTrue(vm.estado.value.podeGerenciar)
    }

    @Test
    fun `membro comum nao pede a lista e nao tem acao de administrador`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor, papel = PapelMembro.OPERADOR)

        vm.carregar().join()
        vm.editarEmail("novo@bar.com")
        vm.gerarConvite().join()
        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, MembroDaCasa("m-beto", "Beto Lima", PapelMembro.OPERADOR, null, false))
        vm.confirmar().join()

        val estado = vm.estado.value
        assertEquals(ListaDaEquipe.SoAdministrador, estado.lista)
        assertFalse(estado.podeGerenciar)
        assertTrue(servidor.leituras.isEmpty())
        assertTrue(servidor.convites.isEmpty())
        assertTrue(servidor.remocoes.isEmpty())
        assertNull(estado.pendente)
        assertEquals("", estado.email)
    }

    @Test
    fun `papel que o app nao conhece tambem nao gerencia`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor, papel = null)

        vm.carregar().join()

        assertEquals(ListaDaEquipe.SoAdministrador, vm.estado.value.lista)
        assertTrue(servidor.leituras.isEmpty())
    }

    @Test
    fun `403 da lista, mesmo para quem se achava administrador, vira so administrador`() = runBlocking {
        val servidor = servidorComEquipe().apply { falhaDaLista = erro(CodigoErroAPI.SEM_PERMISSAO) }
        val vm = viewModel(servidor)

        vm.carregar().join()

        assertEquals(ListaDaEquipe.SoAdministrador, vm.estado.value.lista)
    }

    @Test
    fun `conta suspensa, sem rede e resposta ilegivel tem mensagem propria e deixam tentar de novo`() = runBlocking {
        val casos = listOf(
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to TextosEquipeDaCasa.CONTA_SUSPENSA,
            erro(CodigoErroAPI.SEM_REDE) to TextosEquipeDaCasa.SEM_REDE,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosEquipeDaCasa.SESSAO,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosEquipeDaCasa.ERRO_DA_LISTA,
            IllegalStateException("corpo não é JSON") to TextosEquipeDaCasa.ERRO_DA_LISTA,
        )
        casos.forEach { (falha, mensagem) ->
            val servidor = servidorComEquipe().apply { falhaDaLista = falha }
            val vm = viewModel(servidor)
            vm.carregar().join()
            assertEquals(ListaDaEquipe.Erro(mensagem), vm.estado.value.lista, falha.toString())
            servidor.falhaDaLista = null
            vm.carregar().join()
            assertTrue(vm.estado.value.lista is ListaDaEquipe.Conteudo)
        }
    }

    // ---- Convite ----

    @Test
    fun `gerar convite manda estabelecimento, e-mail e papel e monta o link da web com o token`() = runBlocking {
        val servidor = servidorComEquipe()
        val links = mutableListOf<String>()
        val vm = viewModel(servidor, links = links)
        vm.editarEmail("  novo@bar.com  ")
        vm.escolherPapel(PapelMembro.ADMINISTRADOR)

        vm.gerarConvite().join()

        assertEquals(listOf(Triple(casa, "novo@bar.com", "administrador")), servidor.convites)
        assertEquals(listOf(token), links)
        val convite = vm.estado.value.convite!!
        assertEquals("https://frilabr.com/app/convite#$token", convite.link)
        assertEquals("novo@bar.com", convite.email)
        assertEquals(PapelMembro.ADMINISTRADOR, convite.papel)
        assertNotNull(convite.expiraEm)
        assertEquals("", vm.estado.value.email)
        assertFalse(vm.estado.value.gerandoConvite)
        assertNull(vm.estado.value.erroDoConvite)

        // Trocar o papel no formulário depois de gerar não muda o papel do convite já pronto.
        vm.escolherPapel(PapelMembro.OPERADOR)
        assertEquals(PapelMembro.ADMINISTRADOR, vm.estado.value.convite?.papel)
    }

    @Test
    fun `e-mail invalido nao chega a rede`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor)
        listOf("", "sem-arroba", "a@b", "a b@c.com").forEach { texto ->
            vm.editarEmail(texto)
            vm.gerarConvite().join()
            assertEquals(TextosEquipeDaCasa.EMAIL_INVALIDO, vm.estado.value.erroDoEmail, texto)
        }
        assertTrue(servidor.convites.isEmpty())
        vm.editarEmail("ok@bar.com")
        assertNull(vm.estado.value.erroDoEmail)
    }

    @Test
    fun `recusas do convite viram mensagem do Frila`() = runBlocking {
        val casos = listOf(
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to TextosEquipeDaCasa.CONTA_SUSPENSA,
            erro(CodigoErroAPI.NAO_ENCONTRADO) to TextosEquipeDaCasa.INDISPONIVEL,
            erro(CodigoErroAPI.CAMPO_OBRIGATORIO, "papel") to TextosEquipeDaCasa.PAPEL_INVALIDO,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosEquipeDaCasa.SESSAO,
            erro(CodigoErroAPI.SEM_REDE) to TextosEquipeDaCasa.SEM_REDE,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosEquipeDaCasa.ERRO,
            IllegalStateException("corpo não é JSON") to TextosEquipeDaCasa.ERRO,
        )
        casos.forEach { (falha, mensagem) ->
            val servidor = servidorComEquipe().apply { falhaDoConvite = falha }
            val vm = viewModel(servidor)
            vm.editarEmail("novo@bar.com")
            vm.gerarConvite().join()
            assertEquals(mensagem, vm.estado.value.erroDoConvite, falha.toString())
            assertNull(vm.estado.value.convite)
            assertFalse(vm.estado.value.gerandoConvite)
            assertEquals("novo@bar.com", vm.estado.value.email)
        }
    }

    @Test
    fun `422 de e-mail do servidor marca o campo`() = runBlocking {
        val servidor = servidorComEquipe().apply { falhaDoConvite = erro(CodigoErroAPI.CAMPO_INVALIDO, "email") }
        val vm = viewModel(servidor)
        vm.editarEmail("novo@bar.com")

        vm.gerarConvite().join()

        assertEquals(TextosEquipeDaCasa.EMAIL_INVALIDO, vm.estado.value.erroDoEmail)
        assertNull(vm.estado.value.erroDoConvite)
    }

    @Test
    fun `token fora do formato nao vira link`() = runBlocking {
        val servidor = servidorComEquipe().apply { tokenDoConvite = "curto" }
        val links = mutableListOf<String>()
        val vm = viewModel(servidor, links = links)
        vm.editarEmail("novo@bar.com")

        vm.gerarConvite().join()

        assertNull(vm.estado.value.convite)
        assertTrue(links.isEmpty())
        assertEquals(TextosEquipeDaCasa.ERRO, vm.estado.value.erroDoConvite)
    }

    @Test
    fun `segundo toque durante a geracao nao manda segundo convite`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val convites = mutableListOf<String>()
        val vm = EquipeDaCasaViewModel(
            estabelecimentoId = casa,
            papel = PapelMembro.ADMINISTRADOR,
            listar = { emptyList() },
            convidar = { id, email, papel -> convites += email; liberar.await(); ConviteMembroDto("c1", token, "2026-11-25T15:00:00Z", id, email, papel) },
            remover = { _, _ -> error("não deveria") },
            transferir = { _, _ -> error("não deveria") },
            montarLink = { "https://frilabr.com/app/convite#$it" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.editarEmail("novo@bar.com")

        val primeiro = vm.gerarConvite()
        assertTrue(vm.estado.value.gerandoConvite)
        vm.gerarConvite()
        liberar.complete(Unit)
        withTimeout(5_000) { primeiro.join() }

        assertEquals(1, convites.size)
    }

    // ---- Remover e transferir ----

    private fun MembroDoEstabelecimentoDto.paraTela() = paraMembroDaCasa()

    @Test
    fun `remover pede confirmacao, chama o servidor e relê a lista`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor)
        vm.carregar().join()

        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, beto.paraTela())
        assertEquals(AcaoPendente(AcaoSobreMembro.REMOVER, "m-beto", "Beto Lima"), vm.estado.value.pendente)
        assertTrue(servidor.remocoes.isEmpty())
        servidor.membros = listOf(ana, carla)

        vm.confirmar().join()

        assertEquals(listOf(casa to "m-beto"), servidor.remocoes)
        assertEquals(TextosEquipeDaCasa.REMOVIDA, vm.estado.value.aviso)
        assertNull(vm.estado.value.pendente)
        assertNull(vm.estado.value.agindoEm)
        assertEquals(2, servidor.leituras.size)
        assertEquals(listOf("Ana Souza", "Carla Dias"), (vm.estado.value.lista as ListaDaEquipe.Conteudo).membros.map { it.nome })
    }

    @Test
    fun `cancelar a confirmacao nao chama o servidor`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor)
        vm.carregar().join()
        vm.pedirConfirmacao(AcaoSobreMembro.TRANSFERIR, beto.paraTela())

        vm.cancelarConfirmacao()
        vm.confirmar().join()

        assertNull(vm.estado.value.pendente)
        assertTrue(servidor.transferencias.isEmpty() && servidor.remocoes.isEmpty())
    }

    @Test
    fun `tornar administrador manda novo_admin_id e mostra o aviso`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor)
        vm.carregar().join()
        vm.pedirConfirmacao(AcaoSobreMembro.TRANSFERIR, beto.paraTela())

        vm.confirmar().join()

        assertEquals(listOf(casa to "m-beto"), servidor.transferencias)
        assertEquals(TextosEquipeDaCasa.TRANSFERIDA, vm.estado.value.aviso)
    }

    @Test
    fun `a linha de voce nao tem remover nem transferir`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor)
        vm.carregar().join()

        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, ana.paraTela())
        vm.pedirConfirmacao(AcaoSobreMembro.TRANSFERIR, ana.paraTela())

        assertNull(vm.estado.value.pendente)
    }

    @Test
    fun `recusas de remover e transferir que nao sao 403 viram mensagem e a lista e relida do servidor`() = runBlocking {
        val casos = listOf(
            erro(CodigoErroAPI.ULTIMO_ADMINISTRADOR) to TextosEquipeDaCasa.ULTIMO_ADMINISTRADOR,
            erro(CodigoErroAPI.NAO_ENCONTRADO) to TextosEquipeDaCasa.INDISPONIVEL,
            erro(CodigoErroAPI.SEM_REDE) to TextosEquipeDaCasa.SEM_REDE,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosEquipeDaCasa.ERRO,
            IllegalStateException("corpo não é JSON") to TextosEquipeDaCasa.ERRO,
        )
        AcaoSobreMembro.entries.forEach { acao ->
            casos.forEach { (falha, mensagem) ->
                val servidor = servidorComEquipe().apply { falhaDaAcao = falha }
                val vm = viewModel(servidor)
                vm.carregar().join()
                vm.pedirConfirmacao(acao, beto.paraTela())
                // Enquanto a ação falha, o servidor já mudou: quem tinha sido removido por outro admin não está mais na lista.
                servidor.membros = listOf(ana, carla)

                vm.confirmar().join()

                assertEquals(mensagem, vm.estado.value.erroDaAcao, "$acao $falha")
                assertNull(vm.estado.value.aviso)
                assertNull(vm.estado.value.agindoEm)
                assertEquals(2, servidor.leituras.size, "$acao $falha: a lista é relida depois da recusa")
                assertEquals(listOf("Ana Souza", "Carla Dias"), (vm.estado.value.lista as ListaDaEquipe.Conteudo).membros.map { it.nome }, "$acao $falha")
                assertTrue(vm.estado.value.podeGerenciar)
            }
        }
    }

    // Parecer do Lince Codex no #998: 403 sem_permissao é "você não é (mais) administrador".

    @Test
    fun `403 da lista tira a capacidade de administrador e o convite nao chega a rede`() = runBlocking {
        val servidor = servidorComEquipe().apply { falhaDaLista = erro(CodigoErroAPI.SEM_PERMISSAO) }
        val vm = viewModel(servidor)

        vm.carregar().join()
        vm.editarEmail("novo@bar.com")
        vm.gerarConvite().join()

        assertFalse(vm.estado.value.podeGerenciar)
        assertEquals(ListaDaEquipe.SoAdministrador, vm.estado.value.lista)
        assertTrue(servidor.convites.isEmpty())
        assertNull(vm.estado.value.convite)
    }

    @Test
    fun `403 de convidar tira a capacidade, a lista e o convite`() = runBlocking {
        val servidor = servidorComEquipe().apply { falhaDoConvite = erro(CodigoErroAPI.SEM_PERMISSAO) }
        val vm = viewModel(servidor)
        vm.carregar().join()
        vm.editarEmail("novo@bar.com")

        vm.gerarConvite().join()

        val estado = vm.estado.value
        assertFalse(estado.podeGerenciar)
        assertEquals(ListaDaEquipe.SoAdministrador, estado.lista)
        assertNull(estado.convite)
        assertNull(estado.pendente)
        assertEquals("", estado.email)
        // Sem capacidade, nem um segundo convite nem uma ação sobre alguém chegam ao servidor.
        vm.editarEmail("outro@bar.com")
        vm.gerarConvite().join()
        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, beto.paraTela())
        vm.confirmar().join()
        assertEquals(1, servidor.convites.size)
        assertTrue(servidor.remocoes.isEmpty())
    }

    @Test
    fun `403 de remover ou transferir some com a lista e nao deixa repetir a chamada`() = runBlocking {
        AcaoSobreMembro.entries.forEach { acao ->
            val servidor = servidorComEquipe().apply { falhaDaAcao = erro(CodigoErroAPI.SEM_PERMISSAO) }
            val vm = viewModel(servidor)
            vm.carregar().join()
            vm.pedirConfirmacao(acao, beto.paraTela())

            vm.confirmar().join()

            val estado = vm.estado.value
            assertFalse(estado.podeGerenciar, "$acao")
            assertEquals(ListaDaEquipe.SoAdministrador, estado.lista, "$acao")
            assertEquals(TextosEquipeDaCasa.SO_ADMINISTRADOR, estado.erroDaAcao, "$acao")
            assertNull(estado.pendente)
            assertNull(estado.agindoEm)
            vm.pedirConfirmacao(acao, beto.paraTela())
            assertNull(vm.estado.value.pendente, "$acao: sem capacidade não abre confirmação")
            vm.confirmar().join()
            assertEquals(1, servidor.remocoes.size + servidor.transferencias.size, "$acao chamada só uma vez")
        }
    }

    @Test
    fun `403 de conta suspensa na acao mostra a mensagem certa e tira a lista em vez de conservar a antiga`() = runBlocking {
        val servidor = servidorComEquipe().apply { falhaDaAcao = erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") }
        val vm = viewModel(servidor)
        vm.carregar().join()
        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, beto.paraTela())
        // A releitura do servidor também recusa pela mesma razão.
        servidor.falhaDaLista = erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa")

        vm.confirmar().join()

        assertEquals(TextosEquipeDaCasa.CONTA_SUSPENSA, vm.estado.value.erroDaAcao)
        assertEquals(ListaDaEquipe.Erro(TextosEquipeDaCasa.CONTA_SUSPENSA), vm.estado.value.lista)
    }

    @Test
    fun `falha da releitura depois da acao nao apaga a lista`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor)
        vm.carregar().join()
        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, beto.paraTela())
        servidor.falhaDaLista = erro(CodigoErroAPI.SEM_REDE)

        vm.confirmar().join()

        assertEquals(TextosEquipeDaCasa.REMOVIDA, vm.estado.value.aviso)
        assertTrue(vm.estado.value.lista is ListaDaEquipe.Conteudo)
    }

    @Test
    fun `papel desconhecido nao abre confirmacao de remover nem de transferir`() = runBlocking {
        val servidor = servidorComEquipe()
        val vm = viewModel(servidor, papel = PapelMembro.ADMINISTRADOR)
        vm.carregar().join()
        val desconhecido = MembroDaCasa("m-carla", "Carla Dias", null, null, false)

        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, desconhecido)
        assertNull(vm.estado.value.pendente)
        vm.pedirConfirmacao(AcaoSobreMembro.TRANSFERIR, desconhecido)
        assertNull(vm.estado.value.pendente)
        vm.confirmar().join()

        assertTrue(servidor.remocoes.isEmpty())
        // Quem tem papel conhecido segue podendo.
        vm.pedirConfirmacao(AcaoSobreMembro.REMOVER, MembroDaCasa("m-beto", "Beto Lima", PapelMembro.OPERADOR, null, false))
        assertNotNull(vm.estado.value.pendente)
    }
}
