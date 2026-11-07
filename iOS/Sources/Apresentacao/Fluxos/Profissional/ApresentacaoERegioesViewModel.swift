import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class ApresentacaoERegioesViewModel {
    public static let limiteSobreMim = 600
    public static let limiteOndeTrabalhei = 400
    public static let limiteMaxCursos = 5
    public static let limiteCursoCaractere = 80

    private let api: any ApiCliente

    // Estados de fluxo
    public var carregando: Bool = false
    public var salvando: Bool = false
    public var sucesso: Bool = false
    public var erroGeral: String?

    // Erros específicos por campo
    public var erroSobreMim: String?
    public var erroOndeTrabalhei: String?
    public var erroCursos: String?
    public var erroRegioes: String?

    // Rascunho de apresentação
    public var sobreMim: String = "" {
        didSet {
            if erroSobreMim != nil { erroSobreMim = nil }
        }
    }

    public var ondeTrabalhei: String = "" {
        didSet {
            if erroOndeTrabalhei != nil { erroOndeTrabalhei = nil }
        }
    }

    public var experienciaFaixa: ExperienciaFaixa?

    public var cursos: [String] = [] {
        didSet {
            if erroCursos != nil { erroCursos = nil }
        }
    }

    public var novoCursoTexto: String = "" {
        didSet {
            if erroCursos != nil { erroCursos = nil }
        }
    }

    public var idiomasSelecionados: Set<Idioma> = []

    // Rascunho de regiões
    public var atendeTodoDF: Bool = false {
        didSet {
            if atendeTodoDF {
                regioesSelecionadas.removeAll()
            }
            if erroRegioes != nil { erroRegioes = nil }
        }
    }

    public var regioesSelecionadas: Set<Int> = [] {
        didSet {
            if erroRegioes != nil { erroRegioes = nil }
        }
    }

    public var regioesDisponiveis: [RegiaoAdministrativa] = []

    public init(api: any ApiCliente) {
        self.api = api
    }

    public func carregar() async {
        carregando = true
        defer { carregando = false }
        limparErros()

        do {
            async let regioesAsync = api.regioesAdministrativas()
            async let perfilAsync = api.meuPerfilDetalhado()

            let (regioes, perfil) = try await (regioesAsync, perfilAsync)
            self.regioesDisponiveis = regioes
            aplicarPerfil(perfil)
        } catch let erro as ErroDaApi {
            if erro.codigo == .naoEncontrado {
                if let regioes = try? await api.regioesAdministrativas() {
                    self.regioesDisponiveis = regioes
                }
            } else if erro.codigo == .semRede {
                erroGeral = TextosApresentacaoERegioes.erroSemRede
            } else {
                erroGeral = TextosApresentacaoERegioes.erroCarregar
            }
        } catch {
            erroGeral = TextosApresentacaoERegioes.erroCarregar
        }
    }

    public func aplicarPerfil(_ perfil: PerfilProfissionalDetalhado) {
        sobreMim = perfil.apresentacao ?? ""
        ondeTrabalhei = perfil.ondeTrabalhei ?? ""
        experienciaFaixa = perfil.experienciaFaixa
        cursos = perfil.cursos
        idiomasSelecionados = Set(perfil.idiomas)
        atendeTodoDF = perfil.atendeTodoDF
        regioesSelecionadas = Set(perfil.regioes.map(\.id))
    }

    public func adicionarCurso() {
        let limpo = novoCursoTexto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return }

        guard cursos.count < Self.limiteMaxCursos else {
            erroCursos = TextosApresentacaoERegioes.limiteCursosAtingido
            return
        }

        guard limpo.count <= Self.limiteCursoCaractere else {
            erroCursos = TextosApresentacaoERegioes.cursoMuitoLongo
            return
        }

        cursos.append(limpo)
        novoCursoTexto = ""
        erroCursos = nil
    }

    public func removerCurso(em indice: Int) {
        guard cursos.indices.contains(indice) else { return }
        cursos.remove(at: indice)
        erroCursos = nil
    }

    public func alternarIdioma(_ idioma: Idioma) {
        if idiomasSelecionados.contains(idioma) {
            idiomasSelecionados.remove(idioma)
        } else {
            idiomasSelecionados.insert(idioma)
        }
    }

    public func alternarRegiao(id: Int) {
        if atendeTodoDF {
            atendeTodoDF = false
        }
        if regioesSelecionadas.contains(id) {
            regioesSelecionadas.remove(id)
        } else {
            regioesSelecionadas.insert(id)
        }
    }

    public func limparErros() {
        erroGeral = nil
        erroSobreMim = nil
        erroOndeTrabalhei = nil
        erroCursos = nil
        erroRegioes = nil
    }

    @discardableResult
    public func salvar() async -> Bool {
        limparErros()

        if sobreMim.count > Self.limiteSobreMim {
            erroSobreMim = TextosApresentacaoERegioes.limiteSobreMimExcedido
            return false
        }

        if ondeTrabalhei.count > Self.limiteOndeTrabalhei {
            erroOndeTrabalhei = TextosApresentacaoERegioes.limiteOndeTrabalheiExcedido
            return false
        }

        if cursos.count > Self.limiteMaxCursos {
            erroCursos = TextosApresentacaoERegioes.limiteCursosAtingido
            return false
        }

        for curso in cursos {
            if curso.count > Self.limiteCursoCaractere {
                erroCursos = TextosApresentacaoERegioes.cursoMuitoLongo
                return false
            }
        }

        let cursoPendente = novoCursoTexto.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cursoPendente.isEmpty && cursos.count < Self.limiteMaxCursos && cursoPendente.count <= Self.limiteCursoCaractere {
            cursos.append(cursoPendente)
            novoCursoTexto = ""
        }

        salvando = true
        defer { salvando = false }

        let sobre = sobreMim.trimmingCharacters(in: .whitespacesAndNewlines)
        let onde = ondeTrabalhei.trimmingCharacters(in: .whitespacesAndNewlines)

        let payloadApresentacao = ApresentacaoDoProfissional(
            apresentacao: sobre.isEmpty ? nil : sobre,
            ondeTrabalhei: onde.isEmpty ? nil : onde,
            experienciaFaixa: experienciaFaixa,
            cursos: cursos,
            idiomas: Array(idiomasSelecionados)
        )

        let payloadRegioes = RegioesAtendidas(
            regioes: atendeTodoDF ? [] : Array(regioesSelecionadas),
            atendeTodoDF: atendeTodoDF
        )

        do {
            _ = try await api.atualizarApresentacaoProfissional(payloadApresentacao)
            _ = try await api.definirRegioesAtendidas(payloadRegioes)
            sucesso = true
            return true
        } catch let erro as ErroDaApi {
            tratarErroDaApi(erro)
            return false
        } catch {
            erroGeral = TextosApresentacaoERegioes.erroSalvar
            return false
        }
    }

    private func tratarErroDaApi(_ erro: ErroDaApi) {
        switch erro.codigo {
        case .campoInvalido:
            let detalhe = erro.detalhes?.lowercased()
            if detalhe == "apresentacao" || detalhe == "sobre" || detalhe == "sobre_mim" {
                erroSobreMim = TextosApresentacaoERegioes.erroAntiContato
            } else if detalhe == "onde_trabalhei" {
                erroOndeTrabalhei = TextosApresentacaoERegioes.erroAntiContato
            } else if detalhe == "cursos" {
                erroCursos = TextosApresentacaoERegioes.erroAntiContato
            } else if detalhe == "regioes" {
                erroRegioes = TextosApresentacaoERegioes.erroRegioesInvalidas
            } else {
                erroSobreMim = TextosApresentacaoERegioes.erroAntiContato
            }
        case .semRede:
            erroGeral = TextosApresentacaoERegioes.erroSemRede
        default:
            erroGeral = TextosApresentacaoERegioes.erroSalvar
        }
    }
}
