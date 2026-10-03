// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Textos PROVISÓRIOS do check-in e do check-out
// (#17), até a alta fidelidade da chegada ao turno e o guia de voz (#186). Ficam num arquivo próprio,
// como extensão de `TextosDoProfissional`, para não disputar o arquivo com os outros cartões do turno.

import Foundation
import FrilaDominio

extension TextosDoProfissional {
    enum Presenca {
        static let titulo = String(localized: "Presença", bundle: bundleApresentacao)
        static let fazerCheckin = String(localized: "Fazer check-in", bundle: bundleApresentacao)
        static let fazerCheckout = String(localized: "Fazer check-out", bundle: bundleApresentacao)

        static let explicacaoTitulo = String(localized: "Sua localização, só neste toque", bundle: bundleApresentacao)
        static let explicacao = String(
            localized: "O Frila lê sua localização só quando você toca no botão, para medir a distância até o endereço da vaga. Só a distância é enviada: sua posição não sai do aparelho e nada é lido em segundo plano.",
            bundle: bundleApresentacao
        )
        static let continuar = String(localized: "Continuar", bundle: bundleApresentacao)
        static let agoraNao = String(localized: "Agora não", bundle: bundleApresentacao)

        static let lendo = String(localized: "Lendo sua localização…", bundle: bundleApresentacao)
        static let enviando = String(localized: "Enviando…", bundle: bundleApresentacao)

        static let semGPSTitulo = String(localized: "Não consegui pelo GPS", bundle: bundleApresentacao)
        static let motivoPermissaoNegada = String(localized: "O Frila está sem permissão para usar a localização. Você pode liberar nos Ajustes.", bundle: bundleApresentacao)
        static let motivoAproximada = String(localized: "A localização precisa está desligada para o Frila, e a aproximada não mede a distância até o endereço.", bundle: bundleApresentacao)
        static let motivoSemSinal = String(localized: "O GPS não respondeu em 10 segundos.", bundle: bundleApresentacao)
        static let motivoImprecisa = String(localized: "O sinal do GPS está fraco demais para confirmar que você está no endereço.", bundle: bundleApresentacao)
        static func motivoLonge(_ metros: Int) -> String {
            String(localized: "O GPS indica que você está a cerca de \(metros) m do endereço da vaga.", bundle: bundleApresentacao)
        }
        static let motivoEnderecoIndisponivel = String(localized: "Não foi possível carregar o endereço da vaga para medir a distância.", bundle: bundleApresentacao)

        static let manualExplicacao = String(localized: "Você pode fazer o check-in manual. Ele fica aguardando a confirmação do contratante.", bundle: bundleApresentacao)
        static let checkinManual = String(localized: "Fazer check-in manual", bundle: bundleApresentacao)
        static let saidaSemLocalizacaoExplicacao = String(localized: "Você pode registrar a saída sem a localização.", bundle: bundleApresentacao)
        static let saidaSemLocalizacao = String(localized: "Registrar saída sem localização", bundle: bundleApresentacao)
        static let tentarGPS = String(localized: "Tentar o GPS de novo", bundle: bundleApresentacao)
        static let abrirAjustes = String(localized: "Abrir Ajustes", bundle: bundleApresentacao)

        static func checkinVerificado(_ hora: String, metros: Int?) -> String {
            guard let metros else { return String(localized: "Check-in verificado às \(hora).", bundle: bundleApresentacao) }
            return String(localized: "Check-in verificado às \(hora), a \(metros) m do endereço.", bundle: bundleApresentacao)
        }
        static func checkinAguardando(_ hora: String) -> String {
            String(localized: "Check-in manual feito às \(hora). Aguardando confirmação do contratante.", bundle: bundleApresentacao)
        }
        static func checkinSemVerificacao(_ hora: String) -> String {
            String(localized: "Check-in feito às \(hora), sem verificação.", bundle: bundleApresentacao)
        }
        static func checkinNaFila(_ hora: String, manual: Bool) -> String {
            manual
                ? String(localized: "Sem conexão. O check-in manual das \(hora) está guardado neste aparelho e será enviado quando a internet voltar, com esse horário. Depois ele aguarda a confirmação do contratante.", bundle: bundleApresentacao)
                : String(localized: "Sem conexão. O check-in das \(hora) está guardado neste aparelho e será enviado quando a internet voltar, com esse horário.", bundle: bundleApresentacao)
        }
        static func checkoutRegistrado(_ hora: String, metros: Int?) -> String {
            guard let metros else { return String(localized: "Check-out registrado às \(hora).", bundle: bundleApresentacao) }
            return String(localized: "Check-out registrado às \(hora), a \(metros) m do endereço.", bundle: bundleApresentacao)
        }
        static func checkoutNaFila(_ hora: String) -> String {
            String(localized: "Sem conexão. O check-out das \(hora) está guardado neste aparelho e será enviado quando a internet voltar, com esse horário.", bundle: bundleApresentacao)
        }

        static let foraDaJanela = String(localized: "O registro só pode ser feito de 60 minutos antes do início até o fim previsto do turno.", bundle: bundleApresentacao)
        static let relogioAdiantado = String(localized: "O relógio do aparelho parece adiantado. Ajuste a data e a hora e tente de novo.", bundle: bundleApresentacao)
        static let falhaAoGuardar = String(localized: "Sem conexão, e não foi possível guardar o registro neste aparelho. Tente de novo.", bundle: bundleApresentacao)
        static let falhaAoEnviar = String(localized: "Não foi possível enviar o registro. Tente de novo.", bundle: bundleApresentacao)
    }
}

// Textos provisórios para validação pelo Cauê.
enum TextosDaFila {
    static func texto(_ tipo: TipoAcaoPendente) -> String {
        switch tipo {
        case .checkin:
            String(localized: "O check-in guardado neste aparelho não foi registrado. Esse envio não será repetido.", bundle: bundleApresentacao)
        case .checkout:
            String(localized: "O check-out guardado neste aparelho não foi registrado. Esse envio não será repetido.", bundle: bundleApresentacao)
        case .publicacaoVaga:
            String(localized: "A publicação guardada neste aparelho não foi registrada. Esse envio não será repetido.", bundle: bundleApresentacao)
        case .republicacaoVaga:
            String(localized: "A republicação guardada neste aparelho não foi registrada. Esse envio não será repetido.", bundle: bundleApresentacao)
        case .avaliacao:
            "" // O tratamento da avaliação permanece no fluxo existente.
        }
    }
}
