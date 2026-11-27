import FrilaDominio
import SwiftUI
import UIKit

public struct TrechoReveladoDeSenha: Equatable, Sendable {
    public let intervaloUTF16: NSRange
    public let caractere: String

    public init(intervaloUTF16: NSRange, caractere: String) {
        self.intervaloUTF16 = intervaloUTF16
        self.caractere = caractere
    }
}

public enum RegraDeRevelacaoBreveDeSenha {
    public static let atrasoMascaramentoNs: UInt64 = 1_000_000_000

    /// Decide se a edição deve revelar um único grafema recém-digitado.
    /// Retorna `nil` em composição IME, seleção não-colapsada, deleção, colagem ou inserção de múltiplos grafemas.
    public static func trechoRecemDigitado(
        textoAnterior: String,
        intervaloSubstituidoUTF16: NSRange,
        substituicao: String,
        emComposicaoIME: Bool,
        emColagem: Bool
    ) -> TrechoReveladoDeSenha? {
        guard !emComposicaoIME, !emColagem else { return nil }
        guard intervaloSubstituidoUTF16.length == 0 else { return nil }
        guard substituicao.count == 1, let unico = substituicao.first else { return nil }
        let nsAnterior = textoAnterior as NSString
        guard intervaloSubstituidoUTF16.location >= 0,
              intervaloSubstituidoUTF16.location <= nsAnterior.length
        else { return nil }
        let intervaloNovo = NSRange(
            location: intervaloSubstituidoUTF16.location,
            length: (substituicao as NSString).length
        )
        return TrechoReveladoDeSenha(intervaloUTF16: intervaloNovo, caractere: String(unico))
    }

    /// Monta a linha inteira mascarada com `•`, mantendo em claro apenas o único grafema de `trecho`.
    public static func textoMascarado(texto: String, revelando trecho: TrechoReveladoDeSenha) -> String {
        let nsTexto = texto as NSString
        guard trecho.intervaloUTF16.location >= 0,
              NSMaxRange(trecho.intervaloUTF16) <= nsTexto.length,
              let rangeSwift = Range(trecho.intervaloUTF16, in: texto)
        else {
            return String(repeating: "\u{2022}", count: texto.count)
        }
        let antes = String(repeating: "\u{2022}", count: texto[..<rangeSwift.lowerBound].count)
        let depois = String(repeating: "\u{2022}", count: texto[rangeSwift.upperBound...].count)
        return antes + trecho.caractere + depois
    }
}

public struct TelaDefinirSenha: View {
    @State private var viewModel: DefinirSenhaViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private let permitirPular: Bool
    private let aoConcluir: (() -> Void)?

    @State private var campoFocado: Campo?

    private enum Campo: Hashable {
        case senha
        case confirmacao
    }

    public init(
        api: any ApiCliente,
        permitirPular: Bool = false,
        manterDispositivoAtual: Bool = false,
        aoConcluir: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: DefinirSenhaViewModel(api: api, manterDispositivoAtual: manterDispositivoAtual))
        self.permitirPular = permitirPular
        self.aoConcluir = aoConcluir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text("Definir senha", bundle: bundleApresentacao)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("Crie ou atualize a senha desta conta para entrar sem depender do código por e-mail. Você continua podendo usar o código quando quiser.", bundle: bundleApresentacao)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text("Nova senha", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)

