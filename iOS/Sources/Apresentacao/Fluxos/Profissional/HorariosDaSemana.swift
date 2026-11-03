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

/// As opções de início e de fim que a roleta oferece: passos de 30 minutos, como a roleta de turno do Estúdio. Um horário já salvo
/// que não cai num passo (por exemplo 18:15, vindo do contrato) continua existindo e aparece na roleta,
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

    var id: String { self == .inicio ? "inicio" : "fim" }
}

/// Um horário em edição no editor linear. Fica só na tela: nada entra em `disponibilidades` antes do
/// "Concluir", então abrir, mexer e cancelar nunca preenche um horário sem intenção.
struct EdicaoDeHorario: Equatable {
    enum Origem: Equatable {
        case nova(dia: Int)
        case existente(JanelaDeDisponibilidade)
    }

    var origem: Origem
    var etapa: CampoDeHorario = .inicio
    var inicio: HoraDoDia
    var fim: HoraDoDia
    /// O fim só vira valor da pessoa quando ela passa por ele: antes disso o segmento mostra "Selecionar".
    var fimVisitado: Bool

    var dia: Int {
        switch origem {
        case let .nova(dia): dia
        case let .existente(janela): janela.diaDaSemana
        }
    }

    /// Ponto de partida da roleta (não é uma escolha): início às 18:00 e fim 6 horas depois, como no Estúdio.
    static func nova(dia: Int) -> EdicaoDeHorario {
        let inicio = Self.inicioPadrao
        return EdicaoDeHorario(origem: .nova(dia: dia), inicio: inicio, fim: sugestaoDeFim(apos: inicio), fimVisitado: false)
    }

    static func existente(_ janela: JanelaDeDisponibilidade) -> EdicaoDeHorario {
        EdicaoDeHorario(origem: .existente(janela), inicio: janela.inicio, fim: janela.fim, fimVisitado: true)
    }

    private static let inicioPadrao: HoraDoDia = {
        do { return try HoraDoDia(hora: 18, minuto: 0) } catch { preconditionFailure("18:00 é um horário válido.") }
    }()

    static func sugestaoDeFim(apos inicio: HoraDoDia) -> HoraDoDia {
        (try? HoraDoDia(hora: (inicio.hora + 6) % 24, minuto: inicio.minuto)) ?? inicio
    }
}

// MARK: - Seção

/// Bloco "Seus horários": a faixa fixa dos sete dias e, no mesmo contêiner, os horários agrupados por dia.
///
/// O desenho segue o contrato do fluxo de turno da publicação de vaga: **uma etapa por vez**, com o valor
/// vivo nos segmentos Início e Fim, **um controle só** (a roleta nativa, com tipografia própria) e um botão
/// de seta que avança e vira "Concluir" na última etapa. Nada entra em `disponibilidades` antes do "Concluir".
///
/// - Abre no domingo, sem horário presumido: uma linha "Escolher horário".
/// - Tocar num dia sem horário abre o editor no início; tocar num dia com horário só o põe em evidência.
/// - Sem `Menu`, sem chips de hora: a hora é da roleta.
struct SecaoDeHorarios: View {
    let viewModel: PerfilProfissionalViewModel
    /// Há um horário aberto no editor, ainda sem "Concluir": o salvar pede para concluir ou cancelar.
    @Binding var rascunhoIncompleto: Bool
    @Binding var avisoDeRascunho: Bool
    /// A seção pede à tela para rolar até o editor quando ele abre.
    @Binding var pedidoDeRolagem: String?

    @State private var diaSelecionado = 0
    @State private var edicao: EdicaoDeHorario?
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    static let idDoEditor = "editor-horario"

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

    /// Dias que aparecem na lista: os que têm horário, o dia selecionado e o dia em edição.
    private var diasComConteudo: [Int] {
        (0...6).filter { !janelas(do: $0).isEmpty || $0 == diaSelecionado || edicao?.dia == $0 }
    }

    // MARK: Corpo

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            FrilaWeekStrip(dias: diasDaFaixa, selecionado: diaSelecionado, aoSelecionar: tocarDia)

