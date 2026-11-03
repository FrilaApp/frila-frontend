import FrilaDominio
import SwiftUI

// MARK: - Opções de horário

/// Uma opção da fileira de chips.
public struct OpcaoDeHorario: Identifiable, Equatable, Sendable {
    public let hora: HoraDoDia
    /// Primeira opção depois da meia-noite, quando o fim vira o dia seguinte.
    public let iniciaDiaSeguinte: Bool
    public var id: String { hora.contrato }
}

/// As opções de início e de fim que a fileira de chips oferece: passos de 30 minutos. Um horário já salvo
/// que não cai num passo (por exemplo 18:15, vindo do contrato) continua existindo e aparece na fileira,
/// no lugar certo, para a precisão de minutos nunca se perder.
public enum OpcoesDeHorario {
    public static let passoEmMinutos = 30

    /// 00:00, 00:30 ... 23:30.
    public static func passos() -> [HoraDoDia] {
        stride(from: 0, to: 24 * 60, by: passoEmMinutos).compactMap { total in
            try? HoraDoDia(hora: total / 60, minuto: total % 60)
        }
    }

    /// Opções de início em ordem do dia. Não oferece o horário igual ao fim já escolhido: janela de
    /// duração zero não existe.
    public static func inicio(atual: HoraDoDia?, excluindo fim: HoraDoDia?) -> [OpcaoDeHorario] {
        var horas = Set(passos())
        if let atual { horas.insert(atual) }
        if let fim { horas.remove(fim) }
        return horas.sorted().map { OpcaoDeHorario(hora: $0, iniciaDiaSeguinte: false) }
    }

    /// Opções de fim a partir do início: primeiro o resto do mesmo dia, depois a virada da meia-noite,
    /// com a primeira opção do dia seguinte marcada. Nunca oferece o próprio início.
    public static func fim(apos inicio: HoraDoDia, atual: HoraDoDia?) -> [OpcaoDeHorario] {
        var horas = Set(passos())
        if let atual { horas.insert(atual) }
        horas.remove(inicio)
        let mesmoDia = horas.filter { $0 > inicio }.sorted()
        let diaSeguinte = horas.filter { $0 < inicio }.sorted()
        return mesmoDia.map { OpcaoDeHorario(hora: $0, iniciaDiaSeguinte: false) }
            + diaSeguinte.enumerated().map { OpcaoDeHorario(hora: $1, iniciaDiaSeguinte: $0 == 0) }
    }
}

// MARK: - Estado local da edição

enum CampoDeHorario: Hashable {
    case inicio
    case fim
}

/// O que está sendo editado: um campo do rascunho ou um campo de um horário já salvo.
enum AlvoDeEdicao: Hashable {
    case rascunho(CampoDeHorario)
    case janela(JanelaDeDisponibilidade, CampoDeHorario)
}

/// Um horário ainda sem os dois valores. Fica só na tela: nunca entra em `disponibilidades` enquanto não
/// tiver início e fim escolhidos pela pessoa, e então entra sozinho.
struct RascunhoDeHorario: Equatable {
    var dia: Int
    var inicio: HoraDoDia?
    var fim: HoraDoDia?

    var temValor: Bool { inicio != nil || fim != nil }
}

// MARK: - Seção

/// Bloco "Seus horários": a faixa fixa dos sete dias e, no mesmo contêiner, os horários agrupados por dia.
///
/// - Abre com o domingo selecionado e uma linha de rascunho vazia ("Selecionar"), sem horário presumido.
/// - Tocar num dia sem horário cria o rascunho dele e abre a escolha do início; tocar num dia com horário
///   só põe em evidência as linhas dele.
/// - Escolher início e fim (chips de 30 minutos) confirma o horário sozinho; o fim antes do início
///   atravessa a meia-noite e é marcado como dia seguinte.
/// - Sem `Menu`, sem `Picker`, sem roleta nativa.
struct SecaoDeHorarios: View {
    let viewModel: PerfilProfissionalViewModel
    @Binding var rascunhoIncompleto: Bool
    @Binding var avisoDeRascunho: Bool

