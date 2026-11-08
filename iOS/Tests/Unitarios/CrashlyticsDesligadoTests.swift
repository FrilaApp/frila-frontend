import Foundation
@testable import FrilaInfraestrutura
import Testing

/// Espia o destino do Crashlytics: guarda tudo o que chegaria ao SDK.
private final class DestinoEspiao: DestinoDeFalhas, @unchecked Sendable {
    private let trava = NSLock()
    private var gravados: [String] = []

    func gravar(codigo: String, rpc: String, duracaoNs: Int64) {
        trava.withLock { gravados.append("\(codigo)|\(rpc)|\(duracaoNs)") }
    }

    var registros: [String] { trava.withLock { gravados } }
}

/// C1 (08/11/2026): a 1.1 não envia nada ao Crashlytics. Falta base legal para transferir dados de
/// falha ao Google nos EUA (orquestracao/retornos/juridico-transferencias-fornecedores-08-11.md).
@Suite("Crashlytics desligado na 1.1 (C1)")
struct CrashlyticsDesligadoTests {
    @Test("O Info.plist do app instalado traz FirebaseCrashlyticsCollectionEnabled como o booleano false")
    func chaveDesligadaNoAppInstalado() throws {
        try #require(Bundle.main.bundleIdentifier?.hasPrefix("com.frila") == true, "o teste precisa rodar dentro do app")
        let valor = Bundle.main.object(forInfoDictionaryKey: RelatorioDeFalhas.chaveDaColeta)
        #expect(valor != nil, "sem a chave, o SDK do Crashlytics coleta por padrão")
        #expect((valor as? Bool) == false, "a coleta tem de estar desligada (encontrado: \(String(describing: valor)))")
        #expect(!RelatorioDeFalhas.coletaLigada())
    }

    @Test("Com o Info.plist do app, a telemetria não grava nenhum erro da API no Crashlytics")
    func nadaEGravadoComOInfoPlistDoApp() async {
        let espiao = DestinoEspiao()
        let telemetria = TelemetriaCrashlytics(destino: espiao)
        await telemetria.registrarErroDaApi(codigo: "sem_rede", rpc: "vagas_abertas", duracao: .milliseconds(120))
        await telemetria.registrarErroDaApi(codigo: "nao_autorizado", rpc: "minha_conta", duracao: .seconds(2))
        #expect(espiao.registros.isEmpty, "nada pode chegar ao Crashlytics: \(espiao.registros)")
    }

    @Test("Controle: com a coleta ligada, o mesmo espião recebe o erro (o teste acima não passa à toa)")
    func espiaoRecebeComAColetaLigada() async {
        let espiao = DestinoEspiao()
        let telemetria = TelemetriaCrashlytics(coletaLigada: true, destino: espiao)
        await telemetria.registrarErroDaApi(codigo: "sem_rede", rpc: "vagas_abertas", duracao: .milliseconds(120))
        #expect(espiao.registros == ["sem_rede|vagas_abertas|120000000"])
    }
}
