import Foundation

/// Cobertura atual do Frila: o Distrito Federal. Endereço fora dele pode ser cadastrado, mas a
/// pessoa é avisada de que o foco e a cobertura do Frila, por ora, são só do DF (decisão da PO sobre
/// o relatório de testes da 0.5.5, item A6).
///
/// A conferência é uma heurística local, sem rede: usa a unidade federativa que o geocodificador
/// devolve quando existe e, sem ela, um retângulo que envolve o DF. O retângulo é folgado de
/// propósito e inclui um pedaço do Entorno em Goiás, então um ponto de fora pode passar por dentro.
/// O aviso é informativo: nunca impede o cadastro nem decide quem recebe vaga (isso é do servidor).
public enum CoberturaDoDF {
    /// Retângulo que envolve o Distrito Federal (limites do GDF, com folga de cerca de 1 km).
    static let latitudes: ClosedRange<Double> = -16.06 ... -15.49
    static let longitudes: ClosedRange<Double> = -48.30 ... -47.29

    /// `true` quando o ponto está fora do Distrito Federal.
    ///
    /// - Parameters:
    ///   - area: unidade federativa do endereço, como o geocodificador devolveu ("DF", "Distrito
    ///     Federal", "Federal District", "GO"…). Quando vem, vale mais que o retângulo.
    ///   - codigoDoPais: código ISO do país do endereço ("BR"…), quando o geocodificador o traz.
    public static func estaForaDoDF(latitude: Double, longitude: Double, area: String? = nil, codigoDoPais: String? = nil) -> Bool {
        if let pais = codigoDoPais?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           !pais.isEmpty, pais != "BR" {
            return true
        }
        if let area = normalizar(area), !area.isEmpty {
            return !ehDistritoFederal(area)
        }
        return !(latitudes.contains(latitude) && longitudes.contains(longitude))
    }

    public static func estaForaDoDF(_ coordenada: Coordenada, area: String? = nil, codigoDoPais: String? = nil) -> Bool {
        estaForaDoDF(latitude: coordenada.latitude, longitude: coordenada.longitude, area: area, codigoDoPais: codigoDoPais)
    }

    private static func ehDistritoFederal(_ area: String) -> Bool {
        ["df", "distrito federal", "federal district"].contains(area)
    }

    private static func normalizar(_ texto: String?) -> String? {
        texto?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
    }
}
