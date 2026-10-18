import FrilaDominio
import SwiftUI
import UIKit
@testable import FrilaApresentacao
import XCTest

@MainActor
final class CampoMascaraTests: XCTestCase {
    func testTelefoneDigitacaoEmSequenciaEExcessoDeDigitos() throws {
        var texto = ""
        let tela = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { texto }, set: { texto = $0 }),
            placeholder: "(61) 9 0000-0000",
            rotuloAcessibilidade: "Telefone com WhatsApp",
            identificadorAcessibilidade: "cadastro-telefone",
            teclado: .phonePad,
            tipoConteudo: .telephoneNumber,
            formatar: CadastroViewModel.formatarTelefone
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = tela
        janela.makeKeyAndVisible()
        tela.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campo = try XCTUnwrap(campoDeTexto(em: tela.view))
        let delegado = try XCTUnwrap(campo.delegate)

        let teclas = ["6", "1", "9", "8", "8", "8", "8", "7", "7", "7", "7"]
        let esperados = [
            "(6",
            "(61) ",
            "(61) 9",
            "(61) 98",
            "(61) 988",
            "(61) 9888",
            "(61) 9888-8",
            "(61) 9888-87",
            "(61) 9888-877",
            "(61) 9888-8777",
            "(61) 98888-7777"
        ]

        for (indice, tecla) in teclas.enumerated() {
            let tamanhoAtual = campo.text?.count ?? 0
            _ = delegado.textField?(
                campo,
                shouldChangeCharactersIn: NSRange(location: tamanhoAtual, length: 0),
                replacementString: tecla
            )
            XCTAssertEqual(campo.text, esperados[indice])
            XCTAssertEqual(texto, esperados[indice])
        }

