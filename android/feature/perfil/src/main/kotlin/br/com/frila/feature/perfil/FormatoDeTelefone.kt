package br.com.frila.feature.perfil

import br.com.frila.core.dominio.regra.ValidadorTelefone

/**
 * O telefone da conta como as pessoas leem: "(61) 98888-7777", e não "+5561988887777" (`FormatoDeTelefone.swift` do iOS).
 * Só número brasileiro (+55 com DDD e 8 ou 9 dígitos) ganha máscara; outro formato aparece como veio, para a máscara de 11
 * dígitos não cortar um número estrangeiro.
 */
object FormatoDeTelefone {
    fun paraExibir(telefone: String): String {
        val digitos = telefone.count { it.isDigit() }
        if (!telefone.startsWith("+55") || digitos !in 12..13) return telefone
        return ValidadorTelefone.formatar(telefone)
    }
}
