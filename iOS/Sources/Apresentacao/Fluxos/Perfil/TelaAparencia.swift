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
public struct TelaAparencia: View {
    private let preferencia: PreferenciaDeAparencia

    public init(preferencia: PreferenciaDeAparencia = .compartilhada) {
        self.preferencia = preferencia
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: TextosAparencia.explicacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GrupoDeLinhas {
                    ForEach(Array(Aparencia.allCases.enumerated()), id: \.element) { posicao, aparencia in
                        if posicao > 0 { DivisoriaDeLinha() }
                        opcao(aparencia)
                    }
                }
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosAparencia.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tela-aparencia")
    }

    private func opcao(_ aparencia: Aparencia) -> some View {
        let marcada = preferencia.aparencia == aparencia
        return Button {
            preferencia.escolher(aparencia)
        } label: {
            HStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosAparencia.nome(aparencia))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FrilaEspaco.pequeno)
                Image(systemName: "checkmark")
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .opacity(marcada ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, FrilaEspaco.minimo)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(marcada ? .isSelected : [])
        .accessibilityIdentifier("aparencia-\(aparencia.rawValue)")
    }
}
