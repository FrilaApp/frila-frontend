import Foundation
import os
import SwiftUI

// MARK: - Modelos de Função e Categoria (Frila Role Catalog)

/// Origem de uma função selecionada na vaga.
public enum FrilaRoleOrigin: String, Hashable, Sendable {
    /// Função pré-existente no catálogo oficial do Frila.
    case catalog
    /// Função criada sob demanda pelo contratante.
    case custom
}

/// Função individual do catálogo do Frila.
public struct FrilaRole: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Categoria organizadora de funções.
public struct FrilaRoleCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let roleIDs: [String]

    public init(id: String, name: String, roleIDs: [String]) {
        self.id = id
        self.name = name
        self.roleIDs = roleIDs
    }
}

// MARK: - Catálogo Oficial v1

/// Catálogo canônico de categorias e funções do Frila.
/// Desenvolvido para a base de freelas do Brasil: trabalho informal e recorrente,
/// sem certificação técnica nem especialização prévia obrigatória.
public enum FrilaRoleCatalog {
    /// Categoria especial que agrupa todas as funções do catálogo em ordem alfabética.
    public static var allCategory: FrilaRoleCategory {
        FrilaRoleCategory(id: "todas", name: "Todas", roleIDs: allRolesSorted.map(\.id))
    }

    // Enxerto: o catálogo da origem (45 funções) não casa com as funções do servidor. A tela do
    // estúdio chama `usar(categorias:)` com `api.funcoes()`; o catálogo estático só vale até lá.
    private struct Estado: Sendable {
        var categories: [FrilaRoleCategory]
        var roles: [FrilaRole]
    }

    private static let estado = OSAllocatedUnfairLock(initialState: Estado(categories: categoriasDaOrigem, roles: funcoesDaOrigem))

    public static var categories: [FrilaRoleCategory] { estado.withLock { $0.categories } }
    public static var roles: [FrilaRole] { estado.withLock { $0.roles } }

    /// Troca o catálogo pelas funções do servidor, agrupadas por categoria na ordem em que chegam.
    public static func usar(categorias: [(nome: String, funcoes: [FrilaRole])]) {
        let categories = categorias.map { categoria in
            FrilaRoleCategory(id: categoria.nome, name: categoria.nome, roleIDs: categoria.funcoes.map(\.id))
        }
        let roles = categorias.flatMap(\.funcoes)
        estado.withLock { $0 = Estado(categories: categories, roles: roles) }
    }

    /// As 12 categorias canônicas do catálogo v1.
    private static let categoriasDaOrigem: [FrilaRoleCategory] = [
        FrilaRoleCategory(
            id: "bar",
            name: "Bar",
            roleIDs: ["garcom", "bartender", "barback", "atendente", "operador-de-caixa", "copeiro"]
        ),
        FrilaRoleCategory(
            id: "restaurante",
            name: "Restaurante",
            roleIDs: ["garcom", "cumim", "recepcionista", "atendente", "operador-de-caixa", "copeiro"]
        ),
        FrilaRoleCategory(
            id: "cozinha",
            name: "Cozinha",
            roleIDs: ["cozinheiro", "auxiliar-de-cozinha", "chapeiro", "pizzaiolo", "salgadeiro", "confeiteiro", "lavador-de-pratos"]
        ),
        FrilaRoleCategory(
            id: "cafe-e-padaria",
            name: "Café e padaria",
            roleIDs: ["barista", "balconista", "atendente", "padeiro", "confeiteiro", "operador-de-caixa"]
        ),
        FrilaRoleCategory(
            id: "eventos",
            name: "Eventos",
            roleIDs: ["garcom", "bartender", "copeiro", "recepcionista", "promotor-de-eventos", "montador-de-eventos", "controlador-de-acesso", "carregador", "monitor-infantil"]
        ),
        FrilaRoleCategory(
            id: "loja-e-mercado",
            name: "Loja e mercado",
            roleIDs: ["vendedor", "repositor", "operador-de-caixa", "empacotador", "promotor-de-vendas", "estoquista"]
        ),
        FrilaRoleCategory(
            id: "limpeza",
            name: "Limpeza",
            roleIDs: ["auxiliar-de-limpeza", "diarista", "camareira", "lavador-de-pratos", "lavador-de-carros"]
        ),
        FrilaRoleCategory(
            id: "hotel",
            name: "Hotel",
            roleIDs: ["camareira", "recepcionista", "mensageiro", "garcom", "auxiliar-de-limpeza"]
        ),
        FrilaRoleCategory(
            id: "carga-e-entrega",
            name: "Carga e entrega",
            roleIDs: ["entregador", "ajudante-de-carga", "carregador", "separador-de-pedidos", "estoquista"]
        ),
        FrilaRoleCategory(
            id: "obras-e-reparos",
            name: "Obras e reparos",
            roleIDs: ["ajudante-de-obras", "pintor", "montador-de-moveis", "carregador"]
        ),
        FrilaRoleCategory(
            id: "portaria",
            name: "Portaria",
            roleIDs: ["porteiro", "controlador-de-acesso", "manobrista"]
        ),
        FrilaRoleCategory(
            id: "casa-e-cuidados",
            name: "Casa e cuidados",
            roleIDs: ["diarista", "baba", "cuidador-de-idosos", "jardineiro", "passeador-de-caes"]
        )
    ]

