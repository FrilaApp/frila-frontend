#if DEBUG
import Foundation
import FrilaDominio

/// Os dois cenários "vitrine" do `ApiClienteEmMemoria` (`vitrine-profissional` e `vitrine-contratante`):
/// uma conta com dados de exemplo em todas as telas, para navegar à mão sem rede nem backend. Só em
/// Debug, como o resto dos argumentos de lançamento (#96). Tudo é relativo ao relógio do cliente
/// (`agora`), e nomes, casas e valores são inventados: nenhum dado de pessoa ou telefone real.
///
/// Este tipo só monta os dados. Quem os guarda e responde por eles é o próprio `ApiClienteEmMemoria`,
/// que copia o resultado para os seus campos no `init`.
struct VitrineDeExemplo {
    struct CandidaturaDeVitrine {
        let id: UUID
        let vagaID: UUID
        let profissional: PerfilPublico
        let daConta: Bool
        var estado: EstadoCandidatura
        let criadaEm: Date
        var turnoID: UUID?
    }

    struct Lugar {
        let endereco: String
        let regiao: String
        let latitude: Double
        let longitude: Double
    }

    // MARK: Saída

    var estabelecimentos: [Estabelecimento] = []
    var vagas: [Vaga] = []
    var turnos: [Turno] = []
    var turnosCancelados: [Turno] = []
    var contatos: [UUID: Contato] = [:]
    var checkins: [UUID: ResultadoRegistro] = [:]
    var checkouts: [UUID: ResultadoRegistro] = [:]
    var confirmacoesDeCheckin: [UUID: Date] = [:]
    var cancelamentosPorPosicao: [UUID: CancelamentoDaPosicao] = [:]
    var avaliacoes: [UUID: Avaliacao] = [:]
    var equipes: [UUID: [UUID]] = [:]
    var bloqueios: [Alvo: Bloqueio] = [:]
    var candidaturas: [CandidaturaDeVitrine] = []
    var profissionaisEscolhidos: [UUID: PerfilPublico] = [:]
    var posicoesFechadas: [UUID: [UUID]] = [:]
    var perfilProfissional: PerfilProfissional?

    // MARK: Entrada

    let agora: Date
    let catalogo: [Funcao]
    let contatoDeExemplo: Contato

    /// O turno da vitrine do contratante que já nasce avaliado. O "avaliado" da casa mora no aparelho
    /// (`UserDefaultsArmazenamentoAvaliacoes`), e quem monta o cliente grava a resposta nele.
    static let turnoAvaliadoDoContratante = uuid(0x93000000, 8)

    // MARK: Lugares do DF

    static let asaSul = Lugar(endereco: "CLS 405, Asa Sul, Brasília - DF", regiao: "Plano Piloto", latitude: -15.8121, longitude: -47.8997)
    static let asaNorte = Lugar(endereco: "CLN 408, Bloco B, Asa Norte, Brasília - DF", regiao: "Plano Piloto", latitude: -15.7620, longitude: -47.8830)
    static let lagoSul = Lugar(endereco: "SHIS QI 15, Lago Sul, Brasília - DF", regiao: "Lago Sul", latitude: -15.8480, longitude: -47.8680)
    static let aguasClaras = Lugar(endereco: "Rua 25 Sul, Águas Claras, Brasília - DF", regiao: "Águas Claras", latitude: -15.8340, longitude: -48.0270)
    static let taguatinga = Lugar(endereco: "CNB 5, Taguatinga, Brasília - DF", regiao: "Taguatinga", latitude: -15.8330, longitude: -48.0400)
    static let sudoeste = Lugar(endereco: "CLSW 303, Sudoeste, Brasília - DF", regiao: "Sudoeste e Octogonal", latitude: -15.7990, longitude: -47.9230)
    static let guara = Lugar(endereco: "QE 17, Guará II, Brasília - DF", regiao: "Guará", latitude: -15.8300, longitude: -47.9770)
    static let lagoNorte = Lugar(endereco: "SHIN CA 5, Lago Norte, Brasília - DF", regiao: "Lago Norte", latitude: -15.7330, longitude: -47.8630)

    init(agora: Date, catalogo: [Funcao], contato: Contato) {
        self.agora = agora
        self.catalogo = catalogo
        self.contatoDeExemplo = contato
    }

    // MARK: Blocos de montagem

