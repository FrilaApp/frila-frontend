import Foundation
import Security

public enum ErroKeychain: Error, Equatable, Sendable {
    case status(OSStatus)
}

public struct ArmazenamentoKeychain: Sendable {
    private let servico: String
    public init(servico: String) { self.servico = servico }

    public func salvar(_ dados: Data, conta: String) throws {
        let consulta = base(conta: conta)
        SecItemDelete(consulta as CFDictionary)
        var item = consulta
        item[kSecValueData as String] = dados
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw ErroKeychain.status(status) }
    }

    public func ler(conta: String) throws -> Data? {
        var consulta = base(conta: conta)
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: CFTypeRef?
        let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw ErroKeychain.status(status) }
        return resultado as? Data
    }

    public func remover(conta: String) throws {
        let status = SecItemDelete(base(conta: conta) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ErroKeychain.status(status) }
    }

    private func base(conta: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servico, kSecAttrAccount as String: conta]
    }
}
