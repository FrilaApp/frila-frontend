package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao

/** Quantas vezes relê e tenta de novo se outra escrita entrou entre a leitura e a gravação. */
private const val TENTATIVAS_DE_GRAVACAO = 3

/**
 * Grava o resultado de uma chamada de rede na sessão guardada, **só se a sessão ainda é a de quem a fez** (cartão O9aPbBR2).
 *
 * Quem lê a sessão, espera a rede e depois grava `copy(...)` sem comparar pode gravar o dado da conta A na sessão da conta B, se B entrou
 * durante a espera (o `vinculo_id` do aparelho de A, ou a sessão nova de A inteira). [antes] é a sessão lida **antes** da chamada.
 *
 * - O refresh token vigente é o mesmo de [antes]: nada mudou, grava.
 * - Mudou, mas a conta é a mesma (a própria chamada, ou outra, renovou o token enquanto esperava; o `sub` do JWT não muda): grava sobre a
 *   sessão vigente, para não desfazer a renovação.
 * - Não há sessão (saiu) ou é outra conta (ou não dá para provar que é a mesma): não grava.
 * A comparação e a gravação são uma operação só do armazenamento ([ArmazenamentoDeSessao.salvarSeRefreshTokenIgual]); se outra escrita entrar entre
 * a leitura e ela, relê e decide de novo, no máximo [TENTATIVAS_DE_GRAVACAO] vezes.
 *
 * [mudar] recebe a sessão vigente e devolve a que deve ficar guardada. Devolve `true` se gravou.
 */
fun ArmazenamentoDeSessao.atualizarSeASessaoDeQuemChamou(antes: Sessao, mudar: (vigente: Sessao) -> Sessao): Boolean {
    repeat(TENTATIVAS_DE_GRAVACAO) {
        val vigente = obterSessao() ?: return false
        if (!ehDaMesmaConta(antes, vigente)) return false
        if (salvarSeRefreshTokenIgual(vigente.refreshToken, mudar(vigente))) return true
    }
    return false
}

private fun ehDaMesmaConta(antes: Sessao, vigente: Sessao): Boolean {
    if (vigente.refreshToken == antes.refreshToken) return true
    val contaAntes = contaDaSessaoParaTelemetria(antes)
    return contaAntes != null && contaAntes == contaDaSessaoParaTelemetria(vigente)
}