    @State private var diaSelecionado = 0
    @State private var rascunho: RascunhoDeHorario?
    @State private var campo: AlvoDeEdicao?
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    // MARK: Dados derivados

    private func janelas(do dia: Int) -> [JanelaDeDisponibilidade] {
        viewModel.disponibilidades.filter { $0.diaDaSemana == dia }
    }

    private var diasDaFaixa: [FrilaWeekStripDia] {
        (0...6).map { dia in
            FrilaWeekStripDia(
                id: dia,
                rotulo: TextosDoProfissional.Perfil.diasAbreviados[dia],
                preenchido: !janelas(do: dia).isEmpty
            )
        }
    }

    private var diasComConteudo: [Int] {
        (0...6).filter { !janelas(do: $0).isEmpty || rascunho?.dia == $0 }
    }

    // MARK: Corpo

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            FrilaWeekStrip(dias: diasDaFaixa, selecionado: diaSelecionado, aoSelecionar: tocarDia)

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                ForEach(diasComConteudo, id: \.self) { dia in
                    grupo(dia)
                        .transition(transicaoDeLinha)
                }
            }
        }
        .padding(FrilaEspaco.pequeno)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("faixa-semanal")
        .onAppear { garantirRascunhoDoDiaSelecionado() }
        .onChange(of: rascunho) { _, novo in
            rascunhoIncompleto = novo?.temValor ?? false
            avisoDeRascunho = false
        }
    }

    private var transicaoDeLinha: AnyTransition {
        .asymmetric(
            insertion: AnyTransition.opacity.combined(with: .offset(y: 4))
                .animation(FrilaMovimento.animacao(FrilaMotion.horarioLinhaEntrada, reduzir: reduzirMovimento)),
            removal: AnyTransition.opacity
                .animation(FrilaMovimento.animacao(FrilaMotion.horarioRemover, reduzir: reduzirMovimento))
        )
    }

    // MARK: Grupo de um dia

    private func grupo(_ dia: Int) -> some View {
        let selecionado = dia == diaSelecionado
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: PerfilProfissionalViewModel.nomeDoDia(dia))
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)

            ForEach(janelas(do: dia), id: \.self) { janela in
                linhaDeJanela(janela)
                    .transition(transicaoDeLinha)
            }

            if let rascunho, rascunho.dia == dia {
                linhaDeRascunho(rascunho)
                    .transition(transicaoDeLinha)
                if avisoDeRascunho {
                    Text(verbatim: TextosDoProfissional.Perfil.horarioCompletar)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.perigo)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("aviso-rascunho-horario")
                }
            } else if selecionado {
                Button(action: adicionarOutroHorario) {
                    Text(verbatim: TextosDoProfissional.Perfil.adicionarHorario)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.selecao)
                        .frame(minHeight: 36, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("botao-adicionar-janela")
            }
        }
        .padding(FrilaEspaco.pequeno)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                .fill(FrilaCor.selecao.opacity(selecionado ? 0.08 : 0))
        )
        .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: selecionado)
    }

    // MARK: Linhas

    private func linhaDeJanela(_ janela: JanelaDeDisponibilidade) -> some View {
        let inicio = AlvoDeEdicao.janela(janela, .inicio)
        let fim = AlvoDeEdicao.janela(janela, .fim)
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            HStack(spacing: FrilaEspaco.pequeno) {
                campoDeHora(
                    rotulo: TextosDoProfissional.Perfil.inicio,
                    valor: janela.inicio,
                    ativo: campo == inicio,
                    identificador: "janela-inicio-\(janela.diaDaSemana)-\(janela.inicio.contrato)"
                ) { abrir(inicio) }
                campoDeHora(
                    rotulo: TextosDoProfissional.Perfil.fim,
                    valor: janela.fim,
                    nota: janela.atravessaMeiaNoite ? TextosDoProfissional.Perfil.horarioDiaSeguinte : nil,
                    ativo: campo == fim,
                    identificador: "janela-fim-\(janela.diaDaSemana)-\(janela.inicio.contrato)"
                ) { abrir(fim) }
                Spacer(minLength: 0)
                Button { remover(janela) } label: {
                    Text(verbatim: TextosDoProfissional.Perfil.remover)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("remover-janela-\(janela.diaDaSemana)-\(janela.inicio.contrato)")
            }
            .fixedSize(horizontal: false, vertical: true)
            painel(se: inicio)
            painel(se: fim)
        }
    }

    private func linhaDeRascunho(_ r: RascunhoDeHorario) -> some View {
        let inicio = AlvoDeEdicao.rascunho(.inicio)
        let fim = AlvoDeEdicao.rascunho(.fim)
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            HStack(spacing: FrilaEspaco.pequeno) {
                campoDeHora(
                    rotulo: TextosDoProfissional.Perfil.inicio,
                    valor: r.inicio,
                    ativo: campo == inicio,
                    identificador: "rascunho-inicio"
                ) { abrir(inicio) }
                campoDeHora(
                    rotulo: TextosDoProfissional.Perfil.fim,
                    valor: r.fim,
                    ativo: campo == fim,
                    identificador: "rascunho-fim"
                ) { abrir(fim) }
                Spacer(minLength: 0)
                if r.temValor {
                    Button(action: descartarRascunho) {
                        Text(verbatim: TextosDoProfissional.Perfil.horarioDescartar)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("descartar-rascunho")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            painel(se: inicio)
            painel(se: fim)
        }
    }

    /// Campo de hora: o rótulo pequeno, o valor (ou "Selecionar") e, no fim que vira o dia seguinte, uma nota.
    private func campoDeHora(
        rotulo: String,
        valor: HoraDoDia?,
        nota: String? = nil,
        ativo: Bool,
        identificador: String,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                Text(verbatim: rotulo)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: valor?.contrato ?? TextosDoProfissional.Perfil.horarioSelecionar)
                    .font(FrilaTipo.corpo.weight(.semibold))
                    .foregroundStyle(valor == nil ? FrilaCor.textoSecundario : FrilaCor.texto)
                if let nota {
                    Text(verbatim: nota)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }
            .padding(.horizontal, FrilaEspaco.compacto)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(minWidth: 88, maxHeight: .infinity, alignment: .leading)
            .frame(minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                    .strokeBorder(ativo ? FrilaCor.selecao : FrilaCor.divisoria, lineWidth: 1)
            )
            .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: ativo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identificador)
    }

    // MARK: Painel de chips

    @ViewBuilder
    private func painel(se alvo: AlvoDeEdicao) -> some View {
        if campo == alvo, let conteudo = itens(para: alvo) {
            FrilaTimeChipRow(itens: conteudo.itens, ancora: conteudo.ancora) { id in
                if let hora = try? HoraDoDia(id) { escolher(hora, para: alvo) }
            }
            .id(alvo)
            .transition(transicaoDeLinha)
        }
    }

    private func itens(para alvo: AlvoDeEdicao) -> (itens: [FrilaTimeChipItem], ancora: String?)? {
        let opcoes: [OpcaoDeHorario]
        let atual: HoraDoDia?
        let ehInicio: Bool
        switch alvo {
        case .rascunho(.inicio):
            atual = rascunho?.inicio
            opcoes = OpcoesDeHorario.inicio(atual: atual, excluindo: rascunho?.fim)
            ehInicio = true
        case .rascunho(.fim):
            guard let inicio = rascunho?.inicio else { return nil }
            atual = rascunho?.fim
            opcoes = OpcoesDeHorario.fim(apos: inicio, atual: atual)
            ehInicio = false
        case let .janela(janela, .inicio):
            atual = janela.inicio
            opcoes = OpcoesDeHorario.inicio(atual: atual, excluindo: janela.fim)
            ehInicio = true
        case let .janela(janela, .fim):
            atual = janela.fim
            opcoes = OpcoesDeHorario.fim(apos: janela.inicio, atual: atual)
            ehInicio = false
        }
        let itens = opcoes.map {
            FrilaTimeChipItem(
                id: $0.id,
                rotulo: $0.id,
                selecionado: $0.hora == atual,
                marcaAntes: $0.iniciaDiaSeguinte ? TextosDoProfissional.Perfil.horarioDiaSeguinte : nil
            )
        }
        // A âncora é só onde a fileira abre, nunca uma escolha: o início abre perto do começo da noite.
        let ancora = atual?.contrato ?? (ehInicio ? "18:00" : opcoes.first?.id)
        return (itens, ancora)
    }

    // MARK: Ações

    private func animar(_ animacao: Animation = FrilaMotion.horarioExpandir, _ mudanca: () -> Void) {
        withAnimation(FrilaMovimento.animacao(animacao, reduzir: reduzirMovimento), mudanca)
    }

    private func garantirRascunhoDoDiaSelecionado() {
        guard janelas(do: diaSelecionado).isEmpty, rascunho?.dia != diaSelecionado else { return }
        rascunho = RascunhoDeHorario(dia: diaSelecionado)
    }

    private func tocarDia(_ dia: Int) {
        animar {
            diaSelecionado = dia
            if janelas(do: dia).isEmpty {
                if rascunho?.dia != dia { rascunho = RascunhoDeHorario(dia: dia) }
                campo = .rascunho(rascunho?.inicio == nil ? .inicio : .fim)
            } else {
                campo = nil
            }
            avisoDeRascunho = false
        }
    }

    private func adicionarOutroHorario() {
        animar {
            rascunho = RascunhoDeHorario(dia: diaSelecionado)
            campo = .rascunho(.inicio)
        }
    }

    private func abrir(_ alvo: AlvoDeEdicao) {
        // O fim do rascunho depende do início: sem início, a pessoa começa por ele.
        var destino = alvo
        if alvo == .rascunho(.fim), rascunho?.inicio == nil { destino = .rascunho(.inicio) }
        animar { campo = (campo == destino) ? nil : destino }
    }

    private func escolher(_ hora: HoraDoDia, para alvo: AlvoDeEdicao) {
        animar {
            switch alvo {
            case let .rascunho(qual):
                guard var r = rascunho else { return }
                if qual == .inicio {
                    r.inicio = hora
                    if r.fim == hora { r.fim = nil }
                } else {
                    r.fim = hora
                }
                rascunho = r
                if let inicio = r.inicio, let fim = r.fim {
                    viewModel.adicionarJanela(diaDaSemana: r.dia, inicio: inicio, fim: fim)
                    rascunho = nil
                    campo = nil
                } else {
                    campo = .rascunho(r.inicio == nil ? .inicio : .fim)
                }
            case let .janela(janela, qual):
                let nova = JanelaDeDisponibilidade(
                    diaDaSemana: janela.diaDaSemana,
                    inicio: qual == .inicio ? hora : janela.inicio,
                    fim: qual == .fim ? hora : janela.fim
                )
                if viewModel.substituirJanela(janela, por: nova) { campo = nil }
            }
        }
    }

    private func remover(_ janela: JanelaDeDisponibilidade) {
        animar(FrilaMotion.horarioRemover) {
            viewModel.removerJanela(janela)
            campo = nil
            garantirRascunhoDoDiaSelecionado()
        }
    }

    private func descartarRascunho() {
        animar(FrilaMotion.horarioRemover) {
            rascunho = nil
            campo = nil
            avisoDeRascunho = false
            garantirRascunhoDoDiaSelecionado()
        }
    }
}
