@testable import FrilaApresentacao
import Testing

/// Regressão do achado do Lince Codex no R3: na main o "Tentar de novo" do aviso "a caminho" ficava fora do `switch` das
/// etapas da presença e valia em todas elas (`.parada`, `.explicando`, `.lendo`, `.enviando`, `.semGPS`).
struct TentarDeNovoDoACaminhoTests {
    typealias Etapa = PresencaDoTurnoViewModel.Etapa

    static let etapas: [Etapa] = [
        .parada,
        .explicando(.checkin), .explicando(.checkout),
        .lendo(.checkin), .lendo(.checkout),
        .enviando(.checkin), .enviando(.checkout),
        .semGPS(.checkin, .semSinal), .semGPS(.checkout, .permissaoNegada)
    ]

    @Test("Com o erro do A caminho e a tentativa liberada, o Tentar de novo aparece em toda etapa", arguments: etapas)
    func apareceEmToda(etapa: Etapa) {
        #expect(RegrasDeTelaDaPresenca.mostraTentarDeNovoDoACaminho(estado: etapa, erro: "Sem conexão.", podeTentar: true))
    }

    @Test("Sem erro ou sem a tentativa liberada, não aparece em etapa nenhuma", arguments: etapas)
    func naoApareceSemCondicao(etapa: Etapa) {
        #expect(!RegrasDeTelaDaPresenca.mostraTentarDeNovoDoACaminho(estado: etapa, erro: nil, podeTentar: true))
        #expect(!RegrasDeTelaDaPresenca.mostraTentarDeNovoDoACaminho(estado: etapa, erro: "Sem conexão.", podeTentar: false))
    }
}
