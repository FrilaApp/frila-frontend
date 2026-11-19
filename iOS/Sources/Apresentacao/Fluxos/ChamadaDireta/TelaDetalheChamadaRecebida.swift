import FrilaDominio
import SwiftUI

/// A tela guarda o modelo em `@State`, e o `@State` sobrevive quando o roteador troca a chamada do aviso
/// por outra na mesma posição da pilha. A identidade pela chamada recria o estado e carrega a nova.
public struct TelaDetalheChamadaRecebida: View {
    private let viewModel: ChamadaRecebidaViewModel
    private let onAbrirTurno: ((UUID) -> Void)?

    public init(viewModel: ChamadaRecebidaViewModel, onAbrirTurno: ((UUID) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onAbrirTurno = onAbrirTurno
    }

    public var body: some View {
        ConteudoDaChamadaRecebida(viewModel: viewModel, onAbrirTurno: onAbrirTurno)
            .id(viewModel.chamadaID)
    }
}

private struct ConteudoDaChamadaRecebida: View {
    @State private var viewModel: ChamadaRecebidaViewModel
    var onAbrirTurno: ((UUID) -> Void)?
    @Environment(\.dismiss) private var fechar
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }

    init(viewModel: ChamadaRecebidaViewModel, onAbrirTurno: ((UUID) -> Void)?) {
        _viewModel = State(initialValue: viewModel)
        self.onAbrirTurno = onAbrirTurno
    }

    /// O que a tela mostra, na mesma ordem de prioridade de sempre.
    private enum Quadro {
        case carregando, erro(String), concorrencia(String), aceita(ResultadoChamada), recusada
        case detalhe(ChamadaDetalhe), nada
    }

    private var quadro: Quadro {
        if viewModel.carregando { return .carregando }
        if let erro = viewModel.erro { return .erro(erro) }
        if let msg = viewModel.mensagemConcorrencia { return .concorrencia(msg) }
        if let resultado = viewModel.resultado, resultado.chamada.estado == .aceita { return .aceita(resultado) }
        if let resultado = viewModel.resultado, resultado.chamada.estado == .recusada { return .recusada }
        if let detalhe = viewModel.detalhe { return .detalhe(detalhe) }
        return .nada
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                switch quadro {
                case .carregando:
                    EstadoCarregando()
                case let .erro(erro):
                    AvisoFrila(verbatim: erro, tom: .erro)
                    BotaoSecundario("Tentar novamente") {
                        Task { await viewModel.carregar() }
                    }
                case let .concorrencia(msg):
                    AvisoFrila(verbatim: msg, tom: .alerta)
                case let .aceita(resultado):
                    sucessoAceite(resultado)
                case .recusada:
                    AvisoFrila(verbatim: TextosChamadaDireta.chamadaRecusadaAviso, tom: .informativo)
                    // Recusar não tira o direito de denunciar ou bloquear quem chamou (CD-RF12, CD-S13).
                    if let detalhe = viewModel.detalhe { acoesDeSeguranca(detalhe.outraParte, chamadaID: detalhe.id) }
                case let .detalhe(detalhe):
                    conteudoChamada(detalhe)
                case .nada:
                    EmptyView()
                }
                // Com texto grande o grupo de botões ocuparia quase metade da tela: vai para o fim do conteúdo.
                if tamanhoDoTexto.isAccessibilitySize, rodapeVisivel {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) { rodape }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosChamadaDireta.chamadaRecebidaTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .rodapeAncoradoDoPerfilSe(rodapeVisivel && !tamanhoDoTexto.isAccessibilitySize) {
            rodape
        }
        .task { await viewModel.carregar() }
        .sheet(isPresented: $viewModel.mostrarRecusa) {
            sheetRecusa
        }
    }

    // MARK: Rodapé ancorado

    private var turnoAceito: UUID? {
        if case let .aceita(resultado) = quadro { return resultado.turnoID }
        return nil
    }

