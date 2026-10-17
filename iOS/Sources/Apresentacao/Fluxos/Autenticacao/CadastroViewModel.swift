import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class CadastroViewModel {
    private let api: any ApiCliente
    private let relogio: any Relogio
    private let verificadorDeIdade: any VerificadorDeIdade
    public let email: String

    public enum CampoCadastro: Hashable, Sendable {
        case nome
        case telefone
        case nascimento
        case termos
    }

    public var perfil: PerfilConta = .profissional
    public var nome: String = ""
    public var telefone: String = ""
    public var nascimentoTexto: String = ""
    public var aceitouTermos: Bool = false
    public var carregando: Bool = false
    public var erro: String?
    public var campoComErro: CampoCadastro?

    public init(
        api: any ApiCliente,
        email: String,
        relogio: any Relogio = RelogioDoSistema(),
        verificadorDeIdade: any VerificadorDeIdade = VerificadorDeIdadeIndisponivel()
    ) {
        self.api = api
        self.email = email
        self.relogio = relogio
        self.verificadorDeIdade = verificadorDeIdade
    }

    public var ehMenorDeIdade: Bool {
        guard let nascimento = normalizarDataNascimento(nascimentoTexto),
              let hoje = DataCivil.deSaoPaulo(relogio.agora),
              let aniversario18 = try? DataCivil(ano: nascimento.ano + 18, mes: nascimento.mes, dia: nascimento.dia)
        else {
            return false
        }
        return aniversario18 > hoje
    }

    public var formularioPreenchido: Bool {
        let nomeLimpo = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        let telefoneLimpo = telefone.trimmingCharacters(in: .whitespacesAndNewlines)
        let nascimentoLimpo = nascimentoTexto.trimmingCharacters(in: .whitespacesAndNewlines)
        return !nomeLimpo.isEmpty && !telefoneLimpo.isEmpty && !nascimentoLimpo.isEmpty && aceitouTermos && !ehMenorDeIdade
    }

    public func criarConta() async -> DestinoAposEntrada? {
        guard !carregando else { return nil }
        let nomeLimpo = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nomeLimpo.count >= 2 else {
            campoComErro = .nome
            erro = String(localized: "Informe seu nome completo.", bundle: bundleApresentacao)
            return nil
        }

        guard let telefoneE164 = normalizarTelefone(telefone) else {
            campoComErro = .telefone
            erro = String(localized: "Informe um telefone válido com DDD.", bundle: bundleApresentacao)
            return nil
        }

        guard let nascimento = normalizarDataNascimento(nascimentoTexto) else {
            campoComErro = .nascimento
            erro = String(localized: "Informe a data de nascimento no formato dd/mm/aaaa.", bundle: bundleApresentacao)
            return nil
        }

        // Validação preventiva da maioridade no cliente antes de enviar ao servidor
        if let hoje = DataCivil.deSaoPaulo(relogio.agora),
           let aniversario18 = try? DataCivil(ano: nascimento.ano + 18, mes: nascimento.mes, dia: nascimento.dia),
           aniversario18 > hoje {
            campoComErro = .nascimento
            erro = String(localized: "O Frila é exclusivo para maiores de 18 anos.", bundle: bundleApresentacao)
            return nil
        }

        guard aceitouTermos else {
            campoComErro = .termos
            erro = String(localized: "É necessário aceitar os Termos de uso e a Política de privacidade para continuar.", bundle: bundleApresentacao)
            return nil
        }

        campoComErro = nil
        carregando = true
        erro = nil
        defer { carregando = false }

        // Verificação condicional de maioridade via Declared Age Range (iOS 26.2+, RN20 / Cartão #215)
        let resultadoIdade = await verificadorDeIdade.verificarMaioridade()
        if resultadoIdade == .abaixoDe18 {
            campoComErro = .nascimento
            erro = String(localized: "O Frila é exclusivo para maiores de 18 anos.", bundle: bundleApresentacao)
            return nil
        }

        let cadastro = CadastroConta(
            nome: nomeLimpo,
            telefone: telefoneE164,
            nascimento: nascimento,
            perfil: perfil,
            versaoTermos: "2026-09-22"
        )

        do {
            let conta = try await api.criarConta(cadastro)
            switch conta.perfil {
            case .profissional:
                DestinoGuardado.salvar(.funcoesEHorarios)
                return .funcoesEHorarios
            case .contratante:
                DestinoGuardado.salvar(.contratante)
                return .contratante
            }
        } catch let erroApi as ErroDaApi {
            tratarErroDeCriacao(erroApi)
            return nil
        } catch {
            erro = String(localized: "Não foi possível criar sua conta. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    private func tratarErroDeCriacao(_ erroApi: ErroDaApi) {
        if erroApi.codigo == .menorDeIdade {
            erro = String(localized: "O Frila é exclusivo para maiores de 18 anos.", bundle: bundleApresentacao)
        } else if erroApi.codigo == .contaExistente {
            erro = String(localized: "Esta conta já foi cadastrada.", bundle: bundleApresentacao)
        } else {
            erro = MensagemDoErroAPI.texto(erroApi)
        }
    }

    public static func normalizarTelefone(_ texto: String) -> String? {
        let digitos = texto.filter(\.isNumber)
        guard digitos.count >= 10 else { return nil }

        if texto.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+") {
            return "+\(digitos)"
        }

        // Se tem 10 ou 11 dígitos no padrão brasileiro, adiciona o código do país +55
        if digitos.count == 10 || digitos.count == 11 {
            return "+55\(digitos)"
        }
        return "+\(digitos)"
    }

    public static func normalizarDataNascimento(_ texto: String) -> DataCivil? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)

        // Tenta formato dd/mm/aaaa
        let partesBarra = limpo.split(separator: "/")
        if partesBarra.count == 3,
           let dia = Int(partesBarra[0]),
           let mes = Int(partesBarra[1]),
           let ano = Int(partesBarra[2]) {
            return try? DataCivil(ano: ano, mes: mes, dia: dia)
        }

        // Tenta formato aaaa-mm-dd
        let partesTraco = limpo.split(separator: "-")
        if partesTraco.count == 3,
           let ano = Int(partesTraco[0]),
           let mes = Int(partesTraco[1]),
           let dia = Int(partesTraco[2]) {
            return try? DataCivil(ano: ano, mes: mes, dia: dia)
        }

        return nil
    }

    public func normalizarTelefone(_ texto: String) -> String? {
        Self.normalizarTelefone(texto)
    }

    public func normalizarDataNascimento(_ texto: String) -> DataCivil? {
        Self.normalizarDataNascimento(texto)
    }

    public static func formatarDataNascimento(_ novoTexto: String, textoAnterior: String = "") -> String {
        let digitosNovos = novoTexto.filter(\.isNumber)
        let digitosAnteriores = textoAnterior.filter(\.isNumber)

        var digitos = Array(digitosNovos.prefix(8))

        // Se o usuário apagou a barra de formatação (ex: estava em "17/" e ficou "17"),
        // remove também o dígito correspondente para não travar na barra.
        if textoAnterior.hasSuffix("/") && !novoTexto.hasSuffix("/") && digitosNovos.count == digitosAnteriores.count && !digitos.isEmpty {
            digitos.removeLast()
        }

        if digitos.isEmpty { return "" }

        var resultado = ""
        for (indice, digito) in digitos.enumerated() {
            if indice == 2 || indice == 4 {
                resultado.append("/")
            }
            resultado.append(digito)
        }

        if (digitos.count == 2 || digitos.count == 4) && novoTexto.count >= textoAnterior.count {
            resultado.append("/")
        }

        return resultado
    }

    public static func formatarTelefone(_ novoTexto: String, textoAnterior: String = "") -> String {
        var digitosNovos = Array(novoTexto.filter(\.isNumber))
        let digitosAnteriores = Array(textoAnterior.filter(\.isNumber))

        if digitosNovos.count > 11 && digitosNovos.prefix(2) == ["5", "5"] {
            digitosNovos = Array(digitosNovos.dropFirst(2))
        }

        // Se o usuário apagou caractere de formatação (ex: estava em "(61) " e ficou "(61)", ou "(61) 9888-" e ficou "(61) 9888")
        if digitosNovos.count == digitosAnteriores.count && novoTexto.count < textoAnterior.count && !digitosNovos.isEmpty {
            digitosNovos.removeLast()
        }

        let digitos = Array(digitosNovos.prefix(11))
        if digitos.isEmpty { return "" }

        let count = digitos.count
        if count == 1 {
            return "(\(digitos[0])"
        }
        if count == 2 {
            if novoTexto.count >= textoAnterior.count {
                return "(\(digitos[0])\(digitos[1])) "
            } else {
                return "(\(digitos[0])\(digitos[1])"
            }
        }

        let ddd = String(digitos[0..<2])
        if count <= 6 {
            let resto = String(digitos[2..<count])
            return "(\(ddd)) \(resto)"
        }
        if count <= 10 {
            let parte1 = String(digitos[2..<6])
            let parte2 = String(digitos[6..<count])
            if parte2.isEmpty {
                return "(\(ddd)) \(parte1)"
            }
            return "(\(ddd)) \(parte1)-\(parte2)"
        }
        let parte1 = String(digitos[2..<7])
        let parte2 = String(digitos[7..<11])
        return "(\(ddd)) \(parte1)-\(parte2)"
    }
}
