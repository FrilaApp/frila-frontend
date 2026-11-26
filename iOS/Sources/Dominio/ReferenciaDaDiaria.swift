/// A faixa de referência da diária (B-124; decisão dos três sócios de 25/11/2026; contrato 0.2.116): de R$ 50,00 a
/// R$ 2.000,00 é **só aviso** na tela da casa. Nada recusa nem trava por faixa: o servidor só recusa valor zero ou negativo,
/// e a regra do valor obrigatório continua em cada tela. A API não expõe a faixa: os apps a têm fixa, e no iOS é aqui.
public enum ReferenciaDaDiaria {
    public static let minimoEmCentavos = 5_000
    public static let maximoEmCentavos = 200_000

    public enum ForaDaFaixa: Equatable, Sendable { case abaixo, acima }

    /// `nil` dentro da faixa (as bordas contam como dentro) e para zero ou negativo, que não ganham aviso novo.
    public static func avaliar(centavos: Int) -> ForaDaFaixa? {
        guard centavos > 0 else { return nil }
        if centavos < minimoEmCentavos { return .abaixo }
        if centavos > maximoEmCentavos { return .acima }
        return nil
    }
}
