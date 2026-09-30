import Foundation
import FrilaDominio

/// Fixtures em `Resources/Fixtures`, validadas contra o contrato pela CI e lidas pelos mesmos DTOs
/// do cliente real: se o DTO e o contrato divergirem, o dublê e os testes quebram juntos.
enum FixturesDoContrato {
    static func dados(_ nome: String) throws -> Data {
        guard let url = Bundle(for: MarcadorDoBundle.self).url(forResource: nome, withExtension: "json") else {
            throw ErroDeConversao(campo: "fixture \(nome).json")
        }
        return try Data(contentsOf: url)
    }

    static func carregar<Valor: Decodable>(_ nome: String, como tipo: Valor.Type = Valor.self) throws -> Valor {
        try ContratoAPI.decodificador().decode(Valor.self, from: dados(nome))
    }

    static func todosOsErros() throws -> [EnvelopeErroAPI] {
        try carregar("erros", como: [EnvelopeErroAPI].self)
    }

    static func erros() throws -> [String: EnvelopeErroAPI] {
        let envelopes = try todosOsErros()
        return Dictionary(envelopes.map { ($0.code, $0) }, uniquingKeysWith: { primeiro, _ in primeiro })
    }
}

private final class MarcadorDoBundle {}
