import Foundation

/// O telefone da conta como as pessoas leem: "(61) 98888-7777", e não "+5561988887777" (V20 da
/// conferência visual da 1.1). Usa a mesma máscara do cadastro.
enum FormatoDeTelefone {
    /// Só número brasileiro (+55 com DDD e 8 ou 9 dígitos) ganha máscara. Outro formato aparece como
    /// veio, para a máscara de 11 dígitos não cortar um número estrangeiro.
    static func paraExibir(_ telefone: String) -> String {
        let digitos = telefone.filter(\.isNumber)
        guard telefone.hasPrefix("+55"), digitos.count == 12 || digitos.count == 13 else { return telefone }
        return CadastroViewModel.formatarTelefone(telefone)
    }
}
