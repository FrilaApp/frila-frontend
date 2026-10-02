import Foundation
@testable import FrilaApresentacao
import FrilaDominio
import Testing

@Suite("Catálogo de strings de interface (pt-BR)")
struct CatalogoStringsTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func carregarCatalogo() throws -> (chaves: Set<String>, traducoes: [String: String]) {
        let url = raiz.appending(path: "Resources/Localizable.xcstrings")
        let dados = try Data(contentsOf: url)

        struct CatalogoJSON: Decodable {
            struct Entrada: Decodable {
                struct Localizacao: Decodable {
                    struct Unidade: Decodable {
                        let state: String?
                        let value: String?
                    }
                    struct Variacoes: Decodable {
                        struct Plural: Decodable {
                            struct Regra: Decodable {
                                let stringUnit: Unidade?
                            }
                            let one: Regra?
                            let other: Regra?
                            let zero: Regra?
                        }
                        let plural: Plural?
                    }
                    let stringUnit: Unidade?
                    let variations: Variacoes?
                }
                struct Localizacoes: Decodable {
                    let ptBR: Localizacao?

                    enum CodingKeys: String, CodingKey {
                        case ptBR = "pt-BR"
                    }
                }
                let localizations: Localizacoes?
            }
            let sourceLanguage: String
            let strings: [String: Entrada]
        }

        let decodificado = try JSONDecoder().decode(CatalogoJSON.self, from: dados)
        #expect(decodificado.sourceLanguage == "pt-BR", "o idioma de origem deve ser pt-BR")