    /// As 45 funções únicas do catálogo v1.
    private static let funcoesDaOrigem: [FrilaRole] = [
        FrilaRole(id: "garcom", name: "Garçom"),
        FrilaRole(id: "bartender", name: "Bartender"),
        FrilaRole(id: "barback", name: "Barback"),
        FrilaRole(id: "atendente", name: "Atendente"),
        FrilaRole(id: "operador-de-caixa", name: "Operador de caixa"),
        FrilaRole(id: "copeiro", name: "Copeiro"),
        FrilaRole(id: "cumim", name: "Cumim"),
        FrilaRole(id: "recepcionista", name: "Recepcionista"),
        FrilaRole(id: "cozinheiro", name: "Cozinheiro"),
        FrilaRole(id: "auxiliar-de-cozinha", name: "Auxiliar de cozinha"),
        FrilaRole(id: "chapeiro", name: "Chapeiro"),
        FrilaRole(id: "pizzaiolo", name: "Pizzaiolo"),
        FrilaRole(id: "salgadeiro", name: "Salgadeiro"),
        FrilaRole(id: "confeiteiro", name: "Confeiteiro"),
        FrilaRole(id: "lavador-de-pratos", name: "Lavador de pratos"),
        FrilaRole(id: "barista", name: "Barista"),
        FrilaRole(id: "balconista", name: "Balconista"),
        FrilaRole(id: "padeiro", name: "Padeiro"),
        FrilaRole(id: "promotor-de-eventos", name: "Promotor de eventos"),
        FrilaRole(id: "montador-de-eventos", name: "Montador de eventos"),
        FrilaRole(id: "controlador-de-acesso", name: "Controlador de acesso"),
        FrilaRole(id: "carregador", name: "Carregador"),
        FrilaRole(id: "monitor-infantil", name: "Monitor infantil"),
        FrilaRole(id: "vendedor", name: "Vendedor"),
        FrilaRole(id: "repositor", name: "Repositor"),
        FrilaRole(id: "empacotador", name: "Empacotador"),
        FrilaRole(id: "promotor-de-vendas", name: "Promotor de vendas"),
        FrilaRole(id: "estoquista", name: "Estoquista"),
        FrilaRole(id: "auxiliar-de-limpeza", name: "Auxiliar de limpeza"),
        FrilaRole(id: "diarista", name: "Diarista"),
        FrilaRole(id: "camareira", name: "Camareira"),
        FrilaRole(id: "lavador-de-carros", name: "Lavador de carros"),
        FrilaRole(id: "mensageiro", name: "Mensageiro"),
        FrilaRole(id: "entregador", name: "Entregador"),
        FrilaRole(id: "ajudante-de-carga", name: "Ajudante de carga"),
        FrilaRole(id: "separador-de-pedidos", name: "Separador de pedidos"),
        FrilaRole(id: "ajudante-de-obras", name: "Ajudante de obras"),
        FrilaRole(id: "pintor", name: "Pintor"),
        FrilaRole(id: "montador-de-moveis", name: "Montador de móveis"),
        FrilaRole(id: "porteiro", name: "Porteiro"),
        FrilaRole(id: "manobrista", name: "Manobrista"),
        FrilaRole(id: "baba", name: "Babá"),
        FrilaRole(id: "cuidador-de-idosos", name: "Cuidador de idosos"),
        FrilaRole(id: "jardineiro", name: "Jardineiro"),
        FrilaRole(id: "passeador-de-caes", name: "Passeador de cães")
    ]

    private static var rolesMap: [String: FrilaRole] {
        Dictionary(roles.map { ($0.id, $0) }, uniquingKeysWith: { primeira, _ in primeira })
    }

    /// Retorna as funções pertencentes à categoria informada, na ordem de demanda do catálogo.
    public static func roles(in category: FrilaRoleCategory) -> [FrilaRole] {
        if category.id == allCategory.id {
            return allRolesSorted
        }
        return category.roleIDs.compactMap { rolesMap[$0] }
    }

    /// Retorna as funções pertencentes à categoria com o identificador informado.
    public static func roles(inCategoryID categoryID: String) -> [FrilaRole] {
        if categoryID == allCategory.id {
            return allRolesSorted
        }
        guard let cat = categories.first(where: { $0.id == categoryID }) else { return [] }
        return cat.roleIDs.compactMap { rolesMap[$0] }
    }

