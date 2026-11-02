import SwiftUI

/// Ação final fixa de um `FrilaSearchBar`, por exemplo o botão de buscar um endereço.
public struct FrilaSearchBarAcao {
    public let icone: String
    public let rotulo: String
    public let identificador: String
    public let carregando: Bool
    public let executar: () -> Void

    public init(
        icone: String,
        rotulo: String,
        identificador: String,
        carregando: Bool = false,
        executar: @escaping () -> Void
    ) {
        self.icone = icone
        self.rotulo = rotulo
        self.identificador = identificador
        self.carregando = carregando
        self.executar = executar
    }
}

/// Campo de busca do app: ícone inicial, campo de texto e, à direita, o botão de limpar (quando em uso)
/// ou uma ação fixa (por exemplo buscar). Tem sempre a mesma altura e o mesmo lugar: em repouso é um
/// campo com contorno leve; em uso (com foco ou com texto) o contorno ganha força e nada se move.
///
/// O fechamento de teclado do app já vem embutido: o campo se registra com `frilaFormField` e fecha
/// ao tocar fora, ao arrastar a rolagem e no Return, como exige o padrão do app. A tela que o usa só
/// precisa ter `frilaKeyboardDismissScope()` acima e passar o estado de foco.
public struct FrilaSearchBar: View {
    @Binding private var texto: String
    private let foco: FocusState<Bool>.Binding
    private let icone: String
    private let rotulo: String
    private let idDoCampo: String
    private let identificador: String
    private let submitLabel: SubmitLabel
    private let limpar: (rotulo: String, identificador: String)?
    private let acao: FrilaSearchBarAcao?
    private let aoEnviar: (() -> Void)?
    private let recuoInicial: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    /// - Parameters:
    ///   - texto: o texto digitado.
    ///   - foco: o estado de foco, que a tela guarda para poder fechar o campo por fora.
    ///   - icone: símbolo à esquerda (lupa, alfinete).
    ///   - rotulo: nome e dica do campo.
    ///   - idDoCampo: id único do campo para o fechamento de teclado do app.
    ///   - identificador: identificador de interface do campo.
    ///   - submitLabel: rótulo da tecla Return.
    ///   - limpar: quando informado, mostra o botão de limpar enquanto o campo está em uso.
    ///   - acao: ação final fixa, à direita.
    ///   - aoEnviar: o que o Return faz além de fechar o teclado.
    ///   - recuoInicial: distância do ícone até a borda do campo; reduza quando o campo estiver dentro de um
    ///     contêiner, para o ícone cair na mesma borda interna do resto do contêiner.
    public init(
        texto: Binding<String>,
        foco: FocusState<Bool>.Binding,
        icone: String = "magnifyingglass",
        rotulo: String,
        idDoCampo: String,
        identificador: String,
        submitLabel: SubmitLabel = .done,
        limpar: (rotulo: String, identificador: String)? = nil,
        acao: FrilaSearchBarAcao? = nil,
        aoEnviar: (() -> Void)? = nil,
        recuoInicial: CGFloat = FrilaEspaco.medio
    ) {
        _texto = texto
        self.foco = foco
        self.icone = icone
        self.rotulo = rotulo
        self.idDoCampo = idDoCampo
        self.identificador = identificador
        self.submitLabel = submitLabel
        self.limpar = limpar
        self.acao = acao
        self.aoEnviar = aoEnviar
        self.recuoInicial = recuoInicial
    }

    private var emUso: Bool { foco.wrappedValue || !texto.isEmpty }

    public var body: some View {
        HStack(spacing: FrilaEspaco.compacto) {
            Image(systemName: icone)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)

            TextField(
                text: $texto,
                prompt: Text(verbatim: rotulo).foregroundStyle(FrilaCor.textoSecundario)
            ) {
                Text(verbatim: rotulo)
            }
            .textFieldStyle(.plain)
            .font(FrilaTipo.valorDoCampo)
            .foregroundStyle(FrilaCor.texto)
            .submitLabel(submitLabel)
            .autocorrectionDisabled()
            .focused(foco)
            .onSubmit {
                aoEnviar?()
                foco.wrappedValue = false
            }
            .frilaFormField(id: idDoCampo, isFocused: foco.wrappedValue, onDismiss: { foco.wrappedValue = false })
            .accessibilityIdentifier(identificador)

            if let limpar, emUso {
                Button {
                    texto = ""
                    foco.wrappedValue = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityLabel(Text(verbatim: limpar.rotulo))
                .accessibilityIdentifier(limpar.identificador)
            }

            if let acao {
                Button(action: acao.executar) {
                    Group {
                        if acao.carregando {
                            ProgressView()
                        } else {
                            Image(systemName: acao.icone)
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                        }
                    }
                    .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: acao.rotulo))
                .accessibilityIdentifier(acao.identificador)
            }
        }
        .padding(.leading, recuoInicial)
        .padding(.trailing, FrilaEspaco.minimo)
        .frame(minHeight: FrilaMetrica.alturaDoCampo)
        .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                .strokeBorder(emUso ? FrilaCor.bordaDoCampo : FrilaCor.divisoria, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { foco.wrappedValue = true }
        .animation(FrilaMovimento.animacao(.easeOut(duration: 0.16), reduzir: reduzirMovimento), value: emUso)
    }
}