        var traducoes: [String: String] = [:]
        for (chave, entrada) in decodificado.strings {
            if let valor = entrada.localizations?.ptBR?.stringUnit?.value {
                traducoes[chave] = valor
            } else if let valorOther = entrada.localizations?.ptBR?.variations?.plural?.other?.stringUnit?.value {
                traducoes[chave] = valorOther
            }
        }
        return (Set(decodificado.strings.keys), traducoes)
    }

    @Test("Catálogo Localizable.xcstrings possui idioma pt-BR e todas as chaves têm tradução válida")
    func catalogoValido() throws {
        let (chaves, traducoes) = try Self.carregarCatalogo()
        #expect(chaves.count >= 90, "esperava pelo menos 90 chaves no catálogo, encontrou \(chaves.count)")

        var chavesSemTraducao: [String] = []
        for chave in chaves {
            if let traducao = traducoes[chave], !traducao.isEmpty {
                continue
            }
            chavesSemTraducao.append(chave)
        }
        #expect(chavesSemTraducao.isEmpty, "chaves sem tradução pt-BR: \(chavesSemTraducao)")
    }

    @Test("Todas as constantes de TextosDoProfissional existem no catálogo pt-BR")
    func textosDoProfissional() throws {
        let (chaves, _) = try Self.carregarCatalogo()

        let stringsDaLista = [
            TextosDoProfissional.Lista.titulo,
            TextosDoProfissional.Lista.qualquerFuncao,
            TextosDoProfissional.Lista.qualquerData,
            TextosDoProfissional.Lista.hoje,
            TextosDoProfissional.Lista.amanha,
            TextosDoProfissional.Lista.qualquerDistancia,
            TextosDoProfissional.Lista.vazioTitulo,
            TextosDoProfissional.Lista.vazioMensagem,
            TextosDoProfissional.Lista.erroMensagem,
            TextosDoProfissional.Lista.semPontoDeReferencia,
            TextosDoProfissional.Lista.perfilIncompativel,
            TextosDoProfissional.Lista.semConexaoMensagem,
        ]

        let stringsDoDetalhe = [
            TextosDoProfissional.Detalhe.titulo,
            TextosDoProfissional.Detalhe.quando,
            TextosDoProfissional.Detalhe.horario,
            TextosDoProfissional.Detalhe.valor,
            TextosDoProfissional.Detalhe.posicoes,
            TextosDoProfissional.Detalhe.valorIntegral,
            TextosDoProfissional.Detalhe.incluso,
            TextosDoProfissional.Detalhe.quemRecebe,
            TextosDoProfissional.Detalhe.traje,
            TextosDoProfissional.Detalhe.urgencia,
            TextosDoProfissional.Detalhe.urgenciaDetalhe,
            TextosDoProfissional.Detalhe.selecao,
            TextosDoProfissional.Detalhe.selecaoDetalhe,
            TextosDoProfissional.Detalhe.candidatar,
            TextosDoProfissional.Detalhe.denunciar,
            TextosDoProfissional.Detalhe.bloquear,
            TextosDoProfissional.Detalhe.erroMensagem,
            TextosDoProfissional.Detalhe.naoEncontrada,
        ]

        let stringsDaCandidatura = [
            TextosDoProfissional.Candidatura.enviando,
            TextosDoProfissional.Candidatura.voltarParaLista,
            TextosDoProfissional.Candidatura.confirmadoTitulo,
            TextosDoProfissional.Candidatura.contato,
            TextosDoProfissional.Candidatura.contatoLiberado,
            TextosDoProfissional.Candidatura.abrirWhatsApp,
            TextosDoProfissional.Candidatura.preenchidaTitulo,
            TextosDoProfissional.Candidatura.preenchidaMensagem,
            TextosDoProfissional.Candidatura.encerradaTitulo,
            TextosDoProfissional.Candidatura.encerradaMensagem,
            TextosDoProfissional.Candidatura.sobrepostoTitulo,
            TextosDoProfissional.Candidatura.sobrepostoMensagem,
            TextosDoProfissional.Candidatura.funcaoTitulo,
            TextosDoProfissional.Candidatura.funcaoMensagem,
            TextosDoProfissional.Candidatura.inelegivelTitulo,
            TextosDoProfissional.Candidatura.inelegivelMensagem,
            TextosDoProfissional.Candidatura.suspensaTitulo,
            TextosDoProfissional.Candidatura.suspensaMensagem,
            TextosDoProfissional.Candidatura.contestar,
            TextosDoProfissional.Candidatura.contestarEmBreve,
            TextosDoProfissional.Candidatura.naoEncontrada,
            TextosDoProfissional.Candidatura.falha,
            TextosDoProfissional.Candidatura.semConexao,
            TextosDoProfissional.Candidatura.outraEmAndamento,
        ]

        let stringsDosTurnos = [
            TextosDoProfissional.Turnos.tituloMeusTurnos,
            TextosDoProfissional.Turnos.tituloMeuTurno,
            TextosDoProfissional.Turnos.confirmadoTitulo,
            TextosDoProfissional.Turnos.avisoCache,
            TextosDoProfissional.Turnos.vazioTitulo,
            TextosDoProfissional.Turnos.vazioMensagem,
            TextosDoProfissional.Turnos.erroAoCarregar,
            TextosDoProfissional.Turnos.contatoEncerrado,
            TextosDoProfissional.Turnos.lembretesEVisibilidade,
            TextosDoProfissional.Turnos.verNoMapas,
            TextosDoProfissional.Turnos.quemRecebe,
        ]

        let stringsDoPerfil = [
            TextosDoProfissional.Perfil.titulo,
            TextosDoProfissional.Perfil.cabecalho,
            TextosDoProfissional.Perfil.secaoFuncoes,
            TextosDoProfissional.Perfil.pontoBase,
            TextosDoProfissional.Perfil.pontoBaseSalvo,
            TextosDoProfissional.Perfil.dicaPontoBase,
            TextosDoProfissional.Perfil.buscarPontoBase,
            TextosDoProfissional.Perfil.secaoHorarios,
            TextosDoProfissional.Perfil.adicionarHorario,
            TextosDoProfissional.Perfil.diaSeguinte,
            TextosDoProfissional.Perfil.avisoFixo,
            TextosDoProfissional.Perfil.salvarCriacao,
            TextosDoProfissional.Perfil.salvarEdicao,
            TextosDoProfissional.Perfil.erroSemFuncao,
            TextosDoProfissional.Perfil.erroSemPontoBase,
            TextosDoProfissional.Perfil.erroJanelaDuracaoZero,
            TextosDoProfissional.Perfil.nenhumHorario,
            TextosDoProfissional.Perfil.domingo,
            TextosDoProfissional.Perfil.segunda,
            TextosDoProfissional.Perfil.terca,
            TextosDoProfissional.Perfil.quarta,
            TextosDoProfissional.Perfil.quinta,
            TextosDoProfissional.Perfil.sexta,
            TextosDoProfissional.Perfil.sabado,
            TextosDoProfissional.Perfil.diaSemana,
            TextosDoProfissional.Perfil.inicio,
            TextosDoProfissional.Perfil.fim,
            TextosDoProfissional.Perfil.adicionar,
            TextosDoProfissional.Perfil.remover,
            TextosDoProfissional.Perfil.erroHorarioInvalido,
            TextosDoProfissional.Perfil.erroCoordenadasInvalidas,
            TextosDoProfissional.Perfil.erroCarregar,
            TextosDoProfissional.Perfil.erroSalvar,
            TextosDoProfissional.Perfil.perfilSalvoComSucesso,
            TextosDoProfissional.Perfil.buscar,
        ]

        let stringsDaAvaliacao = [
            TextosDoProfissional.Avaliacao.titulo,
            TextosDoProfissional.Avaliacao.perguntaProfissional,
            TextosDoProfissional.Avaliacao.perguntaContratante,
            TextosDoProfissional.Avaliacao.explicacao,
            TextosDoProfissional.Avaliacao.botaoEnviar,
            TextosDoProfissional.Avaliacao.avaliadoSucesso,
            TextosDoProfissional.Avaliacao.avaliadoOffline,
            TextosDoProfissional.Avaliacao.respostaRegistrada,
            TextosDoProfissional.Avaliacao.suaResposta,
            TextosDoProfissional.Avaliacao.erroIndisponivel,
            TextosDoProfissional.Avaliacao.erroJaRegistrada,
            TextosDoProfissional.Avaliacao.erroSemRede,
            TextosDoProfissional.Avaliacao.erroGenerico,
            TextosDoProfissional.Avaliacao.erroSelecioneResposta,
            TextosDoProfissional.Avaliacao.cartaoTitulo,
            TextosDoProfissional.Avaliacao.cartaoChamada,
            TextosDoProfissional.Avaliacao.botaoAvaliar,
            TextosDoProfissional.Avaliacao.botaoVerAvaliacao,
            TextosDoProfissional.Avaliacao.statusAvaliado,
            TextosDoProfissional.Avaliacao.statusResposta(true),
            TextosDoProfissional.Avaliacao.statusResposta(false),
        ]

        let todasConstantes = stringsDaLista + stringsDoDetalhe + stringsDaCandidatura + stringsDosTurnos + stringsDoPerfil + stringsDaAvaliacao + [
            TextosDoProfissional.simNao(true),
            TextosDoProfissional.simNao(false),
            "Sem histórico",
        ]

        var faltantes: [String] = []
        for texto in todasConstantes {
            if !chaves.contains(texto) {
                faltantes.append(texto)
            }
        }
        #expect(faltantes.isEmpty, "constantes de TextosDoProfissional fora do catálogo: \(faltantes)")

        // Padrões com interpolação
        let padroesInterpolados = [
            "Até %lld km",
            "Ao confirmar, seu telefone e WhatsApp serão mostrados ao %@ para combinar o turno.",
            "Trabalhariam lá de novo: %lld de %lld",
            "Remover horário de %@",
            "%@ às %@",
            "Olá! Sou o profissional do turno de %@ em %@ no %@.",
        ]
        for padrao in padroesInterpolados {
            #expect(chaves.contains(padrao), "padrão interpolado fora do catálogo: \(padrao)")
        }
    }

    @Test("Todas as mensagens de erro de API (MensagemDoErroAPI) existem no catálogo pt-BR")
    func errosAPIEstaoNoCatalogo() throws {
        let (chaves, _) = try Self.carregarCatalogo()

        let codigos: [CodigoErroAPI] = [
            .posicaoJaPreenchida,
            .vagaEncerrada,
            .checkinPendente,
            .checkinJaConfirmado,
            .posicaoNaoCancelavel,
            .semRede,
            .naoAutenticado,
            .semPermissao,
            .perfilIncompativel,
            .limiteExcedido,
            .avaliacaoIndisponivel,
            .avaliacaoJaRegistrada,
            .menorDeIdade,
            .contaExistente,
            .desconhecido,
        ]

        var faltantes: [String] = []
        for codigo in codigos {
            let msg = MensagemDoErroAPI.texto(ErroDaApi(codigo: codigo))
            if !chaves.contains(msg) {
                faltantes.append("\(codigo): \(msg)")
            }
        }
        #expect(faltantes.isEmpty, "mensagens de erro da API fora do catálogo: \(faltantes)")
    }

    @Test("Literais de interface do app de Release estão no catálogo pt-BR")
    func literaisDeInterfaceEstaoNoCatalogo() throws {
        let (chaves, _) = try Self.carregarCatalogo()

        let literaisEsperados = [
            "Carregando",
            "Carregando…",
            "Código de acesso",
            "Digite os seis números enviados para seu e-mail",
            "%lld vagas abertas",
            "Vaga de %@",
            "Refeição",
            "Transporte",
            "Sim",
            "Não",
            "Chamaria de novo?",
            "Algo deu errado",
            "Tentar novamente",
            "Sem conexão. Mostrando os dados salvos neste aparelho.",
            "Atualize o Frila para continuar.",
            "Atualização necessária",
            "Atualizar agora",
            "Abre o detalhe da vaga",
            "filtro ativo",
            "%lld aberta(s) de %lld",
            "Refeição: %@",
            "Transporte: %@",
            "Material próprio: %@",
            "Frila",
            "Turnos avulsos no DF, perto de você.",
            "E-mail",
            "voce@exemplo.com",
            "Sem senha e sem SMS: você entra com um código enviado ao seu e-mail.",
            "Receber código",
            "Ao continuar, você aceita os Termos de Uso e a Política de Privacidade.",
            "Entrar",
            "Voltar",
            "Digite o código",
            "Enviamos um código de 6 dígitos para %@. Ele vale por pouco tempo.",
            "Reenviar código",
            "Não foi possível reenviar o código. Tente novamente.",
            "Quem já tem conta entra do mesmo jeito. Cada e-mail é uma conta.",
            "Cadastro",
            "Como você vai usar o Frila?",
            "Quero trabalhar em turnos",
            "Perfil de profissional: receba vagas perto de você e candidate-se sem formulário.",
            "Quero contratar para o meu negócio",
            "Perfil de contratante: publique turnos e acompanhe quem vai trabalhar.",
            "Nome",
            "Como você quer ser chamado",
            "Telefone com WhatsApp",
            "(61) 9 0000-0000",
            "A outra parte só vê o seu número depois que o turno é confirmado.",
            "Data de nascimento",
            "dd/mm/aaaa",
            "Tenho 18 anos ou mais",
            "Li e aceito os Termos de uso e a Política de privacidade",
            "Funções e horários",
            "Início do contratante",
            "Abre o endereço no Apple Maps",
            "Abre a conversa no WhatsApp com mensagem pré-formatada",
            "Abre o detalhe do turno",
            "Minhas vagas",
            "Em alerta",
            "Hoje",
            "Próximas",
            "Encerradas",
            "Suas vagas aparecem aqui",
            "Publique sua primeira vaga para acompanhar posições abertas, confirmações e alertas.",
            "Não encontramos o estabelecimento cadastrado.",
            "Não foi possível carregar suas vagas. Tente novamente.",
            "Tentar novamente",
            "Atualizar vagas",
            "%d posições",
            "%d de %d confirmadas",
            "Posição aberta",
            "Começa em %@",
            "%d h %d min",
            "%d min",
            "Menos de um minuto para começar",
            "Ver posições e confirmações",
            "Detalhe da vaga",
            "Posições",
            "Profissionais confirmados",
            "Ver perfil público",
            "Perfil público",
            "Sem histórico",
            "Ver contato liberado",
            "O prazo para ver este contato terminou.",
            "Não foi possível carregar o contato. Tente novamente.",
            "Ligar",
            "WhatsApp",
            "%@ – %@",
            "Região Administrativa",
            "A Região Administrativa do DF onde o estabelecimento fica. Ex.: Plano Piloto, Águas Claras, Taguatinga.",
            "Ainda não há turnos considerados.",
            "Meu perfil",
            "Perfil do estabelecimento",
            "Respondemos em até 5 dias úteis.",
            "Você recebe notificação de vagas da sua função, perto de você, quando o turno inteiro cabe nos horários em que marcou disponibilidade. Todas as vagas do DF aparecem na lista.",
            "Compareceu a %lld de %lld turno",
            "Compareceu a %lld de %lld turnos",
            "Termos de uso",
            "Política de privacidade",
            "Disponível no cartão #219",
            "Disponível no cartão #50",
            "Endereço de suporte pendente",
            "Link pendente",
            "%lld horários cadastrados",
        ]

        var faltantes: [String] = []
        for literal in literaisEsperados {
            if !chaves.contains(literal) {
                faltantes.append(literal)
            }
        }
        #expect(faltantes.isEmpty, "literais de interface fora do catálogo: \(faltantes)")
    }

    @Test("Variação de plural para '%lld vagas abertas' está definida no catálogo pt-BR com one e other")
    func pluralVagasAbertas() throws {
        let url = Self.raiz.appending(path: "Resources/Localizable.xcstrings")
        let dados = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any]
        let strings = json?["strings"] as? [String: Any]
        let entrada = strings?["%lld vagas abertas"] as? [String: Any]
        let localizations = entrada?["localizations"] as? [String: Any]
        let ptBR = localizations?["pt-BR"] as? [String: Any]
        let variations = ptBR?["variations"] as? [String: Any]
        let plural = variations?["plural"] as? [String: Any]

        let one = plural?["one"] as? [String: Any]
        let oneUnit = one?["stringUnit"] as? [String: Any]
        let oneValue = oneUnit?["value"] as? String

        let other = plural?["other"] as? [String: Any]
        let otherUnit = other?["stringUnit"] as? [String: Any]
        let otherValue = otherUnit?["value"] as? String

        #expect(oneValue == "%lld vaga aberta")
        #expect(otherValue == "%lld vagas abertas")
    }

    @Test("Chave com variação de plural resolve singular e plural corretamente no bundle da Apresentação")
    func pluralNoBundleApresentacao() {
        let singular = String(localized: "\(1) vagas abertas", bundle: bundleApresentacao)
        let plural = String(localized: "\(2) vagas abertas", bundle: bundleApresentacao)

        #expect(singular == "1 vaga aberta")
        #expect(plural == "2 vagas abertas")
    }

    @Test("Cartão de vaga formata variação de plural corretamente no singular e no plural")
    func pluralNoCartaoVaga() {
        let inicio = Date.now.addingTimeInterval(86_400)
        guard let periodo = try? Periodo(inicio: inicio, fim: inicio.addingTimeInterval(14_400)) else {
            Issue.record("Período de teste inválido")
            return
        }
        let reputacao = Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20, turnosRealizados: 21)

        let vagaUmaPosicao = VagaNaLista(
            id: UUID(),
            funcao: Funcao(id: UUID(), nome: "Garçom", categoria: "Salão"),
            estabelecimento: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô Ipê", reputacao: reputacao),
            periodo: periodo,
            local: "CLS 405, Asa Sul, Brasília - DF",
            regiaoAdministrativa: "Plano Piloto",
            distanciaKm: 2.4,
            valor: Dinheiro(centavos: 12000),
            posicoesAbertas: 1,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            modo: .urgencia
        )

        let vagaDuasPosicoes = VagaNaLista(
            id: UUID(),
            funcao: Funcao(id: UUID(), nome: "Garçom", categoria: "Salão"),
            estabelecimento: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bistrô Ipê", reputacao: reputacao),
            periodo: periodo,
            local: "CLS 405, Asa Sul, Brasília - DF",
            regiaoAdministrativa: "Plano Piloto",
            distanciaKm: 2.4,
            valor: Dinheiro(centavos: 12000),
            posicoesAbertas: 2,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            modo: .urgencia
        )

        let cartao1 = CartaoVaga(vagaUmaPosicao)
        let cartao2 = CartaoVaga(vagaDuasPosicoes)

        #expect(cartao1.rotuloDeAcessibilidade.contains("1 vaga aberta"))
        #expect(cartao2.rotuloDeAcessibilidade.contains("2 vagas abertas"))
    }
}
