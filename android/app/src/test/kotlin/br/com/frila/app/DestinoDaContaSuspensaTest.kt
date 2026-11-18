package br.com.frila.app

import br.com.frila.core.rede.PerfilProfissionalDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import br.com.frila.core.rede.UsuarioDto
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/** L2-5: quem leva até "Conta suspensa". Como no iOS (`DestinoAposEntrada.avaliar`): a conta existe, a situação diz suspensa, a tela da suspensão abre. */
class DestinoDaContaSuspensaTest {

    private fun conta(perfil: String) = UsuarioDto("u1", perfil, "Conta Teste", "61999990000", "conta@exemplo.com", "1990-01-01", "ativa")
    private val perfilProfissional = PerfilProfissionalDto(id = "p1", usuarioId = "u1", reputacao = ReputacaoDto(0, 0, null, 0, 0))
    private val ativa = SituacaoDaContaDto(estado = "ativa")
    private val suspensa = SituacaoDaContaDto(estado = "suspensa", suspensao = SuspensaoDaContaDto(motivo = "Conduta", desde = "2026-11-10T12:00:00Z"))

    private class GuardadoFalso(var valor: DestinoDaConta? = null, var limpou: Boolean = false) : DestinoGuardado {
        override fun obter() = valor
        override fun salvar(destino: DestinoDaConta) { valor = destino }
        override fun limpar() { valor = null; limpou = true }
    }

    @Test
    fun `conta suspensa vai para a tela da suspensao, seja profissional ou contratante`() = runTest {
        val profissional = avaliarDestinoDaConta(
            buscarConta = { conta("profissional") },
            buscarPerfilProfissional = { error("suspensa não lê o perfil") },
            listarCasas = { error("suspensa não lista casas") },
            buscarSituacao = { suspensa },
        )
        val contratante = avaliarDestinoDaConta(
            buscarConta = { conta("contratante") },
            buscarPerfilProfissional = { error("x") },
            listarCasas = { error("suspensa não lista casas") },
            buscarSituacao = { suspensa },
        )

        assertEquals(DestinoDaConta.ContaSuspensa, profissional)
        assertEquals(DestinoDaConta.ContaSuspensa, contratante)
        assertEquals(Rotas.contaSuspensa(), profissional.rota())
    }

    @Test
    fun `conta ativa segue o caminho de sempre`() = runTest {
        val destino = avaliarDestinoDaConta(
            buscarConta = { conta("profissional") },
            buscarPerfilProfissional = { perfilProfissional },
            listarCasas = { error("x") },
            buscarSituacao = { ativa },
        )

        assertEquals(DestinoDaConta.Profissional, destino)
    }

    @Test
    fun `sem o servico da situacao no grafo a abertura e a de antes`() = runTest {
        val destino = avaliarDestinoDaConta(
            buscarConta = { conta("profissional") },
            buscarPerfilProfissional = { perfilProfissional },
            listarCasas = { error("x") },
        )

        assertEquals(DestinoDaConta.Profissional, destino)
    }

    @Test
    fun `a suspensao nao mexe no destino guardado, para a abertura sem rede de depois`() = runTest {
        val guardado = GuardadoFalso(valor = DestinoDaConta.Profissional)

        val resultado = AvaliadorDeDestino({ DestinoDaConta.ContaSuspensa }, guardado, sessaoGuardada = { false }).avaliar()

        assertEquals(ResultadoDaAbertura.Destino(DestinoDaConta.ContaSuspensa), resultado)
        assertEquals(DestinoDaConta.Profissional, guardado.valor)
        assertEquals(false, guardado.limpou)
    }
}
