import Foundation
import FrilaDominio

/// O ciclo de vida do token de push neste aparelho (#162). O token é do aparelho, e não da pessoa:
/// quem entra passa a ser a dona dele no servidor, e quem sai deixa de ser, antes de a sessão
/// acabar. Sem isso, o iPhone continua recebendo o push de quem já saiu (RN15).
///
/// As operações rodam uma de cada vez, na ordem em que chegam: uma saída pedida com um registro
/// ainda em voo espera o registro terminar e só então tira o token, e nunca o contrário.
public actor AparelhoDePush {
    public enum Registro: Equatable, Sendable {
        /// O FCM ainda não entregou o token: não há o que registrar.
        case semToken
        /// O token está guardado, e ninguém entrou ainda.
        case semConta
        case registrado(VinculoDoAparelho)
        /// O servidor não confirmou. O vínculo fica como estava, e a próxima abertura tenta de novo.
        case falhou(ErroDaApi)
    }

    private let api: any ApiCliente
    private let armazenamento: any ArmazenamentoDoAparelho
    private let relogio: any Relogio
    /// A mesma fila FIFO da sessão do cliente, em outra instância: um `actor` sozinho é reentrante
    /// em cada `await`.
    private let fila = FilaDeSessao()
    private var aparelho: AparelhoGuardado?
    private var carregado = false
    /// A conta com sessão neste aparelho, só em memória: é para ela que um token que chegue ou
    /// troque depois da entrada é registrado.
    private var contaAtiva: UUID?

    public init(api: any ApiCliente, armazenamento: any ArmazenamentoDoAparelho, relogio: any Relogio = RelogioDoSistema()) {
        self.api = api
        self.armazenamento = armazenamento
        self.relogio = relogio
    }

    /// A conta a que o aparelho está entregue, ou nada: sem entrada, sem token ou sem a confirmação
    /// do servidor.
    public func vinculo() -> VinculoDoAparelho? {
        guardado()?.vinculo
    }

    /// A cada abertura com sessão e a cada entrada (contrato: "chamar a cada abertura do app").
    /// O registro repetido da mesma conta mantém o `desde`; o de outra conta começa um vínculo novo.
    @discardableResult
    public func registrar(para contaID: UUID) async -> Registro {
        await naVez { await $0.registrarNaVez(para: contaID) } ?? .falhou(ErroDaApi(codigo: .desconhecido))
    }

    /// O FCM entregou o token, na abertura ou porque trocou. Com alguém dentro, o token novo é
    /// registrado na hora, e o antigo sai do servidor se der.
    @discardableResult
    public func receber(token: String) async -> Registro {
        await naVez { await $0.receberNaVez(token: token) } ?? .falhou(ErroDaApi(codigo: .desconhecido))
    }

    /// A saída pedida pela pessoa. `sair` recebe o token guardado e encerra a sessão; é ele quem
    /// chama `remover_dispositivo` antes do `signOut`. Depois, o aparelho não é de ninguém.
    public func encerrar(_ sair: @escaping @Sendable (_ tokenFCM: String?) async -> Void) async {
        await naVez { aparelho in
            await sair(await aparelho.guardado()?.token)
            await aparelho.soltar()
        }
    }

    /// A sessão acabou sem a pessoa pedir (401, conta excluída). Não há mais sessão para tirar o
    /// token do servidor; o que dá para fazer aqui é o aparelho deixar de ser da conta.
    public func desvincular() async {
        await naVez { await $0.soltar() }
    }

    // MARK: Dentro da fila

    private func naVez<Valor: Sendable>(_ operacao: @escaping @Sendable (AparelhoDePush) async -> Valor) async -> Valor? {
        try? await fila.executar { [self] in await operacao(self) }
    }

    private func registrarNaVez(para contaID: UUID) async -> Registro {
        contaAtiva = contaID
        guard let atual = guardado() else { return .semToken }
        do {
            _ = try await api.registrarDispositivo(tokenFCM: atual.token)
        } catch {
            return .falhou(error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido))
        }
        // O `desde` é o relógio deste aparelho depois da resposta, o mesmo relógio que data a
        // entrega de um push: o que chegou antes era de quem estava aqui antes.
        let vinculo = if let anterior = atual.vinculo, anterior.contaID == contaID {
            anterior
        } else {
            VinculoDoAparelho(contaID: contaID, desde: relogio.agora)
        }
        guardar(AparelhoGuardado(token: atual.token, vinculo: vinculo))
        return .registrado(vinculo)
    }

    private func receberNaVez(token: String) async -> Registro {
        let anterior = guardado()
        if anterior?.token != token {
            // O vínculo é do aparelho com a conta, e não do token: a troca de token não o desfaz.
            guardar(AparelhoGuardado(token: token, vinculo: anterior?.vinculo))
        }
        guard let contaAtiva else { return .semConta }
        if let anterior, anterior.token == token, let vinculo = anterior.vinculo, vinculo.contaID == contaAtiva {
            return .registrado(vinculo)
        }
        if let antigo = anterior?.token, antigo != token {
            // O token antigo morre no FCM de qualquer jeito, e o servidor o limpa sozinho quando o
            // envio falha; tirar agora só adianta a limpeza.
            try? await api.removerDispositivo(tokenFCM: antigo)
        }
        return await registrarNaVez(para: contaAtiva)
    }

    private func soltar() {
        contaAtiva = nil
        guard let atual = guardado(), atual.vinculo != nil else { return }
        guardar(AparelhoGuardado(token: atual.token, vinculo: nil))
    }

    private func guardado() -> AparelhoGuardado? {
        if !carregado {
            aparelho = armazenamento.ler()
            carregado = true
        }
        return aparelho
    }

    private func guardar(_ novo: AparelhoGuardado) {
        aparelho = novo
        carregado = true
        armazenamento.guardar(novo)
    }
}

/// O guardado só em memória: testes, prévias e o esquema Local, que não toca o Keychain.
public final class ArmazenamentoDoAparelhoEmMemoria: ArmazenamentoDoAparelho, @unchecked Sendable {
    private let trava = NSLock()
    private var aparelho: AparelhoGuardado?

    public init(_ aparelho: AparelhoGuardado? = nil) {
        self.aparelho = aparelho
    }

    public func ler() -> AparelhoGuardado? { trava.withLock { aparelho } }
    public func guardar(_ aparelho: AparelhoGuardado) { trava.withLock { self.aparelho = aparelho } }
}
