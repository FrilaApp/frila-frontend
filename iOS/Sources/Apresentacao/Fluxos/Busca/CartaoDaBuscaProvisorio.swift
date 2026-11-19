import FrilaDominio
import SwiftUI

// O cartão da busca: foto pequena e circular quando o servidor mandou `foto_url` (contrato 0.2.90, CD-B07), senão a
// inicial do nome. Desenho do sistema do Fabrício extrapolado para a casa (R6); o nome do tipo ficou, para não mexer
// no projeto e nos testes.

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
        .overlay { Circle().strokeBorder(FrilaCor.divisoria, lineWidth: 1) }
        .accessibilityHidden(true)
    }

    private var letra: some View {
        Text(verbatim: Self.inicial(de: nome))
            .font(FrilaTipo.nome)
            .foregroundStyle(FrilaCor.textoSecundario)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrilaCor.controle)
    }
}

/// O cartão de um resultado da busca: foto ou inicial, nome, serviço com preço, faixa de distância, reputação escrita
/// como fato (na voz de quem avalia) e o selo "disponível nesse horário". É o rótulo da linha da lista em
/// `TelaBuscaDeProfissionais`; sem laranja: a lista é de escolha.
public struct CartaoDaBuscaProvisorio: View {
    private let cartao: CartaoProfissional

    public init(cartao: CartaoProfissional) { self.cartao = cartao }

    public var body: some View {
        HStack(alignment: .top, spacing: FrilaEspaco.bloco) {
            FotoDoCartaoDaBusca(nome: cartao.nome, fotoURL: cartao.fotoURL)
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text(verbatim: cartao.nome)
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                Text(verbatim: TextosDosServicos.resumoDoServico(cartao.servico.servico) ?? cartao.servico.funcao.nome)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                Text(verbatim: cartao.distanciaFaixa.rotulo)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: SeloReputacao.descricao(cartao.reputacao))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                if cartao.disponivelNoHorario == true {
                    SeloDeStatus(verbatim: TextosBuscaDeProfissionais.disponivelNesseHorario, estilo: .contorno, icone: "checkmark")
                        .padding(.top, FrilaEspaco.junto)
                        .accessibilityIdentifier("disponivel-\(cartao.id)")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: FrilaMetrica.alvo)
    }
}
