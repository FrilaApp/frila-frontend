import Foundation
import os
import SwiftUI

// MARK: - Modelos de Função e Categoria (Frila Role Catalog)

/// Origem de uma função selecionada na vaga.
public enum FrilaLPERoleOrigin: String, Hashable, Sendable {
    /// Função pré-existente no catálogo oficial do Frila.
    case catalog
    /// Função criada sob demanda pelo contratante.
    case custom
}

/// Função individual do catálogo do Frila.
public struct FrilaLPERole: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Categoria organizadora de funções.
public struct FrilaLPERoleCategory: Identifiable, Hashable, Sendable {
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
public enum FrilaLPERoleCatalog {
    /// Categoria especial que agrupa todas as funções do catálogo em ordem alfabética.
    public static var allCategory: FrilaLPERoleCategory {
        FrilaLPERoleCategory(id: "todas", name: "Todas", roleIDs: allRolesSorted.map(\.id))
    }

    // Enxerto: o catálogo da origem (45 funções) não casa com as funções do servidor. A tela do
    // estúdio chama `usar(categorias:)` com `api.funcoes()`; o catálogo estático só vale até lá.
    private struct Estado: Sendable {
        var categories: [FrilaLPERoleCategory]
        var roles: [FrilaLPERole]
    }

    private static let estado = OSAllocatedUnfairLock(initialState: Estado(categories: categoriasDaOrigem, roles: funcoesDaOrigem))

    public static var categories: [FrilaLPERoleCategory] { estado.withLock { $0.categories } }
    public static var roles: [FrilaLPERole] { estado.withLock { $0.roles } }

    /// Troca o catálogo pelas funções do servidor, agrupadas por categoria na ordem em que chegam.
    public static func usar(categorias: [(nome: String, funcoes: [FrilaLPERole])]) {
        let categories = categorias.map { categoria in
            FrilaLPERoleCategory(id: categoria.nome, name: categoria.nome, roleIDs: categoria.funcoes.map(\.id))
        }
        let roles = categorias.flatMap(\.funcoes)
        estado.withLock { $0 = Estado(categories: categories, roles: roles) }
    }

    /// As 12 categorias canônicas do catálogo v1.
    private static let categoriasDaOrigem: [FrilaLPERoleCategory] = [
        FrilaLPERoleCategory(
            id: "bar",
            name: "Bar",
            roleIDs: ["garcom", "bartender", "barback", "atendente", "operador-de-caixa", "copeiro"]
        ),
        FrilaLPERoleCategory(
            id: "restaurante",
            name: "Restaurante",
            roleIDs: ["garcom", "cumim", "recepcionista", "atendente", "operador-de-caixa", "copeiro"]
        ),
        FrilaLPERoleCategory(
            id: "cozinha",
            name: "Cozinha",
            roleIDs: ["cozinheiro", "auxiliar-de-cozinha", "chapeiro", "pizzaiolo", "salgadeiro", "confeiteiro", "lavador-de-pratos"]
        ),
        FrilaLPERoleCategory(
            id: "cafe-e-padaria",
            name: "Café e padaria",
            roleIDs: ["barista", "balconista", "atendente", "padeiro", "confeiteiro", "operador-de-caixa"]
        ),
        FrilaLPERoleCategory(
            id: "eventos",
            name: "Eventos",
            roleIDs: ["garcom", "bartender", "copeiro", "recepcionista", "promotor-de-eventos", "montador-de-eventos", "controlador-de-acesso", "carregador", "monitor-infantil"]
        ),
        FrilaLPERoleCategory(
            id: "loja-e-mercado",
            name: "Loja e mercado",
            roleIDs: ["vendedor", "repositor", "operador-de-caixa", "empacotador", "promotor-de-vendas", "estoquista"]
        ),
        FrilaLPERoleCategory(
            id: "limpeza",
            name: "Limpeza",
            roleIDs: ["auxiliar-de-limpeza", "diarista", "camareira", "lavador-de-pratos", "lavador-de-carros"]
        ),
        FrilaLPERoleCategory(
            id: "hotel",
            name: "Hotel",
            roleIDs: ["camareira", "recepcionista", "mensageiro", "garcom", "auxiliar-de-limpeza"]
        ),
        FrilaLPERoleCategory(
            id: "carga-e-entrega",
            name: "Carga e entrega",
            roleIDs: ["entregador", "ajudante-de-carga", "carregador", "separador-de-pedidos", "estoquista"]
        ),
        FrilaLPERoleCategory(
            id: "obras-e-reparos",
            name: "Obras e reparos",
            roleIDs: ["ajudante-de-obras", "pintor", "montador-de-moveis", "carregador"]
        ),
        FrilaLPERoleCategory(
            id: "portaria",
            name: "Portaria",
            roleIDs: ["porteiro", "controlador-de-acesso", "manobrista"]
        ),
        FrilaLPERoleCategory(
            id: "casa-e-cuidados",
            name: "Casa e cuidados",
            roleIDs: ["diarista", "baba", "cuidador-de-idosos", "jardineiro", "passeador-de-caes"]
        )
    ]

