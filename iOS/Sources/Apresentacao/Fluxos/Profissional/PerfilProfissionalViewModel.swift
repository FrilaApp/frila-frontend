import Foundation
import FrilaDominio
import MapKit
import Observation

@MainActor @Observable
public final class PerfilProfissionalViewModel {
    public enum Modo: Equatable, Sendable {
        case criacao
        case edicao
    }

    public private(set) var modo: Modo
    public private(set) var funcoesDisponiveis: [Funcao] = []
    public var funcoesSelecionadas: Set<UUID> = []
    public var enderecoTexto: String = ""
    public private(set) var pontoBase: Coordenada?
    public private(set) var descricaoPontoBase: String?
    public private(set) var sugestoes: [MKMapItem] = []
    public private(set) var carregandoBusca: Bool = false
    public private(set) var disponibilidades: [JanelaDeDisponibilidade] = []
    public private(set) var carregando: Bool = false
    public private(set) var salvando: Bool = false
    public var mensagemDeErro: String?
    public private(set) var perfilSalvo: PerfilProfissional?
    public private(set) var sucesso: Bool = false

    private let api: any ApiCliente
    private let buscarPontoBase: (@MainActor (String) async throws -> [MKMapItem])?

    public init(
        api: any ApiCliente,
        modo: Modo = .criacao,
        buscarPontoBase: (@MainActor (String) async throws -> [MKMapItem])? = nil
    ) {
        self.api = api
        self.modo = modo
        self.buscarPontoBase = buscarPontoBase
    }

    public func carregar() async {
        carregando = true
        defer { carregando = false }
        mensagemDeErro = nil

        do {
            funcoesDisponiveis = try await api.funcoes()
            if modo == .edicao {
                let perfil = try await api.meuPerfilProfissional()
                aplicarPerfil(perfil)
            }
        } catch let erro as ErroDaApi {
            mensagemDeErro = MensagemDoErroAPI.texto(erro)
        } catch {
            mensagemDeErro = TextosDoProfissional.Perfil.erroCarregar
        }
    }

    public func carregarMeuPerfil() async {
        modo = .edicao
        await carregar()
    }

    public func alternarFuncao(_ id: UUID) {
        if funcoesSelecionadas.contains(id) {
            funcoesSelecionadas.remove(id)
        } else {
            funcoesSelecionadas.insert(id)
        }
        mensagemDeErro = nil
    }

    public func definirPontoBase(_ coordenada: Coordenada, nome: String? = nil) {
        pontoBase = coordenada
        if let nome {
            enderecoTexto = nome
            descricaoPontoBase = nome
        } else {
            descricaoPontoBase = TextosDoProfissional.Perfil.pontoBaseSalvo
        }
        sugestoes = []
        mensagemDeErro = nil
    }

