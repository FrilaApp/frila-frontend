import CryptoKit
import Foundation
import Security

/// Armazena o token opaco de confiança de dispositivo (30 dias) por conta normalizada.
///
/// Contrato 0.2.112 §4: fica em item de Keychain próprio (`br.com.frila.dispositivo`), isolado da
/// sessão do GoTrue (`SessaoNoKeychainDoAparelho` / `supabase.gotrue.swift`) e com proteção
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` para não sair deste aparelho no backup.
public protocol ArmazenamentoDeDeviceToken: Sendable {
    func salvar(token: String, email: String) throws
    func obter(email: String) -> String?
    func remover(email: String)
    func removerTodos()
}

public struct DispositivoNoKeychainDoAparelho: ArmazenamentoDeDeviceToken {
    public static let servicoPadrao = "br.com.frila.dispositivo"
    private let servico: String
    private let operacoes: any OperacoesDoKeychainDaSessao

    public init(servico: String = Self.servicoPadrao) {
        self.init(servico: servico, operacoes: OperacoesDoKeychainDoSistema())
    }

    init(servico: String = Self.servicoPadrao, operacoes: any OperacoesDoKeychainDaSessao) {
        self.servico = servico
        self.operacoes = operacoes
    }

    public static func chaveDaConta(email: String) -> String {
        let normalizado = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digest = SHA256.hash(data: Data(normalizado.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "frila.dispositivo_token.\(hex)"
    }

    public func salvar(token: String, email: String) throws {
        guard !token.isEmpty else {
            remover(email: email)
            return
        }
        let chave = Self.chaveDaConta(email: email)
        let dados = Data(token.utf8)
        _ = operacoes.secItemDelete(consulta(chave: chave) as CFDictionary)
        var item = consulta(chave: chave)
        item[kSecValueData as String] = dados
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = operacoes.secItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw ErroDoKeychainDaSessao.status(status) }
    }

    public func obter(email: String) -> String? {
        let chave = Self.chaveDaConta(email: email)
        var consulta = consulta(chave: chave)
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: CFTypeRef?
        let status = operacoes.secItemCopyMatching(consulta as CFDictionary, &resultado)
        guard status == errSecSuccess, let dados = resultado as? Data else { return nil }
        let token = String(data: dados, encoding: .utf8)
        return (token?.isEmpty == false) ? token : nil
    }

    public func remover(email: String) {
        let chave = Self.chaveDaConta(email: email)
        _ = operacoes.secItemDelete(consulta(chave: chave) as CFDictionary)
    }

    public func removerTodos() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
        ]
        _ = operacoes.secItemDelete(query as CFDictionary)
    }

    func classeDeAcesso(email: String) -> String? {
        let chave = Self.chaveDaConta(email: email)
        var consulta = consulta(chave: chave)
        consulta[kSecReturnAttributes as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: CFTypeRef?
        guard operacoes.secItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let atributos = resultado as? [String: Any] else { return nil }
        return atributos[kSecAttrAccessible as String] as? String
    }

    private func consulta(chave: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: chave,
        ]
    }
}

/// Armazenamento em memória para testes unitários sem acesso ao Keychain do sistema.
final class ArmazenamentoDeDeviceTokenEmMemoria: ArmazenamentoDeDeviceToken, @unchecked Sendable {
    private let trava = NSLock()
    private var tokens: [String: String] = [:]

    func salvar(token: String, email: String) throws {
        let chave = DispositivoNoKeychainDoAparelho.chaveDaConta(email: email)
        trava.withLock {
            if token.isEmpty {
                tokens.removeValue(forKey: chave)
            } else {
                tokens[chave] = token
            }
        }
    }

    func obter(email: String) -> String? {
        let chave = DispositivoNoKeychainDoAparelho.chaveDaConta(email: email)
        return trava.withLock { tokens[chave] }
    }

    func remover(email: String) {
        let chave = DispositivoNoKeychainDoAparelho.chaveDaConta(email: email)
        _ = trava.withLock { tokens.removeValue(forKey: chave) }
    }

    func removerTodos() {
        trava.withLock { tokens.removeAll() }
    }
}
