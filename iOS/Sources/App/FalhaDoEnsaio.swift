#if FRILA_ENSAIO_FALHA
import FrilaApresentacao
import SwiftUI

/// Botão do ensaio de falha do TestFlight (#203): prova que uma falha do build distribuído chega
/// simbolizada ao Crashlytics. Só existe no build de ensaio, que o `Scripts/enviar-testflight.sh`
/// compila com `FRILA_ENSAIO_FALHA` e manda ao TestFlight marcado como só para teste interno. O
/// `conferir-release.sh` reprova qualquer outro Release que o contenha.
struct BotaoDeFalhaDoEnsaio: View {
    var body: some View {
        Button {
            fatalError("Falha forçada do ensaio do TestFlight")
        } label: {
            Text(verbatim: "Forçar falha (ensaio)")
        }
        .buttonStyle(.borderedProminent)
        .tint(FrilaCor.perigo)
        .padding()
        .accessibilityIdentifier("ensaio-forcar-falha")
    }
}
#endif
