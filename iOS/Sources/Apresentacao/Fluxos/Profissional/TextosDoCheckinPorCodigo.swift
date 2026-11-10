import Foundation

/// Textos da tela do check-in por código na visão do Profissional (contrato 0.2.68, direção de 10/11/2026).
/// Sem QR code na etapa 1; foco na digitação direta dos 6 números com validação de servidor.
public enum TextosDoCheckinPorCodigo {
    public enum Profissional {
        public static let abrir = String(localized: "Digitar o código da casa", bundle: bundleApresentacao)
        public static let titulo = String(localized: "Código da casa", bundle: bundleApresentacao)
        public static let explicacao = String(
            localized: "Peça o código à casa e digite os 6 números abaixo para confirmar a sua presença.",
            bundle: bundleApresentacao
        )
        public static let casaConfirma = String(
            localized: "A casa também pode confirmar a sua chegada pelo painel dela.",
            bundle: bundleApresentacao
        )
        public static let rotuloDoCampo = String(localized: "Código de 6 números", bundle: bundleApresentacao)
        public static let confirmar = String(localized: "Confirmar presença", bundle: bundleApresentacao)
        public static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
        public static let medindo = String(localized: "Conferindo a sua posição…", bundle: bundleApresentacao)
        public static let enviando = String(localized: "Conferindo o código…", bundle: bundleApresentacao)

        public static let formatoInvalido = String(localized: "O código tem 6 números.", bundle: bundleApresentacao)
        public static let invalido = String(
            localized: "Esse código não vale. Confira com a casa e digite de novo.",
            bundle: bundleApresentacao
        )
        public static func chegueMaisPerto(_ metros: Int) -> String {
            String(
                format: String(
                    localized: "Você está a %d m do local. Chegue mais perto e tente de novo: o código não foi enviado.",
                    bundle: bundleApresentacao
                ),
                metros
            )
        }
        public static let bloqueadoPorUmTempo = String(
            localized: "Você errou várias vezes. Espere alguns minutos ou peça à casa para confirmar a sua chegada.",
            bundle: bundleApresentacao
        )
        public static let encerrado = String(
            localized: "O código não vale mais neste turno. Peça à casa para confirmar a sua chegada.",
            bundle: bundleApresentacao
        )
        public static let indisponivel = String(
            localized: "A leitura do código não está disponível agora. Peça à casa para confirmar a sua chegada.",
            bundle: bundleApresentacao
        )
        public static let respostaPerdida = String(
            localized: "Não deu para saber se o código foi aceito. Veja se a sua presença já aparece como verificada; se não, digite de novo.",
            bundle: bundleApresentacao
        )
    }
}
