import Foundation

public enum Plataforma: String, Codable, Sendable {
    case ios, android, web
}

/// O que `registrar_dispositivo` devolve. O token não volta: quem o tem é o aparelho.
public struct Dispositivo: Codable, Equatable, Sendable {
    public let plataforma: Plataforma
    public let atualizadoEm: Date

    public init(plataforma: Plataforma, atualizadoEm: Date) {
        self.plataforma = plataforma
        self.atualizadoEm = atualizadoEm
    }
}

/// A conta a que este aparelho está entregue para o push, e desde quando. Começa quando o servidor
/// confirma o registro do token para a conta e acaba quando a sessão acaba. O payload do push não
/// diz para quem ele é (RN15): é por aqui que o app sabe de quem é o aviso que chegou.
///
/// Na troca de conta, `desde` fica `carenciaNaTrocaDeConta` depois da confirmação do servidor: o
/// aviso que ele mandou para a conta anterior e ainda estava a caminho chega nesse intervalo.
public struct VinculoDoAparelho: Codable, Equatable, Sendable {
    /// Quanto tempo depois da troca de conta um aviso ainda é tratado como da conta anterior.
    /// Inferência: não há medição da latência do FCM e do APNs; um minuto cobre a entrega que já
    /// estava a caminho, e não a que o APNs guardou por mais tempo.
    public static let carenciaNaTrocaDeConta: TimeInterval = 60

    public let contaID: UUID
    public let desde: Date

    public init(contaID: UUID, desde: Date) {
        self.contaID = contaID
        self.desde = desde
    }
}

/// O que o aparelho guarda do push: o token do FCM, que é do aparelho e não da pessoa, o vínculo
/// com a conta que está nele e, sem vínculo, a conta de quem ele era por último.
public struct AparelhoGuardado: Codable, Equatable, Sendable {
    public var token: String
    public var vinculo: VinculoDoAparelho?
    /// A conta do último vínculo desfeito. O servidor pode ainda ter o token com ela (saída sem
    /// rede): é por aqui que a entrada seguinte sabe que houve troca de conta.
    public var contaAnterior: UUID?

    public init(token: String, vinculo: VinculoDoAparelho? = nil, contaAnterior: UUID? = nil) {
        self.token = token
        self.vinculo = vinculo
        self.contaAnterior = contaAnterior
    }
}

/// Onde o `AparelhoGuardado` fica entre uma abertura e outra. Falha ao gravar ou ao ler não derruba
/// nada: sem o guardado, o token chega de novo do FCM e o registro se repete na abertura seguinte.
public protocol ArmazenamentoDoAparelho: Sendable {
    func ler() -> AparelhoGuardado?
    func guardar(_ aparelho: AparelhoGuardado)
}
