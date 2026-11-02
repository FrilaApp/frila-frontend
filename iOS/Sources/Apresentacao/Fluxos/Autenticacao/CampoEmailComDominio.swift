import SwiftUI
import UIKit

struct CampoEmailComDominio: UIViewRepresentable {
    @Binding var texto: String
    let habilitado: Bool
    let aoEnviar: () -> Void

    func makeCoordinator() -> Coordenador { Coordenador(self) }

    func makeUIView(context: Context) -> CampoEmailNativo {
        let campo = CampoEmailNativo()
        campo.delegate = context.coordinator
        campo.keyboardType = .emailAddress
        campo.textContentType = .emailAddress
        campo.autocapitalizationType = .none
        campo.autocorrectionType = .no
        campo.returnKeyType = .send
        campo.font = .preferredFont(forTextStyle: .body)
        campo.textColor = FrilaCor.textoUIKit
        campo.placeholder = "nome@exemplo.com"
        campo.accessibilityLabel = String(localized: "E-mail", bundle: bundleApresentacao)
        campo.accessibilityIdentifier = "entrada-email"
        campo.addTarget(context.coordinator, action: #selector(Coordenador.editou(_:)), for: .editingChanged)
        campo.aoConfirmar = { [weak coordenador = context.coordinator, weak campo] in
            guard let campo else { return }
            coordenador?.confirmar(campo)
        }
        campo.aoDeslizar = { [weak coordenador = context.coordinator, weak campo] gesto in
            guard let campo else { return }
            coordenador?.deslizar(gesto, campo: campo)
        }
        return campo
    }

    func updateUIView(_ campo: CampoEmailNativo, context: Context) {
        context.coordinator.pai = self
        campo.isEnabled = habilitado
        if campo.text != texto, campo.markedTextRange == nil {
            campo.text = texto
            context.coordinator.atualizar(campo)
        }
    }

    final class Coordenador: NSObject, UITextFieldDelegate {
        var pai: CampoEmailComDominio
        var sugestao: SugestaoDominio?
        var inicioGesto: SugestaoDominio?
        var escolha = 0
        var colagemCompleta = false
        init(_ pai: CampoEmailComDominio) { self.pai = pai }
        func cursor(_ campo: UITextField) -> Int? {
            guard let selecao = campo.selectedTextRange, selecao.isEmpty else { return nil }
            return campo.offset(from: campo.beginningOfDocument, to: selecao.start)
        }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            inicioGesto = nil
            colagemCompleta = string.count > 1 && string.contains("@")
            return true
        }
        @objc func editou(_ campo: CampoEmailNativo) {
            inicioGesto = nil
            pai.texto = campo.text ?? ""
            atualizar(campo)
        }
        func textFieldDidChangeSelection(_ textField: UITextField) {
            guard let campo = textField as? CampoEmailNativo else { return }
            if let inicioGesto, (inicioGesto.texto != campo.text || inicioGesto.cursor != cursor(campo)) { self.inicioGesto = nil }
            atualizar(campo)
        }
        func textFieldDidBeginEditing(_ textField: UITextField) { if let campo = textField as? CampoEmailNativo { atualizar(campo) } }
        func textFieldDidEndEditing(_ textField: UITextField) {
            inicioGesto = nil
            (textField as? CampoEmailNativo)?.mostrar(nil, dominio: nil)
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool { pai.aoEnviar(); return true }
        func atualizar(_ campo: CampoEmailNativo) {
            guard campo.isFirstResponder, campo.markedTextRange == nil, !colagemCompleta, let cursor = cursor(campo) else {
                sugestao = nil; campo.mostrar(nil, dominio: nil); return
            }
            sugestao = SugestaoDominio.criar(campo.text ?? "", cursor: cursor)
            campo.mostrar(sugestao, dominio: sugestao?.dominio)
        }
        func confirmar(_ campo: CampoEmailNativo, dominio: String? = nil) {
            guard let sugestao, let cursor = cursor(campo), let escolhido = dominio ?? self.sugestao?.dominio,
                  let texto = sugestao.confirmar(escolhido, textoAtual: campo.text ?? "", cursorAtual: cursor) else { return }
            UIView.transition(with: campo, duration: 0.18, options: .transitionCrossDissolve) { campo.text = texto }
            campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
            pai.texto = texto
            self.sugestao = nil
            campo.mostrar(nil, dominio: nil)
        }
        func deslizar(_ gesto: UIPanGestureRecognizer, campo: CampoEmailNativo) {
            switch gesto.state {
            case .began:
                inicioGesto = sugestao; escolha = 0
            case .changed:
                guard let inicioGesto else { return }
                escolha = Int((gesto.translation(in: campo).y / 28).rounded())
                campo.mostrar(inicioGesto, dominio: inicioGesto.vizinho(escolha), emGesto: true)
            case .ended:
                guard let inicio = inicioGesto, escolha != 0, inicio.texto == campo.text, inicio.cursor == cursor(campo) else {
                    inicioGesto = nil; atualizar(campo); return
                }
                let escolhido = inicio.vizinho(escolha)
                inicioGesto = nil
                if escolhido.hasPrefix(String(inicio.texto.split(separator: "@", omittingEmptySubsequences: false).last ?? "").lowercased()) {
                    confirmar(campo, dominio: escolhido)
                    UISelectionFeedbackGenerator().selectionChanged()
                } else { atualizar(campo) }
            default:
                inicioGesto = nil; atualizar(campo)
            }
        }
    }
}

final class CampoEmailNativo: UITextField, UIGestureRecognizerDelegate {
    var aoConfirmar: (() -> Void)?
    var aoDeslizar: ((UIPanGestureRecognizer) -> Void)?
    private let sugestaoLabel = UILabel()
    private let seta = UIButton(type: .system)
    private var atual: SugestaoDominio?
    private var dominioAtual: String?
    private var emGesto = false
    private weak var gestoRoda: UIPanGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        sugestaoLabel.textColor = FrilaCor.marcaUIKit
        sugestaoLabel.font = .preferredFont(forTextStyle: .body)
        sugestaoLabel.isUserInteractionEnabled = true
        sugestaoLabel.lineBreakMode = .byClipping
        sugestaoLabel.numberOfLines = 0
        addSubview(sugestaoLabel)
        let gesto = UIPanGestureRecognizer(target: self, action: #selector(deslizou(_:)))
        gesto.delegate = self
        gestoRoda = gesto
        sugestaoLabel.addGestureRecognizer(gesto)
        sugestaoLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tocouSugestao)))
        seta.setImage(UIImage(systemName: "arrow.right"), for: .normal)
        seta.tintColor = FrilaCor.marcaUIKit
        seta.layer.cornerRadius = 8
        seta.addTarget(self, action: #selector(confirmou), for: .touchUpInside)
        seta.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        rightView = seta
        rightViewMode = .never
    }
    required init?(coder: NSCoder) { nil }
    func mostrar(_ sugestao: SugestaoDominio?, dominio: String?, emGesto: Bool = false) {
        atual = sugestao; dominioAtual = dominio; self.emGesto = emGesto
        rightViewMode = sugestao == nil ? .never : .always
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let atual, let dominioAtual, let posicao = selectedTextRange?.start else {
            sugestaoLabel.isHidden = true; return
        }
        let prefixo = String(atual.texto.split(separator: "@", omittingEmptySubsequences: false).last ?? "")
        let exibicao = dominioAtual.hasPrefix(prefixo.lowercased()) ? String(dominioAtual.dropFirst(prefixo.count)) : dominioAtual
        let x = max(0, caretRect(for: posicao).maxX + 2)
        let largura = max(0, bounds.width - x - 42)
        if emGesto, let indice = SugestaoDominio.dominios.firstIndex(of: dominioAtual) {
            let dominios = SugestaoDominio.dominios
            sugestaoLabel.font = .systemFont(ofSize: 13)
            sugestaoLabel.text = (-3...3).map { dominios[(indice + $0 + dominios.count) % dominios.count] }.joined(separator: "\n")
            sugestaoLabel.frame = CGRect(x: x, y: bounds.midY - 63, width: largura, height: 126)
        } else {
            sugestaoLabel.font = .preferredFont(forTextStyle: .body)
            sugestaoLabel.text = exibicao + " ↕"
            sugestaoLabel.frame = CGRect(x: x, y: 0, width: largura, height: bounds.height)
        }
        sugestaoLabel.isHidden = false
    }
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        super.textRect(forBounds: bounds).insetBy(dx: FrilaEspaco.medio, dy: 0)
    }
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        super.editingRect(forBounds: bounds).insetBy(dx: FrilaEspaco.medio, dy: 0)
    }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        textRect(forBounds: bounds)
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === gestoRoda, let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let v = pan.velocity(in: self)
        return abs(v.y) > abs(v.x) && abs(v.y) > 40
    }
    @objc private func tocouSugestao() { _ = becomeFirstResponder() }
    @objc private func confirmou() { aoConfirmar?() }
    @objc private func deslizou(_ gesto: UIPanGestureRecognizer) { aoDeslizar?(gesto) }
}
