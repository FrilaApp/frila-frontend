import SwiftUI
import UIKit

/// Campo de texto com máscara síncrona em UIKit, evitando perda de teclas rápidas.
/// Segue o padrão arquitetural de `CampoValorVaga`.
@MainActor
public struct CampoMascara: UIViewRepresentable {
    @Binding private var texto: String
    private let placeholder: String
    private let rotuloAcessibilidade: String
    private let identificadorAcessibilidade: String?
    private let teclado: UIKeyboardType
    private let tipoConteudo: UITextContentType?
    private let formatar: (String, String) -> String
    @Environment(\.isEnabled) private var habilitado

    public init(
        texto: Binding<String>,
        placeholder: String,
        rotuloAcessibilidade: String,
        identificadorAcessibilidade: String? = nil,
        teclado: UIKeyboardType = .numberPad,
        tipoConteudo: UITextContentType? = nil,
        formatar: @escaping (String, String) -> String
    ) {
        _texto = texto
        self.placeholder = placeholder
        self.rotuloAcessibilidade = rotuloAcessibilidade
        self.identificadorAcessibilidade = identificadorAcessibilidade
        self.teclado = teclado
        self.tipoConteudo = tipoConteudo
        self.formatar = formatar
    }

    public func makeCoordinator() -> Coordenador {
        Coordenador(texto: $texto, formatar: formatar)
    }

    public func makeUIView(context: Context) -> UITextField {
        let campo = UITextField()
        campo.keyboardType = teclado
        campo.textContentType = tipoConteudo
        campo.borderStyle = .none
        campo.font = .preferredFont(forTextStyle: .body)
        campo.adjustsFontForContentSizeCategory = true
        campo.textColor = FrilaCor.textoUIKit
        campo.placeholder = placeholder
        campo.accessibilityLabel = rotuloAcessibilidade
        if let identificadorAcessibilidade {
            campo.accessibilityIdentifier = identificadorAcessibilidade
        }
        campo.autocorrectionType = .no
        campo.spellCheckingType = .no
        campo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        campo.addTarget(context.coordinator, action: #selector(Coordenador.editar(_:)), for: .editingChanged)
        campo.delegate = context.coordinator
        campo.text = texto
        return campo
    }

    public func updateUIView(_ campo: UITextField, context: Context) {
        context.coordinator.texto = $texto
        context.coordinator.formatar = formatar
        campo.isEnabled = habilitado
        if campo.text != texto {
            let formatado = formatar(texto, campo.text ?? "")
            campo.text = formatado
            context.coordinator.ultimoTextoAplicado = formatado
        }
    }

    @MainActor
    public final class Coordenador: NSObject, UITextFieldDelegate {
        var texto: Binding<String>
        var formatar: (String, String) -> String
        var ultimoTextoAplicado: String

        init(texto: Binding<String>, formatar: @escaping (String, String) -> String) {
            self.texto = texto
            self.formatar = formatar
            self.ultimoTextoAplicado = texto.wrappedValue
        }

        public func textField(
            _ campo: UITextField,
            shouldChangeCharactersIn intervalo: NSRange,
            replacementString novo: String
        ) -> Bool {
            let textoAnterior = campo.text ?? ""
            let nsTexto = textoAnterior as NSString
            guard intervalo.location != NSNotFound,
                  intervalo.location + intervalo.length <= nsTexto.length else {
                return false
            }
            let textoProvisorio = nsTexto.replacingCharacters(in: intervalo, with: novo)
            let formatado = formatar(textoProvisorio, textoAnterior)

            campo.text = formatado
            ultimoTextoAplicado = formatado
            texto.wrappedValue = formatado

            ajustarCursor(
                em: campo,
                textoAnterior: textoAnterior,
                intervalo: intervalo,
                substituicao: novo,
                textoFormatado: formatado
            )
            return false
        }

        @objc public func editar(_ campo: UITextField) {
            let textoAtual = campo.text ?? ""
            let formatado = formatar(textoAtual, ultimoTextoAplicado)
            if campo.text != formatado {
                campo.text = formatado
            }
            campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
            ultimoTextoAplicado = formatado
            texto.wrappedValue = formatado
        }

        private func ajustarCursor(
            em campo: UITextField,
            textoAnterior: String,
            intervalo: NSRange,
            substituicao: String,
            textoFormatado: String
        ) {
            if (intervalo.location + intervalo.length >= textoAnterior.count) || substituicao.count > 1 || textoAnterior.isEmpty {
                campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
                return
            }

            let digitosAntes = textoAnterior.prefix(intervalo.location).filter(\.isNumber).count
            let digitosInseridos = substituicao.filter(\.isNumber).count
            let alvoDigitos = digitosAntes + digitosInseridos

            if alvoDigitos == 0 {
                let pos = campo.beginningOfDocument
                campo.selectedTextRange = campo.textRange(from: pos, to: pos)
                return
            }

            var contagem = 0
            var indiceAlvo = textoFormatado.count
            for (indice, caractere) in textoFormatado.enumerated() {
                if caractere.isNumber {
                    contagem += 1
                    if contagem == alvoDigitos {
                        indiceAlvo = indice + 1
                        break
                    }
                }
            }

            while indiceAlvo < textoFormatado.count {
                let idx = textoFormatado.index(textoFormatado.startIndex, offsetBy: indiceAlvo)
                if !textoFormatado[idx].isNumber {
                    indiceAlvo += 1
                } else {
                    break
                }
            }

            if let pos = campo.position(from: campo.beginningOfDocument, offset: indiceAlvo) {
                campo.selectedTextRange = campo.textRange(from: pos, to: pos)
            } else {
                campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
            }
        }
    }
}
