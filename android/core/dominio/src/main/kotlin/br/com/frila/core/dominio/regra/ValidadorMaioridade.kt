package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.DataCivil

/** Idade mínima para cadastro de profissional (RN20), verificada sempre no fuso de Brasília. */
object ValidadorMaioridade {

    const val IDADE_MINIMA_ANOS = 18

    fun ehMaiorDeIdade(nascimento: DataCivil, hoje: DataCivil = DataCivil.hoje()): Boolean =
        nascimento.idadeEm(hoje) >= IDADE_MINIMA_ANOS
}
