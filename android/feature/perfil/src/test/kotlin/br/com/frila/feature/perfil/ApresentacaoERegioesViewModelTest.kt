package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ApresentacaoDoProfissionalDto
import br.com.frila.core.rede.DefinirRegioesAtendidasDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PerfilProfissionalDetalhadoDto
import br.com.frila.core.rede.RegiaoAdministrativaDto
import br.com.frila.core.rede.ReputacaoDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.yield
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-2a: apresentação ("Sobre mim", experiência, cursos, idiomas) e regiões atendidas. Espelha `ApresentacaoERegioesViewModel` do iOS. */
class ApresentacaoERegioesViewModelTest {

    private val regioes = listOf(
        RegiaoAdministrativaDto(1, "I", "Plano Piloto", true),
        RegiaoAdministrativaDto(3, "III", "Taguatinga", true),
        RegiaoAdministrativaDto(5, "V", "Ceilândia", true),
    )

    private fun perfil(
        apresentacao: String? = "Garçom há 8 anos",
        ondeTrabalhei: String? = "Buffet de casamento",
        experiencia: String? = "de_5_a_10_anos",
        cursos: List<String> = listOf("Coquetelaria"),
        idiomas: List<String> = listOf("portugues", "ingles"),
        atendeTodoDf: Boolean = false,
        regioesDoPerfil: List<RegiaoAdministrativaDto> = listOf(regioes[0], regioes[1]),
    ) = PerfilProfissionalDetalhadoDto(
        id = "p1", usuarioId = "u1", reputacao = ReputacaoDto(0, 0, null, 0, 0),
        apresentacao = apresentacao, ondeTrabalhei = ondeTrabalhei, experienciaFaixa = experiencia,
        cursos = cursos, idiomas = idiomas, regioes = regioesDoPerfil, atendeTodoDf = atendeTodoDf,
    )

    private fun erro(codigo: CodigoErroAPI, original: String, detalhes: String? = null) =
        ErroDaApi(codigo = codigo, codigoOriginal = original, detalhes = detalhes, mensagemCrua = "x")