                        CampoDeSenhaComRevelacaoBreve(
                            texto: $viewModel.senha,
                            placeholder: String(localized: "Mínimo de 8 caracteres", bundle: bundleApresentacao),
                            rotuloAcessibilidade: String(localized: "Nova senha", bundle: bundleApresentacao),
                            identificadorAcessibilidade: "definir-senha-campo",
                            returnKeyType: .next,
                            habilitado: !viewModel.carregando,
                            estaFocado: Binding(
                                get: { campoFocado == .senha },
                                set: { focado in
                                    if focado {
                                        campoFocado = .senha
                                    } else if campoFocado == .senha {
                                        campoFocado = nil
                                    }
                                }
                            ),
                            ocultarRevelacao: scenePhase != .active,
                            aoSubmeter: { campoFocado = .confirmacao }
                        )
                        .frame(minHeight: FrilaMetrica.alturaDoCampo)
                        .padding(.horizontal, FrilaEspaco.bloco)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                .strokeBorder(FrilaCor.borda, lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text("Confirmar senha", bundle: bundleApresentacao)
                            .font(FrilaTipo.rotuloDeGrupo)
                            .foregroundStyle(FrilaCor.textoSecundario)

                        CampoDeSenhaComRevelacaoBreve(
                            texto: $viewModel.confirmacao,
                            placeholder: String(localized: "Repita a nova senha", bundle: bundleApresentacao),
                            rotuloAcessibilidade: String(localized: "Confirmar senha", bundle: bundleApresentacao),
                            identificadorAcessibilidade: "definir-senha-confirmacao",
                            returnKeyType: .done,
                            habilitado: !viewModel.carregando,
                            estaFocado: Binding(
                                get: { campoFocado == .confirmacao },
                                set: { focado in
                                    if focado {
                                        campoFocado = .confirmacao
                                    } else if campoFocado == .confirmacao {
                                        campoFocado = nil
                                    }
                                }
                            ),
                            ocultarRevelacao: scenePhase != .active,
                            aoSubmeter: { salvar() }
                        )
                        .frame(minHeight: FrilaMetrica.alturaDoCampo)
                        .padding(.horizontal, FrilaEspaco.bloco)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                                .strokeBorder(FrilaCor.borda, lineWidth: 1)
                        )
                    }

                    if viewModel.concluido {
                        Text("Senha salva nesta conta.", bundle: bundleApresentacao)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityIdentifier("definir-senha-sucesso")
                    }
                }
            }
            .padding(.top, FrilaEspaco.bloco)
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.bottom, FrilaEspaco.secao)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text("Senha da conta", bundle: bundleApresentacao))
        .navigationBarTitleDisplayMode(.inline)
        .rodapeAncorado {
            if let erro = viewModel.erro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("definir-senha-erro")
            }

            if permitirPular {
                BotaoSecundario(verbatim: String(localized: "Agora não", bundle: bundleApresentacao)) {
                    concluirOuFechar()
                }
                .disabled(viewModel.carregando)
                .accessibilityIdentifier("definir-senha-pular")
            }

            BotaoPrimario("Salvar senha", carregando: viewModel.carregando) {
                salvar()
            }
            .disabled(viewModel.carregando)
            .accessibilityIdentifier("definir-senha-salvar")
        }
        .frilaKeyboardDismissScope()
        .onChange(of: viewModel.senha) { _, _ in viewModel.erro = nil }
        .onChange(of: viewModel.confirmacao) { _, _ in viewModel.erro = nil }
    }

    private func salvar() {
        guard !viewModel.carregando else { return }
        campoFocado = nil
        Task {
            if await viewModel.salvar() {
                concluirOuFechar()
            }
        }
    }

    private func concluirOuFechar() {
        if let aoConcluir {
            aoConcluir()
        } else {
            dismiss()
        }
    }
}

private final class CampoSeguroInternoUITextField: UITextField {
    var emColagem: Bool = false
    var aoMudarEstadoDeCaptura: (() -> Void)?
    var aoRolarHorizontalmente: (() -> Void)?
    private var ultimoOffsetX: CGFloat = 0

    override func paste(_ sender: Any?) {
        emColagem = true
        defer { emColagem = false }
        super.paste(sender)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let atualX = bounds.origin.x
        if abs(atualX - ultimoOffsetX) > 0.5 {
            ultimoOffsetX = atualX
            aoRolarHorizontalmente?()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *),
           traitCollection.sceneCaptureState != previousTraitCollection?.sceneCaptureState {
            aoMudarEstadoDeCaptura?()
        }
    }
}

private struct CampoDeSenhaComRevelacaoBreve: UIViewRepresentable {
    @Binding var texto: String
    let placeholder: String
    let rotuloAcessibilidade: String
    let identificadorAcessibilidade: String
    let returnKeyType: UIReturnKeyType
    let habilitado: Bool
    @Binding var estaFocado: Bool
    let ocultarRevelacao: Bool
    let aoSubmeter: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CampoSeguroInternoUITextField {
        let campo = CampoSeguroInternoUITextField(frame: .zero)
        campo.delegate = context.coordinator
        campo.isSecureTextEntry = true
        campo.textContentType = .newPassword
        campo.autocorrectionType = .no
        campo.spellCheckingType = .no
        campo.smartQuotesType = .no
        campo.smartDashesType = .no
        campo.smartInsertDeleteType = .no
        if #available(iOS 17.0, *) {
            campo.inlinePredictionType = .no
        }
        campo.autocapitalizationType = .none
        campo.returnKeyType = returnKeyType
        campo.font = UIFont.preferredFont(forTextStyle: .body)
        campo.adjustsFontForContentSizeCategory = true
        campo.textColor = UIColor(named: "TextPrimary", in: bundleApresentacao, compatibleWith: nil) ?? .label
        campo.tintColor = campo.textColor
        campo.backgroundColor = .clear
        campo.borderStyle = .none
        campo.clipsToBounds = true
        campo.placeholder = placeholder
        campo.accessibilityLabel = rotuloAcessibilidade
        campo.accessibilityIdentifier = identificadorAcessibilidade
        campo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        campo.setContentHuggingPriority(.defaultLow, for: .horizontal)
        campo.addTarget(context.coordinator, action: #selector(Coordinator.textoMudou(_:)), for: .editingChanged)
        context.coordinator.configurarSobreposicao(em: campo)
        return campo
    }