    static func uuid(_ bloco: Int, _ n: Int) -> UUID {
        UUID(uuidString: String(format: "%08lX-0000-4000-8000-%012lX", bloco, n)) ?? UUID()
    }

    /// `horas` a partir de agora; negativo é passado.
    func hora(_ horas: Double) -> Date { agora.addingTimeInterval(horas * 3600) }

    func funcao(_ nome: String) -> Funcao { catalogo.first { $0.nome == nome } ?? catalogo[0] }

    func pessoa(
        _ n: Int, _ nome: String, _ funcoes: [String], positivas: Int, total: Int,
        comparecimento: Double?, considerados: Int, realizados: Int
    ) -> PerfilPublico {
        PerfilPublico(
            id: Self.uuid(0x95000000, n), tipo: .profissional, nome: nome, funcoes: funcoes,
            reputacao: Reputacao(
                positivas: positivas, total: total, taxaComparecimento: comparecimento,
                turnosConsiderados: considerados, turnosRealizados: realizados
            )
        )
    }

    func casa(
        _ n: Int, _ nome: String, positivas: Int, total: Int,
        comparecimento: Double?, considerados: Int, realizados: Int
    ) -> PerfilPublico {
        PerfilPublico(
            id: Self.uuid(0x95100000, n), tipo: .estabelecimento, nome: nome,
            reputacao: Reputacao(
                positivas: positivas, total: total, taxaComparecimento: comparecimento,
                turnosConsiderados: considerados, turnosRealizados: realizados
            )
        )
    }

    func estabelecimento(de casa: PerfilPublico, em lugar: Lugar, tipo: TipoEstabelecimento = .foodService) -> Estabelecimento {
        Estabelecimento(
            id: casa.id, nome: casa.nome, tipo: tipo, endereco: lugar.endereco, regiaoAdministrativa: lugar.regiao,
            ponto: ponto(lugar), papel: .administrador
        )
    }

    func ponto(_ lugar: Lugar) -> Coordenada {
        // As coordenadas são fixas e válidas; o `try!` só existe porque o inicializador é falível.
        // swiftlint:disable:next force_try
        try! Coordenada(latitude: lugar.latitude, longitude: lugar.longitude)
    }

    @discardableResult
    mutating func vaga(
        _ n: Int, _ casa: PerfilPublico, _ lugar: Lugar, _ nomeDaFuncao: String,
        inicio: Double, horas: Double = 5, reais: Int,
        posicoes: Int = 1, abertas: Int? = nil,
        modo: ModoPreenchimento = .urgencia, estado: EstadoVaga = .publicada,
        refeicao: Bool = false, transporte: Bool = false, material: Bool = false,
        responsavel: String, traje: String? = nil, observacoes: String? = nil
    ) -> Vaga {
        // swiftlint:disable:next force_try
        let periodo = try! Periodo(inicio: hora(inicio), fim: hora(inicio + horas))
        let publicadaHaHoras = inicio < 0 ? 48 - inicio : 6
        let nova = Vaga(
            id: Self.uuid(0x94000000, n), estabelecimento: casa, funcao: funcao(nomeDaFuncao), periodo: periodo,
            local: lugar.endereco, regiaoAdministrativa: lugar.regiao, ponto: ponto(lugar),
            valor: Dinheiro(centavos: reais * 100), posicoes: posicoes,
            posicoesAbertas: abertas ?? (estado == .publicada ? posicoes : 0),
            inclusos: Inclusos(refeicao: refeicao, transporte: transporte, exigeMaterialProprio: material),
            responsavelLocal: responsavel, traje: traje, participaRateio: nil, observacoes: observacoes,
            modo: modo, estado: estado, publicadoEm: hora(-publicadaHaHoras)
        )
        vagas.append(nova)
        return nova
    }

