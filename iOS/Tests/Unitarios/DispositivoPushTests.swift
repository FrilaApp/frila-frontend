import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Aparelho, Push e Isolamento de Sessão (RN15)")
struct DispositivoPushTests {
    @Test("Carência padrão na troca de conta é de 60 segundos")
    func carenciaTrocaDeConta() {
        #expect(VinculoDoAparelho.carenciaNaTrocaDeConta == 60)
    }

    @Test("Instanciação de VinculoDoAparelho com e sem vinculo_id (contrato 0.2.30)")
    func vinculoDoAparelhoCompatibilidade() {
        let contaID = UUID()
        let agora = Date()
        let vinculoID = UUID()

        let comVinculo = VinculoDoAparelho(contaID: contaID, desde: agora, vinculoID: vinculoID)
        #expect(comVinculo.contaID == contaID)
        #expect(comVinculo.desde == agora)
        #expect(comVinculo.vinculoID == vinculoID)

        let semVinculo = VinculoDoAparelho(contaID: contaID, desde: agora)
        #expect(semVinculo.contaID == contaID)
        #expect(semVinculo.vinculoID == nil)
    }

    @Test("Serialização e desserialização JSON de VinculoDoAparelho mantendo campos")
    func serializacaoVinculo() throws {
        let contaID = UUID()
        let agora = Date(timeIntervalSince1970: 1_700_000_000)
        let vinculo = VinculoDoAparelho(contaID: contaID, desde: agora, vinculoID: UUID())

        let data = try JSONEncoder().encode(vinculo)
        let decodificado = try JSONDecoder().decode(VinculoDoAparelho.self, from: data)

        #expect(decodificado == vinculo)
        #expect(decodificado.contaID == contaID)
        #expect(decodificado.desde == agora)
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

    @Test("AparelhoGuardado registra transição de saída e preserva contaAnterior")
    func transicaoDeContaNoAparelho() {
        let conta1 = UUID()
        let vinculo1 = UUID()
        let agora = Date()

        var aparelho = AparelhoGuardado(
            token: "fcm-token-123",
            vinculo: VinculoDoAparelho(contaID: conta1, desde: agora, vinculoID: vinculo1),
            contaAnterior: nil
        )

        #expect(aparelho.vinculo?.contaID == conta1)
        #expect(aparelho.contaAnterior == nil)

        // Simulação de logout/desvinculação no aparelho
        aparelho.contaAnterior = aparelho.vinculo?.contaID
        aparelho.vinculo = nil

        #expect(aparelho.vinculo == nil)
        #expect(aparelho.contaAnterior == conta1)
        #expect(aparelho.token == "fcm-token-123")
    }

    @Test("Enum Plataforma codifica valores de contrato corretos")
    func plataformaValores() throws {
        #expect(Plataforma.ios.rawValue == "ios")
        #expect(Plataforma.android.rawValue == "android")
        #expect(Plataforma.web.rawValue == "web")

        let encoded = try JSONEncoder().encode(Plataforma.ios)
        let string = String(decoding: encoded, as: UTF8.self)
        #expect(string.contains("ios"))
    }

    @Test("Dispositivo mapeia campos de registro com sucesso")
    func dispositivoModel() {
        let agora = Date()
        let vinculo = UUID()
        let disp = Dispositivo(plataforma: .ios, atualizadoEm: agora, vinculoID: vinculo)

        #expect(disp.plataforma == .ios)
        #expect(disp.atualizadoEm == agora)
        #expect(disp.vinculoID == vinculo)
    }
}
