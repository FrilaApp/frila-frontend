import FrilaDominio
import SwiftUI

/// Linha de dado de turno com ícone da pele nova: ícone de 20 pt alinhado à primeira linha base de texto.
public struct LinhaDoTurnoComIcone: View {
    @ScaledMetric(relativeTo: .subheadline) private var larguraDoIcone: CGFloat = 20
    let icone: String
    let texto: String

    public init(icone: String, texto: String) {
        self.icone = icone
        self.texto = texto
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .frame(width: larguraDoIcone)
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Cartão de turno do profissional para a lista simplificada ou retrocompatibilidade.
public struct CartaoMeuTurno: View {
    private let turno: Turno
    private let formatador = FormatadorFrila()

    public init(turno: Turno) {
        self.turno = turno
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                Text(verbatim: turno.contraparte.nome)
                    .font(FrilaTipo.tituloDoCartao)
                    .foregroundStyle(FrilaCor.texto)
                Text(verbatim: turno.vaga.funcao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                LinhaDoTurnoComIcone(icone: "clock", texto: formatador.intervalo(turno.vaga.periodo))
                LinhaDoTurnoComIcone(icone: "mappin", texto: turno.vaga.local)
            }
            .padding(.vertical, FrilaEspaco.fio)

            Rectangle().fill(FrilaCor.borda).frame(height: 1).accessibilityHidden(true)

            HStack {
                FrilaPriceTag(texto: formatador.dinheiro(turno.valorAcordado),
                              leitura: formatador.dinheiroFalado(turno.valorAcordado), tamanho: 28)
                Spacer()
                if turno.cancelado {
                    Label {
                        Text(verbatim: TextosDoProfissional.Turnos.canceladoTitulo)
                    } icon: {
                        Image(systemName: "xmark.circle")
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }
}

/// Tela de Meus Turnos da pele nova (T7): "Turnos" com quatro seções ordenadas:
/// 1. "Hoje": card de destaque com botão primário laranja "Estou a caminho";
/// 2. "Precisa de você": itens pendentes de avaliação ou verificação;
/// 3. "Próximos": turnos confirmados em datas futuras;
/// 4. "Histórico": total faturado no cabeçalho e lista de turnos concluídos.
/// Quando vazia, exibe o estado vazio (T7-sem-turnos).
public struct TelaMeusTurnos: View {
    @Bindable private var viewModel: MeusTurnosViewModel
    private let abrir: (Turno) -> Void
    private let formatador = FormatadorFrila()

    private var calendario: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = FormatadorFrila.fuso
        cal.locale = FormatadorFrila.locale
        return cal
    }

    public init(viewModel: MeusTurnosViewModel, abrir: @escaping (Turno) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    private var agora: Date { Date() }

    private var turnoHoje: Turno? {
        viewModel.turnos.first { turno in
            !turno.cancelado && turno.estado != .cumprida && calendario.isDate(turno.vaga.periodo.inicio, inSameDayAs: agora)
        }
    }

    private var turnosPrecisaDeVoce: [Turno] {
        viewModel.turnos.filter { turno in
            !turno.cancelado && (turno.podeAvaliar || turno.verificacao == .naoVerificado)
        }
    }

    private var turnosProximos: [Turno] {
        viewModel.turnos.filter { turno in
            !turno.cancelado &&
            turno.estado != .cumprida &&
            turno.vaga.periodo.inicio > agora &&
            !calendario.isDate(turno.vaga.periodo.inicio, inSameDayAs: agora)
        }
    }

    private var turnosHistorico: [Turno] {
        viewModel.turnos.filter { turno in
            turno.estado == .cumprida || (turno.vaga.periodo.fim < agora && turno.checkin != nil)
        }
    }

    private var turnosNaoClassificados: [Turno] {
        viewModel.turnos.filter { turno in
            turno != turnoHoje &&
            !turnosPrecisaDeVoce.contains(turno) &&
            !turnosProximos.contains(turno) &&
            !turnosHistorico.contains(turno)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if case let .carregada(_, origem) = viewModel.estado, origem == .cache {
                    AvisoFrila(verbatim: TextosDoProfissional.Turnos.avisoCache, tom: .informativo)
                        .accessibilityIdentifier("aviso-cache-turnos")
                }

                tituloTela
                conteudo
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.atualizar() }
        .task { if viewModel.estado == .ociosa { await viewModel.carregar() } }
        .atualizacaoAutomatica(.meusTurnos, recarregar: viewModel.atualizarEmSilencio)
        .accessibilityIdentifier("tela-meus-turnos")
    }

    private var tituloTela: some View {
        Text("Turnos", bundle: bundleApresentacao)
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .ociosa, .carregando:
            EstadoCarregando()
        case .carregada:
            if viewModel.turnos.isEmpty {
                estadoVazio
            } else {
                secoesTurnos
            }
        case let .falha(mensagem):
            EstadoErro(verbatim: mensagem) {
                Task { await viewModel.carregar() }
            }
            .accessibilityIdentifier("meus-turnos-erro")
        }
    }

    private var secoesTurnos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
            if let hoje = turnoHoje {
                secaoHoje(hoje)
            }

            if !turnosPrecisaDeVoce.isEmpty {
                secaoPrecisa(turnosPrecisaDeVoce)
            }

            let proximos = turnosProximos + turnosNaoClassificados
            if !proximos.isEmpty {
                secaoProximos(proximos)
            }

            if !turnosHistorico.isEmpty {
                secaoHistorico(turnosHistorico)
            }
        }
    }

    // MARK: - Seção Hoje

    private func secaoHoje(_ turno: Turno) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Hoje", bundle: bundleApresentacao)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                Button { abrir(turno) } label: {
                    VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                            Text(verbatim: turno.contraparte.nome)
                                .font(FrilaTipo.tituloDoCartao)
                                .foregroundStyle(FrilaCor.texto)
                            Text(verbatim: TextosDoProfissional.reputacaoDoEstabelecimento(turno.contraparte.reputacao))
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }

                        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                            LinhaDoTurnoComIcone(icone: "briefcase", texto: turno.vaga.funcao)
                            LinhaDoTurnoComIcone(
                                icone: "calendar",
                                texto: "\(formatadorDataCurta(turno.vaga.periodo.inicio)) \(formatadorHora(turno.vaga.periodo))"
                            )
                            LinhaDoTurnoComIcone(
                                icone: "mappin",
                                texto: turno.vaga.local
                            )
                        }
                        .padding(.vertical, FrilaEspaco.fio)