    func updateUIView(_ uiView: CampoSeguroInternoUITextField, context: Context) {
        context.coordinator.pai = self
        if uiView.text != texto {
            uiView.text = texto
            context.coordinator.limparRevelacao()
        }
        uiView.isEnabled = habilitado
        uiView.placeholder = placeholder
        uiView.accessibilityLabel = rotuloAcessibilidade
        uiView.accessibilityIdentifier = identificadorAcessibilidade
        if ocultarRevelacao || context.coordinator.capturaAtiva(para: uiView) {
            context.coordinator.limparRevelacao()
        }
        if estaFocado, !uiView.isFirstResponder, habilitado, uiView.window != nil {
            uiView.becomeFirstResponder()
        } else if !estaFocado, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var pai: CampoDeSenhaComRevelacaoBreve
        private weak var campo: CampoSeguroInternoUITextField?
        private let conteinerRevelacao = UIView()
        private let rotuloRevelacao = UILabel()
        private let barraCursor = UIView()
        private var trechoPendente: TrechoReveladoDeSenha?
        private var trechoAtivo: TrechoReveladoDeSenha?
        private var tarefaOcultar: Task<Void, Never>?

        init(_ pai: CampoDeSenhaComRevelacaoBreve) {
            self.pai = pai
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func configurarSobreposicao(em campo: CampoSeguroInternoUITextField) {
            self.campo = campo
            let corTexto = UIColor(named: "TextPrimary", in: bundleApresentacao, compatibleWith: nil) ?? .label
            let corSuperficie = UIColor(named: "SurfaceElevated", in: bundleApresentacao, compatibleWith: nil) ?? .systemBackground

            conteinerRevelacao.isHidden = true
            conteinerRevelacao.isUserInteractionEnabled = false
            conteinerRevelacao.isAccessibilityElement = false
            conteinerRevelacao.accessibilityElementsHidden = true
            conteinerRevelacao.clipsToBounds = true
            conteinerRevelacao.backgroundColor = corSuperficie

            rotuloRevelacao.isUserInteractionEnabled = false
            rotuloRevelacao.isAccessibilityElement = false
            rotuloRevelacao.accessibilityElementsHidden = true
            rotuloRevelacao.textAlignment = .left
            rotuloRevelacao.lineBreakMode = .byClipping
            rotuloRevelacao.font = UIFont.preferredFont(forTextStyle: .body)
            rotuloRevelacao.adjustsFontForContentSizeCategory = true
            rotuloRevelacao.textColor = corTexto
            rotuloRevelacao.backgroundColor = .clear

            barraCursor.isUserInteractionEnabled = false
            barraCursor.isAccessibilityElement = false
            barraCursor.accessibilityElementsHidden = true
            barraCursor.backgroundColor = corTexto

            conteinerRevelacao.addSubview(rotuloRevelacao)
            conteinerRevelacao.addSubview(barraCursor)
            campo.addSubview(conteinerRevelacao)

            campo.aoRolarHorizontalmente = { [weak self] in
                self?.limparRevelacao()
            }

            campo.aoMudarEstadoDeCaptura = { [weak self] in
                Task { @MainActor in
                    guard let self, let campo = self.campo else { return }
                    if self.capturaAtiva(para: campo) {
                        self.limparRevelacao()
                    }
                }
            }

            let centro = NotificationCenter.default
            centro.addObserver(
                self,
                selector: #selector(aoPerderFocoDeAplicacao),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
            centro.addObserver(
                self,
                selector: #selector(aoMudarCapturaDeTela),
                name: UIScreen.capturedDidChangeNotification,
                object: nil
            )
        }

        @objc private func aoPerderFocoDeAplicacao() {
            limparRevelacao()
        }

        @objc private func aoMudarCapturaDeTela() {
            guard let campo else { return }
            if capturaAtiva(para: campo) {
                limparRevelacao()
            }
        }

        func capturaAtiva(para textField: UITextField) -> Bool {
            if #available(iOS 17.0, *), textField.traitCollection.sceneCaptureState == .active {
                return true
            }
            if let screen = textField.window?.windowScene?.screen, screen.isCaptured {
                return true
            }
            return UIScreen.main.isCaptured
        }

        func limparRevelacao() {
            tarefaOcultar?.cancel()
            tarefaOcultar = nil
            trechoPendente = nil
            trechoAtivo = nil
            rotuloRevelacao.text = nil
            conteinerRevelacao.isHidden = true
            if let campo {
                let corTexto = UIColor(named: "TextPrimary", in: bundleApresentacao, compatibleWith: nil) ?? .label
                campo.tintColor = corTexto
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !pai.estaFocado {
                pai.estaFocado = true
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            limparRevelacao()
            if pai.estaFocado {
                pai.estaFocado = false
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            limparRevelacao()
            pai.aoSubmeter()
            return false
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            guard let ativo = trechoAtivo else { return }
            guard let selecionada = textField.selectedTextRange, selecionada.isEmpty else {
                limparRevelacao()
                return
            }
            let offsetCursor = textField.offset(from: textField.beginningOfDocument, to: selecionada.start)
            if offsetCursor != ativo.intervaloUTF16.location + ativo.intervaloUTF16.length {
                limparRevelacao()
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let anterior = textField.text ?? ""
            let emComposicao = textField.markedTextRange != nil
            let emColagem = (textField as? CampoSeguroInternoUITextField)?.emColagem ?? false
            trechoPendente = RegraDeRevelacaoBreveDeSenha.trechoRecemDigitado(
                textoAnterior: anterior,
                intervaloSubstituidoUTF16: range,
                substituicao: string,
                emComposicaoIME: emComposicao,
                emColagem: emColagem
            )
            if trechoPendente == nil {
                limparRevelacao()
            }
            return true
        }

        @objc func textoMudou(_ textField: UITextField) {
            let novoTexto = textField.text ?? ""
            if pai.texto != novoTexto {
                pai.texto = novoTexto
            }
            guard !pai.ocultarRevelacao,
                  !capturaAtiva(para: textField),
                  let trecho = trechoPendente
            else {
                limparRevelacao()
                return
            }
            trechoPendente = nil
            exibirRevelacao(trecho, em: textField)
        }

        private func exibirRevelacao(_ trecho: TrechoReveladoDeSenha, em textField: UITextField) {
            let textoAtual = textField.text ?? ""
            guard let rangeSwift = Range(trecho.intervaloUTF16, in: textoAtual) else {
                limparRevelacao()
                return
            }
            let textoExibido = RegraDeRevelacaoBreveDeSenha.textoMascarado(texto: textoAtual, revelando: trecho)
            let qtdAntes = textoAtual[..<rangeSwift.lowerBound].count
            let prefixoAteCursor = String(repeating: "\u{2022}", count: qtdAntes) + trecho.caractere

            let fonteAtual = textField.font ?? UIFont.preferredFont(forTextStyle: .body)
            let limiteEdicao = textField.editingRect(forBounds: textField.bounds)
            guard limiteEdicao.width > 4, limiteEdicao.height > 0 else {
                limparRevelacao()
                return
            }

            let larguraTotal = ceil((textoExibido as NSString).size(withAttributes: [.font: fonteAtual]).width)
            let larguraAteCursor = ceil((prefixoAteCursor as NSString).size(withAttributes: [.font: fonteAtual]).width)
            let larguraCursor: CGFloat = 2
            let folgaCursor: CGFloat = 1
            let larguraDisponivel = limiteEdicao.width - larguraCursor - folgaCursor
            let deslocamentoX = larguraAteCursor > larguraDisponivel ? (larguraDisponivel - larguraAteCursor) : 0
            let alturaLinha = ceil(fonteAtual.lineHeight)
            let yTexto = (limiteEdicao.height - alturaLinha) / 2

            conteinerRevelacao.frame = limiteEdicao
            rotuloRevelacao.font = fonteAtual
            rotuloRevelacao.text = textoExibido
            rotuloRevelacao.frame = CGRect(
                x: deslocamentoX,
                y: yTexto,
                width: max(larguraTotal + 4, limiteEdicao.width),
                height: alturaLinha
            )
            let xCursor = min(max(0, larguraAteCursor + deslocamentoX + folgaCursor), limiteEdicao.width - larguraCursor)
            barraCursor.frame = CGRect(x: xCursor, y: yTexto, width: larguraCursor, height: alturaLinha)
            conteinerRevelacao.isHidden = false
            trechoAtivo = trecho
            textField.tintColor = .clear
            textField.bringSubviewToFront(conteinerRevelacao)

            tarefaOcultar?.cancel()
            tarefaOcultar = Task { [weak self] in
                try? await Task.sleep(nanoseconds: RegraDeRevelacaoBreveDeSenha.atrasoMascaramentoNs)
                guard !Task.isCancelled else { return }
                self?.limparRevelacao()
            }
        }
    }
}
