import FrilaDominio
import SwiftUI

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício.
// O cartão provisório da busca: foto pequena e circular quando o servidor mandou `foto_url` (contrato 0.2.90, CD-B07),
// senão a inicial do nome. Só `AsyncImage` nativo e os tokens que o app já usa; nenhum componente novo.

/// A foto (ou a inicial) do cartão da busca. Foto que não carrega (404, qualquer erro) ou que ainda carrega mostra a
/// INICIAL, sem mensagem de erro na tela.
public struct FotoDoCartaoDaBusca: View {
    /// O que se desenha para uma fase do `AsyncImage`.
    public enum Aparencia {
        case foto(Image)
        case inicial
    }

    /// Lado do círculo, em pontos.
    public static let lado: CGFloat = 40

    private let nome: String
    private let fotoURL: URL?

    public init(nome: String, fotoURL: URL?) {
        self.nome = nome
        self.fotoURL = fotoURL
    }

    /// Só a foto carregada vira foto; vazio, carregando ou falha é a inicial.
    public static func aparencia(para fase: AsyncImagePhase) -> Aparencia {
        if case let .success(imagem) = fase { return .foto(imagem) }
        return .inicial
    }

    /// A primeira letra do nome, em maiúscula; sem nome, "?".
    public static func inicial(de nome: String) -> String {
        guard let primeira = nome.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "?" }
        return String(primeira).uppercased()
    }

    public var body: some View {
        Group {
            if let fotoURL {
                AsyncImage(url: fotoURL) { fase in
                    switch Self.aparencia(para: fase) {
                    case let .foto(imagem): imagem.resizable().scaledToFill()
                    case .inicial: letra
                    }
                }
            } else {
                letra
            }
        }
        .frame(width: Self.lado, height: Self.lado)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var letra: some View {
        Text(verbatim: Self.inicial(de: nome))
            .font(FrilaTipo.resumo)
            .foregroundStyle(FrilaCor.textoSecundario)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrilaCor.controle)
    }
}

/// O cartão de um resultado da busca, provisório: foto ou inicial, nome e serviço.
public struct CartaoDaBuscaProvisorio: View {
    private let cartao: CartaoProfissional

    public init(cartao: CartaoProfissional) { self.cartao = cartao }

    public var body: some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            FotoDoCartaoDaBusca(nome: cartao.nome, fotoURL: cartao.fotoURL)
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: cartao.nome).font(FrilaTipo.resumo)
                Text(verbatim: cartao.servico.funcao.nome)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
