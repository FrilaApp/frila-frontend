import Foundation

/// Textos das telas do check-in por código (contrato 0.2.68): o código na casa e a leitura no profissional.
/// O Fabrício não desenhou estas telas; o texto segue o tom do protótipo da cara nova (frases curtas, sem
/// jargão) e é revisto quando o desenho chegar.
enum TextosDoCheckinPorCodigo {
    // MARK: A casa mostra o código

    enum Casa {
        static let titulo = String(localized: "Código de chegada", bundle: bundleApresentacao)
        static let explicacao = String(
            localized: "Mostre este código a quem chegou. A pessoa digita os 6 números ou lê o QR com a câmera.",
            bundle: bundleApresentacao
        )
        static func validade(_ tempo: String) -> String {
            String(localized: "Vale por mais \(tempo)", bundle: bundleApresentacao)
        }
        static let gerandoOutro = String(localized: "O código venceu. Gerando outro…", bundle: bundleApresentacao)
        static let carregando = String(localized: "Gerando o código…", bundle: bundleApresentacao)
        static let falhou = String(localized: "Não deu para gerar o código. Confira a conexão e tente de novo.", bundle: bundleApresentacao)
        static let tentarDeNovo = String(localized: "Tentar de novo", bundle: bundleApresentacao)
        static let encerrado = String(
            localized: "O código não vale mais neste turno. Confirme a chegada pelo botão abaixo.",
            bundle: bundleApresentacao
        )
        static func codigoPorExtenso(_ digitos: String) -> String {
            String(localized: "Código de chegada: \(digitos.map(String.init).joined(separator: " "))", bundle: bundleApresentacao)
        }
        static let qrDoCodigo = String(localized: "QR com o mesmo código", bundle: bundleApresentacao)
    }

    // MARK: O profissional lê o código

    enum Profissional {
        static let abrir = String(localized: "Digitar o código da casa", bundle: bundleApresentacao)
        static let titulo = String(localized: "Código da casa", bundle: bundleApresentacao)
        static let explicacao = String(
            localized: "Peça o código à casa. Digite os 6 números ou leia o QR que ela mostra.",
            bundle: bundleApresentacao
        )
        static let casaConfirma = String(
            localized: "A casa também pode confirmar a sua chegada pelo painel dela.",
            bundle: bundleApresentacao
        )
        static let rotuloDoCampo = String(localized: "Código de 6 números", bundle: bundleApresentacao)
        static let confirmar = String(localized: "Confirmar presença", bundle: bundleApresentacao)
        static let lerQR = String(localized: "Ler o QR", bundle: bundleApresentacao)
        static let digitar = String(localized: "Digitar os números", bundle: bundleApresentacao)
        static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
        static let apontarParaOQR = String(localized: "Aponte a câmera para o QR que a casa mostra.", bundle: bundleApresentacao)
        static let semCamera = String(
            localized: "A câmera não está liberada. Digite o código ou libere a câmera em Ajustes.",
            bundle: bundleApresentacao
        )
        static let abrirAjustes = String(localized: "Abrir Ajustes", bundle: bundleApresentacao)
        static let medindo = String(localized: "Conferindo a sua posição…", bundle: bundleApresentacao)
        static let enviando = String(localized: "Conferindo o código…", bundle: bundleApresentacao)

        static let formatoInvalido = String(localized: "O código tem 6 números.", bundle: bundleApresentacao)
        static let invalido = String(
            localized: "Esse código não vale. Confira com a casa e digite de novo.",
            bundle: bundleApresentacao
        )
        static func chegueMaisPerto(_ metros: Int) -> String {
            String(
                localized: "Você está a \(metros) m do local. Chegue mais perto e tente de novo: o código não foi enviado.",
                bundle: bundleApresentacao
            )
        }
        static let bloqueadoPorUmTempo = String(
            localized: "Você errou várias vezes. Espere alguns minutos ou peça à casa para confirmar a sua chegada.",
            bundle: bundleApresentacao
        )
        static let encerrado = String(
            localized: "O código não vale mais neste turno. Peça à casa para confirmar a sua chegada.",
            bundle: bundleApresentacao
        )
        static let indisponivel = String(
            localized: "A leitura do código não está disponível agora. Peça à casa para confirmar a sua chegada.",
            bundle: bundleApresentacao
        )
        static let respostaPerdida = String(
            localized: "Não deu para saber se o código foi aceito. Veja se a sua presença já aparece como verificada; se não, digite de novo.",
            bundle: bundleApresentacao
        )
    }
}
