package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class RepositorioVagasTest {
    @TempDir lateinit var diretorio: File
    private val arquivo get() = File(diretorio, "vagas.json")
    private val vagas = listOf(VagaAbertaDto(
        id = "vaga-sintetica", funcao = FuncaoDto("funcao", "Atendimento", "Salão"),
        estabelecimento = PerfilPublicoDto("local", "estabelecimento", "Local de teste",
            reputacao = ReputacaoDto(0, 0, turnosConsiderados = 0, turnosRealizados = 0)),
        inicioEm = java.time.Instant.now().plusSeconds(3600).toString(), fimEm = java.time.Instant.now().plusSeconds(7200).toString(),
        local = "Local sintético", regiaoAdministrativa = "Região de teste", distanciaKm = 1.0,
        valorCentavos = 12000, posicoesAbertas = 1, inclusos = InclusosDto(false, false, false), modo = "selecao",
    ))
    private fun erro(codigo: CodigoErroAPI = CodigoErroAPI.SEM_REDE) =
        ErroDaApi(codigo, codigo.name, null, "Erro sintético")

    @Test fun `online persiste e nova instancia offline recupera as mesmas vagas`() = runTest {
        assertEquals(ResultadoVagas(vagas, false), RepositorioVagas(arquivo) { vagas }.listar())
        assertTrue(arquivo.isFile)
        assertEquals(ResultadoVagas(vagas, true), RepositorioVagas(arquivo) { throw erro() }.listar())
    }

    @Test fun `sem rede usa memoria mesmo se arquivo desaparecer`() = runTest {
        var offline = false
        val repositorio = RepositorioVagas(arquivo) { if (offline) throw erro() else vagas }
        repositorio.listar()
        assertTrue(arquivo.delete())
        offline = true
        assertEquals(ResultadoVagas(vagas, true), repositorio.listar())
    }

    @Test fun `sem cache preserva o erro original`() = runTest {
        val original = erro()
        val recebido = try { RepositorioVagas(arquivo) { throw original }.listar(); null }
            catch (erro: ErroDaApi) { erro }
        assertSame(original, recebido)
    }

    @Test fun `cache corrompido nao inventa lista vazia`() = runTest {
        arquivo.writeText("conteudo corrompido")
        val original = erro()
        val recebido = try { RepositorioVagas(arquivo) { throw original }.listar(); null }
            catch (erro: ErroDaApi) { erro }
        assertSame(original, recebido)
    }

    @Test fun `resposta vazia substitui cache antigo`() = runTest {
        RepositorioVagas(arquivo) { vagas }.listar()
        RepositorioVagas(arquivo) { emptyList() }.listar()
        assertEquals(ResultadoVagas(emptyList(), true), RepositorioVagas(arquivo) { throw erro() }.listar())
    }

    @Test fun `erro de servidor nao usa cache`() = runTest {
        RepositorioVagas(arquivo) { vagas }.listar()
        val original = erro(CodigoErroAPI.DESCONHECIDO)
        val recebido = try { RepositorioVagas(arquivo) { throw original }.listar(); null }
            catch (erro: ErroDaApi) { erro }
        assertSame(original, recebido)
    }

    @Test fun `cancelamento nao vira fallback`() = runTest {
        RepositorioVagas(arquivo) { vagas }.listar()
        val original = CancellationException("Teste")
        val recebido = try { RepositorioVagas(arquivo) { throw original }.listar(); null }
            catch (erro: CancellationException) { erro }
        assertSame(original, recebido)
    }

    @Test fun `falha ao persistir nao perde resposta online nem memoria`() = runTest {
        arquivo.mkdir()
        File(arquivo, "ocupado").writeText("teste")
        var offline = false
        val repositorio = RepositorioVagas(arquivo) { if (offline) throw erro() else vagas }
        assertEquals(ResultadoVagas(vagas, false), repositorio.listar())
        offline = true
        assertEquals(ResultadoVagas(vagas, true), repositorio.listar())
    }
    @Test fun cacheExcluiVencidasPreenchidasEDatasInvalidas() = runTest {
        val agora = java.time.Instant.parse("2030-01-01T12:00:00Z")
        val aberta = vagas.single().copy(fimEm = agora.plusSeconds(60).toString())
        val snapshots = listOf(aberta, aberta.copy(id = "vencida", fimEm = agora.toString()),
            aberta.copy(id = "preenchida", posicoesAbertas = 0), aberta.copy(id = "invalida", fimEm = "invalido"))
        val repo = RepositorioVagas(arquivo, agora = { agora }) { snapshots }
        repo.listar()
        assertEquals(listOf(aberta), repo.obterCache()!!.vagas)
        assertEquals(listOf(aberta), RepositorioVagas(arquivo, agora = { agora }) { throw erro() }.listar().vagas)
    }

    @Test fun memoriaReavaliaValidadeQuandoOTempoPassa() = runTest {
        var instante = java.time.Instant.parse("2030-01-01T12:00:00Z")
        val repo = RepositorioVagas(null, agora = { instante }) {
            listOf(vagas.single().copy(fimEm = instante.plusSeconds(60).toString()))
        }
        repo.listar()
        assertEquals(1, repo.obterCache()!!.vagas.size)
        instante = instante.plusSeconds(60)
        assertTrue(repo.obterCache()!!.vagas.isEmpty())
    }

}