    /// Um turno da conta. `escolhido: true` é o turno que a casa vê (a contraparte é o profissional que
    /// ela escolheu); `false` é o do profissional (a contraparte é a casa).
    @discardableResult
    mutating func turno(
        _ n: Int, em vaga: Vaga, com contraparte: PerfilPublico, escolhido: Bool = false,
        verificacao: Verificacao, aCaminhoEm: Date? = nil,
        entrada: Presenca? = nil, saida: Presenca? = nil, contatoNoTurno: Bool = false
    ) -> Turno {
        let bloco = escolhido ? 0x93000000 : 0x92000000
        let id = Self.uuid(bloco, n)
        let visivelAte = vaga.periodo.fim.addingTimeInterval(7 * 24 * 3600)
        let contato = Contato(
            nome: contraparte.nome, telefone: contatoDeExemplo.telefone,
            whatsappURL: contatoDeExemplo.whatsappURL, visivelAte: visivelAte
        )
        let novo = Turno(
            id: id, posicaoID: Self.uuid(bloco, 1000 + n), vaga: vaga.resumo, contraparte: contraparte,
            contatoVisivelAte: visivelAte, aCaminhoEm: aCaminhoEm, checkin: entrada, checkout: saida,
            verificacao: verificacao, valorAcordado: vaga.valor, podeAvaliar: false,
            contato: contatoNoTurno ? contato : nil
        )
        turnos.append(novo)
        contatos[id] = contato
        let doRegistro: Verificacao = verificacao == .pendente ? .pendente : .verificado
        if let entrada {
            checkins[id] = ResultadoRegistro(
                turnoID: id, tipo: entrada.tipo ?? .geolocalizado, verificacao: doRegistro,
                registradoEm: entrada.instante, distanciaMetros: entrada.distanciaMetros
            )
        }
        if let saida {
            checkouts[id] = ResultadoRegistro(
                turnoID: id, tipo: saida.tipo ?? .geolocalizado, verificacao: doRegistro,
                registradoEm: saida.instante, distanciaMetros: saida.distanciaMetros
            )
        }
        if escolhido { profissionaisEscolhidos[id] = contraparte }
        return novo
    }

    /// Tira o turno dos confirmados e o põe entre os cancelados, com o registro que as duas partes leem.
    mutating func cancelar(
        _ turno: Turno, causa: CausaDoCancelamento, falta: Bool, motivo: String? = nil, haHoras: Double
    ) {
        let quando = hora(-haHoras)
        turnos.removeAll { $0.id == turno.id }
        contatos[turno.id] = nil
        cancelamentosPorPosicao[turno.posicaoID] = CancelamentoDaPosicao(causa: causa, falta: falta, motivo: motivo, canceladaEm: quando)
        turnosCancelados.append(Turno(
            id: turno.id, posicaoID: turno.posicaoID, vaga: turno.vaga, contraparte: turno.contraparte,
            contatoVisivelAte: turno.contatoVisivelAte, aCaminhoEm: turno.aCaminhoEm, checkin: turno.checkin,
            checkout: turno.checkout, verificacao: turno.verificacao == .pendente ? .naoVerificado : turno.verificacao,
            valorAcordado: turno.valorAcordado, podeAvaliar: false, estado: .cancelada, avaliacaoInformada: true,
            cancelamento: CancelamentoDoTurno(causa: causa, falta: falta, canceladaEm: quando)
        ))
    }

    mutating func avaliar(_ turno: Turno, chamariaDeNovo: Bool, haHoras: Double) {
        avaliacoes[turno.id] = Avaliacao(turnoID: turno.id, resposta: chamariaDeNovo, criadaEm: hora(-haHoras))
    }

    @discardableResult
    mutating func candidatura(
        _ n: Int, em vaga: Vaga, de profissional: PerfilPublico, daConta: Bool,
        estado: EstadoCandidatura, haHoras: Double, turno: Turno? = nil
    ) -> UUID {
        let id = Self.uuid(0x96000000, n)
        candidaturas.append(CandidaturaDeVitrine(
            id: id, vagaID: vaga.id, profissional: profissional, daConta: daConta,
            estado: estado, criadaEm: hora(-haHoras), turnoID: turno?.id
        ))
        return id
    }

    func presenca(_ instante: Date, _ tipo: TipoRegistro, metros: Int? = nil, confirmadaEm: Date? = nil) -> Presenca {
        Presenca(instante: instante, tipo: tipo, distanciaMetros: metros, confirmadaEm: confirmadaEm)
    }

    // MARK: Vitrine do profissional

