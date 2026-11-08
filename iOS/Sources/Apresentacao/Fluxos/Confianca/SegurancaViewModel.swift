import Foundation
import FrilaDominio
import Observation

/// Vive no fluxo da conta, nunca em singleton ou armazenamento persistente. Também filtra
/// respostas que estavam em voo quando o bloqueio foi confirmado.
@MainActor @Observable
public final class BloqueiosDaSessao {
    public private(set) var alvos: Set<Alvo> = []
    public init() {}
    public func registrar(_ alvo: Alvo) { alvos.insert(alvo) }
    public func contem(_ perfil: PerfilPublico) -> Bool { alvos.contains(Alvo(perfil)) }
    public func contem(_ alvo: Alvo) -> Bool { alvos.contains(alvo) }
    public func filtrar(_ vagas: [VagaNaLista]) -> [VagaNaLista] {
        vagas.filter { !contem($0.estabelecimento) }
    }
}

@MainActor @Observable
public final class SegurancaViewModel {
    public var motivo: MotivoDenuncia = .assedio
    public var relato = ""
    /// CD-RF12: a denúncia é sobre a foto de perfil que a tela mostrou (`midia_id`), e não sobre o perfil.
    public var sobreAFoto = false
    public private(set) var enviando = false
    public private(set) var bloqueando = false
    public private(set) var protocolo: Protocolo?
    public private(set) var erroDenuncia: String?
    public private(set) var erroBloqueio: String?
    public var bloqueado: Bool { bloqueios.alvos.contains(alvo) }
    private let alvo: Alvo
    private let turnoID: UUID?
    /// O `foto_id` do perfil, quando o servidor mandou a foto (recurso ligado e vínculo de leitura).
    private let fotoID: UUID?
    private let api: any ApiCliente
    private let bloqueios: BloqueiosDaSessao
    private var tentativa: Denuncia?

    public init(perfil: PerfilPublico, turnoID: UUID? = nil, api: any ApiCliente, bloqueios: BloqueiosDaSessao) {
        alvo = Alvo(perfil)
        self.turnoID = turnoID
        fotoID = perfil.fotoID
        self.api = api
        self.bloqueios = bloqueios
    }

    /// Só há foto para denunciar quando o perfil a trouxe.
    public var podeDenunciarFoto: Bool { fotoID != nil }

    public var relatoValido: Bool { relato.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 }

    public func denunciar() async {
        guard !enviando, protocolo == nil else { return }
        guard relatoValido else { erroDenuncia = TextosDaSeguranca.relatoMinimo; return }
        let texto = relato.trimmingCharacters(in: .whitespacesAndNewlines)
        // Repetir o mesmo envio depois de perder a resposta conserva a chave. Editar o conteúdo
        // inicia outra denúncia: nunca reutiliza uma chave para um corpo diferente.
        let midiaID = sobreAFoto ? fotoID : nil
        if tentativa?.motivo != motivo || tentativa?.relato != texto || tentativa?.midiaID != midiaID {
            tentativa = Denuncia(alvo: alvo, turnoID: turnoID, motivo: motivo, relato: texto, chave: UUID(), midiaID: midiaID)
        }
        guard let tentativa else { return }
        enviando = true
        erroDenuncia = nil
        defer { enviando = false }
        do { protocolo = try await api.denunciar(tentativa) }
        catch { erroDenuncia = mensagem(error) }
    }

    func bloquear() async {
        guard !bloqueando, !bloqueios.alvos.contains(alvo) else { return }
        bloqueando = true
        erroBloqueio = nil
        defer { bloqueando = false }
        do {
            _ = try await api.bloquear(alvo)
            bloqueios.registrar(alvo)
        } catch { erroBloqueio = mensagem(error) }
    }

    private func mensagem(_ erro: Error) -> String {
        guard let erro = erro as? ErroDaApi else { return TextosDaSeguranca.erro }
        switch erro.codigo {
        case .semRede: return TextosDaSeguranca.semRede
        case .campoObrigatorio, .campoInvalido:
            return erro.detalhes == "relato" ? TextosDaSeguranca.relatoMinimo : TextosDaSeguranca.dadosInvalidos
        case .naoEncontrado: return TextosDaSeguranca.indisponivel
        default: return TextosDaSeguranca.erro
        }
    }
}

@MainActor @Observable
final class PerfilPublicoViewModel {
    enum Estado: Equatable {
        case carregando, carregado(PerfilPublico), indisponivel, falha(String)
    }
    private(set) var estado: Estado = .carregando
    private let id: UUID
    private let api: any ApiCliente
    init(id: UUID, api: any ApiCliente) { self.id = id; self.api = api }
    func carregar() async {
        estado = .carregando
        do { estado = .carregado(try await api.perfilPublico(id: id)) }
        catch let erro as ErroDaApi where erro.codigo == .naoEncontrado { estado = .indisponivel }
        catch let erro as ErroDaApi where erro.codigo == .semRede { estado = .falha(TextosDaSeguranca.semRede) }
        catch { estado = .falha(TextosDaSeguranca.erro) }
    }
}
