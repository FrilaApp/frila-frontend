import Foundation
@testable import FrilaDados
import Security
import Testing

/// O Keychain do simulador é real: cada teste usa um serviço próprio e o apaga ao terminar.
@Suite("Sessão do Supabase no Keychain só deste aparelho", .serialized)
struct SessaoNoKeychainDoAparelhoTests {
    private static let chave = "supabase.auth.token"

    private func servicoDeTeste() -> String { "com.frila.org.app.teste.sessao.\(UUID().uuidString)" }

    @Test("Guarda, lê e remove a sessão")
    func guardaLeERemove() throws {
        let servico = servicoDeTeste()
        let armazenamento = SessaoNoKeychainDoAparelho(servico: servico)
        defer { try? armazenamento.remove(key: Self.chave) }

        #expect(try armazenamento.retrieve(key: Self.chave) == nil)
        try armazenamento.store(key: Self.chave, value: Data("sessao-1".utf8))
        #expect(try armazenamento.retrieve(key: Self.chave) == Data("sessao-1".utf8))
        try armazenamento.store(key: Self.chave, value: Data("sessao-2".utf8))
        #expect(try armazenamento.retrieve(key: Self.chave) == Data("sessao-2".utf8))
        try armazenamento.remove(key: Self.chave)
        #expect(try armazenamento.retrieve(key: Self.chave) == nil)
        // Remover o que não existe não é erro: o SDK remove ao sair mesmo sem sessão guardada.
        try armazenamento.remove(key: Self.chave)
    }

    @Test("O item fica em AfterFirstUnlockThisDeviceOnly: não sai do aparelho no backup")
    func classeDeAcessoSoDesteAparelho() throws {
        let servico = servicoDeTeste()
        let armazenamento = SessaoNoKeychainDoAparelho(servico: servico)
        defer { try? armazenamento.remove(key: Self.chave) }

        try armazenamento.store(key: Self.chave, value: Data("sessao".utf8))
        #expect(armazenamento.classeDeAcesso(chave: Self.chave) == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    @Test("Migra o item que o SDK gravou em AfterFirstUnlock: lê a sessão antiga e a regrava na classe nova")
    func migraOItemDoSDK() throws {
        let servico = servicoDeTeste()
        let armazenamento = SessaoNoKeychainDoAparelho(servico: servico)
        defer { try? armazenamento.remove(key: Self.chave) }

        // O que o KeychainLocalStorage 2.55.2 deixa no aparelho: mesmo serviço e conta, classe sem ThisDeviceOnly.
        let itemAntigo: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: Self.chave,
            kSecValueData as String: Data("sessao-antiga".utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        #expect(SecItemAdd(itemAntigo as CFDictionary, nil) == errSecSuccess)
        #expect(armazenamento.classeDeAcesso(chave: Self.chave) == kSecAttrAccessibleAfterFirstUnlock as String)

        #expect(try armazenamento.retrieve(key: Self.chave) == Data("sessao-antiga".utf8))
        try armazenamento.store(key: Self.chave, value: Data("sessao-renovada".utf8))
        #expect(try armazenamento.retrieve(key: Self.chave) == Data("sessao-renovada".utf8))
        #expect(armazenamento.classeDeAcesso(chave: Self.chave) == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    @Test("O serviço padrão é o do SDK: a sessão de um build anterior continua sendo lida")
    func servicoPadraoEODoSDK() {
        #expect(SessaoNoKeychainDoAparelho.servicoPadrao == "supabase.gotrue.swift")
    }

    // MARK: - Resiliência e Dublê de Falha de Keychain

    @Test("retrieve com dispositivo bloqueado (errSecInteractionNotAllowed) lança ErroDoKeychainDaSessao")
    func retrieveComDispositivoBloqueadoLancaErro() {
        let duble = OperacoesDoKeychainDuble(statusCopy: errSecInteractionNotAllowed)
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)

        #expect(throws: ErroDoKeychainDaSessao.status(errSecInteractionNotAllowed)) {
            try armazenamento.retrieve(key: Self.chave)
        }
    }

    @Test("retrieve com falha de autorização (errSecAuthFailed) lança ErroDoKeychainDaSessao")
    func retrieveComFalhaDeAutorizacaoLancaErro() {
        let duble = OperacoesDoKeychainDuble(statusCopy: errSecAuthFailed)
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)

        #expect(throws: ErroDoKeychainDaSessao.status(errSecAuthFailed)) {
            try armazenamento.retrieve(key: Self.chave)
        }
    }

    @Test("store com erro no SecItemAdd lança ErroDoKeychainDaSessao com o código exato")
    func storeComErroLancaStatus() {
        let duble = OperacoesDoKeychainDuble(statusAdd: errSecDiskFull)
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)

        #expect(throws: ErroDoKeychainDaSessao.status(errSecDiskFull)) {
            try armazenamento.store(key: Self.chave, value: Data("token".utf8))
        }
    }

    @Test("remove com erro diferente de errSecItemNotFound lança ErroDoKeychainDaSessao")
    func removeComErroLancaStatus() {
        let duble = OperacoesDoKeychainDuble(statusDelete: errSecInteractionNotAllowed)
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)

        #expect(throws: ErroDoKeychainDaSessao.status(errSecInteractionNotAllowed)) {
            try armazenamento.remove(key: Self.chave)
        }
    }

    @Test("remove com errSecItemNotFound é resiliente e não lança erro")
    func removeComItemNaoEncontradoNaoLanca() throws {
        let duble = OperacoesDoKeychainDuble(statusDelete: errSecItemNotFound)
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)

        try armazenamento.remove(key: Self.chave)
    }
}

private struct OperacoesDoKeychainDuble: OperacoesDoKeychainDaSessao {
    var statusAdd: OSStatus = errSecSuccess
    var statusCopy: OSStatus = errSecSuccess
    var statusDelete: OSStatus = errSecSuccess
    var dadosRetornados: Data?

    func secItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        statusAdd
    }

    func secItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        if statusCopy == errSecSuccess, let dados = dadosRetornados {
            result?.pointee = dados as CFData
        }
        return statusCopy
    }

    func secItemDelete(_ query: CFDictionary) -> OSStatus {
        statusDelete
    }
}