        // Dígito extra após 11 dígitos deve ser ignorado pela máscara
        let tamanhoFinal = campo.text?.count ?? 0
        _ = delegado.textField?(
            campo,
            shouldChangeCharactersIn: NSRange(location: tamanhoFinal, length: 0),
            replacementString: "9"
        )
        XCTAssertEqual(campo.text, "(61) 98888-7777")
        XCTAssertEqual(texto, "(61) 98888-7777")
    }

    func testDataNascimentoDigitacaoEmSequenciaEExcessoDeDigitos() throws {
        var texto = ""
        let tela = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { texto }, set: { texto = $0 }),
            placeholder: "dd/mm/aaaa",
            rotuloAcessibilidade: "Data de nascimento",
            identificadorAcessibilidade: "cadastro-nascimento",
            teclado: .numberPad,
            tipoConteudo: nil,
            formatar: CadastroViewModel.formatarDataNascimento
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = tela
        janela.makeKeyAndVisible()
        tela.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campo = try XCTUnwrap(campoDeTexto(em: tela.view))
        let delegado = try XCTUnwrap(campo.delegate)

        let teclas = ["1", "7", "1", "0", "2", "0", "0", "0"]
        let esperados = [
            "1",
            "17/",
            "17/1",
            "17/10/",
            "17/10/2",
            "17/10/20",
            "17/10/200",
            "17/10/2000"
        ]

        for (indice, tecla) in teclas.enumerated() {
            let tamanhoAtual = campo.text?.count ?? 0
            _ = delegado.textField?(
                campo,
                shouldChangeCharactersIn: NSRange(location: tamanhoAtual, length: 0),
                replacementString: tecla
            )
            XCTAssertEqual(campo.text, esperados[indice])
            XCTAssertEqual(texto, esperados[indice])
        }

        // Dígito extra após 8 dígitos deve ser ignorado
        let tamanhoFinal = campo.text?.count ?? 0
        _ = delegado.textField?(
            campo,
            shouldChangeCharactersIn: NSRange(location: tamanhoFinal, length: 0),
            replacementString: "9"
        )
        XCTAssertEqual(campo.text, "17/10/2000")
        XCTAssertEqual(texto, "17/10/2000")
    }

    func testColarTextoCompletoTelefoneEData() throws {
        var telefoneTexto = ""
        let telaTelefone = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { telefoneTexto }, set: { telefoneTexto = $0 }),
            placeholder: "(61) 9 0000-0000",
            rotuloAcessibilidade: "Telefone com WhatsApp",
            formatar: CadastroViewModel.formatarTelefone
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = telaTelefone
        janela.makeKeyAndVisible()
        telaTelefone.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campoTelefone = try XCTUnwrap(campoDeTexto(em: telaTelefone.view))
        let delegadoTelefone = try XCTUnwrap(campoTelefone.delegate)

        // Colar com DDI +55
        _ = delegadoTelefone.textField?(
            campoTelefone,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "+5561988887777"
        )
        XCTAssertEqual(campoTelefone.text, "(61) 98888-7777")
        XCTAssertEqual(telefoneTexto, "(61) 98888-7777")

        // Colar apenas dígitos
        _ = delegadoTelefone.textField?(
            campoTelefone,
            shouldChangeCharactersIn: NSRange(location: 0, length: campoTelefone.text?.count ?? 0),
            replacementString: "6133334444"
        )
        XCTAssertEqual(campoTelefone.text, "(61) 3333-4444")
        XCTAssertEqual(telefoneTexto, "(61) 3333-4444")

        // Testar colar data
        var dataTexto = ""
        let telaData = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { dataTexto }, set: { dataTexto = $0 }),
            placeholder: "dd/mm/aaaa",
            rotuloAcessibilidade: "Data de nascimento",
            formatar: CadastroViewModel.formatarDataNascimento
        ))
        let janelaData = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janelaData.rootViewController = telaData
        janelaData.makeKeyAndVisible()
        telaData.view.layoutIfNeeded()
        defer { janelaData.isHidden = true }
        let campoData = try XCTUnwrap(campoDeTexto(em: telaData.view))
        let delegadoData = try XCTUnwrap(campoData.delegate)

        _ = delegadoData.textField?(
            campoData,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "01011990"
        )
        XCTAssertEqual(campoData.text, "01/01/1990")
        XCTAssertEqual(dataTexto, "01/01/1990")
    }

    func testApagarNoMeioDoTexto() throws {
        var dataTexto = ""
        let telaData = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { dataTexto }, set: { dataTexto = $0 }),
            placeholder: "dd/mm/aaaa",
            rotuloAcessibilidade: "Data de nascimento",
            formatar: CadastroViewModel.formatarDataNascimento
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = telaData
        janela.makeKeyAndVisible()
        telaData.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campoData = try XCTUnwrap(campoDeTexto(em: telaData.view))
        let delegadoData = try XCTUnwrap(campoData.delegate)

        campoData.text = "17/10/2000"
        campoData.sendActions(for: .editingChanged)

        // Apagar o "0" de "10" (localização 4, comprimento 1)
        _ = delegadoData.textField?(
            campoData,
            shouldChangeCharactersIn: NSRange(location: 4, length: 1),
            replacementString: ""
        )
        XCTAssertEqual(campoData.text, "17/12/000")
        XCTAssertEqual(dataTexto, "17/12/000")

        // Testar telefone: apagar no meio
        var telefoneTexto = ""
        let telaTelefone = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { telefoneTexto }, set: { telefoneTexto = $0 }),
            placeholder: "(61) 9 0000-0000",
            rotuloAcessibilidade: "Telefone com WhatsApp",
            formatar: CadastroViewModel.formatarTelefone
        ))
        let janelaTelefone = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janelaTelefone.rootViewController = telaTelefone
        janelaTelefone.makeKeyAndVisible()
        telaTelefone.view.layoutIfNeeded()
        defer { janelaTelefone.isHidden = true }
        let campoTelefone = try XCTUnwrap(campoDeTexto(em: telaTelefone.view))
        let delegadoTelefone = try XCTUnwrap(campoTelefone.delegate)

        campoTelefone.text = "(61) 98888-7777"
        campoTelefone.sendActions(for: .editingChanged)

        // Apagar o "9" (localização 5, comprimento 1)
        _ = delegadoTelefone.textField?(
            campoTelefone,
            shouldChangeCharactersIn: NSRange(location: 5, length: 1),
            replacementString: ""
        )
        XCTAssertEqual(campoTelefone.text, "(61) 8888-7777")
        XCTAssertEqual(telefoneTexto, "(61) 8888-7777")
    }

    func testApagarSeparadorNoFinalNaoTravaCursor() throws {
        var dataTexto = ""
        let telaData = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { dataTexto }, set: { dataTexto = $0 }),
            placeholder: "dd/mm/aaaa",
            rotuloAcessibilidade: "Data de nascimento",
            formatar: CadastroViewModel.formatarDataNascimento
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = telaData
        janela.makeKeyAndVisible()
        telaData.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campoData = try XCTUnwrap(campoDeTexto(em: telaData.view))
        let delegadoData = try XCTUnwrap(campoData.delegate)

        campoData.text = "17/"
        campoData.sendActions(for: .editingChanged)

        // Ao apagar a barra em "17/", a máscara deve remover também o '7', retornando "1"
        _ = delegadoData.textField?(
            campoData,
            shouldChangeCharactersIn: NSRange(location: 2, length: 1),
            replacementString: ""
        )
        XCTAssertEqual(campoData.text, "1")
        XCTAssertEqual(dataTexto, "1")

        // Testar telefone apagando o espaço após DDD "(61) "
        var telefoneTexto = ""
        let telaTelefone = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { telefoneTexto }, set: { telefoneTexto = $0 }),
            placeholder: "(61) 9 0000-0000",
            rotuloAcessibilidade: "Telefone com WhatsApp",
            formatar: CadastroViewModel.formatarTelefone
        ))
        let janelaTelefone = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janelaTelefone.rootViewController = telaTelefone
        janelaTelefone.makeKeyAndVisible()
        telaTelefone.view.layoutIfNeeded()
        defer { janelaTelefone.isHidden = true }
        let campoTelefone = try XCTUnwrap(campoDeTexto(em: telaTelefone.view))
        let delegadoTelefone = try XCTUnwrap(campoTelefone.delegate)

        campoTelefone.text = "(61) "
        campoTelefone.sendActions(for: .editingChanged)

        // Ao apagar o espaço em "(61) ", a máscara deve voltar para "(6"
        _ = delegadoTelefone.textField?(
            campoTelefone,
            shouldChangeCharactersIn: NSRange(location: 4, length: 1),
            replacementString: ""
        )
        XCTAssertEqual(campoTelefone.text, "(6")
        XCTAssertEqual(telefoneTexto, "(6")
    }

    func testAtualizacaoSincronaViaEditingChanged() throws {
        var texto = ""
        let tela = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { texto }, set: { texto = $0 }),
            placeholder: "(61) 9 0000-0000",
            rotuloAcessibilidade: "Telefone com WhatsApp",
            formatar: CadastroViewModel.formatarTelefone
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = tela
        janela.makeKeyAndVisible()
        tela.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campo = try XCTUnwrap(campoDeTexto(em: tela.view))

        campo.text = "61999998888"
        campo.sendActions(for: .editingChanged)
        XCTAssertEqual(campo.text, "(61) 99999-8888")
        XCTAssertEqual(texto, "(61) 99999-8888")

        campo.text = ""
        campo.sendActions(for: .editingChanged)
        XCTAssertEqual(campo.text, "")
        XCTAssertEqual(texto, "")
    }

    func testCPFEmSequenciaRapidaNaTelaDoEstabelecimento() throws {
        try comCampoDocumento { campo in
            let esperados = ["1", "12", "123", "123.4", "123.45", "123.456", "123.456.7", "123.456.78", "123.456.789", "123.456.789-0", "123.456.789-01"]
            for (tecla, esperado) in zip("12345678901", esperados) {
                try editar(campo, intervalo: NSRange(location: ((campo.text ?? "") as NSString).length, length: 0), texto: String(tecla))
                XCTAssertEqual(campo.text, esperado)
            }
        }
    }

    func testCNPJEmSequenciaRapidaTrocaMascaraNoDecimoSegundoDigito() throws {
        try comCampoDocumento { campo in
            let esperados = ["1", "12", "123", "123.4", "123.45", "123.456", "123.456.7", "123.456.78", "123.456.780", "123.456.780-0", "123.456.780-00", "12.345.678/0001", "12.345.678/0001-9", "12.345.678/0001-99"]
            for (tecla, esperado) in zip("12345678000199", esperados) {
                try editar(campo, intervalo: NSRange(location: ((campo.text ?? "") as NSString).length, length: 0), texto: String(tecla))
                XCTAssertEqual(campo.text, esperado)
                XCTAssertEqual(try cursor(em: campo), (esperado as NSString).length)
            }
        }
    }

    func testColagemDeCPFEDeCNPJNaTelaDoEstabelecimento() throws {
        try comCampoDocumento { campo in
            for (colado, esperado) in [("12345678901", "123.456.789-01"), ("12.345.678/0001-99", "12.345.678/0001-99")] {
                try editar(campo, intervalo: NSRange(location: 0, length: ((campo.text ?? "") as NSString).length), texto: colado)
                XCTAssertEqual(campo.text, esperado)
                XCTAssertEqual(try cursor(em: campo), (esperado as NSString).length)
            }
        }
    }

    func testApagarNoMeioDoCPFEDeCNPJNaTelaDoEstabelecimento() throws {
        try comCampoDocumento { campo in
            for (documento, esperado) in [("12345678901", "123.467.890-1"), ("12345678000199", "12.346.780/0019-9")] {
                try editar(campo, intervalo: NSRange(location: 0, length: ((campo.text ?? "") as NSString).length), texto: documento)
                try editar(campo, intervalo: NSRange(location: 5, length: 1), texto: "")
                XCTAssertEqual(campo.text, esperado)
                XCTAssertEqual(try cursor(em: campo), 5)
            }
            // Ao voltar de 12 para 11 dígitos, a mesma regra volta ao CPF.
            try editar(campo, intervalo: NSRange(location: 0, length: ((campo.text ?? "") as NSString).length), texto: "123456789012")
            try editar(campo, intervalo: NSRange(location: 0, length: 1), texto: "")
            XCTAssertEqual(campo.text, "234.567.890-12")
            XCTAssertEqual(try cursor(em: campo), 0)
        }
    }

    func testCursorSemDigitosAntesFicaDepoisDoSeparadorInicial() throws {
        var texto = "(61) 98888-7777"
        let tela = UIHostingController(rootView: CampoMascara(
            texto: Binding(get: { texto }, set: { texto = $0 }),
            placeholder: "(61) 9 0000-0000",
            rotuloAcessibilidade: "Telefone com WhatsApp",
            formatar: CadastroViewModel.formatarTelefone
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = tela
        janela.makeKeyAndVisible()
        tela.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campo = try XCTUnwrap(campoDeTexto(em: tela.view))
        try editar(campo, intervalo: NSRange(location: 1, length: 1), texto: "")
        XCTAssertEqual(campo.text, "(19) 8888-7777")
        XCTAssertEqual(texto, "(19) 8888-7777")
        XCTAssertEqual(try cursor(em: campo), 1)
    }

    private func comCampoDocumento(_ verificar: (UITextField) throws -> Void) throws {
        let tela = UIHostingController(rootView: TelaCadastroEstabelecimento(
            api: ApiClienteEncaminhador(), fila: FilaDaMascara(),
            responsavelNome: "Responsável de teste", responsavelTelefone: "(61) 99999-0000"
        ))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        janela.rootViewController = tela
        janela.makeKeyAndVisible()
        tela.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campo = try XCTUnwrap(camposDeTexto(em: tela.view).first { $0.placeholder == "CPF ou CNPJ" })
        try verificar(campo)
    }

    private func editar(_ campo: UITextField, intervalo: NSRange, texto: String) throws {
        let delegado = try XCTUnwrap(campo.delegate)
        let aplicarPeloUIKit = try XCTUnwrap(delegado.textField?(campo, shouldChangeCharactersIn: intervalo, replacementString: texto))
        XCTAssertFalse(aplicarPeloUIKit, "A máscara deve ser aplicada no mesmo evento, antes da próxima tecla")
    }

    private func cursor(em campo: UITextField) throws -> Int {
        let selecao = try XCTUnwrap(campo.selectedTextRange)
        return campo.offset(from: campo.beginningOfDocument, to: selecao.start)
    }

    private func camposDeTexto(em view: UIView) -> [UITextField] {
        if let campo = view as? UITextField { return [campo] }
        return view.subviews.flatMap { camposDeTexto(em: $0) }
    }

    private func campoDeTexto(em view: UIView) -> UITextField? {
        if let campo = view as? UITextField { return campo }
        return view.subviews.lazy.compactMap { self.campoDeTexto(em: $0) }.first
    }
}

private actor FilaDaMascara: FilaDeAcoes {
    func enfileirar(_ acao: AcaoPendente) {}
    func pendentes() -> [AcaoPendente] { [] }
    func remover(id: UUID) {}
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws {}
    func recusadas() -> [AcaoRecusada] { [] }
    func limpar() {}
}
