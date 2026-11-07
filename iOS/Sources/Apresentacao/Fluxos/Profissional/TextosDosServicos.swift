import Foundation
import FrilaDominio

enum TextosDosServicos {
    static func resumoDaDiaria(_ rascunho: ServicoEmEdicao) -> String? {
        guard rascunho.dados.unidade == .diaria, let oferta = try? rascunho.oferta(),
              let centavos = oferta.valorCentavos, let horas = oferta.horasIncluidas else { return nil }
        let valor = (Decimal(centavos) / 100).formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
        return String(localized: "\(valor) a diária de \(horas) h", bundle: bundleApresentacao)
    }

    static func resumoDoServico(_ servico: ServicoOferecido) -> String? {
        if servico.unidade == .diaria, let centavos = servico.valorCentavos, let horas = servico.horasIncluidas {
            let valor = (Decimal(centavos) / 100).formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
            return String(localized: "\(valor) a diária de \(horas) h", bundle: bundleApresentacao)
        }
        if servico.unidade == .aCombinar {
            return unidade(.aCombinar)
        }
        guard let centavos = servico.valorCentavos else {
            return unidade(servico.unidade)
        }
        let valor = (Decimal(centavos) / 100).formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
        return "\(valor) • \(unidade(servico.unidade))"
    }

    static func unidade(_ unidade: UnidadePreco) -> String {
        switch unidade {
        case .hora: String(localized: "Hora", bundle: bundleApresentacao)
        case .diaria: String(localized: "Diária", bundle: bundleApresentacao)
        case .evento: String(localized: "Evento", bundle: bundleApresentacao)
        case .pacote: String(localized: "Pacote", bundle: bundleApresentacao)
        case .porPessoa: String(localized: "Por pessoa", bundle: bundleApresentacao)
        case .aCombinar: String(localized: "A combinar", bundle: bundleApresentacao)
        }
    }

    static func material(_ material: LevaMaterial) -> String {
        switch material {
        case .sim: String(localized: "Sim", bundle: bundleApresentacao)
        case .nao: String(localized: "Não", bundle: bundleApresentacao)
        case .depende: String(localized: "Depende", bundle: bundleApresentacao)
        }
    }

    static func campo(_ campo: String) -> String {
        switch campo {
        case "valor_centavos": String(localized: "Confira o valor: de R$ 10 a R$ 10.000.", bundle: bundleApresentacao)
        case "valor_max_centavos": String(localized: "Confira o valor máximo: deve ser igual ou maior que o valor inicial, até R$ 10.000.", bundle: bundleApresentacao)
        case "horas_incluidas": String(localized: "Horas incluídas (4 a 12)", bundle: bundleApresentacao)
        case "minimo_horas": String(localized: "Mínimo de horas (opcional, 1 a 12)", bundle: bundleApresentacao)
        case "duracao_tipica_h": String(localized: "Duração em horas (opcional, 1 a 24)", bundle: bundleApresentacao)
        case "ate_pessoas": String(localized: "Até quantas pessoas (opcional, 1 a 2.000)", bundle: bundleApresentacao)
        case "minimo_pessoas": String(localized: "Mínimo de pessoas (1 a 2.000)", bundle: bundleApresentacao)
        case "descricao_pacote": String(localized: "Descrição do pacote (até 120 caracteres)", bundle: bundleApresentacao)
        case "inclui": String(localized: "Revise o que está incluído. Não informe contato ou Pix.", bundle: bundleApresentacao)
        case "especialidade_ids": String(localized: "Escolha até 8 especialidades da mesma função.", bundle: bundleApresentacao)
        default: String(localized: "Revise os serviços selecionados.", bundle: bundleApresentacao)
        }
    }
}