    /// As 45 funções únicas do catálogo v1.
    private static let funcoesDaOrigem: [FrilaLPERole] = [
        FrilaLPERole(id: "garcom", name: "Garçom"),
        FrilaLPERole(id: "bartender", name: "Bartender"),
        FrilaLPERole(id: "barback", name: "Barback"),
        FrilaLPERole(id: "atendente", name: "Atendente"),
        FrilaLPERole(id: "operador-de-caixa", name: "Operador de caixa"),
        FrilaLPERole(id: "copeiro", name: "Copeiro"),
        FrilaLPERole(id: "cumim", name: "Cumim"),
        FrilaLPERole(id: "recepcionista", name: "Recepcionista"),
        FrilaLPERole(id: "cozinheiro", name: "Cozinheiro"),
        FrilaLPERole(id: "auxiliar-de-cozinha", name: "Auxiliar de cozinha"),
        FrilaLPERole(id: "chapeiro", name: "Chapeiro"),
        FrilaLPERole(id: "pizzaiolo", name: "Pizzaiolo"),
        FrilaLPERole(id: "salgadeiro", name: "Salgadeiro"),
        FrilaLPERole(id: "confeiteiro", name: "Confeiteiro"),
        FrilaLPERole(id: "lavador-de-pratos", name: "Lavador de pratos"),
        FrilaLPERole(id: "barista", name: "Barista"),
        FrilaLPERole(id: "balconista", name: "Balconista"),
        FrilaLPERole(id: "padeiro", name: "Padeiro"),
        FrilaLPERole(id: "promotor-de-eventos", name: "Promotor de eventos"),
        FrilaLPERole(id: "montador-de-eventos", name: "Montador de eventos"),
        FrilaLPERole(id: "controlador-de-acesso", name: "Controlador de acesso"),
        FrilaLPERole(id: "carregador", name: "Carregador"),
        FrilaLPERole(id: "monitor-infantil", name: "Monitor infantil"),
        FrilaLPERole(id: "vendedor", name: "Vendedor"),
        FrilaLPERole(id: "repositor", name: "Repositor"),
        FrilaLPERole(id: "empacotador", name: "Empacotador"),
        FrilaLPERole(id: "promotor-de-vendas", name: "Promotor de vendas"),
        FrilaLPERole(id: "estoquista", name: "Estoquista"),
        FrilaLPERole(id: "auxiliar-de-limpeza", name: "Auxiliar de limpeza"),
        FrilaLPERole(id: "diarista", name: "Diarista"),
        FrilaLPERole(id: "camareira", name: "Camareira"),
        FrilaLPERole(id: "lavador-de-carros", name: "Lavador de carros"),
        FrilaLPERole(id: "mensageiro", name: "Mensageiro"),
        FrilaLPERole(id: "entregador", name: "Entregador"),
        FrilaLPERole(id: "ajudante-de-carga", name: "Ajudante de carga"),
        FrilaLPERole(id: "separador-de-pedidos", name: "Separador de pedidos"),
        FrilaLPERole(id: "ajudante-de-obras", name: "Ajudante de obras"),
        FrilaLPERole(id: "pintor", name: "Pintor"),
        FrilaLPERole(id: "montador-de-moveis", name: "Montador de móveis"),
        FrilaLPERole(id: "porteiro", name: "Porteiro"),
        FrilaLPERole(id: "manobrista", name: "Manobrista"),
        FrilaLPERole(id: "baba", name: "Babá"),
        FrilaLPERole(id: "cuidador-de-idosos", name: "Cuidador de idosos"),
        FrilaLPERole(id: "jardineiro", name: "Jardineiro"),
        FrilaLPERole(id: "passeador-de-caes", name: "Passeador de cães")
    ]

