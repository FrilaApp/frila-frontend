import FrilaDominio

extension RecursosDoApp {
    /// A chave do servidor, lida com prazo: sem rede ou sem resposta no prazo, tudo desligado. Lida uma vez
    /// por abertura da tela do turno, para os `sinais` do check-in e as telas do código (contrato 0.2.68).
    static func lidosDe(_ api: any ApiCliente) async -> RecursosDoApp {
        (try? await PrazoDaAbertura.esperar(PrazoDaAbertura.padrao) { try await api.configuracaoDoApp() })?.recursos ?? .desligados
    }
}
