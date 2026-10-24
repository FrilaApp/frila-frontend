import Foundation

/// Regra de pré-seleção visual da roleta de Função quando nenhuma função foi escolhida.
/// Com uma categoria em jogo (confirmada ou em foco no arrasto), a roleta já repousa na primeira
/// função da lista, sem confirmá-la. O slot neutro só é o repouso quando a pessoa mexe em Função
/// sem ter tocado em nenhuma categoria.
public enum FrilaRolePreselection: Sendable {
    public static let neutralMarkerID = "marker_role"

    /// - Parameters:
    ///   - selectedRole: Função confirmada (vazia se não há).
    ///   - hasCategoryContext: Há categoria confirmada ou em foco.
    ///   - firstSelectableID: Primeira função selecionável da lista atual.
    ///   - confirmedID: Identificador da função confirmada, quando houver.
    public static func selectedID(
        selectedRole: String,
        confirmedID: String?,
        hasCategoryContext: Bool,
        firstSelectableID: String?
    ) -> String {
        if !selectedRole.isEmpty { return confirmedID ?? selectedRole }
        if hasCategoryContext, let firstSelectableID { return firstSelectableID }
        return neutralMarkerID
    }
}
