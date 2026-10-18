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

    // MARK: - Comportamento de Bloqueio/Desbloqueio (errSecInteractionNotAllowed)

    @Test("Com aparelho bloqueado (errSecInteractionNotAllowed) a sessão é MANTIDA e leitura é recuperada ao desbloquear")
    func sessaoMantidaQuandoAparelhoBloqueadoERecuperadaAoDesbloquear() throws {
        let duble = SimuladorCicloDeVidaKeychain()
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)

        // 1. Sessão é guardada com o aparelho desbloqueado
        try armazenamento.store(key: Self.chave, value: Data("sessao-valida-token".utf8))
        duble.zerarContadores()

        // 2. Aparelho é bloqueado (ex.: reinicialização / push em segundo plano antes do 1º desbloqueio)
        duble.bloquear()

        // 3. Leitura com aparelho bloqueado falha com errSecInteractionNotAllowed, mas a sessão NUNCA é apagada
        #expect(throws: ErroDoKeychainDaSessao.status(errSecInteractionNotAllowed)) {
            try armazenamento.retrieve(key: Self.chave)
        }
        #expect(duble.chamadasDelete == 0, "A sessão JAMAIS pode ser apagada por falha transitória de leitura")
        #expect(duble.temItemArmazenado(chave: Self.chave), "O item deve permanecer intacto no Keychain")

        // 4. Aparelho é desbloqueado pelo usuário
        duble.desbloquear()

        // 5. Leitura subsequente retentada recupera a sessão intacta sem necessidade de novo login
        let sessaoRecuperada = try armazenamento.retrieve(key: Self.chave)
        #expect(sessaoRecuperada == Data("sessao-valida-token".utf8))
        #expect(duble.chamadasDelete == 0)
    }

    @Test("Com falha de autenticação do Keychain (errSecAuthFailed) a sessão gravada é preservada")
    func sessaoMantidaComAuthFailed() throws {
        let duble = SimuladorCicloDeVidaKeychain()
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)
        try armazenamento.store(key: Self.chave, value: Data("sessao-valida-token".utf8))
        duble.zerarContadores()

        duble.simularAuthFailed()
        #expect(throws: ErroDoKeychainDaSessao.status(errSecAuthFailed)) {
            try armazenamento.retrieve(key: Self.chave)
        }
        #expect(duble.chamadasDelete == 0)
        #expect(duble.temItemArmazenado(chave: Self.chave))
    }

    @Test("Com item não encontrado (errSecItemNotFound) retrieve devolve nil sem apagar nada")
    func itemNaoEncontradoDevolveNilSemApagar() throws {
        let duble = SimuladorCicloDeVidaKeychain()
        let armazenamento = SessaoNoKeychainDoAparelho(servico: "teste", operacoes: duble)

        let resultado = try armazenamento.retrieve(key: "chave-inexistente")
        #expect(resultado == nil)
        #expect(duble.chamadasDelete == 0)
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

private final class SimuladorCicloDeVidaKeychain: OperacoesDoKeychainDaSessao, @unchecked Sendable {
    private let trava = NSLock()
    private var itens: [String: Data] = [:]
    private var statusLeitura: OSStatus = errSecSuccess
    private(set) var chamadasDelete = 0

    func bloquear() {
        trava.withLock { statusLeitura = errSecInteractionNotAllowed }
    }

    func desbloquear() {
        trava.withLock { statusLeitura = errSecSuccess }
    }

    func simularAuthFailed() {
        trava.withLock { statusLeitura = errSecAuthFailed }
    }

    func zerarContadores() {
        trava.withLock { chamadasDelete = 0 }
    }

    func temItemArmazenado(chave: String) -> Bool {
        trava.withLock { itens[chave] != nil }
    }

    func secItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        trava.withLock {
            let dict = attributes as NSDictionary
            if let conta = dict[kSecAttrAccount as String] as? String,
               let dados = dict[kSecValueData as String] as? Data {
                itens[conta] = dados
            }
            return errSecSuccess
        }
    }

    func secItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        trava.withLock {
            if statusLeitura != errSecSuccess {
                return statusLeitura
            }
            let dict = query as NSDictionary
            guard let conta = dict[kSecAttrAccount as String] as? String,
                  let dados = itens[conta] else {
                return errSecItemNotFound
            }
            result?.pointee = dados as CFData
            return errSecSuccess
        }
    }

    func secItemDelete(_ query: CFDictionary) -> OSStatus {
        trava.withLock {
            chamadasDelete += 1
            let dict = query as NSDictionary
            if let conta = dict[kSecAttrAccount as String] as? String {
                itens.removeValue(forKey: conta)
            }
            return errSecSuccess
        }
    }
}
