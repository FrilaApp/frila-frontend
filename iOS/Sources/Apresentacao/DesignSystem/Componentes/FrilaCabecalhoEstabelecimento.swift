import SwiftUI

/// Cabeçalho reutilizável do estabelecimento com monograma derivado, nome e metadados opcionais.
/// Conforme especificação Hi-Fi (§2–4, REFERENCIA.md e LOG-010):
/// - Monograma derivado do nome em container circular de 44 pt com fundo `FrilaCor.superficie`, contorno gráfico `FrilaCor.borda` e letra em `FrilaCor.texto` (contraste AAA 16,66:1)
/// - Tipografia e superfícies neutras de leitura, sem lineLimit fixo para compatibilidade integral com Dynamic Type
/// - Bloco tocável com feedback tátil quando `acao` é informada (uso na Detalhe da vaga); sem navegação interna
/// - Modo estático sem affordance de toque quando `acao == nil` (uso no topo da Tela Perfil público)
/// - Hitbox mínima de 44 pt (G8 / FrilaMetrica.alvoMinimo)
public struct FrilaCabecalhoEstabelecimento: View {
    public let nome: String
    public let localizacao: String?
    public let avaliacao: String?
    public let acao: (() -> Void)?

    public init(
        nome: String,
        localizacao: String? = nil,
        avaliacao: String? = nil,
        acao: (() -> Void)? = nil
    ) {
        self.nome = nome
        self.localizacao = localizacao
        self.avaliacao = avaliacao
        self.acao = acao
    }

    /// Monograma derivado: iniciais das duas primeiras palavras ou os dois primeiros caracteres do nome.
    private var monograma: String {
        let partes = nome
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .filter { !$0.isEmpty }
        if partes.count >= 2 {
            let p1 = partes[0].prefix(1)
            let p2 = partes[1].prefix(1)
            return "\(p1)\(p2)".uppercased()
        } else if let primeira = partes.first {
            return String(primeira.prefix(2)).uppercased()
        }
        return ""
    }

    @ViewBuilder
    private var monogramaView: some View {
        let texto = monograma
        ZStack {
            Circle()
                .fill(FrilaCor.superficie)
                .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                .overlay(
                    Circle()
                        .strokeBorder(FrilaCor.borda, lineWidth: 1.5)
                )

            if texto.isEmpty {
                Image(systemName: "building.2.fill")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            } else {
                Text(verbatim: texto)
                    .font(FrilaTipo.resumo.weight(.bold))
                    .foregroundStyle(FrilaCor.texto)
            }
        }
        .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
        .accessibilityHidden(true)
    }

    private var informacoesView: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: nome)
                .font(FrilaTipo.tituloDoCartao.weight(.bold))
                .foregroundStyle(FrilaCor.texto)

            if let localizacao, !localizacao.isEmpty {
                Text(verbatim: localizacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            if let avaliacao, !avaliacao.isEmpty {
                HStack(spacing: FrilaEspaco.minimo) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityHidden(true)

                    Text(verbatim: avaliacao)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var indicadorDeAcaoView: some View {
        if acao != nil {
            Image(systemName: "chevron.right")
                .font(FrilaTipo.nota.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
        }
    }

    private var conteudo: some View {
        HStack(alignment: .center, spacing: FrilaEspaco.compacto) {
            monogramaView
            informacoesView
            indicadorDeAcaoView
        }
        .padding(.vertical, FrilaEspaco.pequeno)
        .contentShape(Rectangle())
    }

    public var body: some View {
        if let acao {
            Button(action: acao) {
                conteudo
            }
            .buttonStyle(EstiloBotaoTatil(scale: 0.98))
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        } else {
            conteudo
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .accessibilityElement(children: .combine)
        }
    }
}