    /// Ana Cunha, com o perfil completo: Vagas, Meus turnos, Candidaturas e Conta com dados em todos os estados.
    static func profissional(
        agora: Date, catalogo: [Funcao], contato: Contato, casaDasFixtures: Estabelecimento,
        ana: PerfilPublico, perfilBase: PerfilProfissional?
    ) -> VitrineDeExemplo {
        var v = VitrineDeExemplo(agora: agora, catalogo: catalogo, contato: contato)

        let bistro = PerfilPublico(
            id: casaDasFixtures.id, tipo: .estabelecimento, nome: casaDasFixtures.nome,
            reputacao: Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20, turnosRealizados: 19)
        )
        let boteco = v.casa(1, "Boteco Candango", positivas: 41, total: 48, comparecimento: 0.97, considerados: 52, realizados: 50)
        let churrascaria = v.casa(2, "Churrascaria Fogo do Cerrado", positivas: 63, total: 70, comparecimento: 0.93, considerados: 75, realizados: 70)
        let cantina = v.casa(3, "Cantina Villa Toscana", positivas: 27, total: 30, comparecimento: 0.96, considerados: 32, realizados: 31)
        let buffet = v.casa(4, "Buffet Estrela do Planalto", positivas: 12, total: 15, comparecimento: 0.9, considerados: 20, realizados: 18)
        let escritorio = v.casa(5, "Escritório Cerrado Contábil", positivas: 8, total: 8, comparecimento: 1.0, considerados: 8, realizados: 8)
        let sabor = v.casa(6, "Restaurante Sabor do Sertão", positivas: 19, total: 24, comparecimento: 0.88, considerados: 30, realizados: 26)
        let festas = v.casa(7, "Casa de Festas Arco-Íris", positivas: 0, total: 0, comparecimento: nil, considerados: 0, realizados: 0)
        let pizzaria = v.casa(8, "Pizzaria Bella Vista", positivas: 5, total: 9, comparecimento: 0.7, considerados: 14, realizados: 10)
        let lanchonete = v.casa(9, "Lanchonete Pit Stop", positivas: 3, total: 6, comparecimento: 0.8, considerados: 10, realizados: 8)

        // As casas da conta do dublê: servem à equipe de confiança (Conta > Por que recebo vagas).
        v.estabelecimentos = [
            Estabelecimento(
                id: casaDasFixtures.id, nome: casaDasFixtures.nome, tipo: casaDasFixtures.tipo,
                endereco: casaDasFixtures.endereco, regiaoAdministrativa: casaDasFixtures.regiaoAdministrativa,
                ponto: casaDasFixtures.ponto, papel: .administrador
            ),
            v.estabelecimento(de: boteco, em: asaNorte),
            v.estabelecimento(de: churrascaria, em: lagoSul)
        ]
        v.equipes = [bistro.id: [ana.id], boteco.id: [ana.id], churrascaria.id: [ana.id]]

        // Perfil completo: quatro funções, reputação de quem trabalha bastante.
        if let base = perfilBase {
            v.perfilProfissional = PerfilProfissional(
                id: base.id, usuarioID: base.usuarioID,
                funcoes: ["Garçom", "Bartender", "Auxiliar de cozinha", "Churrasqueiro"].map(v.funcao),
                pontoBase: base.pontoBase, disponibilidades: base.disponibilidades,
                reputacao: Reputacao(positivas: 23, total: 25, taxaComparecimento: 0.96, turnosConsiderados: 27, turnosRealizados: 26)
            )
        }

        // MARK: Vagas na lista (publicadas, no futuro)

