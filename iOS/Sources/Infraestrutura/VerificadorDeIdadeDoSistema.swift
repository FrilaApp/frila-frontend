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

    /// Interpreta a faixa etária retornada pela Declared Age Range com corte em 18 anos.
    ///
    /// Ordem de decisão:
    /// 1. lowerBound >= 18 -> 18 ou mais (.dezoitoOuMais)
    /// 2. upperBound presente e < 18 -> abaixo de 18 (.abaixoDe18)
    /// 3. qualquer outra combinação (bounds ausentes, cruzando o corte, etc.) -> .indisponivel
    public static func interpretarFaixa(lowerBound: Int?, upperBound: Int?) -> ResultadoVerificacaoIdade {
        if let lower = lowerBound, lower >= 18 {
            return .dezoitoOuMais
        }
        if let upper = upperBound, upper < 18 {
            return .abaixoDe18
        }
        return .indisponivel
    }

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
                    return Self.interpretarFaixa(lowerBound: range.lowerBound, upperBound: range.upperBound)
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
