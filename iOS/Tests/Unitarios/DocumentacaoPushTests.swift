import Foundation
import Testing

@Suite("Roteiro de push no aparelho (#h6RoObK6)")
struct DocumentacaoPushTests {
    private static func carregarRoteiro() throws -> String {
        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let documento = try String(contentsOf: raiz.appending(path: "Docs/Push.md"), encoding: .utf8)
        let inicio = try #require(documento.range(of: "## Roteiro de teste no aparelho\n"))
        return String(documento[inicio.upperBound...].components(separatedBy: "\n## ")[0])
    }

    @Test("O roteiro conserva os dez passos de validação no iPhone com TestFlight")
    func roteiroDeAparelhoPresente() throws {
        let roteiro = try Self.carregarRoteiro()
        #expect(roteiro.contains("iPhone com o build do TestFlight (Beta)"))
        let passos = try Regex(#"(?m)^(\d+)\. \*\*([^*]+)\*\*"#)
        let encontrados = roteiro.matches(of: passos)
        #expect(encontrados.compactMap { Int($0.output[1].substring ?? "") } == Array(1...10))

        let titulos = encontrados.map { String($0.output[2].substring ?? "") }
        #expect(titulos == [
            "Chegada.", "Tela bloqueada.", "App aberto, em segundo plano e fechado.",
            "Reinstalação.", "Duas contas no mesmo iPhone (filtro por vínculo na tela bloqueada - cartão h6RoObK6):",
            "Permissão negada.", "Assinatura.", "Sair sem rede.", "Reativação.", "Reativação sem confirmação."
        ])
    }

    @Test("A troca de contas verifica o aviso ativo, neutraliza o antigo e preserva o destino seguro")
    func roteiroDaExtensaoComDuasContas() throws {
        let roteiro = try Self.carregarRoteiro()
        let inicio = try #require(roteiro.range(of: "5. **Duas contas no mesmo iPhone"))
        let fim = try #require(roteiro.range(of: "\n6. **", range: inicio.upperBound..<roteiro.endIndex))
        let passo = String(roteiro[inicio.lowerBound..<fim.lowerBound])

        let trechosEmOrdem = [
            "Instalar o build assinado no iPhone e entrar com a Conta A.",
            "Bloquear a tela ou fechar o app. Enviar push para a Conta A com `mutable-content: 1` e `vinculo_id`",
            "da Conta A → o aviso aparece com título e corpo originais.",
            "Sair da Conta A e entrar com a Conta B no mesmo aparelho. Bloquear a tela.",
            "Enviar push para a Conta A (com o `vinculo_id` da A)",
            "o aviso aparece com o texto neutro: `\"Frila — Nova notificação disponível\"`.",
            "sem navegar para dados da Conta A.",
            "Enviar push para a Conta B (com o `vinculo_id` da B) → aviso exibido normalmente com título e",
            "corpo originais.",
            "`push_recebido tipo=... com_vinculo=true sessao=true decisao=manter|neutralizar`."
        ]
        var restante = passo.startIndex..<passo.endIndex
        for trecho in trechosEmOrdem {
            let ocorrencia = try #require(passo.range(of: trecho, range: restante), "Passo 5 ausente ou fora de ordem: \(trecho)")
            restante = ocorrencia.upperBound..<passo.endIndex
        }
    }
}