    private var podeResponderNaTela: Bool {
        guard case let .detalhe(detalhe) = quadro else { return false }
        return !bloqueios.contem(detalhe.outraParte) && viewModel.podeResponder
    }

    private var rodapeVisivel: Bool { turnoAceito != nil || podeResponderNaTela }

    /// O botão primário da tela: "Aceitar chamada" com "Recusar chamada" ao lado, ou "Ver meu turno" depois do aceite.
    @ViewBuilder
    private var rodape: some View {
        if let turnoID = turnoAceito {
            BotaoPrimario(verbatim: TextosChamadaDireta.verTurno) {
                if let onAbrirTurno {
                    onAbrirTurno(turnoID)
                } else {
                    fechar()
                }
            }
            .accessibilityIdentifier("ver-turno-aceito")
        } else {
            BotaoPrimario(verbatim: TextosChamadaDireta.aceitarChamada, carregando: viewModel.respondendo) {
                Task { await viewModel.aceitar() }
            }
            .accessibilityIdentifier("aceitar-chamada")

            BotaoSecundario(verbatim: TextosChamadaDireta.recusarChamada) {
                viewModel.mostrarRecusa = true
            }
            .disabled(viewModel.respondendo)
            .accessibilityIdentifier("recusar-chamada")
        }
    }

    // MARK: Conteúdo

    @ViewBuilder
    private func conteudoChamada(_ detalhe: ChamadaDetalhe) -> some View {
        // Quem chama, o que e quando: um cartão, com o valor no maior texto (DESIGN.md, "Card de vaga").
        VStack(alignment: .leading, spacing: 0) {
          VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.item) {
                    nomeDaCasa(detalhe)
                    Spacer(minLength: FrilaEspaco.item)
                    seloContaNova(detalhe)
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    seloContaNova(detalhe)
                    nomeDaCasa(detalhe)
                }
            }

            if detalhe.contaNova {
                Text(verbatim: TextosChamadaDireta.contaNovaAviso)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

          }

            FrilaDivisoria()

          VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            FrilaLinhaDeDado(icone: "briefcase") { Text(verbatim: detalhe.funcao.nome) }
            FrilaLinhaDeDado(icone: "clock") { Text(verbatim: FormatoDeHorarioDoTurno().comDia(inicio: detalhe.inicioEm, fim: detalhe.fimEm)) }
            FrilaLinhaDeDado(icone: "mappin") {
                if let faixa = detalhe.distanciaFaixa {
                    Text(verbatim: "\(detalhe.regiaoAdministrativa) • \(faixa.rotulo)")
                } else {
                    Text(verbatim: detalhe.regiaoAdministrativa)
                }
            }
          }

            FrilaDivisoria()

            Text(verbatim: viewModel.valorFormatado)
                .font(FrilaTipo.valorEmDestaque)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

        if let recado = detalhe.recado, !recado.isEmpty {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                rotulo(TextosChamadaDireta.recadoContratanteSecao)
                Text(verbatim: recado)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            rotulo(TextosChamadaDireta.inclusosSecao)
            if detalhe.incluiRefeicao {
                FrilaLinhaDeDado(icone: "fork.knife") {
                    Text("Refeição inclusa", bundle: bundleApresentacao)
                }
            }
            if detalhe.incluiTransporte {
                FrilaLinhaDeDado(icone: "car") {
                    Text("Transporte incluso", bundle: bundleApresentacao)
                }
            }
            if detalhe.exigeMaterialProprio {
                FrilaLinhaDeDado(icone: "wrench.and.screwdriver") {
                    Text("Exige material próprio", bundle: bundleApresentacao)
                }
            }
            if !detalhe.incluiRefeicao && !detalhe.incluiTransporte && !detalhe.exigeMaterialProprio {
                Text("Nenhum benefício adicional especificado.", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }

        // O prazo e o aviso de segurança, em tinta: problema (e urgência) não têm cor.
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: viewModel.expiraEmFormatado)
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: TextosChamadaDireta.avisoSeguranca)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }

        // Bloqueada a casa, a chamada não se responde mais: o servidor a encerra (`404`, RF26).
        if bloqueios.contem(detalhe.outraParte) {
            Text(verbatim: TextosDaSeguranca.voceBloqueouEstabelecimento)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("etiqueta-bloqueio-chamada")
        }

        acoesDeSeguranca(detalhe.outraParte, chamadaID: detalhe.id)
    }

    private func rotulo(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.rotuloDeGrupo)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func nomeDaCasa(_ detalhe: ChamadaDetalhe) -> some View {
        Text(verbatim: detalhe.outraParte.nome)
            .font(FrilaTipo.nome)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func seloContaNova(_ detalhe: ChamadaDetalhe) -> some View {
        if detalhe.contaNova {
            SeloDeStatus(verbatim: TextosChamadaDireta.contaNovaBadge, estilo: .contorno)
        }
    }

    /// CD-RF12: denúncia e bloqueio também a partir da chamada, sobre quem chamou. A denúncia leva o id da chamada
    /// (0.2.71, A-001).
    private func acoesDeSeguranca(_ quemChamou: PerfilPublico, chamadaID: UUID) -> some View {
        AcoesDeSeguranca(perfil: quemChamou, chamadaID: chamadaID, api: viewModel.api, bloqueios: bloqueios,
                         identificadorDenunciar: "denunciar-chamada", identificadorBloquear: "bloquear-chamada",
                         identificadorConfirmarBloqueio: "confirmar-bloqueio-chamada")
            .id(quemChamou.id)
    }

    @ViewBuilder
    private func sucessoAceite(_ resultado: ResultadoChamada) -> some View {
        AvisoFrila(verbatim: TextosChamadaDireta.chamadaAceitaMensagem, tom: .informativo)

        if let local = resultado.local {
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text("Endereço do turno:", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDeGrupo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: local)
                    .font(FrilaTipo.rotuloSecundario)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if let resp = resultado.responsavelLocal {
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text("Responsável no local:", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDeGrupo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: resp)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// O motivo da recusa é opcional e de escolha única: lista com check, e "Recusar chamada" no rodapé ancorado.
    private var sheetRecusa: some View {
        NavigationStack {
            ScrollView {
                FrilaGrupoDeLinhas(verbatim: TextosChamadaDireta.motivoRecusaTitulo, linhasComIcone: false) {
                    opcaoDeMotivo(String(localized: "Nenhum motivo específico", bundle: bundleApresentacao), motivo: nil)
                    opcaoDeMotivo(TextosChamadaDireta.motivoAgenda, motivo: .agenda)
                    opcaoDeMotivo(TextosChamadaDireta.motivoDistancia, motivo: .distancia)
                    opcaoDeMotivo(TextosChamadaDireta.motivoValor, motivo: .valor)
                    opcaoDeMotivo(TextosChamadaDireta.motivoTipoDeServico, motivo: .tipoDeServico)
                    opcaoDeMotivo(TextosChamadaDireta.motivoOutro, motivo: .outro)
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.bloco)
                .padding(.bottom, FrilaEspaco.grupo)
            }
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosChamadaDireta.recusarChamada))
            .navigationBarTitleDisplayMode(.inline)
            .rodapeAncorado {
                BotaoPrimario(verbatim: TextosChamadaDireta.recusarChamada, carregando: viewModel.respondendo) {
                    Task { await viewModel.recusar() }
                }
                .accessibilityIdentifier("confirmar-recusa-chamada")

                Button {
                    viewModel.mostrarRecusa = false
                } label: {
                    Text("Cancelar", bundle: bundleApresentacao)
                }
                .buttonStyle(.frilaAcaoDiscreta)
            }
        }
    }

    private func opcaoDeMotivo(_ titulo: String, motivo: MotivoRecusaChamada?) -> some View {
        FrilaLinhaDeOpcao(titulo: titulo, remate: .marcada(viewModel.motivoSelecionado == motivo)) {
            viewModel.motivoSelecionado = motivo
        }
    }
}