        v.vaga(1, bistro, asaSul, "Garçom", inicio: 26, reais: 150, posicoes: 2, refeicao: true,
               responsavel: "Marina", traje: "Camisa preta e calça escura")
        v.vaga(2, boteco, asaNorte, "Bartender", inicio: 3.5, horas: 6, reais: 180,
               responsavel: "Seu Domingos", traje: "Preto, avental da casa", observacoes: "Sexta de pagode: casa cheia a partir das 21h.")
        let vagaPendente = v.vaga(3, churrascaria, lagoSul, "Churrasqueiro", inicio: 120, horas: 7, reais: 280, modo: .selecao,
                                  transporte: true, material: true, responsavel: "Dona Neide", traje: "Dólmã branco",
                                  observacoes: "Traga suas facas. A brasa fica por conta da casa.")
        v.vaga(4, cantina, aguasClaras, "Cozinheiro", inicio: 52, reais: 210, posicoes: 3, abertas: 1, refeicao: true,
               responsavel: "Chef Rodrigo")
        v.vaga(5, buffet, taguatinga, "Atendente de buffet", inicio: 216, horas: 8, reais: 140, posicoes: 6, modo: .selecao,
               refeicao: true, transporte: true, responsavel: "Cláudia", traje: "Camisa branca, calça e sapato pretos")
        v.vaga(6, escritorio, sudoeste, "Faxina comercial (escritório)", inicio: 72, horas: 4, reais: 120,
               responsavel: "Sr. Antônio")
        v.vaga(7, sabor, guara, "Auxiliar de cozinha", inicio: 144, reais: 110, posicoes: 2, modo: .selecao, refeicao: true,
               responsavel: "Lúcia")
        v.vaga(8, festas, lagoNorte, "Auxiliar de festa", inicio: 288, horas: 9, reais: 150, posicoes: 4, modo: .selecao,
               transporte: true, responsavel: "Beatriz", observacoes: "Aniversário de 15 anos. Montagem às 14h.")
        // Das casas bloqueadas: ficam fora da lista até o desbloqueio (RF26).
        v.vaga(9, pizzaria, lagoNorte, "Pizzaiolo", inicio: 30, reais: 190, responsavel: "Gino")
        v.vaga(10, lanchonete, guara, "Chapeiro", inicio: 28, reais: 130, responsavel: "Edvaldo")

        // MARK: Meus turnos

        // Na janela de "Estou a caminho" (de 3 h antes até 15 min depois do início).
        let vagaACaminho = v.vaga(11, cantina, aguasClaras, "Garçom", inicio: 2, reais: 140, estado: .preenchida, refeicao: true,
                                  responsavel: "Chef Rodrigo", traje: "Camisa branca e avental")
        let turnoACaminho = v.turno(1, em: vagaACaminho, com: cantina, verificacao: .pendente)

        // Confirmado, a menos de 24 h: o cancelamento do profissional conta como falta (RN12).
        let vagaProximo = v.vaga(12, bistro, asaSul, "Garçom", inicio: 20, reais: 150, estado: .preenchida, refeicao: true,
                                 responsavel: "Marina", traje: "Camisa preta e calça escura")
        let turnoProximo = v.turno(2, em: vagaProximo, com: bistro, verificacao: .pendente)

        // Confirmado em dois dias, por escolha da casa na seleção.
        let vagaEscolhida = v.vaga(13, buffet, taguatinga, "Atendente de buffet", inicio: 49, horas: 8, reais: 130, modo: .selecao,
                                   estado: .preenchida, refeicao: true, responsavel: "Cláudia", traje: "Camisa branca, calça e sapato pretos")
        let turnoEscolhido = v.turno(3, em: vagaEscolhida, com: buffet, verificacao: .pendente)

        // Em andamento: começou há 1 h, com check-in por geolocalização.
        let vagaAndamento = v.vaga(14, sabor, guara, "Auxiliar de cozinha", inicio: -1, reais: 110, estado: .preenchida,
                                   refeicao: true, responsavel: "Lúcia")
        v.turno(
            4, em: vagaAndamento, com: sabor, verificacao: .verificado, aCaminhoEm: v.hora(-1.6),
            entrada: v.presenca(v.hora(-0.95), .geolocalizado, metros: 38, confirmadaEm: v.hora(-0.95))
        )

        // Encerrado e já avaliado.
        let vagaAvaliada = v.vaga(15, bistro, asaSul, "Garçom", inicio: -76, horas: 5, reais: 150, estado: .encerrada,
                                  refeicao: true, responsavel: "Marina")
        let turnoAvaliado = v.turno(
            5, em: vagaAvaliada, com: bistro, verificacao: .verificado, aCaminhoEm: v.hora(-77),
            entrada: v.presenca(v.hora(-76), .geolocalizado, metros: 42, confirmadaEm: v.hora(-76)),
            saida: v.presenca(v.hora(-71), .geolocalizado, metros: 40), contatoNoTurno: true
        )
        v.avaliar(turnoAvaliado, chamariaDeNovo: true, haHoras: 70)

