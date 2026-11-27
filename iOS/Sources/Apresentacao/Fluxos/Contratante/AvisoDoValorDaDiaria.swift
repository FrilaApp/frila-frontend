import FrilaDominio

/// O aviso, que não trava, das telas da casa onde se informa o valor da diária (B-124): publicar vaga (Estúdio), escala,
/// chamada direta e chamada da busca. Os textos são provisórios: a redação e o desenho finais são do Fabrício.
enum AvisoDoValorDaDiaria {
    static let muitoBaixo = String(localized: "Valor muito baixo.", bundle: bundleApresentacao)
    static let muitoAlto = String(localized: "Valor muito alto, confira.", bundle: bundleApresentacao)

    /// O texto do aviso para o valor em centavos, ou `nil` quando não há o que avisar.
    static func texto(centavos: Int) -> String? {
        switch ReferenciaDaDiaria.avaliar(centavos: centavos) {
        case .abaixo: muitoBaixo
        case .acima: muitoAlto
        case nil: nil
        }
    }
}

extension VagaDoFormularioDaEscala {
    var avisoDoValor: String? { AvisoDoValorDaDiaria.texto(centavos: valorCentavos) }
}

extension ChamadaDiretaViewModel {
    var avisoDoValor: String? { AvisoDoValorDaDiaria.texto(centavos: valorCentavos) }
}

extension RascunhoDaChamadaDaBusca {
    var avisoDoValor: String? { AvisoDoValorDaDiaria.texto(centavos: valorCentavos ?? 0) }
}

extension FrilaJobCreationDraft {
    /// Só no valor por turno, o único que o app publica: o valor por hora não é a diária. O Estúdio guarda reais inteiros.
    var avisoDoValor: String? {
        paymentMode == .perShift ? AvisoDoValorDaDiaria.texto(centavos: payPerPosition * 100) : nil
    }
}
