import Foundation
import SwiftUI

private final class MarcadorBundle: NSObject {}

public enum FrilaCor {
    private static let recursos = Bundle(for: MarcadorBundle.self)
    public static let primaria = Color("BrandPrimary", bundle: recursos)
    public static let sobrePrimaria = Color("BrandOnPrimary", bundle: recursos)
    public static let fundo = Color("Surface", bundle: recursos)
    public static let superficie = Color("SurfaceElevated", bundle: recursos)
    public static let texto = Color("TextPrimary", bundle: recursos)
    public static let textoSecundario = Color("TextSecondary", bundle: recursos)
    public static let sucesso = Color("Success", bundle: recursos)
    public static let alerta = Color("Warning", bundle: recursos)
    public static let perigo = Color("Danger", bundle: recursos)
}

public enum FrilaEspaco {
    public static let minimo: CGFloat = 4
    public static let pequeno: CGFloat = 8
    public static let medio: CGFloat = 16
    public static let grande: CGFloat = 24
    public static let enorme: CGFloat = 32
}

public enum FrilaRaio {
    public static let pequeno: CGFloat = 8
    public static let medio: CGFloat = 12
    public static let grande: CGFloat = 20
}

public enum FrilaMetrica {
    public static let alvoMinimo: CGFloat = 44
    public static let larguraMaximaDeLeitura: CGFloat = 680
}

public extension View {
    func cartaoFrila() -> some View {
        padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
    }
}