        // Encerrado há 3 h, com presença verificada: falta avaliar.
        let vagaParaAvaliar = v.vaga(16, boteco, asaNorte, "Bartender", inicio: -9, horas: 6, reais: 180, estado: .encerrada,
                                     responsavel: "Seu Domingos")
        v.turno(
            6, em: vagaParaAvaliar, com: boteco, verificacao: .verificado, aCaminhoEm: v.hora(-9.5),
            entrada: v.presenca(v.hora(-9), .geolocalizado, metros: 55, confirmadaEm: v.hora(-9)),
            saida: v.presenca(v.hora(-3), .geolocalizado, metros: 47), contatoNoTurno: true
        )

        // Encerrado com a presença confirmada pela casa (check-in manual), avaliado como "não chamaria".
        let vagaManual = v.vaga(17, festas, lagoNorte, "Auxiliar de festa", inicio: -222, horas: 9, reais: 150, estado: .encerrada,
                                responsavel: "Beatriz")
        let turnoManual = v.turno(
            7, em: vagaManual, com: festas, verificacao: .verificado,
            entrada: v.presenca(v.hora(-221.9), .manual, confirmadaEm: v.hora(-221.5)),
            saida: v.presenca(v.hora(-213), .manual), contatoNoTurno: true
        )
        v.avaliar(turnoManual, chamariaDeNovo: false, haHoras: 200)

        // Cancelado pela casa.
        let vagaCanceladaPelaCasa = v.vaga(18, cantina, aguasClaras, "Cozinheiro", inicio: 96, reais: 200, estado: .preenchida,
                                           responsavel: "Chef Rodrigo")
        let turnoCanceladoPelaCasa = v.turno(8, em: vagaCanceladaPelaCasa, com: cantina, verificacao: .pendente)
        v.cancelar(turnoCanceladoPelaCasa, causa: .estabelecimento, falta: false, haHoras: 2)

        // Cancelado por mim, a menos de 24 h do início: falta.
        let vagaComFalta = v.vaga(19, escritorio, sudoeste, "Faxina comercial (escritório)", inicio: -16, horas: 4, reais: 120,
                                  estado: .encerrada, responsavel: "Sr. Antônio")
        let turnoComFalta = v.turno(9, em: vagaComFalta, com: escritorio, verificacao: .pendente)
        v.cancelar(turnoComFalta, causa: .profissional, falta: true, motivo: "Imprevisto de saúde na família.", haHoras: 20)

        // MARK: Candidaturas (Meus turnos já traz as aceitas da urgência)

        v.candidatura(1, em: vagaPendente, de: ana, daConta: true, estado: .pendente, haHoras: 3)
        v.candidatura(2, em: vagaEscolhida, de: ana, daConta: true, estado: .aceita, haHoras: 50, turno: turnoEscolhido)
        v.candidatura(3, em: vagaProximo, de: ana, daConta: true, estado: .aceita, haHoras: 30, turno: turnoProximo)
        v.candidatura(4, em: vagaACaminho, de: ana, daConta: true, estado: .aceita, haHoras: 26, turno: turnoACaminho)

        let vagaRecusada = v.vaga(20, festas, lagoNorte, "Auxiliar de festa", inicio: 100, horas: 6, reais: 140, modo: .selecao,
                                  estado: .preenchida, responsavel: "Beatriz")
        v.candidatura(5, em: vagaRecusada, de: ana, daConta: true, estado: .recusada, haHoras: 48)

        let vagaExpirada = v.vaga(21, sabor, guara, "Cozinheiro", inicio: 20, reais: 170, modo: .selecao, estado: .encerrada,
                                  refeicao: true, responsavel: "Lúcia")
        v.candidatura(6, em: vagaExpirada, de: ana, daConta: true, estado: .expirada, haHoras: 72)

        // MARK: Bloqueios (Conta > Bloqueios, #687)

