import Foundation
import FrilaDominio
#if canImport(UIKit)
import UIKit
#endif
#if canImport(DeclaredAgeRange)
@preconcurrency import DeclaredAgeRange
#endif

/// Implementação real da verificação de idade usando DeclaredAgeRange (iOS 26.2+).
public struct VerificadorDeIdadeDoSistema: VerificadorDeIdade {
    public init() {}

    @MainActor
    public func verificarMaioridade() async -> ResultadoVerificacaoIdade {
        if #available(iOS 26.2, *) {
            #if canImport(DeclaredAgeRange)
            do {
                guard try await AgeRangeService.shared.isEligibleForAgeFeatures else {
                    return .indisponivel
                }
                guard let viewController = obterViewControllerPrincipal() else {
                    return .indisponivel
                }
                let resposta = try await AgeRangeService.shared.requestAgeRange(ageGates: 18, in: viewController)
                switch resposta {
                case .declinedSharing:
                    return .recusou
                case let .sharing(range):
                    if let upper = range.upperBound, upper <= 18 {
                        return .abaixoDe18
                    }
                    if let lower = range.lowerBound, lower >= 18 {
                        return .dezoitoOuMais
                    }
                    if range.upperBound != nil {
                        return .abaixoDe18
                    }
                    return .dezoitoOuMais
                @unknown default:
                    return .indisponivel
                }
            } catch {
                return .indisponivel
            }
            #else
            return .indisponivel
            #endif
        } else {
            return .indisponivel
        }
    }

    #if canImport(UIKit)
    @MainActor
    private func obterViewControllerPrincipal() -> UIViewController? {
        guard let cena = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let janela = cena.windows.first(where: \.isKeyWindow) ?? cena.windows.first,
              let raiz = janela.rootViewController else {
            return nil
        }
        var atual: UIViewController = raiz
        while let apresentada = atual.presentedViewController {
            atual = apresentada
        }
        return atual
    }
    #endif
}