    private static var rolesMap: [String: FrilaLPERole] {
        Dictionary(roles.map { ($0.id, $0) }, uniquingKeysWith: { primeira, _ in primeira })
    }

    /// Retorna as funções pertencentes à categoria informada, na ordem de demanda do catálogo.
    public static func roles(in category: FrilaLPERoleCategory) -> [FrilaLPERole] {
        if category.id == allCategory.id {
            return allRolesSorted
        }
        return category.roleIDs.compactMap { rolesMap[$0] }
    }

    /// Retorna as funções pertencentes à categoria com o identificador informado.
    public static func roles(inCategoryID categoryID: String) -> [FrilaLPERole] {
        if categoryID == allCategory.id {
            return allRolesSorted
        }
        guard let cat = categories.first(where: { $0.id == categoryID }) else { return [] }
        return cat.roleIDs.compactMap { rolesMap[$0] }
    }

    /// Todas as 45 funções do catálogo sem repetição e ordenadas alfabeticamente.
    public static var allRolesSorted: [FrilaLPERole] {
        roles.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Retorna todas as categorias que contêm a função especificada.
    public static func categories(containing role: FrilaLPERole) -> [FrilaLPERoleCategory] {
        categories(containingRoleID: role.id)
    }

    /// Retorna todas as categorias que contêm o ID de função especificado.
    public static func categories(containingRoleID roleID: String) -> [FrilaLPERoleCategory] {
        categories.filter { $0.roleIDs.contains(roleID) }
    }

    /// Compara o nome informado com o catálogo inteiro sem diferenciar maiúsculas e acentos.
    /// Retorna a função canônica correspondente se houver coincidência exata normalizada.
    public static func match(_ name: String) -> FrilaLPERole? {
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

public enum FrilaLPERoleCouplingRules {
    /// Regra da seção 2.3: se a função atual existe na nova categoria, ela continua selecionada;
    /// se não existe, a seleção de função é apagada (retorna nil).
    public static func resolveRoleOnCategoryChange(
        currentRole: FrilaLPERole?,
        newCategory: FrilaLPERoleCategory,
        customRolesInCategory: [FrilaLPERole] = []
    ) -> FrilaLPERole? {
        guard let currentRole else { return nil }

        let available = FrilaLPERoleCatalog.roles(in: newCategory) + customRolesInCategory
        if available.contains(where: { $0.id == currentRole.id || FrilaLPERoleCatalog.fold($0.name) == FrilaLPERoleCatalog.fold(currentRole.name) }) {
            return currentRole
        }
        return nil
    }
}

// MARK: - Validação de Criação de Categoria e Função

public enum FrilaLPERoleValidation {
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
public struct FrilaLPECustomRoleChip: View {
    public let isDark: Bool

    public init(isDark: Bool = false) {
        self.isDark = isDark
    }

    public var body: some View {
        HStack(spacing: FrilaLPEGeometry.space6) {
            Image(systemName: "square.and.pencil")
                .font(FrilaLPETypography.caption)
            Text("Função criada pelo contratante", tableName: "FrilaLPEEstudio", bundle: bundleApresentacao)
                .font(FrilaLPETypography.captionMedium)
        }
        .foregroundColor(FrilaLPEColor.dynamicBrandChipText(isDark: isDark))
        .padding(.horizontal, FrilaLPEGeometry.space10)
        .padding(.vertical, FrilaLPEGeometry.space4)
        .background(FrilaLPEColor.dynamicBrandChipBg(isDark: isDark), in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    isDark ? FrilaLPEColor.dynamicBrandChipBorder(isDark: isDark) : FrilaLPEColor.dynamicHairline(isDark: isDark),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Função criada pelo contratante", table: "FrilaLPEEstudio", bundle: bundleApresentacao))
    }
}