        v.bloqueios[Alvo(pizzaria)] = Bloqueio(alvo: Alvo(pizzaria), criadoEm: v.hora(-24 * 12))
        v.bloqueios[Alvo(lanchonete)] = Bloqueio(alvo: Alvo(lanchonete), criadoEm: v.hora(-24 * 3))
        return v
    }

    // MARK: Vitrine do contratante

    /// A casa já cadastrada ("Bistrô Ipê") com vagas em todos os estados do painel.
    static func contratante(
        agora: Date, catalogo: [Funcao], contato: Contato, casaDasFixtures: Estabelecimento,
        candidatos: [Candidato]
    ) -> VitrineDeExemplo {
        var v = VitrineDeExemplo(agora: agora, catalogo: catalogo, contato: contato)
        let lugar = asaSul
        let bistro = PerfilPublico(
            id: casaDasFixtures.id, tipo: .estabelecimento, nome: casaDasFixtures.nome,
            reputacao: Reputacao(positivas: 18, total: 20, taxaComparecimento: 0.95, turnosConsiderados: 20, turnosRealizados: 19)
        )
        v.estabelecimentos = [casaDasFixtures]

        let rafaela = v.pessoa(11, "Rafaela Duarte", ["Garçom"], positivas: 14, total: 15, comparecimento: 1.0, considerados: 16, realizados: 16)
        let thiago = v.pessoa(12, "Thiago Nogueira", ["Garçom", "Bartender"], positivas: 9, total: 10, comparecimento: 0.92, considerados: 13, realizados: 12)
        let luana = v.pessoa(13, "Luana Prado", ["Cozinheiro", "Auxiliar de cozinha"], positivas: 22, total: 24, comparecimento: 0.97, considerados: 31, realizados: 30)
        let marcos = v.pessoa(14, "Marcos Vieira", ["Auxiliar de salão"], positivas: 2, total: 3, comparecimento: 0.8, considerados: 5, realizados: 4)
        let patricia = v.pessoa(15, "Patrícia Lemos", ["Hostess", "Garçom"], positivas: 6, total: 8, comparecimento: 0.78, considerados: 9, realizados: 7)
        let wellington = v.pessoa(16, "Wellington Braga", ["Cozinheiro"], positivas: 1, total: 2, comparecimento: 0.6, considerados: 5, realizados: 3)
        let sergio = v.pessoa(17, "Sérgio Albuquerque", ["Cozinheiro"], positivas: 0, total: 3, comparecimento: 0.5, considerados: 6, realizados: 3)
        let joana = v.pessoa(18, "Joana Fontes", ["Cozinheiro", "Confeiteiro"], positivas: 4, total: 4, comparecimento: 1.0, considerados: 4, realizados: 4)

        // MARK: Minhas vagas

        // Aberta, sem nenhum candidato.
        v.vaga(1, bistro, lugar, "Garçom", inicio: 144, reais: 150, posicoes: 2, modo: .selecao, refeicao: true,
               responsavel: "Marina", traje: "Camisa preta e calça escura")

        // Seleção com quatro candidatos (um deles da equipe, o segundo).
        let vagaSelecao = v.vaga(2, bistro, lugar, "Garçom", inicio: 96, reais: 160, modo: .selecao, refeicao: true,
                                 responsavel: "Marina", traje: "Camisa preta e calça escura")
        for (indice, candidato) in candidatos.prefix(4).enumerated() {
            v.candidatura(100 + indice, em: vagaSelecao, de: candidato.profissional, daConta: false, estado: .pendente,
                          haHoras: Double(candidatos.prefix(4).count - indice) * 2)
        }

        // Preenchida: o escolhido (Bruno, da equipe) já tem turno, com o contato liberado.
        let bruno = candidatos.count > 1 ? candidatos[1].profissional : thiago
        let vagaPreenchida = v.vaga(3, bistro, lugar, "Bartender", inicio: 50, reais: 200, modo: .selecao, estado: .preenchida,
                                    responsavel: "Marina")
        let turnoDoBruno = v.turno(1, em: vagaPreenchida, com: bruno, escolhido: true, verificacao: .pendente)
        v.candidatura(110, em: vagaPreenchida, de: bruno, daConta: false, estado: .aceita, haHoras: 60, turno: turnoDoBruno)

        // Em andamento, com check-in manual já confirmado pela casa; a outra posição foi cancelada com motivo.
        let vagaAndamento = v.vaga(4, bistro, lugar, "Cozinheiro", inicio: -1, reais: 190, posicoes: 2, estado: .preenchida,
                                   refeicao: true, responsavel: "Marina")
        let entradaLuana = v.hora(-0.97)
        let turnoDaLuana = v.turno(
            2, em: vagaAndamento, com: luana, escolhido: true, verificacao: .verificado, aCaminhoEm: v.hora(-1.5),
            entrada: v.presenca(entradaLuana, .manual, confirmadaEm: v.hora(-0.9))
        )
        v.confirmacoesDeCheckin[turnoDaLuana.id] = v.hora(-0.9)
        let turnoDoWellington = v.turno(3, em: vagaAndamento, com: wellington, escolhido: true, verificacao: .pendente)
        v.cancelar(turnoDoWellington, causa: .profissional, falta: true, motivo: "Imprevisto de saúde e não poderei comparecer.", haHoras: 0.5)

        // Com check-in manual esperando a confirmação da casa.
        let vagaManual = v.vaga(5, bistro, lugar, "Auxiliar de salão", inicio: -10.0 / 60.0, reais: 120, estado: .preenchida,
                                responsavel: "Marina")
        v.turno(
            4, em: vagaManual, com: marcos, escolhido: true, verificacao: .pendente, aCaminhoEm: v.hora(-0.6),
            entrada: v.presenca(v.hora(-2.0 / 60.0), .manual)
        )

        // Em atraso: passaram 20 minutos do início e não houve check-in.
        let vagaAtraso = v.vaga(6, bistro, lugar, "Hostess", inicio: -20.0 / 60.0, reais: 130, estado: .preenchida,
                                responsavel: "Marina", traje: "Vestido preto")
        v.turno(5, em: vagaAtraso, com: patricia, escolhido: true, verificacao: .pendente, aCaminhoEm: v.hora(-1))

        // Vaga vazia dentro da janela de alerta (começa em 2 h e ninguém se candidatou).
        v.vaga(7, bistro, lugar, "Barback", inicio: 2, reais: 110, responsavel: "Marina")

        // Encerrada, com turno verificado para avaliar (e para republicar).
        let vagaParaAvaliar = v.vaga(8, bistro, lugar, "Garçom", inicio: -9, horas: 6, reais: 150, estado: .encerrada,
                                     refeicao: true, responsavel: "Marina")
        v.turno(
            6, em: vagaParaAvaliar, com: rafaela, escolhido: true, verificacao: .verificado, aCaminhoEm: v.hora(-9.5),
            entrada: v.presenca(v.hora(-9), .geolocalizado, metros: 30, confirmadaEm: v.hora(-9)),
            saida: v.presenca(v.hora(-3), .geolocalizado, metros: 35)
        )

        // Encerrada há dois dias, com o turno já avaliado pela casa.
        let vagaAvaliada = v.vaga(9, bistro, lugar, "Garçom", inicio: -53, horas: 5, reais: 150, estado: .encerrada,
                                  refeicao: true, responsavel: "Marina")
        let turnoAvaliado = v.turno(
            8, em: vagaAvaliada, com: thiago, escolhido: true, verificacao: .verificado, aCaminhoEm: v.hora(-53.5),
            entrada: v.presenca(v.hora(-53), .geolocalizado, metros: 44, confirmadaEm: v.hora(-53)),
            saida: v.presenca(v.hora(-48), .geolocalizado, metros: 41)
        )
        v.avaliar(turnoAvaliado, chamariaDeNovo: true, haHoras: 46)

        // Seleção que fechou sozinha 24 h antes do início, sem escolha (RN24): dá para republicar em urgência.
        let vagaFechada = v.vaga(10, bistro, lugar, "Cozinheiro", inicio: 20, reais: 175, modo: .selecao, estado: .encerrada,
                                 refeicao: true, responsavel: "Marina")
        v.posicoesFechadas[vagaFechada.id] = [uuid(0x97000000, 1)]
        v.candidatura(120, em: vagaFechada, de: sergio, daConta: false, estado: .expirada, haHoras: 50)
        v.candidatura(121, em: vagaFechada, de: joana, daConta: false, estado: .expirada, haHoras: 46)

        // Cancelada pela casa.
        let vagaCancelada = v.vaga(11, bistro, lugar, "Garçom", inicio: 72, reais: 150, estado: .cancelada, responsavel: "Marina")
        v.posicoesFechadas[vagaCancelada.id] = [uuid(0x97000000, 2)]

        // MARK: Equipe de confiança e bloqueios

        // Do incluído mais recente para o mais antigo.
        v.equipes[bistro.id] = [bruno.id, rafaela.id, thiago.id]
        v.bloqueios[Alvo(sergio)] = Bloqueio(alvo: Alvo(sergio), criadoEm: v.hora(-24 * 9))
        v.bloqueios[Alvo(joana)] = Bloqueio(alvo: Alvo(joana), criadoEm: v.hora(-24 * 2))
        return v
    }
}
#endif