    /** Servidor falso: guarda o que o app mandou, na ordem. */
    private class Rede(
        var perfil: Result<PerfilProfissionalDetalhadoDto>,
        var catalogo: Result<List<RegiaoAdministrativaDto>>,
        var respostaApresentacao: Result<PerfilProfissionalDetalhadoDto>? = null,
        var respostaRegioes: Result<PerfilProfissionalDetalhadoDto>? = null,
    ) {
        val chamadas = mutableListOf<String>()
        val apresentacoes = mutableListOf<ApresentacaoDoProfissionalDto>()
        val regioesEnviadas = mutableListOf<DefinirRegioesAtendidasDto>()
        var antesDeSalvar: suspend () -> Unit = {}

        fun viewModel() = ApresentacaoERegioesViewModel(
            carregarPerfil = { chamadas += "perfil"; perfil.getOrThrow() },
            carregarRegioes = { chamadas += "catalogo"; catalogo.getOrThrow() },
            salvarApresentacao = {
                chamadas += "apresentacao"; apresentacoes += it; antesDeSalvar()
                (respostaApresentacao ?: perfil).getOrThrow()
            },
            salvarRegioes = {
                chamadas += "regioes"; regioesEnviadas += it
                (respostaRegioes ?: perfil).getOrThrow()
            },
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun rede(perfil: Result<PerfilProfissionalDetalhadoDto> = Result.success(perfil()), catalogo: List<RegiaoAdministrativaDto> = regioes) =
        Rede(perfil, Result.success(catalogo))

    // ---- Carregar ----

    @Test
    fun `carregar aplica o perfil nos campos e traz o catalogo de regioes`() = runBlocking {
        val vm = rede().viewModel()

        vm.carregar().join()

        val e = vm.estado.value
        assertFalse(e.carregando)
        assertEquals("Garçom há 8 anos", e.sobreMim)
        assertEquals("Buffet de casamento", e.ondeTrabalhei)
        assertEquals("de_5_a_10_anos", e.experienciaFaixa)
        assertEquals(listOf("Coquetelaria"), e.cursos)
        assertEquals(setOf("portugues", "ingles"), e.idiomas)
        assertFalse(e.atendeTodoDf)
        assertEquals(setOf(1, 3), e.regioesSelecionadas)
        assertEquals(regioes, e.regioesDisponiveis)
        assertNull(e.erroGeral)
    }

    @Test
    fun `campo nulo do perfil vira vazio no rascunho`() = runBlocking {
        val vm = rede(Result.success(perfil(apresentacao = null, ondeTrabalhei = null, experiencia = null))).viewModel()

        vm.carregar().join()

        assertEquals("", vm.estado.value.sobreMim)
        assertEquals("", vm.estado.value.ondeTrabalhei)
        assertNull(vm.estado.value.experienciaFaixa)
    }

    @Test
    fun `quem ainda nao tem perfil carrega so o catalogo, sem erro`() = runBlocking {
        val r = rede(Result.failure(erro(CodigoErroAPI.NAO_ENCONTRADO, "nao_encontrado")))
        val vm = r.viewModel()

        vm.carregar().join()

        assertEquals(regioes, vm.estado.value.regioesDisponiveis)
        assertNull(vm.estado.value.erroGeral)
        assertFalse(vm.estado.value.carregando)
        assertEquals("", vm.estado.value.sobreMim)
    }

    @Test
    fun `falha ao carregar diz o motivo e nunca deixa a tela carregando`() = runBlocking {
        val casos = listOf(
            Result.failure<PerfilProfissionalDetalhadoDto>(erro(CodigoErroAPI.SEM_REDE, "sem_rede")) to TextosApresentacaoERegioes.ERRO_SEM_REDE,
            Result.failure<PerfilProfissionalDetalhadoDto>(erro(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao")) to TextosApresentacaoERegioes.ERRO_CARREGAR,
            Result.failure<PerfilProfissionalDetalhadoDto>(IllegalStateException("resposta ilegível")) to TextosApresentacaoERegioes.ERRO_CARREGAR,
        )
        for ((falha, mensagem) in casos) {
            val vm = rede(falha).viewModel()

            vm.carregar().join()

            assertEquals(mensagem, vm.estado.value.erroGeral)
            assertFalse(vm.estado.value.carregando)
        }
    }

    // ---- Cursos ----

    @Test
    fun `adicionar curso corta os espacos, ignora vazio e limpa o campo`() = runBlocking {
        val vm = rede().viewModel()
        vm.carregar().join()

        vm.alterarNovoCurso("   ")
        vm.adicionarCurso()
        assertEquals(listOf("Coquetelaria"), vm.estado.value.cursos)

        vm.alterarNovoCurso("  Primeiros socorros  ")
        vm.adicionarCurso()

        assertEquals(listOf("Coquetelaria", "Primeiros socorros"), vm.estado.value.cursos)
        assertEquals("", vm.estado.value.novoCurso)
        assertNull(vm.estado.value.erroCursos)
    }

    @Test
    fun `no maximo 5 cursos e 80 caracteres cada, contando letras e nao unidades do texto`() = runBlocking {
        val vm = rede(Result.success(perfil(cursos = listOf("a", "b", "c", "d", "e")))).viewModel()
        vm.carregar().join()

        vm.alterarNovoCurso("f")
        vm.adicionarCurso()
        assertEquals(TextosApresentacaoERegioes.LIMITE_CURSOS, vm.estado.value.erroCursos)
        assertEquals(5, vm.estado.value.cursos.size)

        val vm2 = rede(Result.success(perfil(cursos = emptyList()))).viewModel()
        vm2.carregar().join()
        vm2.alterarNovoCurso("x".repeat(81))
        vm2.adicionarCurso()
        assertEquals(TextosApresentacaoERegioes.CURSO_MUITO_LONGO, vm2.estado.value.erroCursos)
        assertTrue(vm2.estado.value.cursos.isEmpty())

        // 80 emojis são 80 caracteres (160 unidades UTF-16): cabem.
        vm2.alterarNovoCurso("😀".repeat(80))
        vm2.adicionarCurso()
        assertEquals(1, vm2.estado.value.cursos.size)
        assertNull(vm2.estado.value.erroCursos)
    }

    @Test
    fun `remover curso tira o da posicao e ignora posicao que nao existe`() = runBlocking {
        val vm = rede(Result.success(perfil(cursos = listOf("A", "B", "C")))).viewModel()
        vm.carregar().join()

        vm.removerCurso(1)
        vm.removerCurso(9)

        assertEquals(listOf("A", "C"), vm.estado.value.cursos)
    }

    // ---- Idiomas e regiões ----

    @Test
    fun `alternar idioma liga e desliga`() = runBlocking {
        val vm = rede(Result.success(perfil(idiomas = emptyList()))).viewModel()
        vm.carregar().join()

        vm.alternarIdioma("libras")
        vm.alternarIdioma("ingles")
        vm.alternarIdioma("libras")

        assertEquals(setOf("ingles"), vm.estado.value.idiomas)
    }

    @Test
    fun `atender todo o DF limpa as regioes e marcar uma regiao desliga o todo o DF`() = runBlocking {
        val vm = rede().viewModel()
        vm.carregar().join()

        vm.alternarTodoDf(true)
        assertTrue(vm.estado.value.atendeTodoDf)
        assertTrue(vm.estado.value.regioesSelecionadas.isEmpty())

        vm.alternarRegiao(5)
        assertFalse(vm.estado.value.atendeTodoDf)
        assertEquals(setOf(5), vm.estado.value.regioesSelecionadas)

        vm.alternarRegiao(5)
        assertTrue(vm.estado.value.regioesSelecionadas.isEmpty())
    }

    // ---- Salvar ----

    @Test
    fun `salvar manda a apresentacao e depois as regioes, e marca o sucesso`() = runBlocking {
        val r = rede()
        val vm = r.viewModel()
        vm.carregar().join()
        r.chamadas.clear()
        vm.alterarSobreMim("  Novo texto  ")
        vm.escolherExperiencia("mais_de_10_anos")
        vm.alternarIdioma("libras")
        vm.alternarRegiao(5)

        vm.salvar().join()

        assertEquals(listOf("apresentacao", "regioes"), r.chamadas)
        val enviado = r.apresentacoes.single()
        assertEquals(JsonPrimitive("Novo texto"), enviado.apresentacao)
        assertEquals(JsonPrimitive("Buffet de casamento"), enviado.ondeTrabalhei)
        assertEquals(JsonPrimitive("mais_de_10_anos"), enviado.experienciaFaixa)
        assertEquals(listOf("Coquetelaria"), enviado.cursos)
        // Idiomas na ordem do contrato, não na do toque.
        assertEquals(listOf("portugues", "ingles", "libras"), enviado.idiomas)
        assertEquals(DefinirRegioesAtendidasDto(regioes = listOf(1, 3, 5), atendeTodoDf = false), r.regioesEnviadas.single())
        assertTrue(vm.estado.value.sucesso)
        assertFalse(vm.estado.value.salvando)
    }

    @Test
    fun `texto e experiencia vazios saem como null para limpar o campo no servidor`() = runBlocking {
        val r = rede()
        val vm = r.viewModel()
        vm.carregar().join()
        vm.alterarSobreMim("   ")
        vm.alterarOndeTrabalhei("")
        vm.escolherExperiencia(null)

        vm.salvar().join()

        val enviado = r.apresentacoes.single()
        assertEquals(JsonNull, enviado.apresentacao)
        assertEquals(JsonNull, enviado.ondeTrabalhei)
        assertEquals(JsonNull, enviado.experienciaFaixa)
    }

    @Test
    fun `atender todo o DF manda regioes vazias e o indicador ligado`() = runBlocking {
        val r = rede()
        val vm = r.viewModel()
        vm.carregar().join()
        vm.alternarTodoDf(true)

        vm.salvar().join()

        assertEquals(DefinirRegioesAtendidasDto(regioes = emptyList(), atendeTodoDf = true), r.regioesEnviadas.single())
    }

    @Test
    fun `curso digitado e nao adicionado entra ao salvar`() = runBlocking {
        val r = rede()
        val vm = r.viewModel()
        vm.carregar().join()
        vm.alterarNovoCurso("  Barista  ")

        vm.salvar().join()

        assertEquals(listOf("Coquetelaria", "Barista"), r.apresentacoes.single().cursos)
        assertEquals("", vm.estado.value.novoCurso)
    }

    @Test
    fun `texto acima do limite nao e enviado e o erro fica no campo`() = runBlocking {
        val casos = listOf<Triple<(ApresentacaoERegioesViewModel) -> Unit, (EstadoApresentacaoERegioes) -> String?, String>>(
            Triple({ it.alterarSobreMim("x".repeat(601)) }, { it.erroSobreMim }, TextosApresentacaoERegioes.LIMITE_SOBRE_MIM),
            Triple({ it.alterarOndeTrabalhei("x".repeat(401)) }, { it.erroOndeTrabalhei }, TextosApresentacaoERegioes.LIMITE_ONDE_TRABALHEI),
        )
        for ((editar, campo, mensagem) in casos) {
            val r = rede()
            val vm = r.viewModel()
            vm.carregar().join()
            r.chamadas.clear()
            editar(vm)

            vm.salvar().join()

            assertEquals(mensagem, campo(vm.estado.value))
            assertTrue(r.chamadas.isEmpty(), mensagem)
            assertFalse(vm.estado.value.sucesso)
        }
    }

    @Test
    fun `600 caracteres ainda cabem`() = runBlocking {
        val r = rede()
        val vm = r.viewModel()
        vm.carregar().join()
        vm.alterarSobreMim("x".repeat(600))

        vm.salvar().join()

        assertTrue(vm.estado.value.sucesso)
    }

    @Test
    fun `campo_invalido do servidor cai no campo certo`() = runBlocking {
        val casos = listOf<Pair<String?, (EstadoApresentacaoERegioes) -> String?>>(
            "apresentacao" to { it.erroSobreMim },
            "sobre_mim" to { it.erroSobreMim },
            "onde_trabalhei" to { it.erroOndeTrabalhei },
            "cursos" to { it.erroCursos },
            // Sem `details` conhecido, como o iOS, o erro vai ao "Sobre mim", que é onde o filtro de contato mais pega.
            null to { it.erroSobreMim },
        )
        for ((detalhes, campo) in casos) {
            val r = rede()
            r.respostaApresentacao = Result.failure(erro(CodigoErroAPI.CAMPO_INVALIDO, "campo_invalido", detalhes))
            val vm = r.viewModel()
            vm.carregar().join()

            vm.salvar().join()

            assertEquals(TextosApresentacaoERegioes.ERRO_ANTI_CONTATO, campo(vm.estado.value), "details=$detalhes")
            assertFalse(vm.estado.value.sucesso)
            // A apresentação falhou: as regiões não são enviadas.
            assertTrue(r.regioesEnviadas.isEmpty(), "details=$detalhes")
        }
    }

    @Test
    fun `regioes invalidas caem em regioes`() = runBlocking {
        val r = rede()
        r.respostaRegioes = Result.failure(erro(CodigoErroAPI.CAMPO_INVALIDO, "campo_invalido", "regioes"))
        val vm = r.viewModel()
        vm.carregar().join()

        vm.salvar().join()

        assertEquals(TextosApresentacaoERegioes.ERRO_REGIOES, vm.estado.value.erroRegioes)
        assertFalse(vm.estado.value.sucesso)
    }

    @Test
    fun `sem rede, falha qualquer e resposta ilegivel viram a mensagem geral e deixam tentar de novo`() = runBlocking {
        val casos = listOf(
            erro(CodigoErroAPI.SEM_REDE, "sem_rede") to TextosApresentacaoERegioes.ERRO_SEM_REDE,
            erro(CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "recurso_desligado") to TextosApresentacaoERegioes.ERRO_SALVAR,
            IllegalStateException("corpo ilegível") to TextosApresentacaoERegioes.ERRO_SALVAR,
        )
        for ((falha, mensagem) in casos) {
            val r = rede()
            r.respostaApresentacao = Result.failure(falha)
            val vm = r.viewModel()
            vm.carregar().join()

            vm.salvar().join()

            assertEquals(mensagem, vm.estado.value.erroGeral)
            assertFalse(vm.estado.value.salvando)
            assertFalse(vm.estado.value.sucesso)
        }
    }

    @Test
    fun `editar um campo tira o erro dele`() = runBlocking {
        val r = rede()
        val vm = r.viewModel()
        vm.carregar().join()
        vm.alterarSobreMim("x".repeat(601))
        vm.salvar().join()
        assertEquals(TextosApresentacaoERegioes.LIMITE_SOBRE_MIM, vm.estado.value.erroSobreMim)

        vm.alterarSobreMim("curto")

        assertNull(vm.estado.value.erroSobreMim)
    }

    @Test
    fun `dois toques em salvar enviam uma vez so`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val r = rede()
        r.antesDeSalvar = { liberar.await() }
        val vm = r.viewModel()
        vm.carregar().join()

        val primeiro = vm.salvar()
        withTimeout(5_000) { while (!vm.estado.value.salvando || r.apresentacoes.isEmpty()) yield() }
        val segundo = vm.salvar()
        liberar.complete(Unit)
        primeiro.join()
        segundo.join()

        assertEquals(1, r.apresentacoes.size)
        assertEquals(1, r.regioesEnviadas.size)
    }
}
