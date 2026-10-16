import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Aparelho, Push e Isolamento de Sessão (RN15)")
struct DispositivoPushTests {
    private static let dataFixa = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Carência padrão na troca de conta é de 60 segundos")
    func carenciaTrocaDeConta() {
        #expect(VinculoDoAparelho.carenciaNaTrocaDeConta == 60)
    }

    @Test("Instanciação de VinculoDoAparelho com e sem vinculo_id (contrato 0.2.30)")
    func vinculoDoAparelhoCompatibilidade() {
        let contaID = UUID()
        let data = Self.dataFixa
        let vinculoID = UUID()

        let comVinculo = VinculoDoAparelho(contaID: contaID, desde: data, vinculoID: vinculoID)
        #expect(comVinculo.contaID == contaID)
        #expect(comVinculo.desde == data)
        #expect(comVinculo.vinculoID == vinculoID)

        let semVinculo = VinculoDoAparelho(contaID: contaID, desde: data)
        #expect(semVinculo.contaID == contaID)
        #expect(semVinculo.vinculoID == nil)
    }

    @Test("Serialização e desserialização JSON de VinculoDoAparelho mantendo campos")
    func serializacaoVinculo() throws {
        let contaID = UUID()
        let data = Self.dataFixa
        let vinculo = VinculoDoAparelho(contaID: contaID, desde: data, vinculoID: UUID())

        let bytes = try JSONEncoder().encode(vinculo)
        let decodificado = try JSONDecoder().decode(VinculoDoAparelho.self, from: bytes)

        #expect(decodificado == vinculo)
        #expect(decodificado.contaID == contaID)
        #expect(decodificado.desde == data)
        #expect(decodificado.vinculoID == vinculo.vinculoID)
    }

    @Test("Decodificação retrocompatível de VinculoDoAparelho sem campo vinculoID (servidor pré-0.2.30)")
    func decodificacaoLegadaSemVinculoID() throws {
        let contaID = UUID()
        let json = """
        {
            "contaID": "\(contaID.uuidString)",
            "desde": 1700000000.0
        }
        """.data(using: .utf8)!

        let decodificado = try JSONDecoder().decode(VinculoDoAparelho.self, from: json)
        #expect(decodificado.contaID == contaID)
        #expect(decodificado.vinculoID == nil)
    }

    @Test("AparelhoGuardado aceita vincular e desvincular campo a campo")
    func aparelhoGuardadoAceitaVincularEDesvincular() {
        let conta1 = UUID()
        let vinculo1 = UUID()
        let data = Self.dataFixa

        var aparelho = AparelhoGuardado(
            token: "fcm-token-123",
            vinculo: VinculoDoAparelho(contaID: conta1, desde: data, vinculoID: vinculo1),
            contaAnterior: nil
        )

        #expect(aparelho.vinculo?.contaID == conta1)
        #expect(aparelho.contaAnterior == nil)

        // Simulação de desvinculação campo a campo no aparelho
        aparelho.contaAnterior = aparelho.vinculo?.contaID
        aparelho.vinculo = nil

        #expect(aparelho.vinculo == nil)
        #expect(aparelho.contaAnterior == conta1)
        #expect(aparelho.token == "fcm-token-123")
    }

    @Test("Descrição de AparelhoGuardado mascara o token do FCM contra vazamento em logs (RN15)")
    func descricaoOcultaToken() {
        let tokenSecreto = "fcm-secret-token-xyz-123456789"
        let contaID = UUID()
        let vinculo = VinculoDoAparelho(contaID: contaID, desde: Self.dataFixa, vinculoID: UUID())
        let aparelho = AparelhoGuardado(token: tokenSecreto, vinculo: vinculo, contaAnterior: nil)

        let descricao = String(describing: aparelho)
        let debugDescricao = String(reflecting: aparelho)

        #expect(!descricao.contains(tokenSecreto), "description não pode conter o token do FCM em claro")
        #expect(!debugDescricao.contains(tokenSecreto), "debugDescription não pode conter o token do FCM em claro")
        #expect(descricao.contains("[REDACTED]"))
        #expect(debugDescricao.contains("[REDACTED]"))
        #expect(descricao.contains(contaID.uuidString))
    }

    @Test("dump() e Mirror de AparelhoGuardado mascaram o token do FCM contra vazamento em logs (RN15)")
    func espelhamentoOcultaToken() {
        let tokenSecreto = "fcm-secret-token-xyz-123456789"
        let contaID = UUID()
        let vinculo = VinculoDoAparelho(contaID: contaID, desde: Self.dataFixa, vinculoID: UUID())
        let aparelho = AparelhoGuardado(token: tokenSecreto, vinculo: vinculo, contaAnterior: nil)

        // 1. Mirror(reflecting:)
        let mirror = Mirror(reflecting: aparelho)
        let tokenFilho = mirror.children.first { $0.label == "token" }
        #expect(tokenFilho != nil)
        #expect(tokenFilho?.value as? String == "[REDACTED]")

        for child in mirror.children {
            if let stringValue = child.value as? String {
                #expect(!stringValue.contains(tokenSecreto), "Nenhum filho do Mirror pode conter o token do FCM")
            }
        }

        // 2. dump()
        var dumpOutput = ""
        dump(aparelho, to: &dumpOutput)
        #expect(!dumpOutput.contains(tokenSecreto), "dump(aparelho) não pode conter o token do FCM em claro")
        #expect(dumpOutput.contains("[REDACTED]"))
        #expect(dumpOutput.contains(contaID.uuidString))
    }

    @Test("Enum Plataforma codifica valores de contrato corretos")
    func plataformaValores() throws {
        #expect(Plataforma.ios.rawValue == "ios")
        #expect(Plataforma.android.rawValue == "android")
        #expect(Plataforma.web.rawValue == "web")

        let encoded = try JSONEncoder().encode(Plataforma.ios)
        let string = String(decoding: encoded, as: UTF8.self)
        #expect(string == "\"ios\"")
    }

    @Test("Dispositivo mapeia campos de registro com sucesso")
    func dispositivoModel() {
        let data = Self.dataFixa
        let vinculo = UUID()
        let disp = Dispositivo(plataforma: .ios, atualizadoEm: data, vinculoID: vinculo)

        #expect(disp.plataforma == .ios)
        #expect(disp.atualizadoEm == data)
        #expect(disp.vinculoID == vinculo)
    }
}