    public func buscarEndereco() async {
        let texto = enderecoTexto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else {
            sugestoes = []
            return
        }
        carregandoBusca = true
        defer { carregandoBusca = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = texto
        do {
            if let buscarPontoBase {
                sugestoes = try await buscarPontoBase(texto)
            } else {
                let response = try await MKLocalSearch(request: request).start()
                sugestoes = response.mapItems
            }
        } catch {
            sugestoes = []
        }
    }

    public func selecionarSugestao(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        do {
            pontoBase = try Coordenada(latitude: coord.latitude, longitude: coord.longitude)
            let titulo = item.name.map { "\($0), \(item.placemark.title ?? "")" } ?? (item.placemark.title ?? enderecoTexto)
            enderecoTexto = titulo
            descricaoPontoBase = titulo
            sugestoes = []
            mensagemDeErro = nil
        } catch {
            mensagemDeErro = TextosDoProfissional.Perfil.erroCoordenadasInvalidas
        }
    }

    public func adicionarJanela(diaDaSemana: Int, inicio: HoraDoDia, fim: HoraDoDia) {
        guard (0...6).contains(diaDaSemana) else { return }
        guard inicio != fim else {
            mensagemDeErro = TextosDoProfissional.Perfil.erroJanelaDuracaoZero
            return
        }
        let nova = JanelaDeDisponibilidade(diaDaSemana: diaDaSemana, inicio: inicio, fim: fim)
        if !disponibilidades.contains(nova) {
            disponibilidades.append(nova)
            disponibilidades.sort {
                if $0.diaDaSemana != $1.diaDaSemana {
                    return $0.diaDaSemana < $1.diaDaSemana
                }
                return $0.inicio < $1.inicio
            }
        }
        mensagemDeErro = nil
    }

    public func removerJanela(em indices: IndexSet) {
        disponibilidades.remove(atOffsets: indices)
    }

    public func removerJanela(_ janela: JanelaDeDisponibilidade) {
        disponibilidades.removeAll { $0 == janela }
    }

    public func formatarJanela(_ janela: JanelaDeDisponibilidade) -> (dia: String, horario: String) {
        let dia = Self.nomeDoDia(janela.diaDaSemana)
        let inicio = janela.inicio.contrato
        let fim = janela.fim.contrato
        let base = String(localized: "\(inicio) às \(fim)", bundle: bundleApresentacao)
        let horario: String
        if janela.atravessaMeiaNoite {
            let sufixo = String(localized: "(dia seguinte)", bundle: bundleApresentacao)
            horario = "\(base) \(sufixo)"
        } else {
            horario = base
        }
        return (dia, horario)
    }

    public func descricaoJanela(_ janela: JanelaDeDisponibilidade) -> String {
        let (dia, horario) = formatarJanela(janela)
        return "\(dia): \(horario)"
    }

    public static func nomeDoDia(_ diaDaSemana: Int) -> String {
        switch diaDaSemana {
        case 0: return TextosDoProfissional.Perfil.domingo
        case 1: return TextosDoProfissional.Perfil.segunda
        case 2: return TextosDoProfissional.Perfil.terca
        case 3: return TextosDoProfissional.Perfil.quarta
        case 4: return TextosDoProfissional.Perfil.quinta
        case 5: return TextosDoProfissional.Perfil.sexta
        case 6: return TextosDoProfissional.Perfil.sabado
        default: return ""
        }
    }

    public func salvar() async -> Bool {
        guard !salvando else { return false }

        guard !funcoesSelecionadas.isEmpty else {
            mensagemDeErro = TextosDoProfissional.Perfil.erroSemFuncao
            return false
        }

        guard let pontoBase = pontoBase else {
            mensagemDeErro = TextosDoProfissional.Perfil.erroSemPontoBase
            return false
        }

        salvando = true
        defer { salvando = false }
        mensagemDeErro = nil

        do {
            switch modo {
            case .criacao:
                let dados = DadosPerfilProfissional(
                    funcoes: Array(funcoesSelecionadas),
                    pontoBase: pontoBase,
                    disponibilidades: disponibilidades
                )
                let perfil: PerfilProfissional
                do {
                    perfil = try await api.criarPerfilProfissional(dados)
                } catch let erro as ErroDaApi where erro.codigo == .perfilJaExiste {
                    // O envio anterior gravou e só a resposta se perdeu. O contrato responde 409 em
                    // vez de sobrescrever, e o perfil que vale é o gravado.
                    perfil = try await api.meuPerfilProfissional()
                }
                self.perfilSalvo = perfil
                self.modo = .edicao
                self.sucesso = true
                return true

            case .edicao:
                let alteracao = AlteracaoPerfilProfissional(
                    funcoes: Array(funcoesSelecionadas),
                    pontoBase: pontoBase,
                    disponibilidades: disponibilidades
                )
                let perfil = try await api.atualizarPerfilProfissional(alteracao)
                self.perfilSalvo = perfil
                self.sucesso = true
                return true
            }
        } catch let erro as ErroDaApi {
            mensagemDeErro = MensagemDoErroAPI.texto(erro)
            return false
        } catch {
            mensagemDeErro = TextosDoProfissional.Perfil.erroSalvar
            return false
        }
    }

    private func aplicarPerfil(_ perfil: PerfilProfissional) {
        self.funcoesSelecionadas = Set(perfil.funcoes.map(\.id))
        self.pontoBase = perfil.pontoBase
        self.disponibilidades = perfil.disponibilidades
        self.enderecoTexto = ""
        self.descricaoPontoBase = TextosDoProfissional.Perfil.pontoBaseSalvo
    }
}