    /// Todas as 45 funções do catálogo sem repetição e ordenadas alfabeticamente.
    public static var allRolesSorted: [FrilaRole] {
        roles.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Retorna todas as categorias que contêm a função especificada.
    public static func categories(containing role: FrilaRole) -> [FrilaRoleCategory] {
        categories(containingRoleID: role.id)
    }

    /// Retorna todas as categorias que contêm o ID de função especificado.
    public static func categories(containingRoleID roleID: String) -> [FrilaRoleCategory] {
        categories.filter { $0.roleIDs.contains(roleID) }
    }

    /// Compara o nome informado com o catálogo inteiro sem diferenciar maiúsculas e acentos.
    /// Retorna a função canônica correspondente se houver coincidência exata normalizada.
    public static func match(_ name: String) -> FrilaRole? {
        let normalized = fold(name)
        guard !normalized.isEmpty else { return nil }
        return roles.first { fold($0.name) == normalized }
    }

    /// Dobra maiúsculas e acentos usando o locale pt_BR.
    public static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
    }
}

// MARK: - Regras de Acoplamento e Troca de Categoria

public enum FrilaRoleCouplingRules {
    /// Regra da seção 2.3: se a função atual existe na nova categoria, ela continua selecionada;
    /// se não existe, a seleção de função é apagada (retorna nil).
    public static func resolveRoleOnCategoryChange(
        currentRole: FrilaRole?,
        newCategory: FrilaRoleCategory,
        customRolesInCategory: [FrilaRole] = []
    ) -> FrilaRole? {
        guard let currentRole else { return nil }

        let available = FrilaRoleCatalog.roles(in: newCategory) + customRolesInCategory
        if available.contains(where: { $0.id == currentRole.id || FrilaRoleCatalog.fold($0.name) == FrilaRoleCatalog.fold(currentRole.name) }) {
            return currentRole
        }
        return nil
    }
}

// MARK: - Validação de Criação de Categoria e Função

public enum FrilaRoleValidation {
    /// Sanitiza espaços nas pontas e espaços duplicados, capitalizando a primeira letra.
    public static func sanitize(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let collapsed = parts.joined(separator: " ")
        guard let first = collapsed.first else { return "" }
        return first.uppercased() + collapsed.dropFirst()
    }

    /// Valida o nome de uma categoria ou função digitada pelo usuário:
    /// - 3 a 40 caracteres
    /// - primeira letra maiúscula
    /// - sem separadores artificiais (`·`, `•`, `—`, `-`)
    /// - sem emojis
    public static func validate(_ text: String) -> (isValid: Bool, sanitized: String, errorMessage: String?) {
        let sanitized = sanitize(text)

        if sanitized.count < 3 {
            return (false, sanitized, "O nome deve ter no mínimo 3 caracteres.")
        }
        if sanitized.count > 40 {
            return (false, sanitized, "O nome deve ter no máximo 40 caracteres.")
        }

        if containsForbiddenSeparators(sanitized) {
            return (false, sanitized, "Separadores especiais não são permitidos.")
        }

        if containsEmoji(sanitized) {
            return (false, sanitized, "Emojis não são permitidos.")
        }

        return (true, sanitized, nil)
    }

    private static func containsForbiddenSeparators(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            // 0x00B7: middle dot, 0x2022: bullet, 0x2014: em-dash
            if scalar.value == 0x00B7 || scalar.value == 0x2022 || scalar.value == 0x2014 {
                return true
            }
        }
        return false
    }

    private static func containsEmoji(_ string: String) -> Bool {
        for scalar in string.unicodeScalars {
            if scalar.properties.isEmoji && (scalar.value > 0x2380 || scalar.properties.isEmojiPresentation) {
                return true
            }
        }
        return false
    }
}

// MARK: - Marca de Função Criada pelo Contratante (Lado do Profissional)

/// Chip exibido nos cards e detalhes de vagas para profissionais,
/// indicando com SF Symbol que a função foi definida pelo contratante.
public struct FrilaCustomRoleChip: View {
    public let isDark: Bool

    public init(isDark: Bool = false) {
        self.isDark = isDark
    }

    public var body: some View {
        HStack(spacing: FrilaGeometry.space6) {
            Image(systemName: "square.and.pencil")
                .font(FrilaTypography.caption)
            Text("Função criada pelo contratante", tableName: "Estudio", bundle: bundleApresentacao)
                .font(FrilaTypography.captionMedium)
        }
        .foregroundColor(FrilaColor.dynamicBrandChipText(isDark: isDark))
        .padding(.horizontal, FrilaGeometry.space10)
        .padding(.vertical, FrilaGeometry.space4)
        .background(FrilaColor.dynamicBrandChipBg(isDark: isDark), in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    isDark ? FrilaColor.dynamicBrandChipBorder(isDark: isDark) : FrilaColor.dynamicHairline(isDark: isDark),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Função criada pelo contratante", table: "Estudio", bundle: bundleApresentacao))
    }
}
