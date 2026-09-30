import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class CadastroViewModel {
    private let api: any ApiCliente
    private let relogio: any Relogio
    public let email: String

    public var perfil: PerfilConta = .profissional
    public var nome: String = ""
    public var telefone: String = ""
    public var nascimentoTexto: String = ""
    public var maiorDeIdade: Bool = false
    public var aceitouTermos: Bool = false
    public var carregando: Bool = false
    public var erro: String?

    public init(api: any ApiCliente, email: String, relogio: any Relogio = RelogioDoSistema()) {
        self.api = api
        self.email = email
        self.relogio = relogio
    }

    public var formularioPreenchido: Bool {
        let nomeLimpo = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        let telefoneLimpo = telefone.trimmingCharacters(in: .whitespacesAndNewlines)
        let nascimentoLimpo = nascimentoTexto.trimmingCharacters(in: .whitespacesAndNewlines)
        return !nomeLimpo.isEmpty && !telefoneLimpo.isEmpty && !nascimentoLimpo.isEmpty && maiorDeIdade && aceitouTermos
    }

    public func criarConta() async -> DestinoAposEntrada? {
        guard !carregando else { return nil }
        let nomeLimpo = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nomeLimpo.count >= 2 else {
            erro = String(localized: "Informe seu nome completo.", bundle: bundleApresentacao)
            return nil
        }

        guard let telefoneE164 = normalizarTelefone(telefone) else {
            erro = String(localized: "Informe um telefone válido com DDD.", bundle: bundleApresentacao)
            return nil
        }

        guard let nascimento = normalizarDataNascimento(nascimentoTexto) else {
            erro = String(localized: "Informe a data de nascimento no formato dd/mm/aaaa.", bundle: bundleApresentacao)
            return nil
        }

        guard maiorDeIdade else {
            erro = String(localized: "O Frila é exclusivo para maiores de 18 anos.", bundle: bundleApresentacao)
            return nil
        }

        guard aceitouTermos else {
            erro = String(localized: "É necessário aceitar os Termos de uso e a Política de privacidade para continuar.", bundle: bundleApresentacao)
            return nil
        }

        // Validação preventiva da maioridade no cliente antes de enviar ao servidor
        if let hoje = DataCivil.deSaoPaulo(relogio.agora),
           let aniversario18 = try? DataCivil(ano: nascimento.ano + 18, mes: nascimento.mes, dia: nascimento.dia),
           aniversario18 > hoje {
            erro = String(localized: "O Frila é exclusivo para maiores de 18 anos.", bundle: bundleApresentacao)
            return nil
        }

        carregando = true
        erro = nil
        defer { carregando = false }

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
                return .funcoesEHorarios(conta)
            case .contratante:
                return .contratante(conta)
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

    private func normalizarTelefone(_ texto: String) -> String? {
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

    private func normalizarDataNascimento(_ texto: String) -> DataCivil? {
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
}
