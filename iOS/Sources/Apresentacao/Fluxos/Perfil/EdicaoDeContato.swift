import SwiftUI
import UIKit

/// Estado da edição de contato no lugar. Um contato por vez. Sem estado de erro: valor inválido não
/// confirma e segue editando; tocar fora descarta o rascunho.
@MainActor @Observable
final class EdicaoDeContato {
    private(set) var campo: CampoDeContato?
    private(set) var salvando = false
    var rascunho = ""
    var focado = false

    func iniciar(_ campo: CampoDeContato, valor: String) {
        guard self.campo == nil else { return }
        rascunho = Self.paraEdicao(campo, valor)
        salvando = false
        self.campo = campo
    }

    func comecarASalvar() { salvando = true }

    func encerrar() {
        campo = nil
        salvando = false
        focado = false
        rascunho = ""
    }

    /// Descartar o rascunho. Enquanto grava, o fim do foco não cancela.
    func cancelar() {
        guard !salvando else { return }
        encerrar()
    }

    /// O telefone chega em E.164 e é editado com a máscara brasileira.
    static func paraEdicao(_ campo: CampoDeContato, _ valor: String) -> String {
        guard campo == .telefone else { return valor }
        var digitos = valor.filter(\.isNumber)
        if digitos.hasPrefix("55"), digitos.count > 11 { digitos.removeFirst(2) }
        return CadastroViewModel.formatarTelefone(digitos)
    }

    /// O valor pronto para gravar, ou nulo se o texto ainda não é um contato válido.
    static func normalizar(_ campo: CampoDeContato, _ texto: String) -> String? {
        switch campo {
        case .telefone:
            let digitos = texto.filter(\.isNumber)
            guard digitos.count == 10 || digitos.count == 11 else { return nil }
            return CadastroViewModel.normalizarTelefone(digitos)
        case .email:
            let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !limpo.contains(where: \.isWhitespace) else { return nil }
            let partes = limpo.split(separator: "@", omittingEmptySubsequences: false)
            guard partes.count == 2, !partes[0].isEmpty else { return nil }
            let dominio = partes[1]
            guard dominio.contains("."), !dominio.hasPrefix("."), !dominio.hasSuffix("."), !dominio.contains("..") else { return nil }
            return limpo
        }
    }
}

/// Campo de texto UIKit que toma o foco assim que entra na janela, no mesmo ciclo em que a pílula some:
/// o teclado sobe junto, sem esperar animação nem temporizador.
final class CampoQueTomaFoco: UITextField {
    private var pediuFoco = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !pediuFoco else { return }
        pediuFoco = true
        becomeFirstResponder()
    }
}

struct CampoDeEdicaoDeContato: UIViewRepresentable {
    let edicao: EdicaoDeContato
    let campo: CampoDeContato
    let identificador: String
    let aoConfirmar: () -> Void

    func makeCoordinator() -> Coordenador { Coordenador(self) }

    func makeUIView(context: Context) -> CampoQueTomaFoco {
        let campoDeTexto = CampoQueTomaFoco()
        campoDeTexto.font = .preferredFont(forTextStyle: .body)
        campoDeTexto.adjustsFontForContentSizeCategory = true
        campoDeTexto.textColor = FrilaCor.textoUIKit
        campoDeTexto.tintColor = FrilaCor.marcaUIKit
        campoDeTexto.borderStyle = .none
        campoDeTexto.autocorrectionType = .no
        campoDeTexto.spellCheckingType = .no
        campoDeTexto.autocapitalizationType = .none
        campoDeTexto.keyboardType = campo == .telefone ? .numbersAndPunctuation : .emailAddress
        campoDeTexto.returnKeyType = .done
        campoDeTexto.accessibilityIdentifier = identificador
        campoDeTexto.delegate = context.coordinator
        campoDeTexto.text = edicao.rascunho
        campoDeTexto.setContentHuggingPriority(.defaultLow, for: .horizontal)
        campoDeTexto.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return campoDeTexto
    }

    func updateUIView(_ campoDeTexto: CampoQueTomaFoco, context: Context) {
        context.coordinator.ponte = self
        if campoDeTexto.text != edicao.rascunho { campoDeTexto.text = edicao.rascunho }
    }

    @MainActor
    final class Coordenador: NSObject, UITextFieldDelegate {
        var ponte: CampoDeEdicaoDeContato

        init(_ ponte: CampoDeEdicaoDeContato) { self.ponte = ponte }

        func textFieldDidBeginEditing(_ campo: UITextField) {
            ponte.edicao.focado = true
        }

        func textFieldDidEndEditing(_ campo: UITextField) {
            ponte.edicao.focado = false
            ponte.edicao.cancelar()
        }

        func textFieldShouldReturn(_ campo: UITextField) -> Bool {
            ponte.aoConfirmar()
            if ponte.edicao.salvando || ponte.edicao.campo == nil { campo.resignFirstResponder() }
            return false
        }

        func textField(_ campo: UITextField, shouldChangeCharactersIn intervalo: NSRange, replacementString novo: String) -> Bool {
            let anterior = campo.text ?? ""
            let nsAnterior = anterior as NSString
            guard intervalo.location != NSNotFound, intervalo.location + intervalo.length <= nsAnterior.length else { return false }
            let provisorio = nsAnterior.replacingCharacters(in: intervalo, with: novo)
            let fimDoTrecho = intervalo.location + (novo as NSString).length
            let formatado: String
            let posicao: Int
            if ponte.campo == .telefone {
                formatado = CadastroViewModel.formatarTelefone(provisorio, textoAnterior: anterior)
                let digitosAntes = (provisorio as NSString).substring(to: min(fimDoTrecho, (provisorio as NSString).length)).filter(\.isNumber).count
                posicao = Self.posicao(depoisDe: digitosAntes, em: formatado)
            } else {
                formatado = provisorio.filter { !$0.isWhitespace }
                posicao = min(intervalo.location + novo.filter { !$0.isWhitespace }.count, (formatado as NSString).length)
            }
            campo.text = formatado
            ponte.edicao.rascunho = formatado
            if let alvo = campo.position(from: campo.beginningOfDocument, offset: posicao) {
                campo.selectedTextRange = campo.textRange(from: alvo, to: alvo)
            }
            return false
        }

        /// Posição logo depois do enésimo dígito, para o cursor não pular quando a máscara insere pontuação.
        private static func posicao(depoisDe digitos: Int, em texto: String) -> Int {
            guard digitos > 0 else { return 0 }
            var vistos = 0
            for (indice, caractere) in texto.enumerated() where caractere.isNumber {
                vistos += 1
                if vistos == digitos { return indice + 1 }
            }
            return texto.count
        }
    }
}
