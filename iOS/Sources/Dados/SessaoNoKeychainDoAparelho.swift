import Foundation
import Security
import Supabase

/// A sessão do Supabase (token de acesso e de renovação) no Keychain só deste aparelho.
///
/// O armazenamento padrão do supabase-swift (`KeychainLocalStorage`, 2.55.2) grava o item com
/// `kSecAttrAccessibleAfterFirstUnlock`, sem `ThisDeviceOnly`: o item entra no backup cifrado e é
/// restaurado em outro iPhone, levando a sessão junto. Aqui a classe é
/// `AfterFirstUnlockThisDeviceOnly`, a mesma do token de push (`ArmazenamentoKeychain`): a sessão
/// não sai do aparelho em que a pessoa entrou.
///
/// O serviço e as chaves são os mesmos do padrão do SDK, de propósito: a sessão guardada por um
/// build anterior continua sendo lida, e a próxima gravação (renovação do token, entrada) a regrava
/// na classe nova. Ninguém precisa entrar de novo.
public struct SessaoNoKeychainDoAparelho: AuthLocalStorage {
    /// O serviço padrão do `KeychainLocalStorage` do SDK.
    public static let servicoPadrao = "supabase.gotrue.swift"
    private let servico: String

    public init(servico: String = Self.servicoPadrao) {
        self.servico = servico
    }

    public func store(key: String, value: Data) throws {
        // Apagar e inserir, em vez de `SecItemUpdate`: só a inserção aplica a classe de acesso, e é
        // ela que migra o item gravado pelo SDK na classe antiga.
        SecItemDelete(consulta(chave: key) as CFDictionary)
        var item = consulta(chave: key)
        item[kSecValueData as String] = value
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw ErroDoKeychainDaSessao.status(status) }
    }

    public func retrieve(key: String) throws -> Data? {
        var consulta = consulta(chave: key)
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: CFTypeRef?
        let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw ErroDoKeychainDaSessao.status(status) }
        return resultado as? Data
    }

    public func remove(key: String) throws {
        let status = SecItemDelete(consulta(chave: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ErroDoKeychainDaSessao.status(status) }
    }

    /// A classe de acesso do item guardado, para o teste comprovar a migração. `nil` sem item.
    func classeDeAcesso(chave: String) -> String? {
        var consulta = consulta(chave: chave)
        consulta[kSecReturnAttributes as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: CFTypeRef?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let atributos = resultado as? [String: Any] else { return nil }
        return atributos[kSecAttrAccessible as String] as? String
    }

    private func consulta(chave: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servico, kSecAttrAccount as String: chave]
    }
}

public enum ErroDoKeychainDaSessao: Error, Equatable, Sendable {
    case status(OSStatus)
}
