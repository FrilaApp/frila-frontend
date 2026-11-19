import SwiftUI

enum TextosAparencia {
    static let titulo = String(localized: "Aparência", bundle: bundleApresentacao)
    static let claro = String(localized: "Claro", bundle: bundleApresentacao)
    static let escuro = String(localized: "Escuro", bundle: bundleApresentacao)
    static let explicacao = String(localized: "Escolha como o Frila aparece. A escolha fica só neste aparelho e vale também depois de trocar de conta.", bundle: bundleApresentacao)

    static func nome(_ aparencia: Aparencia) -> String {
        switch aparencia {
        case .claro: claro
        case .escuro: escuro
        }
    }
}

/// Linha "Aparência" da Conta: abre a tela com as opções Claro e Escuro. Mesmo desenho das
/// outras linhas da Conta, para entrar nas duas telas de perfil com uma linha só.
struct LinhaDeAparencia: View {
    var body: some View {
        NavigationLink {
            TelaAparencia()
        } label: {
            RotuloDeLinha(TextosAparencia.titulo)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("perfil-aparencia")
    }
}

/// Aparência do app: Claro (padrão) ou Escuro. Trocar vale na hora, sem reiniciar: a preferência é
/// observada na raiz (`aparenciaEscolhida`). Fica guardada no aparelho e nada vai ao servidor.
/// Tela de escolha, sem laranja: escolha única em lista com visto em tinta (sistema do Fabrício, extrapolado).
public struct TelaAparencia: View {
    private let preferencia: PreferenciaDeAparencia

    public init(preferencia: PreferenciaDeAparencia = .compartilhada) {
        self.preferencia = preferencia
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                Text(verbatim: TextosAparencia.explicacao)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                FrilaGrupoDeLinhas(linhasComIcone: false) {
                    ForEach(Aparencia.allCases, id: \.self) { aparencia in
                        FrilaLinhaDeOpcao(titulo: TextosAparencia.nome(aparencia), remate: .marcada(preferencia.aparencia == aparencia)) {
                            preferencia.escolher(aparencia)
                        }
                        .accessibilityIdentifier("aparencia-\(aparencia.rawValue)")
                    }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosAparencia.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tela-aparencia")
    }
}