            Rectangle()
                .fill(FrilaCor.divisoria)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                ForEach(diasComConteudo, id: \.self) { dia in
                    grupo(dia)
                        .transition(transicaoDeLinha)
                }
            }
            .padding(.horizontal, FrilaEspaco.pequeno)
            .padding(.bottom, FrilaEspaco.pequeno)
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
        .onChange(of: edicao != nil) { _, aberto in
            rascunhoIncompleto = aberto
            avisoDeRascunho = false
            if aberto { pedirRolagemAoEditor() }
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
        let janelasDoDia = janelas(do: dia)
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: PerfilProfissionalViewModel.nomeDoDia(dia))
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(selecionado ? FrilaCor.texto : FrilaCor.textoSecundario)

            ForEach(janelasDoDia, id: \.self) { janela in
                if edicao?.origem == .existente(janela) {
                    editor
                        .transition(transicaoDeLinha)
                } else {
                    linhaDeJanela(janela)
                        .transition(transicaoDeLinha)
                }
            }

            if case .nova(dia) = edicao?.origem {
                editor
                    .transition(transicaoDeLinha)
                if avisoDeRascunho {
                    Text(verbatim: TextosDoProfissional.Perfil.horarioConclua)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.perigo)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("aviso-rascunho-horario")
                }
            } else if selecionado, edicao == nil {
                if janelasDoDia.isEmpty {
                    linhaEscolherHorario
                } else {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Linhas

    /// Dia sem horário: um convite de uma linha que começa o fluxo. A seta diz que tem próximo passo.
    private var linhaEscolherHorario: some View {
        Button { abrirNovo(dia: diaSelecionado) } label: {
            HStack {
                Text(verbatim: TextosDoProfissional.Perfil.horarioEscolher)
                    .font(FrilaTipo.corpo.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                Spacer(minLength: FrilaEspaco.pequeno)
                Image(systemName: "arrow.right")
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaEspaco.compacto)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("escolher-horario")
    }

    /// Horário salvo: "18:00 até 02:00" e, quando atravessa a meia-noite, uma nota. Tocar edita; Remover tira.
    private func linhaDeJanela(_ janela: JanelaDeDisponibilidade) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            Button { abrirExistente(janela) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                        Text(verbatim: TextosDoProfissional.Perfil.horarioDeAte(inicio: janela.inicio.contrato, fim: janela.fim.contrato))
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .monospacedDigit()
                        if janela.atravessaMeiaNoite {
                            Text(verbatim: TextosDoProfissional.Perfil.horarioDiaSeguinte)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, FrilaEspaco.compacto)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("janela-\(janela.diaDaSemana)-\(janela.inicio.contrato)")

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
    }

    // MARK: Editor linear

    /// Início e Fim em segmentos, a roleta da etapa atual, e a seta que avança e vira "Concluir".
    @ViewBuilder
    private var editor: some View {
        if let e = edicao {
            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                FrilaStepSegments(
                    segmentos: [
                        FrilaStepSegment(id: CampoDeHorario.inicio.id, titulo: TextosDoProfissional.Perfil.inicio, valor: e.inicio.contrato),
                        FrilaStepSegment(
                            id: CampoDeHorario.fim.id,
                            titulo: TextosDoProfissional.Perfil.fim,
                            valor: e.fimVisitado ? e.fim.contrato : TextosDoProfissional.Perfil.horarioSelecionar
                        )
                    ],
                    ativo: e.etapa.id,
                    aoSelecionar: { id in ir(para: id == CampoDeHorario.inicio.id ? .inicio : .fim) }
                )

                roda(e)
                    .id(e.etapa)
                    .transition(.opacity.animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento)))

                if e.etapa == .fim, e.fim < e.inicio {
                    Text(verbatim: TextosDoProfissional.Perfil.horarioTerminaNoDiaSeguinte)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                HStack {
                    Button(action: cancelar) {
                        Text(verbatim: TextosDoProfissional.Perfil.horarioCancelar)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cancelar-horario")

                    Spacer(minLength: 0)

                    botaoDeSeta(ultima: e.etapa == .fim)
                }
            }
            .id(Self.idDoEditor)
        }
    }

    /// A roleta nativa da etapa, com a tipografia tabular do Estúdio. O início não oferece o fim já escolhido;
    /// o fim vai do resto do dia à virada da meia-noite, e nunca oferece o próprio início.
    private func roda(_ e: EdicaoDeHorario) -> some View {
        let opcoes: [HoraDoDia]
        let selecao: Binding<HoraDoDia>
        switch e.etapa {
        case .inicio:
            opcoes = OpcoesDeHorario.inicio(atual: e.inicio, excluindo: e.fimVisitado ? e.fim : nil).map(\.hora)
            selecao = Binding(
                get: { edicao?.inicio ?? e.inicio },
                set: { novo in
                    edicao?.inicio = novo
                    if edicao?.fim == novo { edicao?.fim = EdicaoDeHorario.sugestaoDeFim(apos: novo) }
                }
            )
        case .fim:
            opcoes = OpcoesDeHorario.fim(apos: e.inicio, atual: e.fim).map(\.hora)
            selecao = Binding(get: { edicao?.fim ?? e.fim }, set: { edicao?.fim = $0 })
        }
        return Picker(selection: selecao) {
            ForEach(opcoes, id: \.self) { hora in
                Text(verbatim: hora.contrato)
                    .font(FrilaTypography.metricTabular(size: 22, weight: .medium))
                    .tag(hora)
            }
        } label: {
            Text(verbatim: e.etapa == .inicio ? TextosDoProfissional.Perfil.inicio : TextosDoProfissional.Perfil.fim)
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(height: 150)
        .accessibilityIdentifier("roda-horario-\(e.etapa.id)")
    }

    /// Seta Quente que avança do início para o fim e vira o visto na última etapa.
    private func botaoDeSeta(ultima: Bool) -> some View {
        Button(action: avancar) {
            Image(systemName: ultima ? "checkmark" : "arrow.right")
                .font(FrilaTipo.corpo.weight(.bold))
                .foregroundStyle(FrilaCor.sobreSelecao)
                .frame(width: 52, height: 52)
                .background(Circle().fill(FrilaCor.quente))
                .contentTransition(reduzirMovimento ? .identity : .symbolEffect(.replace))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: ultima ? TextosDoProfissional.Perfil.horarioConcluir : TextosDoProfissional.Perfil.horarioProximo))
        .accessibilityIdentifier("horario-avancar")
    }

    // MARK: Ações

    private func animar(_ animacao: Animation = FrilaMotion.horarioExpandir, _ mudanca: () -> Void) {
        withAnimation(FrilaMovimento.animacao(animacao, reduzir: reduzirMovimento), mudanca)
    }

    /// Espera o contêiner terminar de crescer e então pede a rolagem: o rodapé do editor (Cancelar e a seta)
    /// não pode ficar atrás do botão fixo da tela.
    private func pedirRolagemAoEditor() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            pedidoDeRolagem = Self.idDoEditor
        }
    }

    private func tocarDia(_ dia: Int) {
        animar {
            diaSelecionado = dia
            avisoDeRascunho = false
            if case .nova(let diaEmEdicao) = edicao?.origem, diaEmEdicao == dia { return }
            if janelas(do: dia).isEmpty {
                edicao = .nova(dia: dia)
            } else {
                edicao = nil
            }
        }
    }

    private func abrirNovo(dia: Int) {
        animar { edicao = .nova(dia: dia) }
    }

    private func adicionarOutroHorario() {
        animar { edicao = .nova(dia: diaSelecionado) }
    }

    private func abrirExistente(_ janela: JanelaDeDisponibilidade) {
        animar {
            diaSelecionado = janela.diaDaSemana
            edicao = .existente(janela)
        }
    }

    private func ir(para campo: CampoDeHorario) {
        animar(FrilaMotion.horarioDestaque) {
            edicao?.etapa = campo
            if campo == .fim { edicao?.fimVisitado = true }
        }
    }

    private func avancar() {
        guard let e = edicao else { return }
        if e.etapa == .inicio {
            ir(para: .fim)
        } else {
            concluir(e)
        }
    }

    private func concluir(_ e: EdicaoDeHorario) {
        guard e.inicio != e.fim else { return }
        animar {
            switch e.origem {
            case let .nova(dia):
                viewModel.adicionarJanela(diaDaSemana: dia, inicio: e.inicio, fim: e.fim)
            case let .existente(janela):
                let nova = JanelaDeDisponibilidade(diaDaSemana: janela.diaDaSemana, inicio: e.inicio, fim: e.fim)
                viewModel.substituirJanela(janela, por: nova)
            }
            edicao = nil
        }
    }

    private func cancelar() {
        animar(FrilaMotion.horarioRemover) {
            edicao = nil
            avisoDeRascunho = false
        }
    }

    private func remover(_ janela: JanelaDeDisponibilidade) {
        animar(FrilaMotion.horarioRemover) {
            viewModel.removerJanela(janela)
            if edicao?.origem == .existente(janela) { edicao = nil }
        }
    }
}
