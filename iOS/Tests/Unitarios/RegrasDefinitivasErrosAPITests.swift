import Foundation
import FrilaDominio
import Testing

@Suite("Domínio - Regras Definitivas de Erros de API")
struct RegrasDefinitivasErrosAPITests {
    @Test("Erros que configuram recusa definitiva de publicação de vaga")
    func recusasDefinitivasDePublicacao() {
        let definitivos: Set<CodigoErroAPI> = [
            .campoObrigatorio, .campoInvalido, .horarioInvalido, .funcaoIncompativel,
            .perfilIncompativel, .selecaoSemAntecedencia, .semPermissao, .contaSuspensa,
            .naoEncontrado
        ]

        for codigo in CodigoErroAPI.allCases {
            if definitivos.contains(codigo) {
                #expect(codigo.recusaDefinitivaDePublicacao, "Esperava que \(codigo) fosse recusa definitiva de publicação")
            } else {
                #expect(!codigo.recusaDefinitivaDePublicacao, "Esperava que \(codigo) NÃO fosse recusa definitiva de publicação")
            }
        }
    }

    @Test("Erros que configuram recusa definitiva de cancelamento de turno")
    func recusasDefinitivasDeCancelamento() {
        let definitivos: Set<CodigoErroAPI> = [
            .posicaoNaoCancelavel, .vagaEncerrada, .naoEncontrado, .campoObrigatorio,
            .campoInvalido, .semPermissao, .perfilIncompativel, .contaSuspensa
        ]

        for codigo in CodigoErroAPI.allCases {
            if definitivos.contains(codigo) {
                #expect(codigo.recusaDefinitivaDeCancelamento, "Esperava que \(codigo) fosse recusa definitiva de cancelamento")
            } else {
                #expect(!codigo.recusaDefinitivaDeCancelamento, "Esperava que \(codigo) NÃO fosse recusa definitiva de cancelamento")
            }
        }
    }

    @Test("Motivos de republicação indisponível cobrem exatamente os 6 casos do contrato 0.2.41")
    func motivosRepublicacaoIndisponivel() throws {
        let esperados: Set<String> = [
            "nao_e_selecao", "selecao_em_curso", "vaga_cancelada",
            "ja_comecou", "sem_posicoes_restantes", "ja_republicada"
        ]

        let obtidos = Set(MotivoRepublicacaoIndisponivel.allCases.map(\.rawValue))
        #expect(obtidos == esperados)
        #expect(MotivoRepublicacaoIndisponivel.allCases.count == 6)

        for motivo in MotivoRepublicacaoIndisponivel.allCases {
            let data = try JSONEncoder().encode(motivo)
            let decodificado = try JSONDecoder().decode(MotivoRepublicacaoIndisponivel.self, from: data)
            #expect(decodificado == motivo)
        }
    }

    @Test("EnvelopeErroAPI decodifica payloads da API com sucesso")
    func envelopeErroAPIDecodificacao() throws {
        let json = """
        {
            "code": "42501",
            "message": "permissao negada para a rpc",
            "details": "usuario_id nao confere",
            "hint": "verifique as credenciais"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(EnvelopeErroAPI.self, from: json)
        #expect(envelope.code == "42501")
        #expect(envelope.message == "permissao negada para a rpc")
        #expect(envelope.details == "usuario_id nao confere")
        #expect(envelope.hint == "verifique as credenciais")
    }

    @Test("ErroDaApi preserva código tipado e código original")
    func erroDaApiPreservaCampos() {
        let erro1 = ErroDaApi(codigo: .posicaoJaPreenchida)
        #expect(erro1.codigo == .posicaoJaPreenchida)
        #expect(erro1.codigoOriginal == "posicao_ja_preenchida")
        #expect(erro1.detalhes == nil)

        let erro2 = ErroDaApi(codigo: .campoInvalido, codigoOriginal: "custom_code", detalhes: "valor negativo")
        #expect(erro2.codigo == .campoInvalido)
        #expect(erro2.codigoOriginal == "custom_code")
        #expect(erro2.detalhes == "valor negativo")
    }
}