                        Rectangle()
                            .fill(FrilaCor.borda)
                            .frame(height: 1)
                            .accessibilityHidden(true)

                        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
                            Text(verbatim: formatador.dinheiro(turno.valorAcordado))
                                .font(FrilaTipo.valorEmDestaque)
                                .foregroundStyle(FrilaCor.texto)
                            Text("+ gorjeta", bundle: bundleApresentacao)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                        }

                        Text("Refeição e transporte inclusos", bundle: bundleApresentacao)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                }
                .buttonStyle(.plain)

                if turno.aCaminhoEm == nil && turno.checkin == nil {
                    BotaoPrimario("Estou a caminho") { abrir(turno) }
                        .accessibilityIdentifier("botao-a-caminho-hoje")
                } else if turno.checkin == nil {
                    BotaoSecundario("Marcar presença") { abrir(turno) }
                        .accessibilityIdentifier("botao-marcar-presenca-hoje")
                } else {
                    SeloDeStatus("Presença marcada", estilo: .andamento)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .elevacaoFrila(.suave)
            .accessibilityIdentifier("meu-turno-\(turno.id.uuidString)")
        }
    }

    // MARK: - Seção Precisa de você

    private func secaoPrecisa(_ turnos: [Turno]) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Precisa de você", bundle: bundleApresentacao)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: FrilaEspaco.compacto) {
                ForEach(turnos) { turno in
                    VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                        if turno.podeAvaliar {
                            SeloDeStatus("Concluído", estilo: .contorno)
                            Text(verbatim: turno.contraparte.nome)
                                .font(FrilaTipo.tituloDoCartao)
                                .foregroundStyle(FrilaCor.texto)
                            Text(verbatim: "\(formatadorDataCurta(turno.vaga.periodo.inicio)) \(formatadorHora(turno.vaga.periodo))")
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                            BotaoSecundario("Avaliar") { abrir(turno) }
                                .accessibilityIdentifier("avaliar-turno-\(turno.id.uuidString)")
                        } else if turno.verificacao == .naoVerificado {
                            Text(verbatim: turno.contraparte.nome)
                                .font(FrilaTipo.tituloDoCartao)
                                .foregroundStyle(FrilaCor.texto)
                            Text(verbatim: "\(formatadorDataCurta(turno.vaga.periodo.inicio)) \(formatadorHora(turno.vaga.periodo))")
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                            Text("Presença não confirmada", bundle: bundleApresentacao)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                            BotaoSecundario("Falar com o suporte") { abrir(turno) }
                                .accessibilityIdentifier("suporte-turno-\(turno.id.uuidString)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartaoFrila()
                    .accessibilityIdentifier("precisa-turno-\(turno.id.uuidString)")
                }
            }
        }
    }

    // MARK: - Seção Próximos

    private func secaoProximos(_ turnos: [Turno]) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Próximos", bundle: bundleApresentacao)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: FrilaEspaco.compacto) {
                ForEach(turnos) { turno in
                    Button { abrir(turno) } label: {
                        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                            HStack {
                                SeloDeStatus("Confirmado", estilo: .destaque, icone: "checkmark")
                                Spacer()
                            }

                            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                                Text(verbatim: turno.contraparte.nome)
                                    .font(FrilaTipo.tituloDoCartao)
                                    .foregroundStyle(FrilaCor.texto)
                                Text(verbatim: TextosDoProfissional.reputacaoDoEstabelecimento(turno.contraparte.reputacao))
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                            }

                            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                                LinhaDoTurnoComIcone(icone: "briefcase", texto: turno.vaga.funcao)
                                LinhaDoTurnoComIcone(
                                    icone: "calendar",
                                    texto: "\(formatadorDataCurta(turno.vaga.periodo.inicio)) \(formatadorHora(turno.vaga.periodo))"
                                )
                                LinhaDoTurnoComIcone(
                                    icone: "mappin",
                                    texto: turno.vaga.local
                                )
                            }
                            .padding(.vertical, FrilaEspaco.fio)

                            Rectangle()
                                .fill(FrilaCor.borda)
                                .frame(height: 1)
                                .accessibilityHidden(true)

                            Text(verbatim: formatador.dinheiro(turno.valorAcordado))
                                .font(FrilaTipo.valorEmDestaque)
                                .foregroundStyle(FrilaCor.texto)

                            Text("Transporte incluso", bundle: bundleApresentacao)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartaoFrila()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("meu-turno-\(turno.id.uuidString)")
                }
            }
        }
    }

    // MARK: - Seção Histórico

    private func secaoHistorico(_ turnos: [Turno]) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Histórico", bundle: bundleApresentacao)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            let totalCentavos = turnos.reduce(0) { $0 + $1.valorAcordado.centavos }
            let totalFaturado = Dinheiro(centavos: totalCentavos)

            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
                Text(verbatim: formatador.dinheiro(totalFaturado))
                    .font(FrilaTipo.valorEmDestaque)
                    .foregroundStyle(FrilaCor.texto)
                Text(verbatim: "\(turnos.count) \(turnos.count == 1 ? "turno" : "turnos")")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            VStack(spacing: 0) {
                ForEach(Array(turnos.enumerated()), id: \.element.id) { index, turno in
                    if index > 0 {
                        Rectangle().fill(FrilaCor.borda).frame(height: 1).accessibilityHidden(true)
                    }
                    Button { abrir(turno) } label: {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                                Text(verbatim: turno.contraparte.nome)
                                    .font(FrilaTipo.meta.weight(.semibold))
                                    .foregroundStyle(FrilaCor.texto)
                                Text(verbatim: formatadorDataCurta(turno.vaga.periodo.inicio))
                                    .font(FrilaTipo.nota)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                            }
                            Spacer()
                            Text(verbatim: formatador.dinheiro(turno.valorAcordado))
                                .font(FrilaTipo.meta.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)
                        }
                        .padding(.vertical, FrilaEspaco.pequeno)
                        .frame(minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("historico-turno-\(turno.id.uuidString)")
                }
            }
            .cartaoFrila()
        }
    }

    // MARK: - Estado Vazio (T7-sem-turnos)

    private var estadoVazio: some View {
        VStack(spacing: FrilaEspaco.compacto) {
            ZStack {
                RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous)
                    .fill(FrilaCor.superficie)
                    .frame(width: 96, height: 96)
                    .overlay(RoundedRectangle(cornerRadius: FrilaRaio.folha, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
                Image(systemName: "calendar.badge.clock")
                    .font(FrilaTipo.tituloDaTela)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .padding(.bottom, FrilaEspaco.minimo)
            .accessibilityHidden(true)

            Text("Você ainda não tem turnos.", bundle: bundleApresentacao)
                .font(FrilaTipo.corpo.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .multilineTextAlignment(.center)

            Text("Os turnos que você aceitar e as suas candidaturas aparecem aqui.", bundle: bundleApresentacao)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FrilaEspaco.medio)

            BotaoSecundario("Ver vagas na minha área") {
                // Navegar para a aba Vagas ou atualizar
            }
            .padding(.top, FrilaEspaco.minimo)
        }
        .padding(.vertical, FrilaEspaco.grande)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meus-turnos-vazio")
    }

    private func formatadorDataCurta(_ data: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = FormatadorFrila.locale
        formatter.timeZone = FormatadorFrila.fuso
        formatter.dateFormat = "EEE dd/MM"
        let raw = formatter.string(from: data).replacingOccurrences(of: ".", with: "")
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private func formatadorHora(_ periodo: Periodo) -> String {
        let formatter = DateFormatter()
        formatter.locale = FormatadorFrila.locale
        formatter.timeZone = FormatadorFrila.fuso
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: periodo.inicio)) às \(formatter.string(from: periodo.fim))"
    }
}
